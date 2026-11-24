<#
  overlay\build.ps1 — 从 smali 源码重建悬浮窗 APK

  用法：
    powershell -ExecutionPolicy Bypass -File overlay\build.ps1
    powershell -ExecutionPolicy Bypass -File overlay\build.ps1 -Apktool D:\tools\apktool.jar
    powershell -ExecutionPolicy Bypass -File overlay\build.ps1 -NoSign

  原理：
    overlay\dist\esp.apk 是基线 APK（已含 androidx 依赖）。本脚本把它解码，
    用 overlay\smali\com\lcs\esp 覆盖同名类，再回编译 + 对齐 + 签名。
    这样仓库里只需要存「我们自己写的类」，不用存 37MB 的 androidx smali。

  依赖：
    apktool 3.x      https://github.com/iBotPeaches/Apktool/releases
    JDK 17+          （apktool 与 apksigner 都要）
    Android SDK build-tools（zipalign / apksigner）
#>
param(
  [string]$Apktool = '',
  [string]$Sdk = 'D:\iOS_Dev_Workspace\SDKs\android-sdk',
  [string]$Base = '',
  [switch]$NoSign
)

$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$repo = Split-Path $here -Parent

if (!$Base) { $Base = Join-Path $here 'dist\esp.apk' }
if (!(Test-Path $Base)) { throw "缺少基线 APK：$Base" }

# ---------- 工具定位 ----------
if (!$Apktool) {
  foreach ($c in @(
      (Join-Path $here 'apktool.jar'),
      (Join-Path $repo 'tools\apktool.jar'),
      (Join-Path $env:USERPROFILE 'apktool.jar'))) {
    if (Test-Path $c) { $Apktool = $c; break }
  }
}
if (!$Apktool -or !(Test-Path $Apktool)) {
  throw '找不到 apktool.jar：用 -Apktool <路径> 指定，或放到 overlay\apktool.jar'
}

$bt = Get-ChildItem (Join-Path $Sdk 'build-tools') -Directory -ErrorAction SilentlyContinue |
      Sort-Object Name -Descending | Select-Object -First 1
if (!$bt) { throw "找不到 build-tools：$Sdk\build-tools" }
$zipalign  = Join-Path $bt.FullName 'zipalign.exe'
$apksigner = Join-Path $bt.FullName 'apksigner.bat'

$work = Join-Path $here 'build'
$dec  = Join-Path $work 'decoded'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
New-Item -ItemType Directory -Force $work | Out-Null

# ---------- 解码 ----------
Write-Host '[1/4] 解码基线 APK ...'
& java -jar $Apktool d -f -o $dec $Base
if ($LASTEXITCODE -ne 0) { throw 'apktool d 失败' }

# ---------- 覆盖自有类 ----------
Write-Host '[2/4] 覆盖 smali\com\lcs\esp ...'
$dst = Join-Path $dec 'smali\com\lcs\esp'
if (Test-Path $dst) { Remove-Item $dst -Recurse -Force }
New-Item -ItemType Directory -Force $dst | Out-Null
Copy-Item (Join-Path $here 'smali\com\lcs\esp\*.smali') $dst

# 保证脚本资产是最新的
$assetJs = Join-Path $here 'assets\esp.js'
if (Test-Path $assetJs) {
  Copy-Item $assetJs (Join-Path $dec 'assets\esp.js') -Force
}

# ---------- 回编译 ----------
Write-Host '[3/4] 回编译 ...'
$unsigned = Join-Path $work 'esp-unsigned.apk'
& java -jar $Apktool b $dec -o $unsigned
if ($LASTEXITCODE -ne 0) { throw 'apktool b 失败' }

$aligned = Join-Path $work 'esp-aligned.apk'
& $zipalign -f -p 4 $unsigned $aligned
if ($LASTEXITCODE -ne 0) { throw 'zipalign 失败' }

# ---------- 签名 ----------
if ($NoSign) {
  Write-Host "[4/4] 跳过签名：$aligned"
  exit 0
}

$ks = Join-Path $here 'debug.keystore'
if (!(Test-Path $ks)) {
  Write-Host '生成 debug.keystore ...'
  & keytool -genkeypair -v -keystore $ks -storepass android -keypass android `
            -alias androiddebugkey -keyalg RSA -keysize 2048 -validity 10000 `
            -dname "CN=Android Debug,O=Android,C=US" | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'keytool 失败' }
}

Write-Host '[4/4] 签名 ...'
$out = Join-Path $here 'dist\esp.apk'
& $apksigner sign --ks $ks --ks-pass pass:android --key-pass pass:android `
                  --ks-key-alias androiddebugkey --out $out $aligned
if ($LASTEXITCODE -ne 0) { throw 'apksigner 失败' }

$item = Get-Item $out
Write-Host ''
Write-Host ("OK  {0}  {1:N0} B  md5={2}" -f $item.FullName, $item.Length, (Get-FileHash $out -Algorithm MD5).Hash.ToLower())
Write-Host '注意：换签名后设备上要先卸载旧包（pm uninstall com.sys.deskhelper），否则 install 会因签名冲突失败。'
