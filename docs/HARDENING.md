# 暴露面分析（v2 · 进程外只读）

v2 的核心不是「藏得更好」，而是**游戏进程里根本没有可查的东西**。旧架构（gadget 注入）的暴露面见 [LEGACY-gadget.md](LEGACY-gadget.md)。

> 逐项打分与量化评估见 [SECURITY-ASSESSMENT.md](SECURITY-ASSESSMENT.md)（客户端 8.0/10，算上服务端 6.5/10）。

## 一、实测数据（Android 16 / KernelSU）

```
/proc 挂载参数            hidepid=invisible
root 视角进程数           933
app uid 视角进程数        3（只能看到自己和两个系统进程）
app 读 /proc/1/maps       No such file
app ls /data/local/tmp    Permission denied
app stat /data/adb/modules/esp_local   Permission denied
app pidof espd-arm64      空
espd 跨进程读其他 app      elf_ok=1  tracerpid=0
```

**游戏进程在 `hidepid=invisible` + SELinux 下根本看不到 espd**。不是「藏得好」，是内核层面不可见。

## 二、检测手段对比

| 检测手段 | 旧方案（gadget 注入） | 新方案（espd 进程外） |
|---|---|---|
| 扫进程 maps 里的外来 so | 命中 `libhw.so`，路径/大小/空签名全暴露 | 无。游戏进程无任何外来映射 |
| 扫线程名 | 命中 `gum-js-loop` / `gmain` | 无外来线程 |
| 扫 Frida 字符串 | 命中 `frida:rpc` / `GumScript` | 无 |
| 扫应用私有目录异常文件 | 命中 `.dh` 明文 `mat=/ent=/tk=` | 无。不写游戏目录一个字节 |
| 枚举系统进程找可疑守护 | 能看到 | 看不见（hidepid，pidof 实测空） |
| 遍历 `/data/adb`、模块挂载 | mountinfo 仍露 | 目录已被 SELinux 挡住；mountinfo 是唯一残留 |
| 检测悬浮窗遮挡 | 命中 `com.sys.deskhelper` | **仍命中** ← 残留 1 |
| 检测 root 环境 | 命中 | **部分命中** ← 残留 2 |
| 内存完整性 / 代码段哈希 | 不命中（gadget 不改游戏代码） | 不命中（只读，一个字节都不改） |
| 服务端行为模型 | 命中 | **仍命中，不可消除** |

## 三、结构性安全（架构决定的，不是对抗出来的）

1. **零注入** —— 游戏进程 maps/线程/文件/句柄里没有任何异常项。进程内取证没有取证对象。
2. **不可见** —— `hidepid=invisible` 让 app 只能看到 3 个进程，espd 连名字都查不到。
3. **零挂载** —— 新方案不往 `/system` 挂任何东西；旧方案的 mount bind / overlay / SELinux 标签全部消失，`/proc/self/mountinfo` 不增多余条目。
4. **只读** —— `process_vm_readv` 不写目标内存。`TracerPid=0`（实测）、不改任何字段、不做 inline hook，所有「内存校验和」「字段 canary」「代码段 CRC」天然免疫。

这四条是对手更新版本也检不到的——因为确实没东西可检。

## 四、概率性残留（对手实现了就能抓）

### 残留 1：悬浮窗（最高优先级）

`SYSTEM_ALERT_WINDOW` + 常驻前台服务。反作弊会查窗口是否被覆盖，也会枚举包名+签名。`com.sys.deskhelper` 用 debug 签名、非白名单包名，等于自报身份。

压法（按改造量排序）：

1. **只在游戏前台时创建窗口**，退出立即销毁 —— 去掉常驻前台服务，非对局时段看不到 overlay。改动小，收益中。
2. **包名/图标伪装成系统组件**（如 `com.android.systemui.overlay` 之类），用 release key 签名。改动小，收益中。
3. **不用 APK**：espd 直接用 `SurfaceControl` 建 overlay（root 有 `ACCESS_SURFACE_FLINGER`）。没有包名、安装记录、权限声明可查。改造量大（~200 行 native + 输入穿透），收益最高。

做 1+2 可把悬浮窗风险从「高危」降到「中低」；做到 3 基本消失。

### 残留 2：root 环境

虽然 `/data/adb` 已被 SELinux 挡住（实测 app `ls` 被拒），但 `mountinfo`、su 存在性、`ro.debuggable` 之类仍可能露。

- KernelSU 的 **denylist 对游戏启用**：让游戏进程看不到模块挂载，通常即时生效。新方案不依赖 zygisk，denylist 随便开。
- 实测 `hidepid` 已经挡住进程枚举，这一层主要补 mount 视图。

## 五、不可消除：服务端行为模型

客户端零痕迹 ≠ 数据正常。透视类风险的大头往往不是客户端特征，而是**你看到的和你的操作不匹配**——反应速度、预判路径、胜率曲线，这些在服务端统计里是可建模的。

降低办法只有操作层：

- 用独立测试账号，不和主账号混用
- 只画线、不改操作（本项目的硬约束恰好是行为侧最低暴露形态：不自动瞄准、不预判、不改键位）
- 先在低分段跑，行为与胜率不会异常得离谱
- 不把透视信息用在非人类反应上

## 六、设备安全性（这块提升更大）

| | 旧方案 | 新方案 |
|---|---|---|
| 每次开机 | pkill qsguard ×12、抢时序、可能失败 | 起一个进程，等 pid |
| 调试迭代 | 重启 zygote、掉 adb、屏幕黑一下 | 改 espd 重新 push，不影响系统 |
| 失败后果 | zygote 半残、注入丢失、要重来 | espd 退出，supervisor 5s 后重来 |
| 对系统的侵入 | mount bind、SELinux 标签、exec 阻断对抗 | 零 |

旧方案中设备反复出错（adb 掉线、`/data/adb` 时通时不通、zygote 有 zygisk 但游戏没注入），根因就是到处留手。新方案只做一件事：**读**。

## 七、结论

- 旧方案是结构性必死：gadget 特征摆在进程里，扫到就中，与版本无关。
- 新方案是「结构性隐形 + 两条可控残留」。不是从 0 到 100，是从 0 到 80 出头。
- 剩下约 20 里，一半是服务端行为（技术无解），一半是悬浮窗/root（工程可压）。
- **内核不是一劳永逸，反而维护成本最高**：每次内核更新重编、跟厂商安全模块正面对撞、签名校验；它解决的是「隐藏 root」，不是「消除痕迹」。本项目明确不走内核路线。
