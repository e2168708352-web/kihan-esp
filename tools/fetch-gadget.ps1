<#
  fetch-gadget.ps1 — 拉取 frida-gadget (android-arm64) 并转成 esp/libhw.so.gz

  用法：
    powershell -ExecutionPolicy Bypass -File tools\fetch-gadget.ps1
    powershell -ExecutionPolicy Bypass -File tools\fetch-gadget.ps1 -Version 17.26.3

  说明：
    * gadget 必须以 libhw.so 命名落盘，配置文件名必须是 libhw.config（frida 按
      "<库名>.config" 找同目录配置文件），这是整套改名伪装的基础。
    * 输出的是 gzip 后的 libhw.so.gz，模块里解压，省 25MB 左右。
    * 解压用 Windows 自带的 tar.exe（bsdtar，支持 xz）；没有就找 7z。
#>
param(
  [string]$Version = '17.26.3',
  [string]$Out = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path $PSScriptRoot -Parent
$esp  = Join-Path $repo 'esp'
$tmp  = Join-Path $env:TEMP 'kihan-esp-gadget'
if (!$Out) { $Out = Join-Path $esp 'libhw.so.gz' }

$name = "frida-gadget-$Version-android-arm64.so"
$xz   = "$name.xz"
$url  = "https://github.com/frida/frida/releases/download/$Version/$xz"

New-Item -ItemType Directory -Force $tmp | Out-Null
New-Item -ItemType Directory -Force $esp | Out-Null

$xzPath = Join-Path $tmp $xz
if (!(Test-Path $xzPath)) {
  Write-Host "下载 $url"
  $old = $ProgressPreference; $ProgressPreference = 'SilentlyContinue'
  try {
    Invoke-WebRequest -Uri $url -OutFile $xzPath -UseBasicParsing
  } finally { $ProgressPreference = $old }
}
Write-Host ("xz: {0:N0} B" -f (Get-Item $xzPath).Length)

# ---------- 解 xz ----------
$soPath = Join-Path $tmp $name
if (Test-Path $soPath) { Remove-Item $soPath -Force }

$tar = (Get-Command tar.exe -ErrorAction SilentlyContinue).Source
if ($tar) {
  & $tar -xf $xzPath -C $tmp
} else {
  $seven = @('C:\Program Files\7-Zip\7z.exe','C:\Program Files (x86)\7-Zip\7z.exe') |
            Where-Object { Test-Path $_ } | Select-Object -First 1
  if (!$seven) { throw "没有 tar.exe 也没有 7z，无法解 xz" }
  & $seven x -y "-o$tmp" $xzPath | Out-Null
}

if (!(Test-Path $soPath)) { throw "解压后找不到 $soPath" }

# ---------- 校验 ELF ----------
$fs = [System.IO.File]::OpenRead($soPath)
try {
  $hdr = New-Object byte[] 20
  $fs.Read($hdr, 0, 20) | Out-Null
} finally { $fs.Dispose() }
if ($hdr[0] -ne 0x7f -or $hdr[1] -ne 0x45) { throw "不是 ELF 文件" }
$machine = [BitConverter]::ToUInt16($hdr, 18)
if ($machine -ne 0xB7) { throw ("不是 aarch64 ELF（e_machine=0x{0:x4}）" -f $machine) }
Write-Host ("ELF ok: aarch64, {0:N0} B" -f (Get-Item $soPath).Length)

# ---------- gzip ----------
if (Test-Path $Out) { Remove-Item $Out -Force }
$in  = [System.IO.File]::OpenRead($soPath)
$out = [System.IO.File]::Create($Out)
$gz  = New-Object System.IO.Compression.GZipStream($out, [System.IO.Compression.CompressionLevel]::Optimal)
try { $in.CopyTo($gz) } finally { $gz.Dispose(); $out.Dispose(); $in.Dispose() }

Write-Host ("OK  {0}  {1:N0} B  md5={2}" -f $Out, (Get-Item $Out).Length, (Get-FileHash $Out -Algorithm MD5).Hash.ToLower())
Write-Host '下一步：module\build-module.ps1'
