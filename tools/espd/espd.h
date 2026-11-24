// espd.h — 公共定义：日志、时间、路径、ctx
//
// espd = 进程外只读 ESP daemon。
//   目标进程零注入、零线程、零外来 so、零文件写入，
//   只用 process_vm_readv 读内存，用 UDP 把结果丢给已有的悬浮窗。
//
// 本文件只放无依赖的公共件，具体能力分散在：
//   vm.c       跨进程读 / maps
//   scan.c     il2cpp 类与字段的运行时自解析（按名字，不按偏移）
//   project.c  投影数学（纯函数，可单测）
//   udp.c      UDP 发送
//   main.c     CLI + daemon 循环
#ifndef ESPD_H
#define ESPD_H

#include <stdint.h>
#include <stddef.h>
#include <stdio.h>

#define ESPD_VERSION "2.0.0"

#ifndef ESPD_DEFAULT_PKG
#define ESPD_DEFAULT_PKG "com.tencent.KiHan"
#endif

#define ESPD_DEFAULT_SO      "libil2cpp.so"
#define ESPD_DEFAULT_PORT    29000
#define ESPD_DEFAULT_DIR     "/data/local/tmp/.esp"
#define ESPD_DEFAULT_LOG     ESPD_DEFAULT_DIR "/espd.log"
#define ESPD_DEFAULT_STATUS  ESPD_DEFAULT_DIR "/status.json"
#define ESPD_DEFAULT_CONF    ESPD_DEFAULT_DIR "/espd.conf"

/* ---------- 日志 ----------
 * 一律走 stderr（daemon 模式下 supervisor 重定向到日志文件），
 * 可选同时写文件。不写游戏目录，不创建任何游戏可见的文件。 */
void espd_log_open(const char *path);
void espd_log_close(void);
void espd_log(const char *fmt, ...)
#if defined(__GNUC__)
    __attribute__((format(printf, 1, 2)))
#endif
    ;

/* 只写文件、不写 stderr 的版本（daemon 高频状态行用它，避免 adb 无终端时堆积） */
void espd_log_quiet(const char *fmt, ...);

/* ---------- 杂项 ---------- */
uint64_t now_ms(void);

/* 递归建目录，成功/已存在返回 0 */
int mkdir_p(const char *path);

/* 读整个小文件到 buf（NUL 结尾），返回长度，失败 -1 */
int read_file(const char *path, char *buf, size_t cap);

/* 原子写文件：先写 .tmp 再 rename（status.json 用，避免读方读到半个 JSON） */
int write_file_atomic(const char *path, const char *data, size_t len);

/* 单实例锁：同一 dir 下 flock。成功返回 fd，失败 -1（已被占用） */
int espd_lock(const char *dir);

/* 当前 SELinux 域，写进 buf */
int selinux_domain(char *buf, size_t cap);

/* 屏幕尺寸（像素）。优先 /sys，兜底 0（调用方用 conf 的覆盖值） */
void screen_size(int *w, int *h);

/* ---------- 极简配置（key=value） ----------
 * 用 key=value 而不是 JSON：daemon 每帧要查十几个字段，
 * 扁平表一次解析、零分配，比带解析器的 JSON 便宜一个数量级。
 * resolved.json 是给 --scan 的人读产物，daemon 只吃 espd.conf。 */
typedef struct {
    char key[64];
    char val[256];
} conf_kv;

typedef struct {
    conf_kv *items;
    int n;
    int cap;
} conf;

int  conf_load(conf *c, const char *path);
void conf_free(conf *c);
const char *conf_get(const conf *c, const char *key, const char *def);
int  conf_get_int(const conf *c, const char *key, int def);
double conf_get_double(const conf *c, const char *key, double def);

#endif
