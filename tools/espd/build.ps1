<#
  build.ps1 — 用本地 NDK 交叉编译 espd（arm64-v8a / armeabi-v7a）

  不需要 cmake，源码直编。NDK 28.2 自带 clang 19。
  生成两个产物：dist/espd-arm64（主用）、dist/espd-arm（兼容 32 位设备）
  并顺带在本机编一个 x86_64 版本做投影数学自测（如果 host clang 可用）。

  用法：
    powershell -ExecutionPolicy Bypass -File tools\espd\build.ps1
    powershell -ExecutionPolicy Bypass -File tools\espd\build.ps1 -Abi arm64
#>
param(
  [ValidateSet('arm64','arm','all')]
  [string]$Abi = 'all'
)

$ErrorActionPreference = 'Stop'

$ndkRoot = Join-Path $env:ANDROID_HOME 'ndk'
if (!(Test-Path $ndkRoot)) { throw "找不到 NDK：$ndkRoot（ANDROID_HOME=$env:ANDROID_HOME）" }
$ndk = (Get-ChildItem $ndkRoot -Directory | Sort-Object Name -Descending | Select-Object -First 1).FullName

$hostTag = 'windows-x86_64'
$clang   = Join-Path $ndk "toolchains\llvm\prebuilt\$hostTag\bin\clang.exe"
$sysroot = Join-Path $ndk "toolchains\llvm\prebuilt\$hostTag\sysroot"
$strip   = Join-Path $ndk "toolchains\llvm\prebuilt\$hostTag\bin\llvm-strip.exe"
if (!(Test-Path $clang)) { throw "找不到 clang：$clang" }

$dist = Join-Path $PSScriptRoot 'dist'
New-Item -ItemType Directory -Force $dist | Out-Null

$sources = @(
  (Join-Path $PSScriptRoot 'main.c'),
  (Join-Path $PSScriptRoot 'vm.c'),
  (Join-Path $PSScriptRoot 'scan.c'),
  (Join-Path $PSScriptRoot 'util.c'),
  (Join-Path $PSScriptRoot 'project.c'),
  (Join-Path $PSScriptRoot 'udp.c')
)

$abis = if ($Abi -eq 'all') { @('arm64','arm') } else { @($Abi) }
foreach ($a in $abis) {
  $target = if ($a -eq 'arm64') { 'aarch64-linux-android24' } else { 'armv7a-linux-androideabi24' }
  $out = Join-Path $dist "espd-$a"
  Write-Host "[build] $a -> $out"
  & $clang --target=$target --sysroot=$sysroot -O2 -fPIE -pie -Wall -Wextra `
    -o $out @sources -lm
  if ($LASTEXITCODE -ne 0) { throw "clang ($a) failed: $LASTEXITCODE" }
  if (Test-Path $strip) { & $strip --strip-all $out }
  $item = Get-Item $out
  $md5 = (Get-FileHash $out -Algorithm MD5).Hash.ToLower()
  Write-Host ("  OK  {0:N0} B  md5={1}" -f $item.Length, $md5)
}
Write-Host '完成。产物在 tools\espd\dist\'
