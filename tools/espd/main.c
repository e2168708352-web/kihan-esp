// main.c — espd 进程外只读 ESP daemon
//
// 模式：
//   espd probe                 自检：pid / maps / ELF / SELinux 域 / TracerPid
//   espd selftest              投影数学自测（纯 CPU，不需要设备）
//   espd scan <类名> [命名空间] 扫描 il2cpp 类并打印字段名+偏移
//   espd daemon                常驻：读内存 → 投影 → UDP → status.json
//
// 全局参数：--pkg NAME --so NAME --dir PATH --port N --interval MS --once
#define _GNU_SOURCE
#include "espd.h"
#include "vm.h"
#include "scan.h"
#include "project.h"
#include "udp.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>
#include <errno.h>
#include <time.h>
#include <math.h>

static volatile int g_stop = 0;
static void on_signal(int s) { (void)s; g_stop = 1; }

typedef struct {
    const char *pkg;
    const char *so;
    const char *dir;
    int port, interval;
    int port_set, interval_set;   /* 命令行是否显式指定（conf 只在未指定时覆盖） */
    int once;
} opts;

/* ---------- probe ---------- */

static int read_tracerpid(int pid) {
    char p[64], line[256];
    snprintf(p, sizeof p, "/proc/%d/status", pid);
    FILE *f = fopen(p, "r");
    if (!f) return -1;
    int v = -1;
    while (fgets(line, sizeof line, f)) {
        if (strncmp(line, "TracerPid:", 10) == 0) { v = atoi(line + 10); break; }
    }
    fclose(f);
    return v;
}

static int mode_probe(const opts *o) {
    int pid = vm_find_pid(o->pkg);
    if (pid < 0) { espd_log("%s 未运行", o->pkg); return 3; }

    vm_maps m;
    if (vm_load_maps(pid, &m) != 0) { espd_log("maps 读取失败: %s", strerror(errno)); return 4; }

    uint64_t il2cpp = vm_module_base(&m, o->so);
    uint64_t unity  = vm_module_base(&m, "libunity.so");
    uint64_t elf_base = il2cpp ? il2cpp : vm_module_base(&m, "libc.so");
    unsigned char eh[16];
    int elf_ok = 0;
    if (elf_base && vm_read(pid, elf_base, eh, sizeof eh) == 0)
        elf_ok = (eh[0] == 0x7f && eh[1] == 'E' && eh[2] == 'L' && eh[3] == 'F');

    char domain[128];
    selinux_domain(domain, sizeof domain);
    int tracer = read_tracerpid(pid);

    char status[2048];
    int n = snprintf(status, sizeof status,
        "{\n  \"ts\": %ld,\n  \"pkg\": \"%s\",\n  \"pid\": %d,\n  \"maps\": %d,\n"
        "  \"il2cpp_base\": %llu,\n  \"unity_base\": %llu,\n  \"elf_base\": %llu,\n"
        "  \"elf_ok\": %d,\n  \"tracerpid\": %d,\n  \"domain\": \"%s\",\n  \"version\": \"%s\"\n}\n",
        (long)time(NULL), o->pkg, pid, m.n,
        (unsigned long long)il2cpp, (unsigned long long)unity,
        (unsigned long long)elf_base, elf_ok, tracer, domain, ESPD_VERSION);

    char path[512];
    snprintf(path, sizeof path, "%s/status.json", o->dir);
    mkdir_p(o->dir);
    if (n > 0 && (size_t)n < sizeof status) write_file_atomic(path, status, (size_t)n);
    fputs(status, stdout);

    int rc = (elf_base && elf_ok && tracer == 0) ? 0 : 6;
    vm_free_maps(&m);
    return rc;
}

/* ---------- scan ---------- */

