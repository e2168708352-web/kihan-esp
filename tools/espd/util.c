// util.c — espd.h 的实现（日志 / 时间 / 配置 / 文件）
#define _GNU_SOURCE
#include "espd.h"

#include <stdarg.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <time.h>
#include <sys/stat.h>
#include <sys/file.h>

static int g_logfd = -1;
static char g_logpath[512];

void espd_log_open(const char *path) {
    if (g_logfd >= 0) return;
    snprintf(g_logpath, sizeof g_logpath, "%s", path);
    g_logfd = open(path, O_WRONLY | O_CREAT | O_APPEND, 0644);
}

void espd_log_close(void) {
    if (g_logfd >= 0) { close(g_logfd); g_logfd = -1; }
}

static void vlog(int to_stderr, const char *fmt, va_list ap) {
    char ts[32];
    struct timespec tp;
    clock_gettime(CLOCK_REALTIME, &tp);
    struct tm tm;
    localtime_r(&tp.tv_sec, &tm);
    snprintf(ts, sizeof ts, "%02d-%02d %02d:%02d:%02d",
             tm.tm_mon + 1, tm.tm_mday, tm.tm_hour, tm.tm_min, tm.tm_sec);

    char line[1024];
    int n = snprintf(line, sizeof line, "%s ", ts);
    if (n < 0) return;
    int m = vsnprintf(line + n, sizeof line - (size_t)n, fmt, ap);
    if (m < 0) return;
    size_t len = strlen(line);

    if (to_stderr) {
        fputs(line, stderr);
        fputc('\n', stderr);
        fflush(stderr);
    }
    if (g_logfd >= 0) {
        /* 日志轮转：超过 256KB 只保留最后 200 行。
         * 长期挂机时这是唯一会增长的文件，必须自限。 */
        struct stat st;
        if (fstat(g_logfd, &st) == 0 && st.st_size > 262144) {
            espd_log_close();
            char lines[200][256];
            int keep = 0;
            FILE *lf = fopen(g_logpath, "r");
            if (lf) {
                char tmp[256];
                while (fgets(tmp, sizeof tmp, lf)) {
                    snprintf(lines[keep % 200], sizeof lines[0], "%s", tmp);
                    keep++;
                }
                fclose(lf);
            }
            g_logfd = open(g_logpath, O_WRONLY | O_CREAT | O_TRUNC, 0644);
            if (g_logfd >= 0) {
                int from = keep > 200 ? keep - 200 : 0;
                for (int i = from; i < keep; i++)
                    write(g_logfd, lines[i % 200], strlen(lines[i % 200]));
            }
        }
        if (g_logfd >= 0) {
            write(g_logfd, line, len);
            write(g_logfd, "\n", 1);
        }
    }
}

void espd_log(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vlog(1, fmt, ap);
    va_end(ap);
}

void espd_log_quiet(const char *fmt, ...) {
    va_list ap;
    va_start(ap, fmt);
    vlog(0, fmt, ap);
    va_end(ap);
}

uint64_t now_ms(void) {
    struct timespec tp;
    clock_gettime(CLOCK_MONOTONIC, &tp);
    return (uint64_t)tp.tv_sec * 1000ull + (uint64_t)(tp.tv_nsec / 1000000);
}

int mkdir_p(const char *path) {
    char buf[512];
    size_t n = strlen(path);
    if (n == 0 || n >= sizeof buf) return -1;
    memcpy(buf, path, n + 1);
    for (size_t i = 1; i < n; i++) {
        if (buf[i] != '/') continue;
        buf[i] = 0;
        if (mkdir(buf, 0755) != 0 && errno != EEXIST) return -1;
        buf[i] = '/';
    }
    if (mkdir(buf, 0755) != 0 && errno != EEXIST) return -1;
    return 0;
}

int read_file(const char *path, char *buf, size_t cap) {
    FILE *f = fopen(path, "rb");
    if (!f) return -1;
    size_t n = fread(buf, 1, cap - 1, f);
    int err = ferror(f);
    fclose(f);
    if (err) return -1;
    buf[n] = 0;
    return (int)n;
}

int write_file_atomic(const char *path, const char *data, size_t len) {
    char tmp[512];
    snprintf(tmp, sizeof tmp, "%s.tmp", path);
    int fd = open(tmp, O_WRONLY | O_CREAT | O_TRUNC, 0644);
    if (fd < 0) return -1;
    size_t off = 0;
    while (off < len) {
        ssize_t w = write(fd, data + off, len - off);
        if (w <= 0) { close(fd); unlink(tmp); return -1; }
        off += (size_t)w;
    }
    close(fd);
    if (rename(tmp, path) != 0) { unlink(tmp); return -1; }
    return 0;
}

int espd_lock(const char *dir) {
    char p[512];
    snprintf(p, sizeof p, "%s/espd.lock", dir);
    int fd = open(p, O_RDWR | O_CREAT, 0644);
    if (fd < 0) return -1;
    if (flock(fd, LOCK_EX | LOCK_NB) != 0) { close(fd); return -1; }
    return fd;
}

