@echo off
title Paradise RPG - Atualizar do GitHub e testar
cd /d "%~dp0"
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\atualizar\atualizar_do_github.ps1"
if errorlevel 1 (
  pause
  exit /b 1
)
echo.
echo Pronto! Abrindo o teste offline...
call "%~dp0TESTAR_JOGO_OFFLINE.bat"
