```bat
@echo off
cd /d "%~dp0"
title Kral Tesisat AI Bot
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0KralTesisat.ps1"
if errorlevel 1 (
    echo.
    echo Program kapandi veya bir hata olustu.
    pause
)
```
