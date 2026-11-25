// scan.c — 见 scan.h
#define _GNU_SOURCE
#include "scan.h"
#include "espd.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdarg.h>
#include <time.h>

static char g_err[256];

const char *scan_last_error(void) { return g_err; }

void scan_set_warn(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_err, sizeof g_err, fmt, ap);
    va_end(ap);
}

static void set_err(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vsnprintf(g_err, sizeof g_err, fmt, ap);
    va_end(ap);
}

/* ---------- 小工具 ---------- */

static int ident_char(char c) {
    return (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
           (c >= '0' && c <= '9') || c == '_' || c == '<' || c == '>' ||
           c == '`' || c == '.' || c == '$' || c == '@' || c == '-';
}

/* 判断 addr 处是否一个「像标识符」的 C 字符串，成功时拷进 out */
static int read_ident(int pid, uint64_t addr, char *out, size_t cap) {
    if (!addr) return 0;
    char buf[256];
    int n = vm_read_str(pid, addr, buf, sizeof buf);
    if (n < 1 || n > 120) return 0;
    for (int i = 0; i < n; i++) if (!ident_char(buf[i])) return 0;
    if (out) snprintf(out, cap, "%s", buf);
    return 1;
}

/* 值的形态像 arm64 用户态指针（0x12_0000_0000 ~ 0x7fff_ffff_ffff，且 8 对齐） */
static int looks_like_ptr(uint64_t v) {
    return v >= 0x100000000ull && v < 0x800000000000ull && (v & 7) == 0;
}

/* ---------- 类定位 ---------- */

/* 在 libil2cpp 的可读段里找 name 字符串的所有出现位置 */
typedef struct { uint64_t addr; } str_hit;
#define MAX_STR_HITS 32
#define MAX_TARGETS  64

/* 字符串搜索的总时限（多类共享）。超过就不再找，避免在超大 metadata 上卡太久。
 * 0 = 不限。 */
static uint64_t g_str_deadline;

static int str_deadline_hit(void) {
    return g_str_deadline && now_ms() > g_str_deadline;
}

/* 命中点是否是一个 C 字符串的开头（前一个字节为 NUL）。
 * 不做这个检查的话 "OrthographicCamera\0" 里的 "Camera\0" 也会被当成命中，
 * 32 个额度瞬间被垃圾填满，真正的 metadata 那份反而挤不进去。 */
static int at_str_start(int pid, uint64_t h, uint64_t map_start) {
    if (h == map_start) return 1;
    unsigned char c = 0xff;
    if (vm_read(pid, h - 1, &c, 1) != 0) return 0;
    return c == 0;
}

static int find_name_strings(int pid, const vm_maps *m, const char *soname,
                             const char *name, str_hit *hits, int cap) {
    char needle[128];
    int nl = snprintf(needle, sizeof needle, "%s", name) + 1;  /* 连 NUL 一起匹配 */
    if (nl <= 1 || nl > (int)sizeof needle) return 0;
    if (g_str_deadline && now_ms() > g_str_deadline) return 0;

    int n = 0;
    /* pass 0：soname 自己的段（部分 Unity 版本把类型名放在 .so 的 rodata）
     * pass 1：其他匿名可读段（il2cpp 的 global-metadata.dat 常被 mmap 成 [anon:...]）
     * 两遍都要扫：只认 pass 0 会拿到 .so 里那份「没人引用」的副本，
     * 而真正的 Il2CppClass->name 指向 metadata 里的那份。 */
    for (int pass = 0; pass < 2; pass++) {
        size_t sl = strlen(soname);
        /* 每遍各留额度：pass 0 最多占一半，保证 metadata 那份一定有位置 */
        int lim = (pass == 0) ? cap / 2 : cap;
        for (int i = 0; i < m->n && n < lim; i++) {
            if (str_deadline_hit()) return n;
            const vm_map *e = &m->items[i];
            if (e->perms[0] != 'r') continue;
            if (pass == 0) {
                const char *p = e->path;
                size_t pl = strlen(p);
                if (pl < sl || strcmp(p + pl - sl, soname) != 0) continue;
            } else {
                /* 跳过文件映射与特殊段：[anon:*] 与空路径都参与；
                 * 少数 Unity 版本把 global-metadata.dat 直接 mmap 成文件映射。 */
                const char *p = e->path;
                if (p[0] == '/') {
                    const char *bn = strrchr(p, '/');
                    bn = bn ? bn + 1 : p;
                    if (!strstr(bn, "metadata") && !strstr(bn, ".dat")) continue;
                } else if (p[0] == '[' && strncmp(p, "[anon:", 6) != 0) {
                    continue;
                }
                if (e->end - e->start > 1024ull << 20) continue;
            }
            size_t len = (size_t)(e->end - e->start);
            uint64_t at = e->start;
            while (len && n < lim && !str_deadline_hit()) {
                uint64_t h = vm_find_bytes(pid, at, len, needle, (size_t)nl);
                if (!h) break;
                if (at_str_start(pid, h, e->start)) hits[n++].addr = h;
                uint64_t next = h + 1;
                if (next <= at) break;
                len -= (size_t)(next - at);
                at = next;
            }
        }
    }
    return n;
}

/* 在 libil2cpp 可写段里找「值 == target 的 8 字节」 */
static int find_ptr_refs(int pid, const vm_maps *m, const char *soname,
                         uint64_t target, uint64_t *out, int cap) {
    int n = 0;
    size_t sl = strlen(soname);
    unsigned char needle[8];
    for (int i = 0; i < 8; i++) needle[i] = (unsigned char)(target >> (8 * i));

    for (int i = 0; i < m->n && n < cap; i++) {
        const vm_map *e = &m->items[i];
        if (e->perms[0] != 'r' || e->perms[1] != 'w') continue;
        const char *p = e->path;
        size_t pl = strlen(p);
        if (pl < sl || strcmp(p + pl - sl, soname) != 0) continue;

        size_t len = (size_t)(e->end - e->start);
        uint64_t at = e->start;
        while (len) {
            uint64_t h = vm_find_bytes(pid, at, len, needle, sizeof needle);
            if (!h) break;
            if (n < cap) out[n++] = h;
            uint64_t next = h + 1;
            if (next <= at) break;
            len -= (size_t)(next - at);
            at = next;
        }
    }
    return n;
}

/* ---------- 堆内引用扫描 ----------
 * il2cpp 的 Il2CppClass / FieldInfo 由 IL2CPP_CALLOC 分配在 native 堆
 * （Android 上是 [anon:scudo:*] / 完全匿名段），并不在 libil2cpp.so 自己的
 * rw 段里。所以「值 == 类名字符串地址」的 8 字节槽位只能去堆里找。
 *
 * 一次堆扫描可以同时服务同一轮 resolve 的所有类：把候选字符串地址收集成
 * 集合，扫堆时对命中的槽位**当场做类结构校验**（而不是先存下来再校验），
 * 这样不存在「命中太多把数组撑爆、把真正那条挤掉」的问题。
 * 分块读（1MB）+ 字节/时间预算，避免在超大堆上卡死。
 */
#define HEAP_SCAN_CHUNK   (1u << 20)
#define HEAP_SMALL_MAP    (4ull << 20)      /* 小对象 arena 上限：Il2CppClass 都在这里 */
#define HEAP_SCAN_BUDGET  (4096ull << 20)   /* 全量阶段最多扫 4GB */
#define HEAP_SCAN_MS_MAX  6000              /* 单次最多 6s */

static struct {
    unsigned long long bytes;
    int ms;
    int maps;
    int truncated;
    int hits;        /* 命中目标地址的槽位数（候选） */
} g_heap;

static void heap_stats_reset(void) { memset(&g_heap, 0, sizeof g_heap); }

void scan_heap_stats(char *out, size_t cap) {
    snprintf(out, cap, "堆扫描 %d 段/%lluMB/%dms 候选%d%s",
             g_heap.maps, g_heap.bytes >> 20, g_heap.ms, g_heap.hits,
             g_heap.truncated ? "（预算截断，可能漏）" : "");
}

static int u64cmp(const void *a, const void *b) {
    uint64_t x = *(const uint64_t *)a, y = *(const uint64_t *)b;
    return (x > y) - (x < y);
}

static int u64_in(const uint64_t *arr, int n, uint64_t v) {
    int lo = 0, hi = n - 1;
    while (lo <= hi) {
        int mid = lo + ((hi - lo) >> 1);
        if (arr[mid] == v) return 1;
        if (arr[mid] < v) lo = mid + 1; else hi = mid - 1;
    }
    return 0;
}

static int validate_class(int pid, uint64_t klass, const char *ns, const char *name);

typedef struct {
    const cls_q *q;
    ic_class *out;
    const str_hit *sh;
    int nsh;
} heap_query;

/* 扫匿名堆；对命中目标地址的槽位当场校验，解析成功即写入 hq[i].out->klass。
 * targets 会被就地排序。max_map 限制单段大小（先用小 arena 快速试，再全量）。
 * 返回本次新解析出的类个数。 */
static int heap_scan(int pid, const vm_maps *m, uint64_t *targets, int nt,
                     heap_query *hq, int nq, uint64_t max_map) {
    if (nt <= 0 || nq <= 0) return 0;

    qsort(targets, (size_t)nt, sizeof *targets, u64cmp);
    uint64_t tmin = targets[0], tmax = targets[nt - 1];

    static unsigned char buf[HEAP_SCAN_CHUNK];
    uint64_t t0 = now_ms();
    unsigned long long bytes0 = g_heap.bytes;
    int resolved = 0;

    for (int i = 0; i < m->n; i++) {
        const vm_map *e = &m->items[i];
        if (e->perms[0] != 'r' || e->perms[1] != 'w') continue;

        const char *p = e->path;
        if (p[0] == '/') continue;                       /* 文件映射：so/普通文件 */
        if (p[0] == '[' &&
            strncmp(p, "[anon:", 6) != 0 && strncmp(p, "[heap", 5) != 0) continue;

        uint64_t len = e->end - e->start;
        if (len < 8) continue;
        if (len > max_map) continue;

        g_heap.maps++;
        uint64_t at = e->start;
        while (at + 8 <= e->end) {
            if (g_heap.bytes - bytes0 >= HEAP_SCAN_BUDGET || now_ms() - t0 > HEAP_SCAN_MS_MAX) {
                g_heap.truncated = 1;
                g_heap.ms += (int)(now_ms() - t0);
                return resolved;
            }
            size_t n = (size_t)((e->end - at) < HEAP_SCAN_CHUNK ? (e->end - at) : HEAP_SCAN_CHUNK);
            n &= ~(size_t)7;
            if (n < 8) break;
            if (vm_read(pid, at, buf, n) != 0) { at += n; continue; }
            g_heap.bytes += n;
            for (size_t off = 0; off + 8 <= n; off += 8) {
                uint64_t v;
                memcpy(&v, buf + off, 8);
                if (v < tmin || v > tmax) continue;
                if (!u64_in(targets, nt, v)) continue;
                g_heap.hits++;

                uint64_t klass = at + off - 0x10;
                for (int k = 0; k < nq; k++) {
                    if (hq[k].out->klass) continue;
                    int match = 0;
                    for (int j = 0; j < hq[k].nsh; j++)
                        if (hq[k].sh[j].addr == v) { match = 1; break; }
                    if (!match) continue;
                    if (!validate_class(pid, klass, hq[k].q->ns, hq[k].q->name)) continue;
                    hq[k].out->klass = klass;
                    resolved++;
                }
                if (resolved == nq) {
                    g_heap.ms += (int)(now_ms() - t0);
                    return resolved;
                }
            }
            at += n;
        }
    }
    g_heap.ms += (int)(now_ms() - t0);
    return resolved;
}


static int validate_class(int pid, uint64_t klass, const char *ns, const char *name) {
    if (!klass || (klass & 7)) return 0;
    char got_name[128], got_ns[128];
    uint64_t np = vm_read_ptr(pid, klass + 0x10, NULL);
    uint64_t sp = vm_read_ptr(pid, klass + 0x18, NULL);
    if (!read_ident(pid, np, got_name, sizeof got_name)) return 0;
    if (strcmp(got_name, name) != 0) return 0;
    if (ns && *ns) {
        if (!read_ident(pid, sp, got_ns, sizeof got_ns)) return 0;
        if (strcmp(got_ns, ns) != 0) return 0;
    }
    /* image 指针必须可读，排除偶然命中的字符串表本身 */
    uint64_t img = vm_read_ptr(pid, klass + 0x0, NULL);
    if (!looks_like_ptr(img)) return 0;
    return 1;
}

/* FieldInfo 是否像真的：name 可解析 + offset 合理 */
static int fieldinfo_ok(int pid, uint64_t fi, uint64_t *type_out, int32_t *off_out) {
    if (!fi || (fi & 7)) return 0;
    char nm[128];
    uint64_t np = vm_read_ptr(pid, fi + 0x00, NULL);
    if (!read_ident(pid, np, nm, sizeof nm)) return 0;
    uint64_t tp = vm_read_ptr(pid, fi + 0x08, NULL);
    if (!looks_like_ptr(tp)) return 0;
    int32_t off = vm_read_i32(pid, fi + 0x18, -999999);
    if (off < -1 || off > 0x200000) return 0;
    if (type_out) *type_out = tp;
    if (off_out) *off_out = off;
    return 1;
}

static int probe_fields(int pid, ic_class *c) {
    static const int cand[] = { 0x78, 0x80, 0x88, 0x90, 0x98, 0xa0, 0xa8 };
    for (size_t ci = 0; ci < sizeof cand / sizeof cand[0]; ci++) {
        int fo = cand[ci];
        uint64_t fp = vm_read_ptr(pid, c->klass + (uint64_t)fo, NULL);
        if (!looks_like_ptr(fp)) continue;
        if (!fieldinfo_ok(pid, fp, NULL, NULL)) continue;

        /* 找到 fields 后再探 field_count：用「最后一名字段必须可解析」交叉验证 */
        static const int ccand[] = { 0x10c, 0x110, 0x114, 0x118, 0x11c, 0x120,
                                     0x124, 0x128, 0x0fc, 0x100, 0x104, 0x108 };
        for (size_t cj = 0; cj < sizeof ccand / sizeof ccand[0]; cj++) {
            int co = ccand[cj];
            uint32_t raw = vm_read_u32(pid, c->klass + (uint64_t)co, 0xffffffffu);
            if (raw == 0xffffffffu) continue;
            uint32_t cnt = raw & 0xffff;
            uint32_t cnt_hi = raw >> 16;
            if (cnt < 1 || cnt > 2048) continue;
            if (cnt_hi != 0 && cnt_hi > 2048) continue;

            /* 抽查首项 + 末项 */
            uint64_t first = fp;
            uint64_t last = fp + (uint64_t)(cnt - 1) * 0x20;
            if (!fieldinfo_ok(pid, first, NULL, NULL)) continue;
            if (!fieldinfo_ok(pid, last, NULL, NULL)) continue;
            c->fields_off = fo;
            c->field_count = (int)cnt;
            return 0;
        }
        /* count 的候选偏移都没命中。这里刻意不「顺着 fields 数组数」——
         * il2cpp 的 fields 是连续 FieldInfo 数组，末尾之后往往是别的有效数据，
         * 多数出来的字段会带着错误 offset，按名字匹配时会静默取错偏移（更难查）。
         * 保留 fields_off 但不猜 count，让上层能明确报告「字段数未知」，
         * 并给出 scan 输出供人工核对，而不是伪造一个可能出错的 count。 */
        c->fields_off = fo;
        c->field_count = 0;
        return 0;
    }
    return -1;
}

static void probe_static_fields(int pid, ic_class *c) {
    static const int cand[] = { 0xb0, 0xb8, 0xc0, 0xc8, 0xd0, 0xd8,
                                0xe0, 0xe8, 0xf0, 0xf8, 0x100, 0x108 };
    for (size_t i = 0; i < sizeof cand / sizeof cand[0]; i++) {
        uint64_t sp = vm_read_ptr(pid, c->klass + (uint64_t)cand[i], NULL);
        if (!looks_like_ptr(sp)) continue;
        /* static_fields 一般是一小块；读一个小字段看是否像对象指针 */
        int plausible = 0;
        uint64_t fbase = c->fields_off
                       ? vm_read_ptr(pid, c->klass + (uint64_t)c->fields_off, NULL) : 0;
        if (fbase) {
            for (int f = 0; f < c->field_count && f < 64; f++) {
                uint64_t fi = fbase + (uint64_t)f * 0x20;
                int32_t off;
                uint64_t tp;
                if (!fieldinfo_ok(pid, fi, &tp, &off)) continue;
                if (off < -1) continue;
                uint64_t v = vm_read_ptr(pid, sp + (uint64_t)off, 0);
                if (looks_like_ptr(v)) { plausible = 1; break; }
            }
        }
        if (!plausible) {
            /* 没有字段信息时，退化为「至少里头有像指针的值」 */
            uint64_t v0 = vm_read_ptr(pid, sp, 0);
            uint64_t v8 = vm_read_ptr(pid, sp + 8, 0);
            plausible = looks_like_ptr(v0) || looks_like_ptr(v8);
        }
        if (plausible) { c->static_fields_off = cand[i]; return; }
    }
}

int scan_find_classes(int pid, const vm_maps *m, const char *soname,
                      const cls_q *qs, ic_class *outs, int nq) {
    if (!qs || !outs || nq <= 0 || nq > SCAN_MAX_QUERIES) return -1;

    for (int i = 0; i < nq; i++) {
        memset(&outs[i], 0, sizeof outs[i]);
        if (qs[i].ns) snprintf(outs[i].ns, sizeof outs[i].ns, "%s", qs[i].ns);
        snprintf(outs[i].name, sizeof outs[i].name, "%s", qs[i].name);
    }

    /* 1) 每类先收集所有名字符串出现位置（.so + 匿名段两遍都扫） */
    static str_hit sh[SCAN_MAX_QUERIES][MAX_STR_HITS];
    int nsh[SCAN_MAX_QUERIES];
    uint64_t targets[MAX_TARGETS];
    int nt = 0;

    g_str_deadline = now_ms() + 8000;   /* 字符串搜索总共最多 8s */
    for (int i = 0; i < nq; i++) {
        nsh[i] = find_name_strings(pid, m, soname, qs[i].name, sh[i], MAX_STR_HITS);
        for (int j = 0; j < nsh[i] && nt < MAX_TARGETS; j++) {
            int dup = 0;
            for (int k = 0; k < nt; k++) if (targets[k] == sh[i][j].addr) { dup = 1; break; }
            if (!dup) targets[nt++] = sh[i][j].addr;
        }
    }
    g_str_deadline = 0;

    /* 2) 快路径：类表正好落在 .so 自己的 rw 段（部分 Unity/加固版本） */
    int unresolved = 0;
    for (int i = 0; i < nq; i++) {
        int done = 0;
        for (int j = 0; j < nsh[i] && !done; j++) {
            uint64_t refs[64];
            int nr = find_ptr_refs(pid, m, soname, sh[i][j].addr, refs, 64);
            for (int k = 0; k < nr; k++) {
                uint64_t klass = refs[k] - 0x10;
                if (!validate_class(pid, klass, qs[i].ns, qs[i].name)) continue;
                outs[i].klass = klass;
                done = 1;
                break;
            }
        }
        if (!done) unresolved = 1;
    }

    /* 3) 慢路径：先只扫小对象 arena（Il2CppClass 都分配在这里，快且不压内存），
     *    不行再全量扫。一次扫描服务所有还没解析出来的类。 */
    heap_stats_reset();
    if (unresolved && nt > 0) {
        heap_query hq[SCAN_MAX_QUERIES];
        int nhq = 0;
        for (int i = 0; i < nq; i++) {
            if (outs[i].klass || nsh[i] == 0) continue;   /* 没字符串的类扫堆也白扫 */
            hq[nhq].q = &qs[i];
            hq[nhq].out = &outs[i];
            hq[nhq].sh = sh[i];
            hq[nhq].nsh = nsh[i];
            nhq++;
        }
        if (nhq) {
            heap_scan(pid, m, targets, nt, hq, nhq, HEAP_SMALL_MAP);
            int left = 0;
            for (int i = 0; i < nhq; i++) if (!hq[i].out->klass) left++;
            if (left) heap_scan(pid, m, targets, nt, hq, nhq, 1ull << 30);
        }
    }

    /* 4) 字段布局探测 */
    for (int i = 0; i < nq; i++) {
        if (!outs[i].klass) continue;
        if (probe_fields(pid, &outs[i]) == 0) {
            if (!outs[i].field_count)
                scan_set_warn("类 %s.%s 找到 fields 但字段数未知（Il2CppClass 布局可能变了，请用 scan 输出核对）",
                              qs[i].ns ? qs[i].ns : "", qs[i].name);
            else
                probe_static_fields(pid, &outs[i]);
        }
    }

    /* 5) 失败诊断：把所有没解析出来的类一次说清，并带上堆扫描统计 */
    int bad = 0;
    char msg[400];
    msg[0] = 0;
    for (int i = 0; i < nq; i++) {
        if (outs[i].klass) continue;
        bad++;
        char tmp[180];
        if (nsh[i] == 0)
            snprintf(tmp, sizeof tmp, "%s.%s 字符串未找到",
                     qs[i].ns ? qs[i].ns : "", qs[i].name);
        else
            snprintf(tmp, sizeof tmp, "%s.%s 有字符串(%d处)但无有效类引用",
                     qs[i].ns ? qs[i].ns : "", qs[i].name, nsh[i]);
        if (msg[0]) strncat(msg, "；", sizeof msg - strlen(msg) - 1);
        strncat(msg, tmp, sizeof msg - strlen(msg) - 1);
    }
    if (bad) {
        char hs[160];
        scan_heap_stats(hs, sizeof hs);
        set_err("%s（%s）", msg, hs);
        return -1;
    }
    return 0;
}

int scan_find_class(int pid, const vm_maps *m, const char *soname,
                    const char *ns, const char *name, ic_class *out) {
    cls_q q;
    q.ns = ns;
    q.name = name;
    ic_class c;
    memset(&c, 0, sizeof c);
    if (scan_find_classes(pid, m, soname, &q, &c, 1) != 0) {
        memset(out, 0, sizeof *out);
        return -1;
    }
    *out = c;
    return 0;
}

int scan_fields(int pid, const ic_class *c, ic_field *out, int cap) {
    if (!c->fields_off || !c->field_count) return -1;
    int n = 0;
    for (int i = 0; i < c->field_count && n < cap; i++) {
        uint64_t base = vm_read_ptr(pid, c->klass + (uint64_t)c->fields_off, NULL);
        uint64_t fi = base + (uint64_t)i * 0x20;
        char nm[128];
        uint64_t tp;
        int32_t off;
        if (!fieldinfo_ok(pid, fi, &tp, &off)) continue;
        if (!read_ident(pid, vm_read_ptr(pid, fi, NULL), nm, sizeof nm)) continue;
        snprintf(out[n].name, sizeof out[n].name, "%s", nm);
        out[n].offset = off;
        out[n].type_ptr = tp;
        /* Il2CppType.attrs 在 +0x08，FIELD_ATTRIBUTE_STATIC = 0x10 */
        uint32_t attrs = vm_read_u32(pid, tp + 0x08, 0);
        out[n].is_static = (attrs & 0x10) != 0;
        n++;
    }
    return n;
}

int scan_prepare(int pid, uint64_t klass, const char *ns, const char *name, ic_class *out) {
    if (!klass || !out) return -1;
    memset(out, 0, sizeof *out);
    out->klass = klass;
    if (ns) snprintf(out->ns, sizeof out->ns, "%s", ns);
    if (name) snprintf(out->name, sizeof out->name, "%s", name);
    if (probe_fields(pid, out) == 0) probe_static_fields(pid, out);
    /* fields 探测出来就算可用；static 探不到不影响实例字段读取 */
    return out->fields_off ? 0 : -1;
}

int scan_field_by_name(int pid, const ic_class *c, const char *name, ic_field *out) {
    if (!c->fields_off || !c->field_count) return -1;
    uint64_t base = vm_read_ptr(pid, c->klass + (uint64_t)c->fields_off, NULL);
    for (int i = 0; i < c->field_count; i++) {
        uint64_t fi = base + (uint64_t)i * 0x20;
        char nm[128];
        if (!read_ident(pid, vm_read_ptr(pid, fi, NULL), nm, sizeof nm)) continue;
        if (strcmp(nm, name) != 0) continue;
        uint64_t tp;
        int32_t off;
        if (!fieldinfo_ok(pid, fi, &tp, &off)) return -1;
        snprintf(out->name, sizeof out->name, "%s", nm);
        out->offset = off;
        out->type_ptr = tp;
        out->is_static = (vm_read_u32(pid, tp + 0x08, 0) & 0x10) != 0;
        return 0;
    }
    set_err("类 %s.%s 里没有字段 %s", c->ns, c->name, name);
    return -1;
}

uint64_t scan_static_object(int pid, const ic_class *c, const ic_field *f) {
    if (!c->static_fields_off || !f) return 0;
    uint64_t sf = vm_read_ptr(pid, c->klass + (uint64_t)c->static_fields_off, NULL);
    if (!looks_like_ptr(sf)) return 0;
    return vm_read_ptr(pid, sf + (uint64_t)(uint32_t)f->offset, 0);
}

uint64_t scan_obj_ptr(int pid, uint64_t obj, const ic_field *f) {
    if (!obj || !f) return 0;
    return vm_read_ptr(pid, obj + (uint64_t)(uint32_t)f->offset, 0);
}

