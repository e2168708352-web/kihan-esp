> [!IMPORTANT]
> **个人学习 / 研究用途声明**
>
> 本项目仅限个人学习与研究，**禁止商业盈利、付费分发、捆绑销售**，禁止用于恶意软件、窃密、破坏或冒名官方分发。
>
> **唯一官方分发入口**是本仓库的 [GitHub Releases 页面](https://github.com/e2168708352-web/kihan-esp/releases)。任何非 Releases 页面（QQ 群 / 网盘 / 第三方站点 / 收费群）提供的安装包均**非官方**，作者不担保，风险自负。
>
> 官方**不会**索要账号密码、要求关闭安全软件，也不会通过 QQ 群 / 网盘直发安装包。详见 [SECURITY.md](SECURITY.md)。

# kihan-esp

火影忍者手游（`com.tencent.KiHan`，Unity + il2cpp）的**进程外只读** ESP 实现：root 守护进程 `espd` 站在游戏外面用 `process_vm_readv` 读内存、投影，通过 UDP 把坐标发给悬浮窗画。**游戏进程零注入、零线程、零外来 so、零文件写入**——不需要 Zygisk / ZygiskFrida / Frida gadget，不需要重启 zygote，不需要重启手机。

只画「自己→敌人」直线：无四角框、无箭头、不显示血量。

---

## 功能

| 能力 | 说明 |
|---|---|
| 敌人直线 | 自己脚下 → 敌人，去掉四角框与箭头 |
| 距离 | 相机空间欧氏距离，米 |
| 替身倒计时 | 读 `PVPStatis.enemySubstituteCurStateFlag`，1→0 触发，0→1 校准真实 CD（旧脚本能力，新 daemon 正在补齐） |
| 心跳/状态 | `espd` 每 30 帧写 `/data/local/tmp/.esp/status.json`，不写游戏目录 |
| 自检/诊断 | `espd probe` / `espd scan <类> [命名空间]` / `espd selftest` |

悬浮窗侧不渲染血量：UDP 的 `U` 行照发 hp/mx 字段（填 -1），View 不画。

## 架构（v2 · 进程外只读）

```
[com.tencent.KiHan]        完全干净：无外来 so、无外来线程、无外来文件
        ↑ process_vm_readv（只读，不设 TracerPid；hidepid=invisible 下游戏看不见 espd）
[espd]  root 常驻守护，~31KB 原生，运行在 u:r:ksu:s0
        ├─ 自解析：读 libil2cpp 内存，按「类名/字段名」定位 Il2CppClass（不硬编码偏移）
        ├─ 读世界：PVPStatis.statis → 我方/敌方 actor → Transform 父链 → 世界坐标
        ├─ 算屏幕：相机 Transform → 自建视图矩阵 → 投影（buildView/project）
        └─ 发 UDP 127.0.0.1:29000（帧格式一字不改）
        ↓
[com.sys.deskhelper]       悬浮窗，绘制代码零改动（仅对局期间由 desk-watch 拉起）
```

启动链路：`service.d/97_espd.sh → espd-supervisor.sh → espd daemon`。无 post-fs-data、无 zygote 重启、无 pkill qsguard、无 mount、无 reboot。

> 旧架构（Frida gadget 注入）已归档到 [docs/LEGACY-gadget.md](docs/LEGACY-gadget.md)，不再维护。

## 目录

```
esp/                  参考实现 esp.js（旧脚本，保留作逻辑参考/未来 qjs 复用）
module/               刷机模块：module.prop、service.d 启动器、bin/espd 二进制+脚本、build 脚本
overlay/              悬浮窗 APK 源码（smali）+ 构建脚本 + 预编译 APK
tools/espd/           espd 源码（vm / scan / project / udp / main）+ NDK 构建脚本
tools/                其他历史工具（部署/热更新/gadget 拉取/实验性注入器，legacy）
docs/                 协议、偏移表、部署、加固、模块方案、旧架构归档
```

## 快速开始

```powershell
# 1. 编译 espd（本地 NDK，零下载）
$env:ANDROID_HOME='D:\iOS_Dev_Workspace\SDKs\android-sdk'
powershell -ExecutionPolicy Bypass -File tools\espd\build.ps1

# 2. 打包模块（自动把 espd-arm64 放进 bin/）
powershell -ExecutionPolicy Bypass -File module\build-module.ps1
#   → dist\esp_local-module.zip  (~2.8MB)

# 3. 刷入模块
adb push dist\esp_local-module.zip /data/local/tmp/
adb shell 'su -c "ksud module install /data/local/tmp/esp_local-module.zip"'
```

刷入后 espd 即开始工作，开游戏即在 33ms 内发现 pid 并画线（首次 il2cpp 类扫描约 1s）。

**「开机自启」取决于 root 类型**，两种情形差别很大：

| root 类型 | 完整重启后 | 软重启（`ctl.restart zygote`）后 |
|---|---|---|
| 永久 root（内核已打 KSU 补丁） | ✅ `service.d` 自动起 espd，零手工 | ✅ espd 不受影响 |
| **临时 root**（运行时打补丁） | ❌ root 消失，需重新获取后跑 `espd_boot.sh` | ✅ root 与 espd 都保留，直接开游戏 |

软重启这一点已实测：`espd` / `supervisor` / 悬浮窗全部存活，只有游戏进程（zygote 子进程）会被杀。详见 [docs/TEMP-ROOT.md](docs/TEMP-ROOT.md)。

验证（不进游戏也能跑）：

```sh
su -c "sh -c '/data/adb/modules/esp_local/bin/espd-arm64 selftest'"
su -c "sh -c '/data/adb/modules/esp_local/bin/espd-arm64 probe --pkg com.sys.deskhelper'"
su -c "cat /data/local/tmp/.esp/status.json"
su -c "tail -20 /data/local/tmp/.esp/espd.log"
```

进对局后再扫描类、核对字段：

```sh
su -c "sh -c '/data/adb/modules/esp_local/bin/espd-arm64 scan PVPStatis KH'"
su -c "sh -c '/data/adb/modules/esp_local/bin/espd-arm64 scan Transform UnityEngine'"
```

> Windows 下所有 root 操作都要走「脚本文件 + `su -c "sh /path/x.sh"`」，不要内联 `su -c '...'`——内联会掉到 `u:r:shell:s0`，读不到 app 内存与 `/data/adb`（见 [docs/MODULE.md](docs/MODULE.md)）。

## 环境要求

- 设备：arm64 Android 8.0+（32 位设备可加 `-Abi arm` 编译 `espd-arm`）
- Root：KernelSU / KernelSU Next / Magisk / APatch（service.d 脚本须运行在能读 app 内存的域，KernelSU 实测 `u:r:ksu:s0` 可用）
- **不需要** Zygisk / ZygiskFrida
- 构建：本地 NDK 28.2（clang 19），零下载；不需要 cmake

## 访问范围与网络目标

守护进程 `espd` 坚持最小权限、只读、无隐蔽网络上报：

- **权限**：root（KernelSU / Magisk / APatch），运行在 `u:r:ksu:s0` 域。
- **内存访问**：仅对目标游戏进程用 `process_vm_readv` **只读**；不写目标内存、不 ptrace attach（`TracerPid=0`）、不做 inline hook。
- **文件访问**：仅读写自身工作目录 `/data/local/tmp/.esp/`；**不写游戏目录一个字节**。
- **网络目标**：仅 UDP `127.0.0.1:29000`（本机回环，发往悬浮窗）；**无外网连接、无远程上报**。
- **动态加载**：不加载不明 `dex` / `so`，不从远程拉取可执行文件。

详见 [SECURITY.md](SECURITY.md) 与 [docs/HARDENING.md](docs/HARDENING.md)。

### 临时 root 特别注意

如果 root 是**运行时临时获取的**（内核没打 KSU 补丁，**完整重启**后 `su` 消失），`service.d` 不会开机自启，需要重新获取 root 后手动跑一次启动脚本：

```powershell
adb push module\bin\espd_boot.sh /data/local/tmp/
adb shell 'su -c "sh /data/local/tmp/espd_boot.sh"'
```

脚本会自检 root、起 supervisor、装 desk、打印状态。完整流程与判断方法见 [docs/TEMP-ROOT.md](docs/TEMP-ROOT.md)。

## 文档

- [docs/MODULE.md](docs/MODULE.md) — 模块方案、启动链路、espd 四个模式（主线）
- [docs/TEMP-ROOT.md](docs/TEMP-ROOT.md) — 临时 root 的部署流程（重启后如何恢复）
- [docs/PROTOCOL.md](docs/PROTOCOL.md) — UDP 帧格式
- [docs/OFFSETS.md](docs/OFFSETS.md) — 类/字段偏移与运行时自解析
- [docs/DEPLOY.md](docs/DEPLOY.md) — 构建、刷入、诊断、排错
- [docs/HARDENING.md](docs/HARDENING.md) — 暴露面分析与加固方向
- [docs/SECURITY-ASSESSMENT.md](docs/SECURITY-ASSESSMENT.md) — 对抗反作弊的安全性量化评估（逐项打分）
- [SECURITY.md](SECURITY.md) — 唯一官方分发入口、构建校验、非官方渠道声明、访问范围
- [docs/REPORT-DRAFTS.md](docs/REPORT-DRAFTS.md) — 巡查记录与举报草稿（内部）
- [docs/LEGACY-gadget.md](docs/LEGACY-gadget.md) — 旧注入架构归档（已弃用）

## 已知限制

- `espd.conf` 里的 `fov/near/far` 与相机朝向读取仍需真机校准；未在实机对局中完整验证过。
- 当前只对局内出线（依赖 `PVPStatis`）；练习场/PVE 的「离相机最近=自己」兜底尚未在 espd 里实现，见 [docs/OFFSETS.md](docs/OFFSETS.md)。
- 敌人技能 CD 倒计时：替身 CD 已在旧脚本实现，espd 版本待补。
- 投影不用 `worldToCameraMatrix_Injected`（这套渲染管线下返回近似单位矩阵的假值），改用相机 Transform 自建视图矩阵。
- 这是持续对抗，客户端零痕迹不等于零风险；服务端行为模型永远存在。加固思路见 [docs/HARDENING.md](docs/HARDENING.md)。

## License

MIT，见 [LICENSE](LICENSE)。

仅供在自有设备上研究 Unity/il2cpp 运行时反射、进程内存读取与图形投影。使用后果自负。