static int mode_scan(const opts *o, const char *cls, const char *ns) {
    int pid = vm_find_pid(o->pkg);
    if (pid < 0) { espd_log("%s 未运行", o->pkg); return 3; }
    vm_maps m;
    if (vm_load_maps(pid, &m) != 0) { espd_log("maps 失败: %s", strerror(errno)); return 4; }

    /* 先确认 il2cpp 真的加载了，否则「找不到类」的报错会误导排查方向 */
    uint64_t base = vm_module_base(&m, o->so);
    if (!base) {
        espd_log("进程 %d 里没有 %s（il2cpp 未加载：还没进游戏/还在闪屏）", pid, o->so);
        vm_free_maps(&m);
        return 5;
    }

    ic_class c;
    if (scan_find_class(pid, &m, o->so, ns, cls, &c) != 0) {
        espd_log("扫描类 %s.%s 失败（il2cpp=%#llx）: %s",
                 ns ? ns : "", cls, (unsigned long long)base, scan_last_error());
        vm_free_maps(&m);
        return 7;
    }

    printf("{\n  \"class\": \"%s.%s\",\n  \"klass\": %llu,\n"
           "  \"fields_off\": %d,\n  \"field_count\": %d,\n"
           "  \"static_fields_off\": %d,\n  \"fields\": [\n",
           c.ns, c.name, (unsigned long long)c.klass,
           c.fields_off, c.field_count, c.static_fields_off);

    ic_field fs[SCAN_MAX_FIELDS];
    int nf = scan_fields(pid, &c, fs, SCAN_MAX_FIELDS);
    for (int i = 0; i < nf; i++) {
        printf("    {\"name\": \"%s\", \"offset\": %d, \"static\": %d}%s\n",
               fs[i].name, fs[i].offset, fs[i].is_static, i + 1 < nf ? "," : "");
    }
    printf("  ]\n}\n");
    vm_free_maps(&m);
    return 0;
}

/* ---------- 解析缓存：pid / 基址变化时重建一次，热路径零扫描 ---------- */

typedef struct {
    uint64_t actor, tr;
} obj_cache;

typedef struct {
    int pid;
    uint64_t il2cpp_base;

    ic_class pvp;
    ic_field f_statis, f_my, f_en;
    int ok_pvp;

    ic_class tr;
    ic_field f_pos, f_rot, f_scale, f_father;
    int ok_tr;

    ic_class cam;
    int ok_cam;

    obj_cache cache[8];   /* 小型 actor→transform 映射缓存，命中即省去每帧字段扫描 */
    int ncache;
    uint64_t cached_cam_obj;   /* Camera 实例扫描结果缓存（扫堆很贵，只在失效时重扫） */
} resolve_ctx;

/* 判断某段是否可能是 il2cpp 托管堆：
 * Android 上堆段多是 [anon:scudo:primary] / [anon:libc_malloc] / 完全匿名，
 * 不能只认「路径为空」，否则永远扫不到实例对象。排除文件映射与特殊段即可。 */
static int heapish(const vm_map *e) {
    const char *p = e->path;
    if (p[0] == '/') return 0;                       /* 文件映射：so/普通文件 */
    if (p[0] == '[') {
        /* [anon:...] 是堆；[stack]/[vvar]/[vdso]/[heap] 等要区分 */
        if (strncmp(p, "[anon:", 6) == 0) return 1;
        return 0;                                    /* [stack] [vvar] [vdso] [vectors] */
    }
    return 1;                                        /* 空路径：匿名段，最常见 */
}

/* 在托管堆里找某个 klass 的实例对象头（可选「按 m_Depth 选最大的」）。
 *
 * Unity 场景里 Camera 同时存在 UI/后处理/缩略图多个实例，取第一个命中是错的，
 * 会拿错相机 → 整屏坐标全错（线飞天或钉死）。所以 Camera 走 depth 筛选。
 * 排除 Il2CppClass 自引用（klass+0x78）与 name/ns 指针巧合。
 *
 * pick_max_depth = 0 时返回首个可信命中；=1 时在最多 64 个候选里取 m_Depth 最大者。 */
