param([string]$Target = "")

$ErrorActionPreference = "Stop"
$Payload = Join-Path $PSScriptRoot "payload"

function Write-Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }

if (-not (Test-Path (Join-Path $Payload "ue4ss\UE4SS.dll"))) {
    Write-Host "[错误] 找不到 payload 文件夹，请先完整解压压缩包。" -ForegroundColor Red
    exit 1
}

# ---------- 找游戏目录 ----------
$candidates = @(
    "C:\Program Files (x86)\Steam\steamapps\common\PBZ\platform\steam",
    "D:\Steam\steamapps\common\PBZ\platform\steam",
    "D:\steam\steamapps\common\PBZ\platform\steam",
    "E:\Steam\steamapps\common\PBZ\platform\steam",
    "E:\SteamLibrary\steamapps\common\PBZ\platform\steam",
    "F:\SteamLibrary\steamapps\common\PBZ\platform\steam"
)

if ($Target -ne "") {
    $Target = $Target.Trim('"').TrimEnd('\')
} else {
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "PBZ.exe")) { $Target = $c; break }
    }
}

while ($true) {
    if ($Target -ne "" -and (Test-Path (Join-Path $Target "PBZ.exe"))) { break }

    if ($Target -ne "") {
        Write-Host "[错误] 这个目录里没有 PBZ.exe：$Target" -ForegroundColor Red
    }
    Write-Host ""
    Write-Host "请粘贴 PBZ.exe 所在的文件夹路径，然后回车。"
    Write-Host "例如： D:\steam\steamapps\common\PBZ\platform\steam"
    Write-Host ""
    $Target = Read-Host "路径"
    if ($null -eq $Target) { exit 1 }
    $Target = $Target.Trim('"').TrimEnd('\')
    if ($Target -eq "") { Write-Host "已取消。"; exit 1 }
}

Write-Host ""
Write-Host "目标目录：$Target" -ForegroundColor Green
Write-Host "（目录里确实有 PBZ.exe）"

# ---------- 备份 ----------
Write-Step "备份已有文件"

if (Test-Path (Join-Path $Target "dwmapi.dll")) {
    $bak = Join-Path $Target "dwmapi.dll.bak"
    if (Test-Path $bak) { Remove-Item $bak -Force }
    Move-Item (Join-Path $Target "dwmapi.dll") $bak
    Write-Host "  dwmapi.dll -> dwmapi.dll.bak"
}

if (Test-Path (Join-Path $Target "ue4ss")) {
    $bakDir = Join-Path $Target "ue4ss.bak"
    if (Test-Path $bakDir) { Remove-Item $bakDir -Recurse -Force }
    Move-Item (Join-Path $Target "ue4ss") $bakDir
    Write-Host "  ue4ss\ -> ue4ss.bak\"
}

# ---------- 复制 ----------
Write-Step "复制文件"

Copy-Item (Join-Path $Payload "dwmapi.dll") (Join-Path $Target "dwmapi.dll") -Force
Copy-Item (Join-Path $Payload "ue4ss") (Join-Path $Target "ue4ss") -Recurse -Force

# ---------- 验证 ----------
Write-Step "验证"

$ok = $true
$checks = @(
    @{ Path = "dwmapi.dll"; Desc = "注入 DLL" },
    @{ Path = "ue4ss\UE4SS.dll"; Desc = "UE4SS 本体" },
    @{ Path = "ue4ss\Mods\PBZQuickSave\Scripts\main.lua"; Desc = "模组脚本" }
)
foreach ($c in $checks) {
    $full = Join-Path $Target $c.Path
    if (Test-Path $full) {
        Write-Host ("  [OK]   " + $c.Desc) -ForegroundColor Green
    } else {
        Write-Host ("  [缺失] " + $c.Desc + "  -> " + $c.Path) -ForegroundColor Red
        $ok = $false
    }
}

Write-Host ""
if ($ok) {
    Write-Host "安装完成。" -ForegroundColor Green
    Write-Host ""
    Write-Host "现在从 Steam 启动游戏。进关卡后按："
    Write-Host "   F8   存档 + 记录当前位置"
    Write-Host "   F9   传送回记录的位置"
    Write-Host "   F10  读档 + 传送（读档部分尚未打通）"
    Write-Host ""
    Write-Host "日志：$Target\ue4ss\UE4SS.log  搜 PBZQuickSave"
    exit 0
} else {
    Write-Host "安装不完整。常见原因：杀毒软件拦截、目标目录没有写权限。" -ForegroundColor Red
    exit 1
}
