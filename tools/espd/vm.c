// vm.c — 见 vm.h
#define _GNU_SOURCE
#include "vm.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/uio.h>

static int is_num(const char *s) {
    if (!*s) return 0;
    for (; *s; s++) if (*s < '0' || *s > '9') return 0;
    return 1;
}

int vm_find_pid(const char *name) {
    DIR *d = opendir("/proc");
    if (!d) return -1;
    struct dirent *e;
    int found = -1;
    while ((e = readdir(d))) {
        if (!is_num(e->d_name)) continue;
        char p[64], buf[256];
        snprintf(p, sizeof p, "/proc/%s/cmdline", e->d_name);
        FILE *f = fopen(p, "rb");
        if (!f) continue;
        size_t n = fread(buf, 1, sizeof buf - 1, f);
        fclose(f);
        buf[n] = 0;
        if (n && strcmp(buf, name) == 0) {
            found = atoi(e->d_name);
            break;
        }
    }
    closedir(d);
    return found;
}

int vm_read(int pid, uint64_t addr, void *buf, size_t len) {
    if (len == 0) return 0;
    struct iovec l = { buf, len };
    struct iovec r = { (void *)(uintptr_t)addr, len };
    ssize_t n = process_vm_readv(pid, &l, 1, &r, 1, 0);
    if (n < 0) return -1;
    if ((size_t)n != len) { errno = EFAULT; return -1; }
    return 0;
}

uint64_t vm_read_ptr(int pid, uint64_t addr, int *err) {
    uint64_t v = 0;
    if (vm_read(pid, addr, &v, sizeof v) != 0) {
        if (err) *err = errno;
        return 0;
    }
    if (err) *err = 0;
    return v;
}

static int push_map(vm_maps *m, const vm_map *e) {
    if (m->n == m->cap) {
        int cap = m->cap ? m->cap * 2 : 256;
        vm_map *p = realloc(m->items, sizeof(vm_map) * (size_t)cap);
        if (!p) return -1;
        m->items = p;
        m->cap = cap;
    }
    m->items[m->n++] = *e;
    return 0;
}

int vm_load_maps(int pid, vm_maps *out) {
    memset(out, 0, sizeof *out);
    char path[64];
    snprintf(path, sizeof path, "/proc/%d/maps", pid);
    FILE *f = fopen(path, "r");
    if (!f) return -1;

    char line[1024];
    while (fgets(line, sizeof line, f)) {
        vm_map e;
        memset(&e, 0, sizeof e);
        unsigned long long s = 0, en = 0, off = 0;
        int n = sscanf(line, "%llx-%llx %7s %llx %*s %*s %511s", &s, &en, e.perms, &off, e.path);
        if (n < 4) continue;
        e.start = s; e.end = en; e.off = off;
        if (push_map(out, &e) != 0) { fclose(f); vm_free_maps(out); return -1; }
    }
    fclose(f);
    return 0;
}

void vm_free_maps(vm_maps *m) {
    free(m->items);
    m->items = NULL; m->n = m->cap = 0;
}

uint64_t vm_module_base(const vm_maps *m, const char *soname) {
    uint64_t best = 0;
    size_t nl = strlen(soname);
    for (int i = 0; i < m->n; i++) {
        const char *p = m->items[i].path;
        if (!*p) continue;
        size_t pl = strlen(p);
        if (pl < nl || strcmp(p + pl - nl, soname) != 0) continue;
        uint64_t base = m->items[i].start - (m->items[i].off & ~0xfffULL);
        if (!best || base < best) best = base;
    }
    return best;
}

uint32_t vm_read_u32(int pid, uint64_t addr, uint32_t def) {
    uint32_t v;
    return vm_read(pid, addr, &v, sizeof v) == 0 ? v : def;
}

int32_t vm_read_i32(int pid, uint64_t addr, int32_t def) {
    int32_t v;
    return vm_read(pid, addr, &v, sizeof v) == 0 ? v : def;
}

float vm_read_f32(int pid, uint64_t addr, float def) {
    float v;
    return vm_read(pid, addr, &v, sizeof v) == 0 ? v : def;
}

int vm_read_str(int pid, uint64_t addr, char *buf, size_t cap) {
    if (cap == 0) return -1;
    size_t off = 0;
    while (off + 1 < cap) {
        char chunk[64];
        size_t n = cap - 1 - off;
        if (n > sizeof chunk) n = sizeof chunk;
        if (vm_read(pid, addr + off, chunk, n) != 0) {
            if (off == 0) return -1;
            break;
        }
        for (size_t i = 0; i < n; i++) {
            buf[off + i] = chunk[i];
            if (chunk[i] == 0) return (int)(off + i);
        }
        off += n;
    }
    buf[off] = 0;
    return (int)off;
}

/* 在 [addr, addr+len) 里找 needle。
 * 分块读，每块之间重叠 nlen-1 字节，保证跨块边界的匹配不会被漏掉。 */
uint64_t vm_find_bytes(int pid, uint64_t addr, size_t len,
                       const void *needle, size_t nlen) {
    if (nlen == 0 || nlen > len) return 0;

    const size_t CH = 1u << 20;                 /* 1MB 工作缓冲 */
    unsigned char *buf = malloc(CH + nlen);
    if (!buf) return 0;

    size_t done = 0;
    uint64_t found = 0;
    while (done < len) {
        size_t want = len - done;
        if (want > CH) want = CH;
        if (vm_read(pid, addr + done, buf, want) != 0) break;

        size_t limit = (want >= nlen) ? (want - nlen + 1) : 0;
        for (size_t i = 0; i < limit; i++) {
            if (memcmp(buf + i, needle, nlen) == 0) {
                found = addr + done + i;
                break;
            }
        }
        if (found) break;
        if (want < CH) break;                   /* 最后一块，读完即可 */

        /* 前进 CH - (nlen-1)，让下一块覆盖本块末尾的跨界窗口 */
        size_t step = (nlen > 1) ? (CH - (nlen - 1)) : CH;
        if (step == 0) step = CH;
        done += step;
    }
    free(buf);
    return found;
}

