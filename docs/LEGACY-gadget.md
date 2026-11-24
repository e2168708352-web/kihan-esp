# 旧架构归档（gadget 注入 · 已弃用）

本文保留旧方案的实现与排错记录，供回滚与历史参考。**当前主线已迁移到进程外只读方案（见 `MODULE.md`）**，不要在新设备上再走这条路。

## 旧架构一句话

Frida gadget（`libhw.so`，39MB）由 ZygiskFrida 注入游戏进程 → script 模式加载 `esp.js` → hook `VActor.LateUpdate` 收集实体 + hook 相机 `LateUpdate` 跑 tick → 自建视图矩阵投影 → UDP 29000 → 悬浮窗画线；`.dh` 心跳给 keeper 判活。

## 为什么弃用

1. **暴露面是结构性的**：`gum-js-loop` / `gmain` 线程名、`/proc/self/maps` 里的 `libhw.so`、`frida:rpc` 字符串、`.dh` 明文心跳——任何进程内取证都能直接读到这些特征。
2. **设备侧极不稳定**：KernelSU 3.3.1 + ColorOS 的 `oplus_secure_guard_new` 在 root exec ksud/magisk 时 `execve_block`，zygiskd 被抢时序打断 → zygote 无 libzygisk → gadget 注入随机丢失。为对抗它要 pkill qsguard、mount bind `/dev/null`、`ctl.restart zygote`（掉 adb、屏幕黑一下）。
3. **维护成本倒挂**：光对抗 secureguard 就有 post-fs-data 12 秒 pkill、sepolicy、zygisk 自愈一堆代码，且每次开机都可能失效。

## 遗留设备坑（换架构后仍值得记）

- **内联 `su -c '...'` 会掉到 `u:r:shell:s0`**：读不到 `/data/adb`、读不到其他 app 的 maps。必须用脚本文件：`adb push x.sh /data/local/tmp/` 然后 `su -c "sh /data/local/tmp/x.sh"`。不只是引号被拆，SELinux 域也会掉。
- `/system_ext/bin/qsguard` 可被 `mount -o bind /dev/null` 覆盖成字符设备 1,3；但内核侧 `oplus_secure_guard_new` 的 execve 拦截仍在。
- zygote 有 libzygisk ≠ 游戏里有 gadget；实测 app 进程 maps 里 zygisk=0。
- `.dh` 心跳在 `/data/user/0/com.tencent.KiHan/files/.dh`（不是 `.sys/.dh`），格式 `t=.. mat=1 ent=0 tk=215 pvp=0 g=0`。
- 热更新 `esp.js` 必须原地写（`cat >`、`dd conv=notrunc`），cp/mv 换 inode 会让 gadget 的 inotify 失效。
- 设备：Android 16 / ColorOS 实测（arm64）。adb 路径按自己的 SDK 位置替换。

## 旧部署三路线（历史）

| | A. 模块 | B. 手动 + ZygiskFrida | C. frida-server |
|---|---|---|---|
| Zygisk | 是 | 是 | 否 |
| 开机自启 | 守护脚本 | ZygiskFrida 自管 | 每次手动 |
| 隐蔽性 | 低（gadget 特征） | 低 | 最低 |

ZygiskFrida 配置 `/data/local/tmp/re.zyg.fri/config.json`：

```json
{"targets":[{"app_name":"com.tencent.KiHan","enabled":true,"start_up_delay_ms":20000,
"injected_libraries":[{"path":"/data/local/tmp/.sys/libhw.so"}]}]}
```

gadget 配置 `/data/local/tmp/.sys/libhw.config`（script 模式，on_change reload，runtime qjs）：

```json
{"interaction":{"type":"script","path":"/data/local/tmp/.sys/esp.js","on_change":"reload"},"runtime":"qjs"}
```

`.sys` 内文件要求 `chmod 644` + `chcon u:object_r:apk_data_file:s0`，否则跑在 untrusted_app 里的 gadget 读不到。

## 回滚步骤

```powershell
git checkout <旧 commit> -- module/ esp/ docs/DEPLOY.md docs/HARDENING.md docs/PROTOCOL.md
powershell -ExecutionPolicy Bypass -File tools\fetch-gadget.ps1
powershell -ExecutionPolicy Bypass -File module\build-module.ps1 -WithServiceSh
```

然后刷模块、装 Zygisk Next + ZygiskFrida、重启手机、开游戏等 20s。排错细节见 git 历史里此前的 `DEPLOY.md` / `HARDENING.md`。
