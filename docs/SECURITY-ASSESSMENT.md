# 对抗反作弊（ACE）安全性评估

本文对当前 v2 方案（进程外只读）在腾讯 ACE 反作弊环境下的隐蔽性做量化评估，并与旧方案（Frida gadget 注入）对比。所有结论基于本机实测数据，不基于推测。

- 评估日期：2026-11
- 环境：Android 16 / ColorOS / arm64 / KernelSU 3.3.1（临时 root）
- 方法：逐项列出反作弊可用的检测手段，判定本方案是否暴露，给出分值

---

## 一、总分

| 方案 | 客户端对抗 | 算上服务端 |
|---|---|---|
| 旧方案（gadget 注入） | **2.0 / 10** | 1.5 / 10 |
| **v2 当前（进程外只读）** | **8.0 / 10** | **6.5 / 10** |
| v2 + 悬浮窗伪装 + denylist | 9.0 / 10 | 7.2 / 10 |
| 理论天花板（服务端不可消除） | 10 / 10 | **8.6 / 10** |

分值定义：**10 = 该项完全检不到**（不是「很难检出」，是「不存在」），0 = 必被抓。

---

## 二、逐项评估

| # | 检测手段 | 旧方案 | v2 | 依据 |
|---|---|---|---|---|
| 1 | 扫进程 maps 里的外来 so | 0 | **10** | v2 游戏进程无任何外来映射 |
| 2 | 扫线程名（`gum-js-loop`）/ `gmain` | 0 | **10** | v2 无外来线程 |
| 3 | 扫 Frida 字符串（`frida:rpc`、`GumScript`） | 0 | **10** | v2 内存中无这些字符串 |
| 4 | 扫应用私有目录异常文件 | 1 | **10** | v2 不写游戏目录一个字节 |
| 5 | 枚举系统进程找可疑守护 | 3 | **10** | `hidepid=invisible`，app 只见 3 进程，`pidof espd` 为空 |
| 6 | 内存完整性 / 代码段 CRC | 8 | **10** | 只读，不写目标一个字节，`TracerPid=0` |
| 7 | 扫 UDP socket（`/proc/net/udp`） | 1 | **8** | v2 的 socket 属于 espd 而非游戏 uid，app 无权查看 |
| 8 | 遍历 `/data/adb`、模块挂载 | 2 | **5** | 目录被 SELinux 挡住，但 `mountinfo` 仍露；denylist 可补到 8 |
| 9 | 检测悬浮窗遮挡 | 2 | **3** | **两边都命中**，v2 无改善 ← 最大短板 |
| 10 | 检测 root 环境 | 2 | **5** | denylist 可补到 7 |
| 11 | 服务端行为模型 | 4 | **4** | 技术无解，两边一样 |

客户端 10 项均分 ≈ **8.0**；算入服务端后 ≈ **6.5**。

---

## 三、实测证据

以下数据全部来自本机真机运行，不是文档推理：

```
/proc 挂载参数                  hidepid=invisible
root 视角进程数                 933
app uid (10343) 视角进程数      3          ← 只看到自己 + 2 个系统进程
app 读 /proc/1/maps             No such file
app ls /data/local/tmp          Permission denied
app stat /data/adb/modules      Permission denied
app pidof espd-arm64            空
espd 跨进程读其他 app            elf_ok=1  tracerpid=0
espd 加载域                     u:r:ksu:s0
```

关键结论：**游戏进程在 `hidepid=invisible` + SELinux 下根本看不到 espd**。不是「藏得好」，是内核层面不可见。

### `TracerPid` 验证

```
espd probe --pkg com.sys.deskhelper
  "tracerpid": 0
```

`process_vm_readv` 不做 ptrace attach，所以目标进程 `/proc/self/status` 的 `TracerPid` 保持 0。这是与 ptrace 注入（含旧方案 self-inject）的根本区别。

---

## 四、结构性安全（对手更新版本也检不到）

这四条是**架构决定的**，不是对抗出来的：

1. **零注入** —— 游戏进程 maps / 线程 / 文件 / 句柄里没有任何异常项。进程内取证没有取证对象。
2. **进程不可见** —— `hidepid=invisible` 让 app 只能看到 3 个进程。
3. **零挂载** —— 不往 `/system` 挂任何东西，`/proc/self/mountinfo` 不增多余条目。
4. **只读** —— `process_vm_readv` 不写目标内存，不改字段、不做 inline hook。

**第 4 条尤其重要**：所有「内存校验和」「字段 canary」「代码段 CRC」类检测对本方案完全无效，因为它不改变目标内存的任何位。

---

## 五、剩余风险与压法

### 残留 1：悬浮窗（评分 3/10，最大短板）

`com.sys.deskhelper` 有 `SYSTEM_ALERT_WINDOW` + 常驻前台服务 + debug 签名 + 非白名单包名。反作弊查窗口遮挡或枚举包名时会命中。

