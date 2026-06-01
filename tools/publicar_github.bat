@echo off
cd /d "%~dp0\.."
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\push_to_github.ps1" -Message "Atualiza Paradise RPG"
pause
