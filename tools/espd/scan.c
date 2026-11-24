// scan.c — 见 scan.h
#define _GNU_SOURCE
#include "scan.h"
#include "espd.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <stdarg.h>

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

static int find_name_strings(int pid, const vm_maps *m, const char *soname,
                             const char *name, str_hit *hits, int cap) {
    char needle[128];
    int nl = snprintf(needle, sizeof needle, "%s", name) + 1;  /* 连 NUL 一起匹配 */
    if (nl <= 1 || nl > (int)sizeof needle) return 0;

    int n = 0;
    /* pass 0：soname 自己的段（metadata 字符串通常在这里）
     * pass 1：其他可读段（il2cpp 也可能把 metadata 单独 mmap 成 [anon:...]） */
    for (int pass = 0; pass < 2 && n == 0; pass++) {
        size_t sl = strlen(soname);
        for (int i = 0; i < m->n && n < cap; i++) {
            const vm_map *e = &m->items[i];
            if (e->perms[0] != 'r') continue;
            if (pass == 0) {
                const char *p = e->path;
                size_t pl = strlen(p);
                if (pl < sl || strcmp(p + pl - sl, soname) != 0) continue;
            } else {
                /* 跳过文件映射与特殊段：[anon:*] 与空路径都参与 */
                const char *p = e->path;
                if (p[0] == '/') continue;
                if (p[0] == '[' && strncmp(p, "[anon:", 6) != 0) continue;
                if (e->end - e->start > 1024ull << 20) continue;
            }
            size_t len = (size_t)(e->end - e->start);
            uint64_t at = e->start;
            while (len) {
                uint64_t h = vm_find_bytes(pid, at, len, needle, (size_t)nl);
                if (!h) break;
                if (n < cap) hits[n++].addr = h;
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

/* Il2CppClass 候选校验：name/namespaze 都必须解析正确 */
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
        char nm[128];
        if (c->fields_off) {
            for (int f = 0; f < c->field_count && f < 64; f++) {
                uint64_t fi = vm_read_ptr(pid, c->klass + (uint64_t)c->fields_off, NULL)
                              + (uint64_t)f * 0x20;
                int32_t off;
                uint64_t tp;
                if (!fieldinfo_ok(pid, fi, &tp, &off)) continue;
                if (off < -1) continue;
                uint64_t v = vm_read_ptr(pid, sp + (uint64_t)off, 0);
                if (looks_like_ptr(v)) { plausible = 1; break; }
            }
        }
        (void)nm;
        if (!plausible) {
            /* 没有字段信息时，退化为「至少里头有像指针的值」 */
            uint64_t v0 = vm_read_ptr(pid, sp, 0);
            uint64_t v8 = vm_read_ptr(pid, sp + 8, 0);
            plausible = looks_like_ptr(v0) || looks_like_ptr(v8);
        }
        if (plausible) { c->static_fields_off = cand[i]; return; }
    }
}

int scan_find_class(int pid, const vm_maps *m, const char *soname,
                    const char *ns, const char *name, ic_class *out) {
    memset(out, 0, sizeof *out);
    if (ns) snprintf(out->ns, sizeof out->ns, "%s", ns);
    snprintf(out->name, sizeof out->name, "%s", name);

    str_hit hits[MAX_STR_HITS];
    int nh = find_name_strings(pid, m, soname, name, hits, MAX_STR_HITS);
    if (nh == 0) { set_err("字符串 '%s' 未在 %s 的映射里找到", name, soname); return -1; }

    for (int i = 0; i < nh; i++) {
        uint64_t refs[64];
        int nr = find_ptr_refs(pid, m, soname, hits[i].addr, refs, 64);
        for (int j = 0; j < nr; j++) {
            uint64_t klass = refs[j] - 0x10;
            if (!validate_class(pid, klass, ns, name)) continue;
            out->klass = klass;
            if (probe_fields(pid, out) == 0) {
                if (!out->field_count)
                    scan_set_warn("类 %s.%s 找到 fields 但字段数未知（Il2CppClass 布局可能变了，请用 scan 输出核对）",
                                  ns ? ns : "", name);
                else
                    probe_static_fields(pid, out);
            }
            return 0;
        }
    }
    set_err("找到字符串但没有任何类引用它（ns=%s name=%s）", ns ? ns : "", name);
    return -1;
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

