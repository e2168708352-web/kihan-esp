# 部署（v2 · 进程外只读）

新架构只有一条部署路线：模块 + espd 守护。**不需要 Zygisk / ZygiskFrida / gadget，不需要重启 zygote，不需要重启手机之外的任何手工操作**。旧三路线（模块/手动/frida-server）见 [LEGACY-gadget.md](LEGACY-gadget.md)。

## 一、构建

```powershell
# 1. 编译 espd（本地 NDK 28.2，零下载；生成 tools\espd\dist\espd-arm64）
$env:ANDROID_HOME='D:\iOS_Dev_Workspace\SDKs\android-sdk'
powershell -ExecutionPolicy Bypass -File tools\espd\build.ps1

# 32 位设备（罕见）加 -Abi arm 或 -Abi all

# 2. 打包模块（build 脚本会把 espd-arm64 放进 bin/，并校验无旧架构残留）
powershell -ExecutionPolicy Bypass -File module\build-module.ps1
#   → dist\esp_local-module.zip  (~2.8MB)
```

build 脚本已内置校验：zip 里必须含 `module.prop`、`service.d/97_espd.sh`、`bin/espd-{arm64,arm}`、`bin/espd-supervisor.sh`、`bin/espd.conf`，且不含 `97_esp_module.sh`/`libhw.so.gz`/`libhw.config`。

## 二、刷入

```powershell
$adb='D:\iOS_Dev_Workspace\SDKs\android-sdk\platform-tools\adb.exe'
& $adb push dist\esp_local-module.zip /data/local/tmp/
& $adb shell 'su -c "ksud module install /data/local/tmp/esp_local-module.zip"'
# Magisk: magisk --install-module ... ；APatch: 同名或管理器里刷
```

刷入后**正常重启一次手机**（KernelSU 模块 service.d 只有开机才跑）。此后：开机 → 自动起 supervisor → espd 等游戏 pid → 开游戏即画线。不再有「每次 reboot 注入丢失」。

> 不想重启就想先验证？可以不刷模块，直接手动把 `espd-arm64` + `espd.conf` push 到设备跑 `probe`/`scan`（见第四节）。

## 三、开机后的设备侧形态

```
/data/adb/modules/esp_local/
  module.prop
  service.d/97_espd.sh          开机入口
  bin/espd-arm64                ~31KB 二进制
  bin/espd-supervisor.sh        守护外壳
  bin/espd.conf                 配置模板
  esp/esp.apk                   悬浮窗

/data/local/tmp/.esp/
  espd.conf                     首次从模块拷贝，升级不覆盖
  espd.log                      日志（256KB 轮转）
  status.json                   每 30 帧原子写的状态
  espd.lock                     单实例锁
```

服务进程：`espd-arm64`（唯一常驻）、`espd-supervisor.sh`（shell 守护），均运行在 `u:r:ksu:s0`。

## 四、无游戏也能跑的诊断（关键：用脚本文件，不内联 su）

> 内联 `su -c '...'` 会掉到 `u:r:shell:s0`，读不到 `/data/adb`、也读不到其他 app 的 maps。所有 root 操作都必须走脚本文件。

在 PC 上写 `check.sh`：

```sh
#!/system/bin/sh
BIN=/data/adb/modules/esp_local/bin/espd-arm64
echo "ctx=$(cat /proc/self/attr/current)"
$BIN selftest
$BIN probe --pkg com.sys.deskhelper --dir /data/local/tmp/.esp
$BIN probe --pkg com.tencent.KiHan --dir /data/local/tmp/.esp   # 游戏没开会报 not running，正常
cat /data/local/tmp/.esp/status.json
```

```
adb push check.sh /data/local/tmp/check.sh
adb shell 'su -c "sh /data/local/tmp/check.sh"'
```

期望：`selftest: ok`；probe 的 `elf_ok=1`、`tracerpid=0`、`domain=u:r:ksu:s0`。这一步证明进程外只读链路成立，与账号能否进游戏无关。

## 五、进对局后的校准

账号能进游戏后：

```sh
# 写 verify.sh（同样 su -c "sh verify.sh"）
BIN=/data/adb/modules/esp_local/bin/espd-arm64
$BIN scan PVPStatis KH
$BIN scan Transform UnityEngine
$BIN scan Camera UnityEngine
cat /data/local/tmp/.esp/status.json      # cam=1 pvp=1 表示解析成功
```

- `scan` 输出各字段名 + offset，核对与 `docs/OFFSETS.md` 一致
- 状态里 `cam=1 pvp=1` 且悬浮窗出线 → 校准完成
- 线位置不对：改 `/data/local/tmp/.esp/espd.conf` 的 `fov/near/far`，`kill $(pidof espd-arm64)` 让 supervisor 自动重启即可生效

## 六、排错

| 现象 | 原因 | 处理 |
|---|---|---|
| 开机后没有 espd 进程 | service.d 没跑 / 域不对 | 看 `/data/local/tmp/.esp/espd.log` 有没有 `=== supervisor start`；域必须是 ksu |
| 日志里 `ctx=u:r:shell:s0` | 用错了内联 su 或管理器限制 | 改用脚本文件；确认 KernelSU 的 shell root 授权 |
| `probe` 报 `not running` | 游戏没开 | 正常，开游戏再跑 |
| `probe` 的 `elf_ok=0` | il2cpp 基址算错 / maps 没读到 | 确认 `--so libil2cpp.so`，日志看 maps 条数 |
| `scan` 报「字符串未找到」 | 游戏更新改了类名 | 用新类名重扫，改 `espd.conf` 的 `*_class` |
| `scan` 报「没有字段」 | 字段名改了 | 改 `espd.conf` 的 `field_*` |
| 状态 `pvp=0` | 不在对局 / PVPStatis 未解析 | 进 PVP 对局；看日志的 `PVPStatis 解析失败` |
| 状态 `cam=0` | Camera 解析失败 | 看日志；核对 `camera_ns/class` |
| 悬浮窗不出线但状态正常 | UDP 被拦截 / 悬浮窗没装 | `pm list packages \| grep deskhelper`；确认 29000 端口 |
| `errors` 持续涨 | UDP 发送失败 | 确认悬浮窗在收 127.0.0.1:29000 |

## 七、卸载

```sh
kill $(pidof espd-arm64) 2>/dev/null
kill $(pidof -x espd-supervisor.sh) 2>/dev/null
# 管理器里停用/删除 esp_local 模块；或：
rm -rf /data/adb/modules/esp_local
pm uninstall com.sys.deskhelper
rm -rf /data/local/tmp/.esp
```