static uint64_t scan_object(int pid, const vm_maps *m, uint64_t klass,
                            int pick_max_depth, const char *depth_field) {
    unsigned char needle[8];
    for (int i = 0; i < 8; i++) needle[i] = (unsigned char)(klass >> (8 * i));
    uint64_t k16 = vm_read_ptr(pid, klass + 0x10, NULL);
    uint64_t k24 = vm_read_ptr(pid, klass + 0x18, NULL);

    ic_field f_depth;
    int has_depth = 0;
    if (pick_max_depth) {
        ic_class cc;
        if (scan_prepare(pid, klass, NULL, NULL, &cc) == 0)
            has_depth = (scan_field_by_name(pid, &cc, depth_field, &f_depth) == 0);
    }

    uint64_t best = 0;
    float best_depth = -1e9f;
    int seen = 0;

    for (int i = 0; i < m->n; i++) {
        const vm_map *e = &m->items[i];
        if (e->perms[0] != 'r' || e->perms[1] != 'w') continue;
        if (!heapish(e)) continue;
        uint64_t sz = e->end - e->start;
        if (sz < 8 || sz > 1024ull * 1024 * 1024) continue;

        uint64_t at = e->start, left = sz;
        for (int scanned = 0; left >= 8 && scanned < 8192; scanned++) {
            uint64_t h = vm_find_bytes(pid, at, (size_t)left, needle, 8);
            if (!h) break;
            if (h != klass + 0x78 && (h & 7) == 0) {
                uint64_t h16 = vm_read_ptr(pid, h + 0x10, NULL);
                if (h16 != k16 && vm_read_ptr(pid, h + 0x18, NULL) != k24) {
                    if (!pick_max_depth || !has_depth) return h;
                    if (++seen <= 64) {
                        float d = vm_read_f32(pid, h + (uint64_t)(uint32_t)f_depth.offset, -1e9f);
                        if (!best || d > best_depth) { best_depth = d; best = h; }
                    }
                }
            }
            uint64_t next = h + 8;
            if (next <= at) break;
            left -= (uint64_t)(next - at);
            at = next;
        }
    }
    return best;
}

static uint64_t cache_get(resolve_ctx *r, uint64_t actor) {
    for (int i = 0; i < r->ncache; i++)
        if (r->cache[i].actor == actor) return r->cache[i].tr;
    return 0;
}

static void cache_put(resolve_ctx *r, uint64_t actor, uint64_t tr) {
    if (!actor || !tr) return;
    for (int i = 0; i < r->ncache; i++) {
        if (r->cache[i].actor == actor) { r->cache[i].tr = tr; return; }
    }
    if (r->ncache < 8) r->cache[r->ncache++] = (obj_cache){ actor, tr };
}

/* actor → transform（复用 scan_prepare 的统一探测；缓存命中时零扫描） */
static uint64_t actor_transform(int pid, uint64_t actor, resolve_ctx *r, const conf *cfg) {
    if (!actor) return 0;

    /* 缓存有效性：Transform 对象头 klass 必须仍是我们在 r->tr 里解析到的那个类，
     * 否则说明内存被回收到别的对象上，必须重解析（否则会静默读错坐标）。 */
    uint64_t hit = cache_get(r, actor);
    if (hit && r->tr.klass && vm_read_ptr(pid, hit, NULL) == r->tr.klass) return hit;

    uint64_t klass = vm_read_ptr(pid, actor, NULL);
    if (!klass) return 0;
    ic_class c;
    if (scan_prepare(pid, klass, NULL, NULL, &c) != 0) return 0;

    const char *names[5];
    int nn = 0;
    const char *tf = conf_get(cfg, "field_transform", "");
    if (tf && *tf) names[nn++] = tf;
    names[nn++] = "m_transform";
    names[nn++] = "transform";
    names[nn++] = "_transform";
    names[nn++] = "m_CachedTransform";

    for (int k = 0; k < nn; k++) {
        ic_field f;
        if (scan_field_by_name(pid, &c, names[k], &f) == 0) {
            uint64_t tr = vm_read_ptr(pid, actor + (uint64_t)(uint32_t)f.offset, 0);
            if (tr) cache_put(r, actor, tr);
            return tr;
        }
    }
    return 0;
}

