@echo off
chcp 65001 >nul
title Countdown
cd /d "%~dp0"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ensure-utf8bom.ps1"
if errorlevel 1 goto fail

powershell.exe -NoProfile -ExecutionPolicy Bypass -Sta -File "%~dp0countdown.ps1" %*
if errorlevel 1 goto fail
exit /b 0

:fail
echo.
echo Start failed. See errors above.
pause
exit /b 1
