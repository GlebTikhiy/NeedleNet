@echo off
title NeedleNet - Install
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Install.ps1"
if errorlevel 1 (
  echo.
  echo Installation failed. Read the message above before retrying.
)
echo.
pause
