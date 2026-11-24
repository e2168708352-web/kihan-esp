# 偏移表

以下为编写时（游戏版本对应 `com.tencent.KiHan` 当前线上包）dump 的结果。**游戏更新后必须重新核对**，脚本里除了 `PVPStatis.statis` 是按字段名解析的，其余全是硬编码。

## 静态入口

| 项 | 值 | 说明 |
|---|---|---|
| 程序集 | `Assembly-CSharp` | `il2cpp_domain_assembly_open` |
| 类 | `KH.PVPStatis` | 客户端唯一持有「敌方替身状态」的地方 |
| 静态字段 | `statis` | `il2cpp_field_static_get_value` 取实例指针 |

`statis` 的偏移由 `il2cpp_field_get_offset` 运行时取（脚本 `pvpResolve()` 按字段名遍历），不需要硬编码。

## PVPStatis 实例

| 偏移 | 字段 | 类型 | 说明 |
|---|---|---|---|
| `0x78` | `m_myPlayerCtrl` | ptr | 我方 actor（`KHPlayerActor`） |
| `0x80` | `m_enemyPlayerCtrl` | ptr | 敌方 actor |
| `0xc8` | `mySubstituteCurStateFlag` | int32 | 我方替身：`1`=可用，`0`=冷却中 |
| `0xd0` | `enemySubstituteCurStateFlag` | int32 | 敌方替身，同上 |

实例随回合重建/回收，静态字段可能指向已废弃对象。采信规则（`pvpScore()`）：

1. 对象头 `klass`（`+0x0`）必须等于 `PVPStatis` 的 `Il2CppClass*`
2. `0x78` / `0x80` 至少一个落在「上一帧场上存活角色集合」里（`VActor+0x30` 的 own 指针）

两条都过才 `pvpOk=1`；否则退回「离相机最近 = 自己，离自己最近 = 敌人」的兜底（`pickByCam()`）。

## 实体

| 偏移 | 类 | 字段 | 说明 |
|---|---|---|---|
| `0x30` | `KH.VActor` | `m_owner` | 逻辑角色指针。同一角色的多个 `VActor` 实例靠它去重 |
| `0x60` | `KH.VEntity` | `m_displayObject` | 显示对象 |
| `0x28` | `VDisplayObj` | `m_headHpBar` | 头顶血条（`KH.KHHeadHpBar`） |
| `0xa8` | `KH.KHHeadHpBar` | `isVisible` | byte，0=隐藏 |
| `0xb8` | `KH.KHHeadHpBar` | `curHP` | int32 |
| `0xbc` | `KH.KHHeadHpBar` | `totalHP` | int32 |

本版不渲染血量，但 `hpOf()` 与 `U` 行的 hp/mx 字段保留。

## 对象头（Unity il2cpp GC）

| 偏移 | 含义 |
|---|---|
| `+0x0` | `Il2CppClass*`（klass） |
| `+0x10` | GC 标记 / 存活位；非 0 视为存活 |

对象被回收后内存可能被复用，直接调 `get_transform` 会原生崩溃（闪退）。所以脚本先 `vKlassOk()`（klass 必须在 hook 里见过的白名单里）再 `alive()`。

## 方法（全部走 `il2cpp_class_get_method_from_name`）

| 类 | 方法 | 用途 |
|---|---|---|
| `KH.VActor` | `LateUpdate` / `Update` | 实体来源：hook 后白拿 `this`，零托管分配 |
| `KH.KHMainCameraController` | `LateUpdate` / `Update` | 主节拍：相机每帧必跑，最稳的 tick 源 |
| `UnityEngine.Component` | `get_transform` | — |
| `UnityEngine.Transform` | `get_position_Injected` | 值类型返回，必须用 `_Injected` 变体 |
| `UnityEngine.Transform` | `get_rotation_Injected` | 同上，返回 Quaternion |
| `UnityEngine.Camera` | `get_main` | — |
| `UnityEngine.Camera` | `get_projectionMatrix_Injected` | 投影矩阵取游戏自己的（fov/aspect 才准） |
| `UnityEngine.Screen` | `get_width` / `get_height` | — |

### 为什么必须用 `_Injected`

`get_position()` 直接返回 `Vector3`（12 字节），在 AAPCS64 下走寄存器返回（v0/v1/v2），没有 sret。`NativeFunction` 按普通函数调会拿到垃圾。`_Injected(ref T)` 的 ABI 是：

```
void fn(T* ret, void* self, MethodInfo*)
```

显式传缓冲，稳定。

## 相机矩阵

