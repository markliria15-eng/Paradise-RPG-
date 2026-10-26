@echo off
chcp 65001 >nul
title Paradise Bot
cd /d "%~dp0\..\.."
where py >nul 2>nul && (py -3 tools\paradise_bot\bot.py %*) || (python tools\paradise_bot\bot.py %*)
pause
