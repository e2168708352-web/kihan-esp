# 临时 root 的部署流程

**这套方案在临时 root 环境下走的路，和永久 root 完全不同。** 先确认自己是哪种。

## 一、怎么判断自己是临时 root

```sh
su -c "id"                                    # uid=0 说明有 root
su -c "cat /proc/self/attr/current"           # u:r:ksu:s0 说明域可用
cat /proc/version                              # 看内核串里有没有 ksu/susfs 标记
ls /sys/module/ | grep -iE 'kernelsu|ksu'     # 有则内核已打补丁
```

判定：

| 现象 | 结论 |
|---|---|
| `/proc/version` 有 ksu 标记，或 `/sys/module/kernelsu` 存在 | **永久 root**（内核已刷），`service.d` 能开机自启 |
| 内核串干净、无 ksu 模块，但 `su` 能用 + 域是 `u:r:ksu:s0` | **临时 root**（运行时打补丁），重启后消失 |

本机实测：`Linux 6.6.89-android15-8`，内核无 KSU 标记，但 `su 3.3.1:KernelSU` 可用、域为 `u:r:ksu:s0` → **临时 root**。

## 二、临时 root 下会发生什么

**关键：要区分「完全重启」和「软重启」，两者后果完全不同。**

### 完全重启（关机 / `reboot`）

| 组件 | 状态 |
|---|---|
| 临时 root（`su` / `u:r:ksu:s0`） | ❌ **消失** |
| `service.d/97_espd.sh` 开机自启 | ❌ **不执行**（没有 KSU 就没有这个阶段） |
| `/data/adb/modules/esp_local/` 文件 | ✅ 还在（文件不依赖 root 存活） |
| `espd` 进程 | ❌ 不会自己起来 |
| 悬浮窗 desk | ✅ 普通 App，能用 |
| **ESP 功能** | ❌ **完全不可用**（读不到游戏内存） |

**所以：临时 root 下没有「开机自启」这回事。完全重启后必须手动跑一次启动脚本。**

### 软重启（`setprop ctl.restart zygote`）

本机实测结果：

| 组件 | 状态 |
|---|---|
| 临时 root | ✅ **保留**（软重启只重启 Java 层，不碰内核补丁） |
| `espd` 进程 | ✅ **存活**，pid 不变（挂在 supervisor 下，不在 zygote 子进程链） |
| `supervisor` | ✅ 存活，仍为单实例 |
| 悬浮窗 desk | ✅ 存活 |
| 游戏进程 | ❌ 会被杀（它是 zygote 的子进程），需重新打开 |
| `zygote64` pid | 会变（探针实测 30913/30922 → 6993/7003） |
| zygote 里的 `libzygisk` | ⚠️ **仍为 3，清不掉** |

两个值得记住的点：

1. **软重启后不用跑启动脚本** —— espd 自己活着，直接开游戏即可。
2. **软重启清不掉 `libzygisk`** —— zygisk 在 init/post-fs-data 阶段就加载了，`ctl.restart zygote` 只是重新 fork 一个已带该库的 zygote。要清掉只有完全重启。不过 `libzygisk` 对本方案无影响，espd 不依赖它。

### 一张表看清区别

| | 完全重启 | 软重启 |
|---|---|---|
| 临时 root | ❌ 消失 | ✅ 保留 |
| espd | ❌ 停 | ✅ 活着 |
| 需要跑 `espd_boot.sh` | ✅ 需要 | ❌ 不需要 |
| 能清掉 `libzygisk` | ✅ 能 | ❌ 不能 |

## 三、每次重新拿到 root 后的恢复流程

```powershell
# 1. 确认 root 已就绪
adb shell 'su -c "id"'
# 期望 uid=0(root)

# 2. 推送启动脚本（只需一次，重启后文件还在）
adb push module\bin\espd_boot.sh /data/local/tmp/

# 3. 跑它（注意：必须是脚本文件形式，不能内联命令）
adb shell 'su -c "sh /data/local/tmp/espd_boot.sh"'
```

脚本会做五件事：

1. **root 自检** —— 确认 uid=0 且域不是 `shell`（掉域会明确报错并提示正确用法）
2. **定位 espd** —— 依次找 `模块/bin/espd-arm64` → `.esp/bin/espd-arm64` → `/data/local/tmp/espd`，复制到工作目录
3. **起 supervisor** —— 先杀掉残留实例，清锁文件，单例启动
4. **装 desk** —— 没装就装，已装则补悬浮窗权限
5. **输出状态** —— espd pid、加载域、游戏进程、日志与诊断命令

成功输出长这样：

```
[1] root 自检
    uid=0
    ctx=u:r:ksu:s0
    域可用 ✓
[3] 启动 espd
    espd pid=5514 ✓
    domain=u:r:ksu:s0
[5] 状态
    espd:  5514
    游戏:  未运行（开游戏后自动接管）
```

## 四、关键陷阱：内联 su 会掉域

```sh
# ❌ 错误：会掉到 u:r:shell:s0，读不到 app 内存
adb shell 'su -c "chmod 755 /data/local/tmp/espd; /data/local/tmp/espd probe"'

# ✅ 正确：脚本文件，保持在 u:r:ksu:s0
adb push x.sh /data/local/tmp/
adb shell 'su -c "sh /data/local/tmp/x.sh"'
```

不只是引号被拆的问题——**SELinux 域也会掉**。`espd_boot.sh` 会自检并拦住这种情况。

## 五、日常操作

```sh
# 看状态
su -c "cat /data/local/tmp/.esp/status.json"
su -c "tail -20 /data/local/tmp/.esp/espd.log"

# 重启 espd（改了 conf 后）
su -c "sh /data/local/tmp/espd_boot.sh"

# 停止
su -c "kill \$(pidof espd-arm64)"
su -c "kill \$(pidof -x espd-supervisor.sh)"
```

desk 的三个按钮也是走同一套命令（部署 = 重启 espd，重载 = kill 重启，诊断 = 读 status.json + 日志），所以在临时 root 下点按钮同样可用。

## 六、永久 root 才有的差别

如果将来刷了永久 root（内核补丁），才能享受：

- `service.d/97_espd.sh` 开机自动执行，**开机即用，零手工**
- `zygisksu` 等模块的 `disable` 在开机时正式生效

临时 root 下这两条都不成立，必须保留手动跑 `espd_boot.sh` 的习惯。

## 七、常见问题

| 现象 | 原因 | 处理 |
|---|---|---|
| `不是 root，退出` | 临时 root 还没获取 | 先重新 root |
| `在 shell 域（读不到 app 内存）` | 内联了 `su -c "..."` | 改用脚本文件 |
| `找不到 espd-arm64` | 模块没刷 / 被清理 | `ksud module install` 重刷 |
| `espd 未起来` | 见日志 | `tail /data/local/tmp/.esp/espd.log` |
| 游戏开了但没线 | 没进对局 / 类解析失败 | 看 `status.json` 的 `cam`/`pvp` 字段与日志诊断行 |
