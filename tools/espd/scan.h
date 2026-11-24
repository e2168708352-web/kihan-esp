// scan.h — il2cpp 元数据的进程外自解析
//
// 进程外不能调用 il2cpp_* API（那是目标进程里的函数），所以所有解析
// 都建立在「读内存 + 已知结构布局」上。为了避免随版本偏移失效，
// 这里不硬编码任何类/字段偏移，而是：
//
//   1) 在目标进程的可读段里搜类名字符串，拿到该字符串的地址 A
//   2) 在 libil2cpp 的可写段里搜「值等于 A 的 8 字节」→ 命中位置 - 0x10 = Il2CppClass*
//   3) 用 namespaze 二次校验（字符串共享会让 name 命中多个候选）
//   4) 用「FieldInfo.name 能否解析成合法标识符」探测 fields 指针偏移与 field_count
//
// 这样即使游戏更新换了字段偏移，类与字段的定位仍然成立；
// 真正会变的只有 Il2CppClass 内部的固定布局（几年才动一次），
// 而且也是靠探测而不是硬编码兜住的。
#ifndef ESPD_SCAN_H
#define ESPD_SCAN_H

#include <stdint.h>
#include "vm.h"

#define SCAN_MAX_FIELDS 256

typedef struct {
    uint64_t klass;
    char ns[96];
    char name[112];
    int fields_off;        /* Il2CppClass 里 FieldInfo* 的偏移，0 = 未探测到 */
    int field_count;       /* 字段个数，0 = 未探测到 */
    int static_fields_off; /* Il2CppClass 里 static_fields 的偏移，0 = 未探测到 */
} ic_class;

typedef struct {
    char name[128];
    int32_t offset;
    int is_static;
    uint64_t type_ptr;
} ic_field;

/* 每次都基于最新 maps 工作；内部只做少量缓存，可以放心反复调用 */
int  scan_find_class(int pid, const vm_maps *m, const char *soname,
                     const char *ns, const char *name, ic_class *out);

/* 列出类的字段（实例 + 静态），返回个数，失败 -1 */
int  scan_fields(int pid, const ic_class *c, ic_field *out, int cap);

/* 从已知 klass 地址准备一个可查询的 ic_class（探测 fields/count/static）。
 * 供调用方对「运行时拿到的对象 klass」做一次性解析，避免重复实现探测逻辑。 */
int  scan_prepare(int pid, uint64_t klass, const char *ns, const char *name, ic_class *out);

/* 在字段表里按名字查；返回 0 成功 */
int  scan_field_by_name(int pid, const ic_class *c, const char *name, ic_field *out);

/* 读静态字段的值（class 的 static_fields + field.offset 处的指针） */
uint64_t scan_static_object(int pid, const ic_class *c, const ic_field *f);

/* 从对象读字段（实例字段偏移） */
uint64_t scan_obj_ptr(int pid, uint64_t obj, const ic_field *f);

/* 最近一次操作的诊断串（含字段数未知等警告，供 resolve 失败时打印） */
const char *scan_last_error(void);
void scan_set_warn(const char *fmt, ...);

#endif