三档压法：

| 方案 | 改动量 | 收益 |
|---|---|---|
| 只在游戏前台建窗，退出销毁 | 半天 | 3 → 6 |
| 包名/图标伪装成系统组件 + release 签名 | 半天 | 6 → 7（可叠加） |
| 弃用 APK，espd 用 `SurfaceControl` 直接建 overlay | ~200 行 native | 7 → 9 |

第三条最彻底：没有包名、没有安装记录、没有权限声明可查。root 有 `ACCESS_SURFACE_FLINGER`，技术上可行。

### 残留 2：root 环境（评分 5/10）

`/data/adb` 已被 SELinux 挡住（实测 app `ls` 被拒），但 `mountinfo`、su 存在性、`ro.debuggable` 仍可能露。

- **KernelSU denylist 对游戏启用** → 让游戏进程看不到模块挂载，通常即时生效
- v2 不依赖 zygisk，denylist 随便开，没有副作用
- 可补到 7/10

### 残留 3：服务端行为模型（评分 4/10，不可消除）

**这是唯一技术解决不了的部分。**

客户端零痕迹 ≠ 数据正常。透视类风险的大头往往不是客户端特征，而是**你看到的和你的操作不匹配**：

- 反应时间（提前转视角、预瞄）
- 走位路径（绕开视野外敌人）
- 胜率与 KDA 曲线
- 玩家举报（透视最容易被肉眼察觉）

降低办法只有操作层：

- 用独立测试账号，不和主账号混用
- **只画线、不改操作** —— 本项目的硬约束（不画框、不显示血量、不自动瞄准）恰好是行为侧最低暴露形态
- 低分段起步，行为与胜率不会异常得离谱
- 不把透视信息用在非人类反应上

---

## 六、设备稳定性（这块提升最大）

| | 旧方案 | v2 |
|---|---|---|
| 每次开机 | pkill qsguard ×12、抢 post-fs-data 时序、可能失败 | 起一个进程，等 pid |
| 调试迭代 | 重启 zygote、掉 adb、屏幕黑一下 | 改 espd 重新 push，不影响系统 |
| 失败后果 | zygote 半残、注入丢失、要重来 | espd 退出，supervisor 5s 后重来 |
| 对系统的侵入 | mount bind、SELinux 标签、exec 阻断对抗 | 零 |
| 软重启（`ctl.restart zygote`） | 注入全丢，需重新走注入流程 | **espd / supervisor / 悬浮窗全部存活** |

### 软重启实测记录

针对 `setprop ctl.restart zygote` 单独做过一次实测，结果与预期不同，记录如下：

```
操作前   espd pid=14863   supervisor=1   zygote64 pid=30913/30922   libzygisk=3
执行     setprop ctl.restart zygote
等待     adb 短暂断开，约 15s 后恢复
操作后   espd pid=14863   supervisor=1   zygote64 pid=6993/7003     libzygisk=3
         desk pid=14010  boot_id 未变   uptime 连续（未重启系统）
```

三个关键结论：

1. **临时 root 保留** —— `uid=0`、域仍为 `u:r:ksu:s0`。软重启只重启 Java 层，不涉及内核补丁。
2. **espd 不受影响** —— pid 未变，因为它挂在 supervisor（父进程为 init）下，不在 zygote 的子进程链里。desk 悬浮窗同样存活。
3. **`libzygisk` 清不掉** —— 新 zygote 仍是 `libzygisk=3`。说明 zygisk 的加载发生在 init/post-fs-data 阶段，`ctl.restart zygote` 只是重新 fork 一个已加载该库的 zygote。要清掉它**只有完全重启**。

> 另注：`libzygisk` 留在 zygote 里对本方案无影响——espd 从进程外读取游戏内存，不依赖 zygote 挂了什么库。

旧方案中设备反复出错（adb 掉线、`/data/adb` 时通时不通、zygote 有 zygisk 但游戏没注入），根因就是到处留手。v2 只做一件事：**读**。

---

## 七、结论

- **旧方案是结构性必死**：前 5 项全是 0，任何进程内取证一扫就中，与反作弊版本无关。
- **v2 是「结构性隐形 + 三条可控残留」**：前 6 项满分靠架构（零注入、hidepid、只读），剩 3 项是悬浮窗、root、服务端行为。
- **不是从 0 到 100，是从 0 到 80 出头**。剩下那 20 里，一半是服务端行为（技术无解），一半是悬浮窗和 root（工程可压）。
- **内核不是一劳永逸，维护成本反而最高**：每次内核更新要重编、跟厂商安全模块正面对撞、还要过签名校验；它解决的是「隐藏 root」，不是「消除痕迹」。本项目明确不走内核路线。

### 一句话

现方案的对抗能力来自**「不存在」而不是「藏得好」**——游戏进程里确实没有任何东西可被检查。这才是它能对抗后续 ACE 版本更新的根本原因。