/* pid / 基址变化时重建解析缓存 */
static void resolve_reset(resolve_ctx *r, int pid, uint64_t base,
                          const vm_maps *maps, const char *so, const conf *cfg) {
    memset(r, 0, sizeof *r);
    r->pid = pid;
    r->il2cpp_base = base;

    /* 三个类一次性解析：堆扫描只做一遍，避免每类重复扫堆 */
    cls_q qs[3];
    qs[0].ns = conf_get(cfg, "pvp_ns", "KH");
    qs[0].name = conf_get(cfg, "pvp_class", "PVPStatis");
    qs[1].ns = conf_get(cfg, "camera_ns", "UnityEngine");
    qs[1].name = conf_get(cfg, "camera_class", "Camera");
    qs[2].ns = "UnityEngine";
    qs[2].name = "Transform";

    ic_class cs[3];
    memset(cs, 0, sizeof cs);
    int all = scan_find_classes(pid, maps, so, qs, cs, 3);

    if (cs[0].klass) {
        r->pvp = cs[0];
        r->ok_pvp =
            scan_field_by_name(pid, &r->pvp, conf_get(cfg,"pvp_static_field","statis"), &r->f_statis) == 0 &&
            scan_field_by_name(pid, &r->pvp, conf_get(cfg,"field_my_actor","m_myPlayerCtrl"), &r->f_my) == 0 &&
            scan_field_by_name(pid, &r->pvp, conf_get(cfg,"field_enemy_actor","m_enemyPlayerCtrl"), &r->f_en) == 0;
    }

    if (cs[1].klass) {
        r->cam = cs[1];
        r->ok_cam = 1;
    }
    r->cached_cam_obj = 0;

    if (cs[2].klass) {
        r->tr = cs[2];
        r->ok_tr =
            scan_field_by_name(pid, &r->tr, conf_get(cfg,"field_local_position","m_LocalPosition"), &r->f_pos) == 0 &&
            scan_field_by_name(pid, &r->tr, conf_get(cfg,"field_local_rotation","m_LocalRotation"), &r->f_rot) == 0 &&
            scan_field_by_name(pid, &r->tr, conf_get(cfg,"field_local_scale","m_LocalScale"), &r->f_scale) == 0 &&
            scan_field_by_name(pid, &r->tr, conf_get(cfg,"field_father","m_Father"), &r->f_father) == 0;
    }

    /* 全部命中时清掉可能残留的警告，避免下次成功还打旧诊断 */
    if (all == 0 && r->ok_pvp && r->ok_cam && r->ok_tr)
        scan_set_warn("%s", "");
}

/* Transform 父链累乘 → 世界位置 + 从旋转矩阵反推世界四元数 */
static int transform_world(int pid, const resolve_ctx *r, uint64_t tr,
                           float out_pos[3], float out_rot[4]) {
    if (!tr || !r->ok_tr) return -1;

    uint64_t chain[32];
    int n = 0;
    uint64_t cur = tr;
    while (cur && n < 32) {
        /* 成环检测：父链里出现重复地址说明字段读错或对象被复用，立即中止 */
        int dup = 0;
        for (int i = 0; i < n; i++) if (chain[i] == cur) { dup = 1; break; }
        if (dup) break;
        chain[n++] = cur;
        cur = vm_read_ptr(pid, cur + (uint64_t)(uint32_t)r->f_father.offset, 0);
    }
    if (n == 0) return -4;

    mat4 world;
    memset(&world, 0, sizeof world);
    world.m[0] = world.m[5] = world.m[10] = world.m[15] = 1;

    for (int i = n - 1; i >= 0; i--) {
        uint64_t o = chain[i];
        float p[3], q[4], s[3];
        for (int j = 0; j < 3; j++) p[j] = vm_read_f32(pid, o + (uint64_t)(uint32_t)r->f_pos.offset + j*4, 0);
        for (int j = 0; j < 4; j++) q[j] = vm_read_f32(pid, o + (uint64_t)(uint32_t)r->f_rot.offset + j*4, j==3?1:0);
        for (int j = 0; j < 3; j++) s[j] = vm_read_f32(pid, o + (uint64_t)(uint32_t)r->f_scale.offset + j*4, 1);

        float qn = q[0]*q[0]+q[1]*q[1]+q[2]*q[2]+q[3]*q[3];
        if (qn < 1e-6f || fabsf(qn - 1.0f) > 0.2f) { q[0]=q[1]=q[2]=0; q[3]=1; }  /* 坏数据防御 */

        mat4 local, next;
        mat4_trs(&local, p, q, s);
        mat4_mul(&next, &world, &local);
        world = next;
    }

    out_pos[0] = world.m[12];
    out_pos[1] = world.m[13];
    out_pos[2] = world.m[14];

    /* 旋转矩阵 → 四元数 */
    float m00=world.m[0], m01=world.m[4], m02=world.m[8];
    float m10=world.m[1], m11=world.m[5], m12=world.m[9];
    float m20=world.m[2], m21=world.m[6], m22=world.m[10];
    float t = m00 + m11 + m22;
    float s;
    if (t > 0) {
        s = sqrtf(t + 1.0f) * 2.0f;
        out_rot[3] = 0.25f * s; out_rot[0] = (m21-m12)/s; out_rot[1] = (m02-m20)/s; out_rot[2] = (m10-m01)/s;
    } else if (m00 > m11 && m00 > m22) {
        s = sqrtf(1.0f + m00 - m11 - m22) * 2.0f;
        out_rot[0] = 0.25f * s; out_rot[3] = (m21-m12)/s; out_rot[1] = (m01+m10)/s; out_rot[2] = (m02+m20)/s;
    } else if (m11 > m22) {
        s = sqrtf(1.0f + m11 - m00 - m22) * 2.0f;
        out_rot[1] = 0.25f * s; out_rot[3] = (m02-m20)/s; out_rot[0] = (m01+m10)/s; out_rot[2] = (m12+m21)/s;
    } else {
        s = sqrtf(1.0f + m22 - m00 - m11) * 2.0f;
        out_rot[2] = 0.25f * s; out_rot[3] = (m10-m01)/s; out_rot[0] = (m02+m20)/s; out_rot[1] = (m12+m21)/s;
    }
    return 0;
}

