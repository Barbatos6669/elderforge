@echo off
setlocal

pushd "%~dp0"
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File "%~dp0Elderforge_Playtest_Client.ps1"
set EXIT_CODE=%ERRORLEVEL%
popd

if not "%EXIT_CODE%"=="0" (
	echo.
	echo Elderforge playtest client failed.
	pause
)

exit /b %EXIT_CODE%
