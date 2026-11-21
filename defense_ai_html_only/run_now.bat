@echo off
chcp 65001 > nul
echo.
echo  국방 AI 일일 리포트 - 지금 바로 HTML 생성
echo.
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0main.ps1"
echo.
pause