/* ---------- daemon ---------- */

static int mode_daemon(const opts *o) {
    char conf_path[512], status_path[512];
    snprintf(conf_path, sizeof conf_path, "%s/espd.conf", o->dir);
    snprintf(status_path, sizeof status_path, "%s/status.json", o->dir);
    mkdir_p(o->dir);

    conf cfg;
    if (conf_load(&cfg, conf_path) != 0) {
        /* 首次启动：从模块里的模板生成配置，避免「配置缺失」直接退出。
         * 生成后不再覆盖，保留真机校准值。 */
        static const char *tpls[] = {
            "/data/adb/modules/esp_local/bin/espd.conf",
            NULL
        };
        const char *src = NULL;
        for (int i = 0; tpls[i]; i++) {
            FILE *t = fopen(tpls[i], "rb");
            if (t) { fclose(t); src = tpls[i]; break; }
        }
        if (!src) {
            espd_log("配置缺失且找不到模板: %s", conf_path);
            return 8;
        }
        char buf[8192];
        int n = read_file(src, buf, sizeof buf);
        if (n <= 0 || write_file_atomic(conf_path, buf, (size_t)n) != 0) {
            espd_log("从模板生成配置失败: %s -> %s", src, conf_path);
            return 8;
        }
        if (conf_load(&cfg, conf_path) != 0) {
            espd_log("生成的配置无法解析: %s", conf_path);
            return 8;
        }
        espd_log("首次启动：已从模板生成 %s", conf_path);
    }

    /* 单实例：supervisor 用 pidof 兜了一层，这里再用 flock 兜一层，
     * 防止两条启动路径同时拉起时抢同一个 UDP 端口。fd 故意不关，随进程退出释放。 */
    int lockfd = espd_lock(o->dir);
    if (lockfd < 0) {
        espd_log("另一个 espd daemon 已在运行（%s/espd.lock 被占用），退出", o->dir);
        conf_free(&cfg);
        return 11;
    }
    (void)lockfd;   /* fd 故意不关，随进程退出由内核释放 */

    int port = o->port_set ? o->port : conf_get_int(&cfg, "port", ESPD_DEFAULT_PORT);
    int interval = o->interval_set ? o->interval : conf_get_int(&cfg, "interval_ms", 33);
    if (port <= 0 || port > 65535) port = ESPD_DEFAULT_PORT;
    if (interval < 10 || interval > 1000) interval = 33;

    float fov = (float)conf_get_double(&cfg, "fov", 60.0);
    float nearz = (float)conf_get_double(&cfg, "near", 0.3);
    float farz  = (float)conf_get_double(&cfg, "far", 1000.0);
    int sw = conf_get_int(&cfg, "screen_w", 0), sh = conf_get_int(&cfg, "screen_h", 0);
    if (!sw || !sh) screen_size(&sw, &sh);
    if (!sw || !sh) { sw = 1080; sh = 2400; }

    udp_sock udp;
    if (udp_open(&udp, (uint16_t)port) != 0) { espd_log("UDP socket 失败"); conf_free(&cfg); return 9; }
    mat4 mp;
    build_persp(&mp, fov, (float)sw/(float)sh, nearz, farz);

    char domain[128];
    selinux_domain(domain, sizeof domain);

    vm_maps maps;
    memset(&maps, 0, sizeof maps);
    resolve_ctx r;
    memset(&r, 0, sizeof r);
    int loaded = 0;
    int resolve_tries = 0;
    uint64_t last_resolve_ms = 0;
    long frames = 0, errors = 0, sent = 0, drops = 0, behind = 0;
    uint64_t t0 = now_ms();

    espd_log("daemon start pkg=%s so=%s port=%d interval=%dms domain=%s",
             o->pkg, o->so, port, interval, domain);

    while (!g_stop) {
        /* PID 缓存：kill(pid,0) 只判存活，没必要每帧（30 次/秒）全扫 /proc。
         * 只有 ESRCH 才说明进程真的没了；EPERM/EACCES 表示进程在、只是跨域
         * 无权发信号，仍按存活处理。 */
        int pid = r.pid;
        if (pid > 0 && kill(pid, 0) != 0 && errno == ESRCH) pid = -1;
        if (pid <= 0) pid = vm_find_pid(o->pkg);
        if (pid < 0) {
            if (r.pid > 0) espd_log("游戏进程退出 pid=%d", r.pid);
            memset(&r, 0, sizeof r);
            if (o->once) { espd_log("--once: %s 未运行，退出", o->pkg); break; }
            usleep(500000);
            continue;
        }

        int need_resolve = 0;
        if (pid != r.pid) {
            if (loaded) vm_free_maps(&maps);
            if (vm_load_maps(pid, &maps) != 0) {
                espd_log("maps 读取失败: %s", strerror(errno));
                if (o->once) break;
                usleep(500000);
                continue;
            }
            loaded = 1;
            need_resolve = 1;
            resolve_tries = 0;
        } else if (frames % 120 == 0 && loaded) {
            vm_maps fresh;
            if (vm_load_maps(pid, &fresh) == 0) {
                uint64_t base = vm_module_base(&fresh, o->so);
                vm_free_maps(&maps);
                maps = fresh;
                if (base != r.il2cpp_base) { need_resolve = 1; resolve_tries = 0; }   /* 基址变了才重解析 */
            }
            /* il2cpp 的类表是惰性填充的：libil2cpp.so 刚映射时目标类可能还不存在。
             * 解析失败就重试，但间隔 15s、最多 8 次 —— 全量扫堆会拉高目标进程 RSS，
             * 手机空闲内存只有 1GB 出头，扫太勤会把游戏挤掉。 */
            if (!need_resolve && !(r.ok_pvp && r.ok_cam && r.ok_tr) &&
                resolve_tries < 8 && now_ms() - last_resolve_ms > 15000)
                need_resolve = 1;
        }

        if (need_resolve) {
            resolve_tries++;
            uint64_t base = vm_module_base(&maps, o->so);
            if (!base) {
                /* il2cpp 还没加载（进程刚起，或还在闪屏）。
                 * --once 模式下直接退出，否则会一直等下去。 */
                espd_log_quiet("%s 未加载（进程已在，等待 il2cpp 就绪）", o->so);
                if (o->once) break;
                usleep(1000000);
                continue;
            }
            resolve_reset(&r, pid, base, &maps, o->so, &cfg);
            last_resolve_ms = now_ms();
            espd_log("resolved pid=%d il2cpp=%#llx pvp=%d cam=%d tr=%d",
                     pid, (unsigned long long)base, r.ok_pvp, r.ok_cam, r.ok_tr);
            if (!r.ok_pvp || !r.ok_tr || !r.ok_cam)
                espd_log("  解析诊断: %s", scan_last_error());
            else {
                char hs[160];
                scan_heap_stats(hs, sizeof hs);
                espd_log_quiet("  %s", hs);
            }
        }

        /* 相机：Camera 实例 → transform → 世界位姿 */
        float camPos[3] = {0,0,0}, camRot[4] = {0,0,0,1};
        int cam_ok = 0;
        if (r.ok_cam && r.cam.klass) {
            /* 缓存 Camera 实例；对象头 klass 变了才重扫。
             * 主相机按 m_Depth 最大挑选——直接取第一个会拿到 UI/后处理相机，
             * 导致整屏坐标全错。 */
            uint64_t camObj = r.cached_cam_obj;
            if (!camObj || vm_read_ptr(pid, camObj, NULL) != r.cam.klass) {
                camObj = scan_object(pid, &maps, r.cam.klass, 1, "m_Depth");
                r.cached_cam_obj = camObj;
                if (camObj) espd_log_quiet("camera obj=%#llx", (unsigned long long)camObj);
            }
            uint64_t camTr = actor_transform(pid, camObj, &r, &cfg);
            if (camTr) cam_ok = (transform_world(pid, &r, camTr, camPos, camRot) == 0);
        }

        /* 我方 / 敌方 actor：PVPStatis 静态字段 */
        uint64_t myActor = 0, enActor = 0;
        if (r.ok_pvp) {
            uint64_t inst = scan_static_object(pid, &r.pvp, &r.f_statis);
            if (inst) {
                myActor = scan_obj_ptr(pid, inst, &r.f_my);
                enActor = scan_obj_ptr(pid, inst, &r.f_en);
            }
        }

        char frame[2048];
        int flen = snprintf(frame, sizeof frame, "FRAME\n");
        if (flen < 0) flen = 0;

        /* 悬浮窗的线起点完全取自 A 行（EspView.drawScene：guide==null 就整段跳过），
         * 只发 U 行等于一条线都不画。所以 A 行是本协议的必需项，不是可选项。 */
        if (cam_ok && myActor && enActor) {
            uint64_t myTr = actor_transform(pid, myActor, &r, &cfg);
            uint64_t enTr = actor_transform(pid, enActor, &r, &cfg);
            float myP[3], enP[3], myR[4], enR[4];
            if (myTr && enTr &&
                transform_world(pid, &r, myTr, myP, myR) == 0 &&
                transform_world(pid, &r, enTr, enP, enR) == 0) {
                mat4 mv;
                build_view(&mv, camPos, camRot);
                /* 必须初始化：project_point 返回 0 时不会写 nx/ny，
                 * 后面算方位角会读到未初始化值（UB）。 */
                float mnx = 0, mny = 0, enx = 0, eny = 0;
                int myVis = project_point(&mv, &mp, myP[0], myP[1], myP[2], &mnx, &mny);
                int enVis = project_point(&mv, &mp, enP[0], enP[1], enP[2], &enx, &eny);

                if (enVis) {
                    float dx=enP[0]-camPos[0], dy=enP[1]-camPos[1], dz=enP[2]-camPos[2];
                    float dist = sqrtf(dx*dx + dy*dy + dz*dz);
                    int m = snprintf(frame + flen, sizeof frame - (size_t)flen,
                        "U %.4f %.4f -1 -1 0 -1 %.1f -999\n", enx, eny, dist);
                    if (m > 0 && flen + m < (int)sizeof frame) flen += m;
                } else behind++;

                /* A 行：自己脚下屏幕坐标 + 朝敌方位角。角度用屏幕像素空间算（与 esp.js 一致）。
                 * vang/spd 本版只画线不画箭头，固定 -999/0。 */
                if (myVis) {
                    float ang = -999.0f;
                    if (enVis) {
                        float vx = (enx - mnx) * (float)sw;
                        float vy = (eny - mny) * (float)sh;
                        if (fabsf(vx) + fabsf(vy) > 1.0f)
                            ang = atan2f(vy, vx) * 180.0f / (float)M_PI;
                    }
                    int a = snprintf(frame + flen, sizeof frame - (size_t)flen,
                        "A %.4f %.4f %.0f -999 0.0\n", mnx, mny, ang);
                    if (a > 0 && flen + a < (int)sizeof frame) flen += a;
                } else drops++;      /* 自己在相机后方：无法给出线的起点，计入丢弃 */
            } else drops++;          /* 有 actor 但取不到位姿 */
        } else if (r.ok_pvp || r.ok_cam) {
            /* 解析成功但拿不到我方/敌方（未进对局、回合切换中）—— 正常，不刷屏 */
        }

        int tail = snprintf(frame + flen, sizeof frame - (size_t)flen, "END\n");
        if (tail > 0 && flen + tail < (int)sizeof frame) flen += tail;

        int n = udp_send(&udp, frame, (size_t)flen);
        if (n > 0) sent++; else errors++;

        frames++;
        if (frames % 30 == 0) {
            char st[1024];
            int sl = snprintf(st, sizeof st,
                "{\"ts\":%ld,\"pid\":%d,\"il2cpp\":%llu,\"frames\":%ld,\"sent\":%ld,"
                "\"errors\":%ld,\"drops\":%ld,\"behind\":%ld,\"cam\":%d,\"pvp\":%d,"
                "\"uptime_ms\":%llu,\"domain\":\"%s\"}\n",
                (long)time(NULL), pid, (unsigned long long)r.il2cpp_base,
                frames, sent, errors, drops, behind, cam_ok, r.ok_pvp,
                (unsigned long long)(now_ms() - t0), domain);
            if (sl > 0 && (size_t)sl < sizeof st) write_file_atomic(status_path, st, (size_t)sl);
        }
        /* 日志每 300 帧（约 10s）一行：状态文件 1s 一写够用了，
         * 日志每秒一行会把 200 行轮转窗口压到只剩 3 分钟，真实事件全被淹掉。 */
        if (frames % 300 == 0)
            espd_log_quiet("frames=%ld sent=%ld err=%ld drops=%ld behind=%ld cam=%d pvp=%d",
                           frames, sent, errors, drops, behind, cam_ok, r.ok_pvp);

        if (o->once) break;
        usleep((useconds_t)(interval * 1000));
    }

    udp_close(&udp);
    conf_free(&cfg);
    if (loaded) vm_free_maps(&maps);
    espd_log("daemon stop frames=%ld sent=%ld", frames, sent);
    return 0;
}

