// inject.c — ptrace dlopen injector for Android arm64
// usage: inject <pid> <absolute-so-path>
#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <errno.h>
#include <dlfcn.h>
#include <libgen.h>
#include <sys/ptrace.h>
#include <sys/wait.h>
#include <sys/uio.h>
#include <sys/types.h>
#include <signal.h>
#include <stdint.h>

struct regs64 {
    unsigned long long regs[31];
    unsigned long long sp;
    unsigned long long pc;
    unsigned long long pstate;
};

#ifndef NT_PRSTATUS
#define NT_PRSTATUS 1
#endif

static unsigned long long find_base(const char *maps_path, const char *needle, int *found) {
    FILE *f = fopen(maps_path, "r");
    if (!f) { *found = 0; return 0; }
    char line[1024];
    unsigned long long best = 0; int ok = 0;
    while (fgets(line, sizeof(line), f)) {
        if (!strstr(line, needle)) continue;
        unsigned long long start = 0, end = 0, off = 0;
        char perms[8] = {0}, dev[32] = {0}, path[512] = {0};
        unsigned long inode = 0;
        int n = sscanf(line, "%llx-%llx %7s %llx %31s %lu %511s",
                       &start, &end, perms, &off, dev, &inode, path);
        if (n < 3) continue;
        unsigned long long base = start - (off & ~0xfffULL);
        if (!ok || base < best) { best = base; ok = 1; }
    }
    fclose(f);
    *found = ok;
    return best;
}

static int poke(pid_t pid, unsigned long long addr, const void *buf, size_t len) {
    const unsigned char *p = (const unsigned char *)buf;
    size_t i = 0;
    while (i < len) {
        unsigned long long word = 0;
        size_t n = len - i; if (n > 8) n = 8;
        memcpy(&word, p + i, n);
        if (ptrace(PTRACE_POKEDATA, pid, (void *)(uintptr_t)(addr + i), (void *)(uintptr_t)word) < 0)
            return -1;
        i += n;
    }
    return 0;
}

static int get_regs(pid_t pid, struct regs64 *r) {
    struct iovec io = { r, sizeof(*r) };
    return ptrace(PTRACE_GETREGSET, pid, (void *)NT_PRSTATUS, &io);
}
static int set_regs(pid_t pid, struct regs64 *r) {
    struct iovec io = { r, sizeof(*r) };
    return ptrace(PTRACE_SETREGSET, pid, (void *)NT_PRSTATUS, &io);
}

// 解析目标进程里某个导出函数的地址：本地 dlsym + dladdr 定位模块，再在目标 maps 里找同名模块基址
static int resolve_remote(const char *sym, const char *target_maps, unsigned long long *out) {
    void *s = dlsym(RTLD_DEFAULT, sym);
    if (!s) return -1;
    Dl_info di;
    if (!dladdr(s, &di) || !di.dli_fbase || !di.dli_fname) return -1;
    char tmp[512];
    snprintf(tmp, sizeof(tmp), "%s", di.dli_fname);
    const char *base = basename(tmp);
    int ok = 0;
    unsigned long long tbase = find_base(target_maps, base, &ok);
    if (!ok) return -1;
    *out = tbase + ((unsigned long long)(uintptr_t)s - (unsigned long long)(uintptr_t)di.dli_fbase);
    return 0;
}

