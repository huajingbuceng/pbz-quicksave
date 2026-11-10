@echo off
setlocal
cd /d "%~dp0"

if not exist "%~dp0payload\ue4ss\UE4SS.dll" (
    echo [ERROR] payload folder not found.
    echo Please extract the whole archive first, then run this file.
    echo.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "RC=%ERRORLEVEL%"
echo.
pause
exit /b %RC%