/* ---------- CLI ---------- */

static void usage(const char *p) {
    fprintf(stderr,
        "espd %s — 进程外只读 ESP daemon\n"
        "用法:\n"
        "  %s probe [--pkg N] [--so N] [--dir D]\n"
        "  %s selftest\n"
        "  %s scan <类名> [命名空间] [--pkg N] [--so N]\n"
        "  %s daemon [--dir D] [--port N] [--interval MS] [--once]\n",
        ESPD_VERSION, p, p, p, p);
}

int main(int argc, char **argv) {
    opts o = { .pkg=ESPD_DEFAULT_PKG, .so=ESPD_DEFAULT_SO, .dir=ESPD_DEFAULT_DIR,
               .port=ESPD_DEFAULT_PORT, .interval=33, .port_set=0, .interval_set=0, .once=0 };

    signal(SIGTERM, on_signal);
    signal(SIGINT, on_signal);

    if (argc < 2) { usage(argv[0]); return 2; }
    const char *mode = argv[1];

    const char *scan_cls = NULL, *scan_ns = NULL;
    for (int i = 2; i < argc; i++) {
        if (!strcmp(argv[i], "--pkg") && i + 1 < argc) o.pkg = argv[++i];
        else if (!strcmp(argv[i], "--so") && i + 1 < argc) o.so = argv[++i];
        else if (!strcmp(argv[i], "--dir") && i + 1 < argc) o.dir = argv[++i];
        else if (!strcmp(argv[i], "--port") && i + 1 < argc) { o.port = atoi(argv[++i]); o.port_set = 1; }
        else if (!strcmp(argv[i], "--interval") && i + 1 < argc) { o.interval = atoi(argv[++i]); o.interval_set = 1; }
        else if (!strcmp(argv[i], "--once")) o.once = 1;
        else if (argv[i][0] == '-') {                     /* 未知选项：别再当类名吞掉 */
            fprintf(stderr, "未知选项: %s\n", argv[i]);
            usage(argv[0]);
            return 2;
        }
        else if (!strcmp(mode, "scan") && !scan_cls) scan_cls = argv[i];
        else if (!strcmp(mode, "scan") && !scan_ns) scan_ns = argv[i];
        else { fprintf(stderr, "多余参数: %s\n", argv[i]); usage(argv[0]); return 2; }
    }

    char logp[512];
    snprintf(logp, sizeof logp, "%s/espd.log", o.dir);
    mkdir_p(o.dir);
    espd_log_open(logp);

    int rc;
    if (!strcmp(mode, "probe")) rc = mode_probe(&o);
    else if (!strcmp(mode, "selftest")) {
        char msg[256];
        rc = project_selftest(msg, sizeof msg);
        printf("project selftest: %s\n", msg);
    } else if (!strcmp(mode, "scan")) {
        if (!scan_cls) { usage(argv[0]); rc = 2; }
        else rc = mode_scan(&o, scan_cls, scan_ns);
    } else if (!strcmp(mode, "daemon")) rc = mode_daemon(&o);
    else { usage(argv[0]); rc = 2; }

    espd_log_close();
    return rc;
}
