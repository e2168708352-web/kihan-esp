<#
  deploy.ps1 — 手动部署 payload 到设备（不刷模块，也不需要重启）

  用法：
    powershell -ExecutionPolicy Bypass -File tools\deploy.ps1
    powershell -ExecutionPolicy Bypass -File tools\deploy.ps1 -RestartGame
    powershell -ExecutionPolicy Bypass -File tools\deploy.ps1 -Adb "C:\...\adb.exe"

  做的事：
    1) 推 esp.js / libhw.config / libhw.so.gz 到 /data/local/tmp
    2) 用 root 把它们放进 /data/local/tmp/.sys，chmod 644 + chcon apk_data_file
    3) gadget 缺失时解压 libhw.so.gz
    4) 首次写 ZygiskFrida 的 targets 配置（已存在就不动）
    5) 悬浮窗没装就装，装了就拉起服务
    6) -RestartGame 时强杀并重开游戏

  注意：所有 root 操作都走「推脚本 + su -c "sh 脚本"」，不内联复合命令 ——
        adb shell 的引号会被外层 shell 拆掉，chmod/chcon 会静默失效。
#>
param(
  [string]$Adb = 'D:\iOS_Dev_Workspace\SDKs\android-sdk\platform-tools\adb.exe',
  [switch]$RestartGame,
  [switch]$SkipApk
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$esp  = Join-Path $repo 'esp'
$gz   = Join-Path $esp 'libhw.so.gz'
$apk  = Join-Path $repo 'overlay\dist\esp.apk'
$tmp  = Join-Path $env:TEMP 'kihan-esp-deploy'

if (!(Test-Path $Adb)) { throw "找不到 adb：$Adb" }
New-Item -ItemType Directory -Force $tmp | Out-Null

& $Adb wait-for-device | Out-Null

Write-Host '[1/5] 推送 payload ...'
& $Adb push (Join-Path $esp 'esp.js') /data/local/tmp/esp_new.js | Out-Null
& $Adb push (Join-Path $esp 'libhw.config') /data/local/tmp/libhw.config.new | Out-Null
$haveGz = Test-Path $gz
if ($haveGz) { & $Adb push $gz /data/local/tmp/libhw.so.gz.new | Out-Null }
if (!$SkipApk -and (Test-Path $apk)) { & $Adb push $apk /data/local/tmp/esp.apk.new | Out-Null }

Write-Host '[2/5] 生成设备端脚本 ...'
$sh = @'
#!/system/bin/sh
SYS=/data/local/tmp/.sys
GAME=com.tencent.KiHan
PKG=com.sys.deskhelper
SVC=$PKG/com.lcs.esp.OverlayService
ZF=/data/local/tmp/re.zyg.fri/config.json
SO=$SYS/libhw.so

mkdir -p $SYS
chmod 755 $SYS

# --- esp.js：原地写，保住 inode（gadget 的 inotify 靠它）---
if [ -f $SYS/esp.js ]; then
  SZ=$(wc -c < /data/local/tmp/esp_new.js)
  dd if=/data/local/tmp/esp_new.js of=$SYS/esp.js conv=notrunc 2>/dev/null
  truncate -s $SZ $SYS/esp.js
else
  cp -f /data/local/tmp/esp_new.js $SYS/esp.js
fi

# --- config ---
cp -f /data/local/tmp/libhw.config.new $SYS/libhw.config

# --- gadget：按 gz 的 md5 判断是否需要重新解压（只判存在会导致换了版本还在用旧的）---
if [ -f /data/local/tmp/libhw.so.gz.new ]; then
  GZMD5=$(md5sum /data/local/tmp/libhw.so.gz.new | cut -d' ' -f1)
  OLDMD5=$(cat $SYS/.gz.md5 2>/dev/null)
  if [ ! -f $SO ] || [ "$GZMD5" != "$OLDMD5" ]; then
    echo "gadget: unpack ($GZMD5)"
    gzip -d -c /data/local/tmp/libhw.so.gz.new > $SO
    echo "$GZMD5" > $SYS/.gz.md5
  else
    echo "gadget: up to date"
  fi
fi

chmod 644 $SYS/esp.js $SYS/libhw.config 2>/dev/null
[ -f $SO ] && chmod 644 $SO
chcon u:object_r:apk_data_file:s0 $SYS/esp.js $SYS/libhw.config 2>/dev/null
[ -f $SO ] && chcon u:object_r:apk_data_file:s0 $SO 2>/dev/null

# --- ZygiskFrida targets ---
if [ ! -f $ZF ]; then
  mkdir -p /data/local/tmp/re.zyg.fri
  printf '%s\n' "{\"targets\":[{\"app_name\":\"$GAME\",\"enabled\":true,\"start_up_delay_ms\":20000,\"injected_libraries\":[{\"path\":\"$SO\"}]}]}" > $ZF
  chmod 644 $ZF
  echo "wrote $ZF"
else
  echo "keep existing $ZF"
fi

# --- overlay ---
if [ -f /data/local/tmp/esp.apk.new ]; then
  pm install -r -g /data/local/tmp/esp.apk.new
fi
appops set $PKG SYSTEM_ALERT_WINDOW allow 2>/dev/null
am start-foreground-service -n $SVC 2>/dev/null

echo "--- .sys ---"
ls -lZ $SYS
echo "--- md5 ---"
md5sum $SYS/esp.js
'@
$shPath = Join-Path $tmp 'esp_setup.sh'
[System.IO.File]::WriteAllText($shPath, ($sh -replace "`r`n", "`n"), (New-Object System.Text.UTF8Encoding($false)))

Write-Host '[3/5] 推送并执行 ...'
& $Adb push $shPath /data/local/tmp/esp_setup.sh | Out-Null
& $Adb shell 'su -c "sh /data/local/tmp/esp_setup.sh"'

if ($RestartGame) {
  Write-Host '[4/5] 重启游戏 ...'
  & $Adb shell "am force-stop com.tencent.KiHan"
  Start-Sleep -Seconds 2
  & $Adb shell "monkey -p com.tencent.KiHan -c android.intent.category.LAUNCHER 1" | Out-Null
  Write-Host '等待 25s 注入 ...'
  Start-Sleep -Seconds 25
  & $Adb shell 'su -c "tail -2 /data/user/0/com.tencent.KiHan/files/.dh"'
} else {
  Write-Host '[4/5] 跳过重启（加 -RestartGame 可自动重开）'
}

Write-Host '[5/5] 完成。游戏需重新启动才会加载新 esp.js。'
