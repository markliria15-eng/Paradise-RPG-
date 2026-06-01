@echo off
setlocal
cd /d "%~dp0\.."
echo.
echo [Arcadia] Instalacao remota do APK
set /p DEVICE_IP=IP do celular (ex: 192.168.0.24): 
set PORT=5555
set /p PORT=Porta ADB [5555]: 
if "%PORT%"=="" set PORT=5555
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\android_remote_install.ps1" -DeviceIp "%DEVICE_IP%" -Port %PORT% -Launch
if errorlevel 1 (
  echo.
  echo [ERRO] Falha na instalacao remota.
  pause
  exit /b 1
)
echo.
echo [OK] App instalado e aberto.
pause
