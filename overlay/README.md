# overlay — 悬浮窗 APK

`com.sys.deskhelper` / `com.lcs.esp.OverlayService`：一个前台 Service + 一个 `View`，从 UDP `127.0.0.1:29000` 收帧，在 `Canvas` 上画。

## 画什么

- **敌人直线**：自己脚下 → 敌人（`U` 行的屏幕坐标，可越界表示屏外方位）
- **距离**：`dist` 字段，显示在敌人位置旁
- **替身倒计时**：`cd` 字段（秒），`>0` 才显示
- **脚下指向**：`A` 行，自己脚下按方位角画一个指向箭头（敌人在屏外时用）
- **启动动画**：收到 `SPLASH <pid>` 播一次，同一 pid 只播一次

不画四角框、不画血条、不画头顶箭头。这版是「只画一条线」的最终形态。

## 文件

```
smali/com/lcs/esp/     我们自己写的全部类（32 个文件）
AndroidManifest.xml    Service / Activity 声明（不含 dex 里的库类）
apktool.yml            apktool 配置
assets/                随包资产：esp.js、gadget 配置样例、watch.sh
dist/esp.apk           预编译 APK（debug 签名）
build.ps1              从 smali 重建 APK
```

## 构建

```powershell
powershell -ExecutionPolicy Bypass -File overlay\build.ps1 -Apktool D:\apk-tools\apktool.jar
```

流程：解码 `dist/esp.apk`（作为基线，里面已含 androidx/kotlin 依赖）→ 用本目录 `smali/` 覆盖 `com/lcs/esp` → `apktool b` → `zipalign` → `apksigner`。

> 仓库里不存 37MB 的 androidx smali，只存我们自己的类。基线 APK 就是 `dist/esp.apk`。

## 装机

```sh
adb shell pm uninstall com.sys.deskhelper        # 换签名后必须先卸
adb shell pm install -r -g esp.apk
adb shell appops set com.sys.deskhelper SYSTEM_ALERT_WINDOW allow
adb shell am start-foreground-service -n com.sys.deskhelper/com.lcs.esp.OverlayService
```

MIUI / ColorOS 还要手动给「显示在其他应用上层 / 后台弹出界面」并把包加进电池白名单，否则 Service 会被杀。

## 说明

启动动画副标题原本有一个原作者的联系方式字符串，开源版已清空。
