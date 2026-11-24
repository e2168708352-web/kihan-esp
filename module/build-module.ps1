<#
  build-module.ps1 (v2) — 把 module/ + esp/ 打成可刷入的 KernelSU/Magisk 模块 zip

  新架构：进程外只读（espd），不再需要 gadget / Zygisk / ZygiskFrida。
  模块 zip 从 ~17MB 降到 ~3.1MB（只剩悬浮窗 apk + 31KB 二进制 + 脚本）。

  用法：
    powershell -ExecutionPolicy Bypass -File module\build-module.ps1
    powershell -ExecutionPolicy Bypass -File module\build-module.ps1 -Out dist\my.zip

  依赖：
    module\bin\espd-arm64   已编译的 daemon（tools\espd\build.ps1 产出）
    overlay\dist\esp.apk    悬浮窗（UDP 绘制零改动）
#>
param(
  [string]$Out = '',
  [switch]$AllowNoApk,
  [switch]$AllowNoEspd
)

$ErrorActionPreference = 'Stop'
$repo  = Split-Path $PSScriptRoot -Parent
$dist  = Join-Path $repo 'dist'
$stage = Join-Path $dist '_stage'

if (!$Out) { $Out = Join-Path $dist 'esp_local-module.zip' }
New-Item -ItemType Directory -Force $dist | Out-Null

# -------- espd 二进制：缺失时尝试从 tools\espd\dist 拷入 --------
$bin = Join-Path $PSScriptRoot 'bin'
$espd = Join-Path $bin 'espd-arm64'
if (!(Test-Path $espd)) {
  $built = Join-Path $repo 'tools\espd\dist\espd-arm64'
  if (Test-Path $built) {
    New-Item -ItemType Directory -Force $bin | Out-Null
    Copy-Item $built $espd
    Write-Host '[0/3] 从 tools\espd\dist 拷入 espd-arm64'
  } elseif (!$AllowNoEspd) {
    throw "缺少 $espd（先跑 tools\espd\build.ps1，或加 -AllowNoEspd 跳过）"
  }
}

# -------- 组装 staging --------
Write-Host '[1/3] 组装 staging ...'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
New-Item -ItemType Directory -Force $stage | Out-Null

Copy-Item (Join-Path $PSScriptRoot 'module.prop') $stage
Copy-Item (Join-Path $PSScriptRoot 'META-INF') $stage -Recurse
Copy-Item (Join-Path $PSScriptRoot 'service.d') $stage -Recurse
Copy-Item $bin (Join-Path $stage 'bin') -Recurse

$espStage = Join-Path $stage 'esp'
New-Item -ItemType Directory -Force $espStage | Out-Null
$apk = Join-Path $repo 'overlay\dist\esp.apk'
if (Test-Path $apk) { Copy-Item $apk $espStage }
elseif ($AllowNoApk) { Write-Warning "缺少 overlay\dist\esp.apk —— 模块装完不会有悬浮窗" }
else { throw "缺少 overlay\dist\esp.apk（先跑 overlay\build.ps1，或加 -AllowNoApk 跳过）" }

# -------- 打包（entry 用 '/' 且无顶层目录） --------
Write-Host '[2/3] 打包 ...'
if (Test-Path $Out) { Remove-Item $Out -Force }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($Out, 'Create')
try {
  $root = (Resolve-Path $stage).Path
  Get-ChildItem $stage -Recurse -File | ForEach-Object {
    $rel = $_.FullName.Substring($root.Length + 1).Replace('\', '/')
    $entry = $zip.CreateEntry($rel, [System.IO.Compression.CompressionLevel]::Optimal)
    $es = $entry.Open()
    $fs = [System.IO.File]::OpenRead($_.FullName)
    try { $fs.CopyTo($es) } finally { $fs.Dispose(); $es.Dispose() }
  }
} finally { $zip.Dispose() }

Remove-Item $stage -Recurse -Force

# -------- 校验：zip 内不能有 97_esp_module.sh / libhw.so.gz --------
Write-Host '[3/3] 校验 ...'
$zip2 = [System.IO.Compression.ZipFile]::OpenRead($Out)
try {
  $names = $zip2.Entries.FullName
  $bad = $names | Where-Object { $_ -match '97_esp_module|libhw\.so\.gz|libhw\.config' }
  if ($bad) { throw "zip 里仍有旧架构文件: $($bad -join ', ')" }
  $need = @('module.prop','service.d/97_espd.sh','bin/espd-arm64','bin/espd-supervisor.sh','bin/espd.conf')
  foreach ($n in $need) {
    if ($names -notcontains $n) { throw "zip 缺少必需文件: $n" }
  }
} finally { $zip2.Dispose() }

$item = Get-Item $Out
$md5 = (Get-FileHash $Out -Algorithm MD5).Hash.ToLower()
Write-Host ''
Write-Host ("OK  {0}  {1:N0} B  md5={2}" -f $item.FullName, $item.Length, $md5)
Write-Host '新架构：刷入后开机自动起 espd，开游戏即画线（无 zygote 重启、无 gadget）。'
