@echo off
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0build_windows_playtest.ps1" %*
if errorlevel 1 exit /b %errorlevel%
