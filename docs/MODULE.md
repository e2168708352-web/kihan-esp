# 模块方案（v2 · 进程外只读）

从「对抗 secureguard 的战争机器」退化成「一个开机启动器 + 一个只读进程」。

## 为什么换架构

旧架构把 gadget 注入游戏进程：要 zygisk、要抢 post-fs-data 时序、撞 secureguard、重启 zygote、掉 adb，而且游戏进程里留着 `gum-js-loop` 线程、39MB `libhw.so`、`.dh` 文件——这些特征对任何进程内取证来说都是直接可读的。

新架构**不往游戏进程里塞任何东西**：root 守护进程 `espd` 站在游戏外面，用 `process_vm_readv` 只读内存，按既有 UDP 协议把坐标发给悬浮窗。

关键实测（本机 Android 16 / KernelSU 3.3.1）：

```
service.d 脚本域        u:r:ksu:s0          ← 能读任意 app 的 /proc/<pid>/maps
espd 跨进程读 com.oplus.blur  elf_ok=1  tracerpid=0
/proc 挂载             hidepid=invisible
app uid 视角进程数      3（root 视角 933）  ← 游戏看不见 espd
app pidof espd-arm64    空
```

## 模块结构

```
esp_local/
├── module.prop                 v2.0，去掉 Zygisk 依赖描述
├── service.d/
│   └── 97_espd.sh              唯一入口，nohup 起 supervisor 后立刻返回
├── bin/
│   ├── espd-arm64              31,888 B，进程外只读 daemon
│   ├── espd-supervisor.sh      单例 + 退避 5→15→60s + 日志轮转 + 悬浮窗保活
│   └── espd.conf               配置模板（类/字段名、投影校准）
└── esp/
    └── esp.apk                 悬浮窗，UDP 绘制零改动
```

**删掉**：`post-fs-data.sh`、`service.sh.fallback`、`97_esp_module.sh`（旧 keeper）、`esp/libhw.so.gz`（14.7MB gadget）、`esp/libhw.config`、`ZygiskFrida` 配置、`watch.sh` 的 reload 双写。

模块 zip：17,383,011 B → **2,796,531 B**（瘦身 84%）。

## 启动链路（没有时序，所以没有时序问题）

```
init → ksud (late_start)
     → sh 97_espd.sh                    [ksu 域，立即返回]
        → nohup espd-supervisor.sh &    [ksu 域]
           → espd-arm64 daemon          [ksu 域，唯一常驻进程]
              ├─ 每 33ms 找 com.tencent.KiHan
              ├─ 出现 → 扫描 il2cpp 类 → 读 actor → 投影 → UDP :29000
              └─ 退出 → supervisor 5/15/60s 退避重启
```

对比旧链路 `post-fs-data → pkill qsguard ×12 → zygiskd → 抢时序 → zygote → …`：新链路**没有任何一步依赖另一个进程的启动顺序**，所以不再需要 post-fs-data、pkill、mount bind、`ctl.restart zygote`、zygisksu、zygiskfrida、重启手机。

## espd 的四个模式

| 模式 | 作用 |
|---|---|
| `probe` | 自检：pid / maps / il2cpp 基址 / ELF magic / SELinux 域 / TracerPid，写 `status.json` |
| `selftest` | 投影数学自测（纯 CPU，不需要设备/游戏） |
| `scan <类名> [命名空间]` | 扫描 il2cpp 类，打印字段名+偏移+静态标志 → 生成 resolved 基线 |
| `daemon` | 常驻：读内存 → 投影 → 发 UDP → 每 30 帧写 `status.json` |

```
espd probe
espd selftest
espd scan PVPStatis KH
espd scan Transform UnityEngine
espd daemon --dir /data/local/tmp/.esp
```

## 类与字段的自解析（不硬编码偏移）

进程外不能调用 `il2cpp_*` API（那是目标进程里的函数），所以 `scan.c` 全部建立在读内存 + 结构布局上：

1. 在 libil2cpp 可读段搜类名字符串，拿到字符串地址 A
2. 在 libil2cpp 可写段搜「值 == A 的 8 字节」→ 命中位置 - 0x10 = `Il2CppClass*`
3. 用 `namespaze` 二次校验（字符串共享会让 name 命中多个候选）
4. 用「FieldInfo.name 能否解析成合法标识符」探测 fields 指针偏移与 field_count

这样游戏更新换了字段顺序，只要类名/字段名不变就不用改配置。会变的只有 `Il2CppClass` 内部固定布局（几年才动一次），也是探测兜住的。

## supervisor 的四个细节（踩过的坑）

1. **单例**：`pidof espd-arm64` 检查，避免 service.d 被重复触发起两份
2. **退避**：连续 3 次在 30s 内退出 → sleep 从 5s 涨到 60s，防崩溃循环烧电
3. **日志轮转**：`/data/local/tmp/.esp/espd.log` 超 256KB 只留最后 200 行
4. **域自检**：启动时把 `/proc/self/attr/current` 写进日志第一行。哪天 ROM 更新导致掉到 shell 域，一眼看出来

> 重要环境坑：内联 `su -c '...'` 会掉到 `u:r:shell:s0`（读不到 app 内存、`/data/adb` 也进不去）。本模块所有 root 操作都在脚本文件里跑，保持在 `u:r:ksu:s0`。

## 悬浮窗 APK 的安装

supervisor 里保留 `pm install -r -g` 5 次重试 + 10s 间隔——冷启动阶段 pm service 还没起来（旧日志里 `Can't find service: package`，第 3 次才成功），这段逻辑别删。

## 生命周期

| 事件 | 新模块行为 |
|---|---|
| 开机 | 起 supervisor，等 pid |
| 开游戏 | 33ms 内发现 pid，自解析类后画线（首次扫描约 1s） |
| 游戏被杀 | pid 消失，espd 空转，无动作 |
| 重开游戏 | 自动重新扫描（新 pid/新 ASLR 基址） |
| espd 崩溃 | supervisor 5s 后重启 |
| 手机重启 | 唯一路径，无状态可丢 |
| 游戏更新 | 类名不变就零改动；变了用 `espd scan` 重取基线 |

## 卸载与回滚

```sh
# 停（不用重启，不用删模块）
kill $(pidof espd-arm64); kill $(pidof -x espd-supervisor.sh)

# 停用模块
touch /data/adb/modules/esp_local/disable

# 完整卸载
rm -rf /data/adb/modules/esp_local
pm uninstall com.sys.deskhelper
rm -rf /data/local/tmp/.esp
```

回滚旧架构：`git checkout <旧 commit> -- module/ esp/ docs/` 重新打包（旧流程见 `docs/LEGACY-gadget.md`）。

## 当前实现状态

- ✅ 模块骨架、启动链路、进程外读、il2cpp 类/字段自解析、投影数学、UDP 发送、自检/诊断全部落地并编译通过
- ⚠️ `espd.conf` 里的 `fov/near/far` 与相机朝向读取仍需真机校准（未在实机对局中完整验证）
- ⚠️ 非 PVP 场景（练习场用「离相机最近=自己」兜底）尚未实现，当前只对局内出线
- 见 `docs/OFFSETS.md`「自动解析」章节
