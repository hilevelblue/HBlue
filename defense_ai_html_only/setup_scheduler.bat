@echo off
chcp 65001 > nul
echo.
echo  국방 AI 일일 리포트 - 작업 스케줄러 등록 (HTML 전용, 창 숨김)
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_scheduler.ps1"
echo.
pause
