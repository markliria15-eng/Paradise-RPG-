@echo off
setlocal
cd /d "%~dp0\.."
echo.
echo [Arcadia] Pareamento Wireless Debugging
set /p DEVICE_IP=IP do celular (ex: 192.168.0.24): 
set /p PAIR_PORT=Porta de pareamento (ex: 37123): 
set /p PAIR_CODE=Codigo de pareamento: 
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\android_remote_install.ps1" -Pair -DeviceIp "%DEVICE_IP%" -PairPort %PAIR_PORT% -PairCode "%PAIR_CODE%"
if errorlevel 1 (
  echo.
  echo [ERRO] Falha no pareamento.
  pause
  exit /b 1
)
echo.
echo [OK] Pareamento concluido.
pause