int main(int argc, char **argv) {
    if (argc < 3) { fprintf(stderr, "usage: %s <pid> <so-path>\n", argv[0]); return 2; }
    pid_t pid = (pid_t)atoi(argv[1]);
    const char *so = argv[2];
    if (pid <= 1) { fprintf(stderr, "bad pid\n"); return 2; }
    if (strlen(so) > 400) { fprintf(stderr, "path too long\n"); return 2; }

    char target_maps[64];
    snprintf(target_maps, sizeof(target_maps), "/proc/%d/maps", (int)pid);
    if (access(target_maps, R_OK) != 0) { fprintf(stderr, "no access to %s\n", target_maps); return 3; }

    // caller_addr：用目标进程自己的 libil2cpp.so 基址（落在 app 的 linker namespace 里）
    int ok = 0;
    unsigned long long caller = find_base(target_maps, "libil2cpp.so", &ok);
    if (!ok) caller = find_base(target_maps, "libc.so", &ok);

    unsigned long long fn = 0;
    int nargs = 0;
    const char *which = NULL;
    if (resolve_remote("android_dlopen_ext", target_maps, &fn) == 0) { nargs = 4; which = "android_dlopen_ext"; }
    else if (resolve_remote("__loader_dlopen", target_maps, &fn) == 0) { nargs = 3; which = "__loader_dlopen"; }
    else if (resolve_remote("dlopen", target_maps, &fn) == 0) { nargs = 2; which = "dlopen"; }
    if (!fn) { fprintf(stderr, "cannot resolve dlopen\n"); return 4; }
    fprintf(stderr, "using %s @ %llx caller=%llx\n", which, fn, caller);

    if (ptrace(PTRACE_ATTACH, pid, NULL, NULL) < 0) { fprintf(stderr, "attach: %s\n", strerror(errno)); return 6; }
    int status = 0;
    if (waitpid(pid, &status, __WALL) < 0) { fprintf(stderr, "waitpid: %s\n", strerror(errno)); ptrace(PTRACE_DETACH, pid, NULL, NULL); return 7; }

    struct regs64 saved, r;
    if (get_regs(pid, &saved) < 0) { fprintf(stderr, "getregs: %s\n", strerror(errno)); ptrace(PTRACE_DETACH, pid, NULL, NULL); return 8; }
    r = saved;

    unsigned long long sp = saved.sp & ~0xfULL;
    unsigned long long path_addr = sp - 0x4000;
    unsigned long long stub_addr = sp - 0x3000;
    unsigned int brk_insn = 0xD4200000u; // brk #0

    if (poke(pid, path_addr, so, strlen(so) + 1) < 0) { fprintf(stderr, "poke path: %s\n", strerror(errno)); goto fail; }
    if (poke(pid, stub_addr, &brk_insn, sizeof(brk_insn)) < 0) { fprintf(stderr, "poke stub: %s\n", strerror(errno)); goto fail; }

    r.regs[0] = path_addr;
    r.regs[1] = 2;            // RTLD_NOW
    r.regs[2] = (nargs >= 3) ? caller : 0;
    r.regs[3] = (nargs >= 4) ? caller : 0;
    r.regs[30] = stub_addr;   // LR -> brk #0
    r.pc = fn;

    if (set_regs(pid, &r) < 0) { fprintf(stderr, "setregs: %s\n", strerror(errno)); goto fail; }
    if (ptrace(PTRACE_CONT, pid, NULL, NULL) < 0) { fprintf(stderr, "cont: %s\n", strerror(errno)); goto fail; }

    if (waitpid(pid, &status, __WALL) < 0) { fprintf(stderr, "wait2: %s\n", strerror(errno)); goto fail; }
    int sig = WIFSTOPPED(status) ? WSTOPSIG(status) : -1;

    struct regs64 after;
    unsigned long long ret = 0;
    if (get_regs(pid, &after) == 0) ret = after.regs[0];

    set_regs(pid, &saved);
    ptrace(PTRACE_DETACH, pid, NULL, NULL);

    if (sig == SIGTRAP) {
        fprintf(stderr, "ok: %s(%s) -> %llx\n", which, so, ret);
        return ret ? 0 : 11;
    }
    fprintf(stderr, "stopped with signal %d (ret=%llx)\n", sig, ret);
    return 9;

fail:
    set_regs(pid, &saved);
    ptrace(PTRACE_DETACH, pid, NULL, NULL);
    return 10;
}
