<#
  update-esp-js.ps1 — 热更新设备上的 esp.js

  用法：
    powershell -ExecutionPolicy Bypass -File tools\update-esp-js.ps1
    powershell -ExecutionPolicy Bypass -File tools\update-esp-js.ps1 -Js F:\path\esp.js

  为什么不能直接 cp：
    gadget 用 inotify 监听脚本文件，cp/mv 会换 inode，监听失联 → reload 永不触发。
    必须 dd conv=notrunc 原地覆盖 + truncate 到精确长度。

  更新后要杀进程重开游戏：gadget 只在进程启动时读一次脚本。
#>
param(
  [string]$Adb = 'D:\iOS_Dev_Workspace\SDKs\android-sdk\platform-tools\adb.exe',
  [string]$Js = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
if (!$Js) { $Js = Join-Path $repo 'esp\esp.js' }
if (!(Test-Path $Js)) { throw "找不到 $Js" }
if (!(Test-Path $Adb)) { throw "找不到 adb：$Adb" }

$sz = (Get-Item $Js).Length
$md5 = (Get-FileHash $Js -Algorithm MD5).Hash.ToLower()
Write-Host "源文件: $Js  $sz B  md5=$md5"

& $Adb wait-for-device | Out-Null
& $Adb push $Js /data/local/tmp/esp_new.js | Out-Null

$sh = @"
#!/system/bin/sh
SYS=/data/local/tmp/.sys
[ -f \$SYS/esp.js ] || { echo "no \$SYS/esp.js"; exit 1; }
dd if=/data/local/tmp/esp_new.js of=\$SYS/esp.js conv=notrunc 2>/dev/null
truncate -s $sz \$SYS/esp.js
chmod 644 \$SYS/esp.js
chcon u:object_r:apk_data_file:s0 \$SYS/esp.js 2>/dev/null
md5sum \$SYS/esp.js
"@
$shPath = Join-Path $env:TEMP 'esp_update.sh'
[System.IO.File]::WriteAllText($shPath, ($sh -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

& $Adb push $shPath /data/local/tmp/esp_update.sh | Out-Null
& $Adb shell 'su -c "sh /data/local/tmp/esp_update.sh"'

Write-Host ''
Write-Host "本地 md5: $md5"
Write-Host '设备 md5 应与之一致。然后强杀游戏重开：'
Write-Host '  adb shell am force-stop com.tencent.KiHan'
