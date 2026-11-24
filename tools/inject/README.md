# ptrace 注入器（实验性，未验证）

`inject.c` —— arm64 上通过 ptrace 在目标进程里调 `dlopen` 的小工具，用来在不依赖 Zygisk 的情况下把 gadget 塞进游戏进程。

**状态：未跑通。** 第一次测试目标进程 `SIGSEGV`（原因：`__loader_dlopen` 实际是 3 参，且符号所在模块基址解析错了）。代码已重写为依次尝试 `android_dlopen_ext` / `__loader_dlopen` / `dlopen`，用 `dladdr` 定位模块基址，但**没有在设备上复测成功**。仓库里保留它是因为思路完整、可继续调。

主线部署不要用它，走 `docs/DEPLOY.md` 的模块或 ZygiskFrida 路线。

## 原理

```
PTRACE_ATTACH
  ↓ 读 NT_PRSTATUS（struct user_pt_regs：31 个 x + sp + pc + pstate）
  ↓ 在目标栈下方写：path 字符串、stub（brk #0 指令）
  ↓ 设 x0=path, x1=RTLD_NOW, x2/x3=caller_addr, lr=stub, pc=dlopen
PTRACE_CONT
  ↓ dlopen 执行完 ret 到 stub → brk #0 → SIGTRAP
读 x0 = 返回值（handle）
恢复全部寄存器 → PTRACE_DETACH
```

目标进程不留线程、不留 ptrace 痕迹（attach 期间会被 `TracerPid` 看到）。

## 编译

```powershell
$ndk = 'D:\iOS_Dev_Workspace\SDKs\android-sdk\ndk\28.2.13676358\toolchains\llvm\prebuilt\windows-x86_64\bin'
& "$ndk\aarch64-linux-android26-clang.cmd" -O2 -fPIE -pie -Wall -o inject inject.c -ldl
```

产物约 10.7KB，ELF aarch64 PIE。

## 用法

```sh
su -c "/data/local/tmp/.sys/inject $(pidof com.tencent.KiHan) /data/local/tmp/.sys/libhw.so"
```

## 已知坑

1. **`caller_addr` 必须在目标的 linker namespace 里**。传 0 会走到默认 namespace，`/data/local/tmp` 下的 so 加载不到。用目标进程的 `libil2cpp.so` 基址当 caller。
2. **`__loader_dlopen` 是 3 参**（`name, flags, caller_addr`），`android_dlopen_ext` 是 4 参（多一个 `extinfo`）。签名搞错就是 `SIGSEGV`。
3. **符号地址不能直接用本地 dlsym 的结果**。必须先 `dladdr` 拿到本地模块基址，再在目标 `/proc/<pid>/maps` 里找同名模块基址，做差。
4. **栈上写数据要留余量**。代码用 `sp-0x4000` 放路径、`sp-0x3000` 放 stub，避开目标当前栈帧。
5. **目标可以读 `TracerPid` 发现被 attach**。注入窗口越短越好，attach 期间别做多余 syscall。

## 为什么不建议走这条路

- 每次注入都是一次 ptrace attach，特征明显
- gadget 落地后 maps / 线程 / 字符串特征跟 Zygisk 路线完全一样，隐蔽性没有提升
- 只能用在「有 root 但没有 Zygisk」的机器上
