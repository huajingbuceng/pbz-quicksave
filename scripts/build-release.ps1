<#
.SYNOPSIS
    打包发布版。

.DESCRIPTION
    生成两个 zip：
      dist/PBZQuickSave-<版本>.zip          精简包，只含模组
      dist/PBZQuickSave-完整安装包-<版本>.zip  完整包，自动下载 UE4SS 一并打包

.EXAMPLE
    .\scripts\build-release.ps1
    .\scripts\build-release.ps1 -Full
#>
param(
    [switch]$Full,
    [string]$Ue4ssUrl = "https://github.com/KintaroModding/ue4ss/releases/download/v3.0.1-1195-g1ceefac8/phantombladezero_ue4ss_v3.0.1-1195-g1ceefac8.zip"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot

$Version = "1.0.0"
$vf = Join-Path $Root "mod\version.txt"
if (Test-Path $vf) {
    $line = (Get-Content $vf -Raw).Trim()
    if ($line -match '([\d.]+)$') { $Version = $Matches[1] }
}

$Dist = Join-Path $Root "dist"
$Work = Join-Path $Root "build"
New-Item -ItemType Directory -Force -Path $Dist | Out-Null

# ---------- 精简包 ----------
Write-Host "[1/2] 精简包 v$Version"
$lite = Join-Path $Work "lite\PBZQuickSave"
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory -Force -Path $lite | Out-Null
Copy-Item (Join-Path $Root "mod\*") $lite -Recurse -Force

$zipLite = Join-Path $Dist "PBZQuickSave-$Version.zip"
if (Test-Path $zipLite) { Remove-Item $zipLite -Force }
Compress-Archive -Path $lite -DestinationPath $zipLite -CompressionLevel Optimal
Write-Host "      -> $zipLite"

if (-not $Full) {
    Write-Host "完成（加 -Full 可同时生成完整安装包）"
    return
}

# ---------- 完整包 ----------
Write-Host "[2/2] 完整安装包"

$pkg = Join-Path $Work "full"
$payload = Join-Path $pkg "payload"
New-Item -ItemType Directory -Force -Path $payload | Out-Null

$ue4ssZip = Join-Path $Work "ue4ss.zip"
if (-not (Test-Path $ue4ssZip)) {
    Write-Host "     下载 UE4SS ..."
    $ProgressPreference = "SilentlyContinue"
    Invoke-WebRequest -Uri $Ue4ssUrl -OutFile $ue4ssZip -UseBasicParsing -TimeoutSec 600
}

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::ExtractToDirectory($ue4ssZip, $payload)

$modTarget = Join-Path $payload "ue4ss\Mods\PBZQuickSave"
New-Item -ItemType Directory -Force -Path $modTarget | Out-Null
Copy-Item (Join-Path $Root "mod\*") $modTarget -Recurse -Force

Copy-Item (Join-Path $Root "installer\install.bat") $pkg -Force
Copy-Item (Join-Path $Root "installer\install.ps1") $pkg -Force
Copy-Item (Join-Path $Root "installer\安装说明.txt") $pkg -Force -ErrorAction SilentlyContinue

$zipFull = Join-Path $Dist "PBZQuickSave-完整安装包-$Version.zip"
if (Test-Path $zipFull) { Remove-Item $zipFull -Force }
Compress-Archive -Path (Join-Path $pkg "*") -DestinationPath $zipFull -CompressionLevel Optimal
Write-Host "      -> $zipFull"
Write-Host "完成。"