int selinux_domain(char *buf, size_t cap) {
    int n = read_file("/proc/self/attr/current", buf, cap);
    if (n < 0) { snprintf(buf, cap, "unknown"); return -1; }
    while (n > 0 && (buf[n - 1] == '\n' || buf[n - 1] == '\0')) buf[--n] = 0;
    return 0;
}

void screen_size(int *w, int *h) {
    *w = 0; *h = 0;
    /* 1) 部分机型 fb0 可读，格式 "1080,2400" 或 "1080x2400" */
    static const char *paths[] = {
        "/sys/class/graphics/fb0/virtual_size",
        "/sys/class/graphics/fb0/modes",
        NULL
    };
    for (int i = 0; paths[i]; i++) {
        char buf[128];
        if (read_file(paths[i], buf, sizeof buf) <= 0) continue;
        int a = 0, b = 0;
        if (sscanf(buf, "%d,%d", &a, &b) == 2 && a > 0 && b > 0) {
            if (a >= b) { *w = a; *h = b; } else { *w = b; *h = a; }
            return;
        }
        char *x = strchr(buf, 'x');
        if (x && sscanf(buf, "%dx%d", &a, &b) == 2 && a > 0 && b > 0) {
            if (a >= b) { *w = a; *h = b; } else { *w = b; *h = a; }
            return;
        }
    }

    /* 2) Android 16 上 fb0 常被 SELinux 挡住：退回 `wm size`（输出 "Physical size: 1080x2400"） */
    FILE *p = popen("wm size 2>/dev/null", "r");
    if (p) {
        char line[256];
        int a = 0, b = 0;
        while (fgets(line, sizeof line, p)) {
            char *x = strstr(line, "size:");
            if (!x) x = line;
            if (sscanf(x, "size: %dx%d", &a, &b) == 2 || sscanf(x, "%dx%d", &a, &b) == 2) {
                if (a > 0 && b > 0) {
                    if (a >= b) { *w = a; *h = b; } else { *w = b; *h = a; }
                    break;
                }
            }
        }
        pclose(p);
        if (*w && *h) return;
    }

    /* 3) 最后退到 /sys/class/drm 或常见比例（调用方还会用 conf 覆盖） */
    char buf[128];
    if (read_file("/sys/class/drm/card0-HDMI-A-1/modes", buf, sizeof buf) > 0) {
        int a = 0, b = 0;
        if (sscanf(buf, "%dx%d", &a, &b) == 2 && a > 0 && b > 0) {
            if (a >= b) { *w = a; *h = b; } else { *w = b; *h = a; }
        }
    }
}

/* ---------- conf ---------- */
static int conf_push(conf *c, const char *k, const char *v) {
    if (c->n == c->cap) {
        int cap = c->cap ? c->cap * 2 : 32;
        conf_kv *p = realloc(c->items, sizeof(conf_kv) * (size_t)cap);
        if (!p) return -1;
        c->items = p;
        c->cap = cap;
    }
    snprintf(c->items[c->n].key, sizeof c->items[0].key, "%s", k);
    snprintf(c->items[c->n].val, sizeof c->items[0].val, "%s", v);
    c->n++;
    return 0;
}

int conf_load(conf *c, const char *path) {
    memset(c, 0, sizeof *c);
    FILE *f = fopen(path, "r");
    if (!f) return -1;
    char line[512];
    while (fgets(line, sizeof line, f)) {
        char *p = line;
        while (*p == ' ' || *p == '\t') p++;
        if (*p == '#' || *p == ';' || *p == '\n' || !*p) continue;
        char *eq = strchr(p, '=');
        if (!eq) continue;
        *eq = 0;
        char *k = p, *v = eq + 1;
        char *ke = eq;
        while (ke > k && (ke[-1] == ' ' || ke[-1] == '\t')) ke--;
        *ke = 0;
        while (*v == ' ' || *v == '\t') v++;
        char *ve = v + strlen(v);
        while (ve > v && (ve[-1] == '\n' || ve[-1] == '\r' || ve[-1] == ' ' || ve[-1] == '\t')) ve--;
        *ve = 0;
        conf_push(c, k, v);
    }
    fclose(f);
    return 0;
}

void conf_free(conf *c) {
    free(c->items);
    memset(c, 0, sizeof *c);
}

const char *conf_get(const conf *c, const char *key, const char *def) {
    for (int i = 0; i < c->n; i++)
        if (strcmp(c->items[i].key, key) == 0) return c->items[i].val;
    return def;
}

int conf_get_int(const conf *c, const char *key, int def) {
    const char *v = conf_get(c, key, NULL);
    if (!v || !*v) return def;
    return (int)strtol(v, NULL, 0);
}

double conf_get_double(const conf *c, const char *key, double def) {
    const char *v = conf_get(c, key, NULL);
    if (!v || !*v) return def;
    return strtod(v, NULL);
}
