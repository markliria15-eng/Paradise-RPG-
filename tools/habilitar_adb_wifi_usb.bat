@echo off
setlocal
cd /d "%~dp0\.."
echo.
echo [Arcadia] Habilitando ADB por Wi-Fi via USB...
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\android_remote_install.ps1" -EnableTcpipFromUsb
if errorlevel 1 (
  echo.
  echo [ERRO] Falha ao habilitar ADB Wi-Fi.
  pause
  exit /b 1
)
echo.
echo [OK] ADB Wi-Fi habilitado. Agora use instalar_remoto.bat
pause
