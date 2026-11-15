@echo off
title Paradise RPG - Chave nova do Android
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\android\gerar_chave_nova.ps1"
echo.
pause
