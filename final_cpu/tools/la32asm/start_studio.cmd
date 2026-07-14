@echo off
setlocal
cd /d "%~dp0"
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0start_studio.ps1" %*
if errorlevel 1 (
  echo.
  echo LA32 Studio failed to start. Keep this window open and send the error above.
  pause
)