**不要**用 `get_worldToCameraMatrix_Injected` / `get_worldToLocalMatrix_Injected`：这套渲染管线下实测返回近似单位矩阵（假值），拿它投影会把世界坐标当相机坐标，线会钉在画面中央。

改用相机 Transform 自建（`buildView()`）：

```
worldToCameraMatrix = Scale(1,1,-1) · TRS(camPos, camRot, 1)⁻¹
```

即 `[Rᵀ | -Rᵀp]`，再把 z 行取反。列主序写入。投影矩阵仍取 `get_projectionMatrix_Injected`。

`WorldToScreenPoint_Injected` 同理不用（依赖上面那个假矩阵）。

## 重新 dump

游戏更新后，把 `esp.js` 顶部 `FILE_LOG` 改成 `true`，重载脚本，看 `/data/user/0/com.tencent.KiHan/files/esp7.txt`：

- `pvp: no class` → `KH.PVPStatis` 改名了
- `pvp: no statis field` → `statis` 字段改名了
- `pvp first: enSub=... mySub=...` → 替身字段读到了但值不对 → `0xc8/0xd0` 偏移变了
- `entity hooks=0` → `VActor.LateUpdate/Update` 找不到了
- `mat=0` → 相机矩阵没取到（不在对局内，或 `Camera.main` 变了）

要定位新偏移，先按类名/字段名遍历：

```js
// 在 gadget 的 REPL 或脚本里
var it = Memory.alloc(Process.pointerSize); it.writePointer(ptr(0));
for (var f = pCF(klass, it); !f.isNull(); f = pCF(klass, it)) {
  console.log(pFN(f).readUtf8String(), pFO(f).toString(16));
}
```

字段顺序通常会变，但**名字基本不变**（除非加固壳把 metadata 加密了）。

---

## v2 进程外：按名字自解析（不再靠人工 dump）

上面这些偏移是给旧脚本（gadget 内跑）和人工核对用的。**v2 的 `espd` 不硬编码它们**：进程外不能调用 `il2cpp_*` API，所以 `tools/espd/scan.c` 直接扫进程内存、按名字定位类与字段。

原理（详见 `docs/MODULE.md`）：

1. 在 `libil2cpp.so` 可读段搜类名字符串（如 `PVPStatis`），拿到字符串地址
2. 在可写段搜「值等于该地址」的 8 字节 → 命中处减 `0x10` 就是 `Il2CppClass*`
3. 用 `namespaze` 二次校验（`KH` / `UnityEngine`）
4. 探测 `fields` 指针偏移与 field_count（用 `FieldInfo.name` 可解析性交叉验证）
5. 按字段名（如 `statis` / `m_enemyPlayerCtrl` / `m_LocalPosition`）读取 `offset`

因此**游戏小版本更新只要类名/字段名不变，无需改一行代码**。`espd.conf` 里存的都是名字（`pvp_class` / `field_*_actor` / `field_local_*`），不是数字偏移。

真机上重新取基线（进对局、il2cpp 加载后）：

```sh
BIN=/data/adb/modules/esp_local/bin/espd-arm64
su -c "sh -c '$BIN scan PVPStatis KH'"
su -c "sh -c '$BIN scan Transform UnityEngine'"
su -c "sh -c '$BIN scan Camera UnityEngine'"
```

输出是字段名 + offset + 是否静态的 JSON，可直接对照上表核对。若 `scan` 报「字符串未找到」→ 类名改了；报「没有字段」→ 字段名改了，改 `espd.conf` 对应的 `field_*` 项即可。

### 仍需真机校准的两处

1. **相机投影**：`espd.conf` 的 `fov/near/far` 目前是默认值（60/0.3/1000）。`espd` 自建视图矩阵（见上「相机矩阵」节），投影矩阵按这些参数生成，线位置不对时在这里微调。
2. **Transform 世界朝向**：v2 用 Transform 父链累乘 local TRS 求世界位置（位置准），但 actor 朝向目前回单位四元数——本方案只画直线、不画框，actor 朝向不参与，只有**相机**朝向影响投影。相机朝向的读取仍需真机核对（无父链时 `m_LocalRotation` 即世界朝向）。

### 已知缺口

- 非 PVP 场景（练习场/PVE）没有 `PVPStatis`，旧脚本有「离相机最近=自己，离自己最近=敌人」兜底（`pickByCam()`），v2 的 `espd` 尚未实现，当前只对局内出线。
- 敌人技能 CD 倒计时：替身 CD 逻辑在旧 `esp.js` 里，espd 版本待移植。
