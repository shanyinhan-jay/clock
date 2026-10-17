@echo off
cd /d "%~dp0"
wscript.exe //nologo "%~dp0countdown.vbs" %*
exit /b 0
