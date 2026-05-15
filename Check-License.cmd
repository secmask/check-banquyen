@echo off
setlocal
set "ROOT=%~dp0"
start "Check License" powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%ROOT%src\main.ps1" -Gui