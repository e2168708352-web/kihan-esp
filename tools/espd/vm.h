// vm.h — 进程外只读内存访问（process_vm_readv），espd 的基础层
//
// 设计约束：
//   1) 绝不 ptrace attach —— attach 会让目标 /proc/<pid>/status 的 TracerPid 非 0，
//      这是反作弊最便宜的一条检测。process_vm_readv 只读、不留 TracerPid。
//   2) 所有读都先过 maps 校验 —— 目标进程随时在释放对象，读到 unmapped 页只会
//      返回 EFAULT；但绝不能把脏数据当指针继续用（后续 klass 校验兜底）。
//   3) 批量读优先 —— 单次 readv 最多 1024 个 iovec，能一次拉一大块就别分次。
#ifndef ESPD_VM_H
#define ESPD_VM_H

#include <stdint.h>
#include <stddef.h>

typedef struct {
    uint64_t start;
    uint64_t end;
    uint64_t off;
    char perms[8];
    char path[512];
} vm_map;

typedef struct {
    vm_map *items;
    int n;
    int cap;
} vm_maps;

/* 按进程名（cmdline 完全匹配）找 pid；找不到返回 -1 */
int vm_find_pid(const char *name);

/* 读目标进程内存。成功返回 0，失败返回 -1（errno 有效） */
int vm_read(int pid, uint64_t addr, void *buf, size_t len);

/* 读一个指针；失败返回 0，err 可区分「读到 0」和「读失败」 */
uint64_t vm_read_ptr(int pid, uint64_t addr, int *err);

/* 读标量（失败返回 def） */
uint32_t vm_read_u32(int pid, uint64_t addr, uint32_t def);
int32_t  vm_read_i32(int pid, uint64_t addr, int32_t def);
float    vm_read_f32(int pid, uint64_t addr, float def);

/* 读 C 字符串（最多 cap-1 字节）。成功返回长度，失败 -1 */
int vm_read_str(int pid, uint64_t addr, char *buf, size_t cap);

/* 在 [addr, addr+len) 里找 needle（分块读，块间重叠保证跨块匹配不漏）。
 * 命中返回地址，未找到返回 0。 */
uint64_t vm_find_bytes(int pid, uint64_t addr, size_t len,
                       const void *needle, size_t nlen);

/* 加载 /proc/<pid>/maps */
int vm_load_maps(int pid, vm_maps *out);
void vm_free_maps(vm_maps *m);

/* 取某个 so 的加载基址（按 basename 后缀匹配，取最小 start - off） */
uint64_t vm_module_base(const vm_maps *m, const char *soname);

#endif
