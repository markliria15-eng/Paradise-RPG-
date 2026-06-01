@echo off
setlocal
cd /d "%~dp0\.."

:menu
cls
echo ==========================================
echo      Arcadia Realms 2D - Android Menu
echo ==========================================
echo.
echo  1 - Habilitar ADB Wi-Fi pelo USB
echo  2 - Parear Wireless Debugging
echo  3 - Instalar APK remoto e abrir
echo  4 - Listar dispositivos ADB
echo  5 - Abrir pasta do APK
echo  6 - Importar sprites dos personagens do celular
echo  0 - Sair
echo.
set /p OPCAO=Escolha uma opcao: 

if "%OPCAO%"=="1" goto enable_wifi
if "%OPCAO%"=="2" goto pair_wifi
if "%OPCAO%"=="3" goto install_remote
if "%OPCAO%"=="4" goto list_devices
if "%OPCAO%"=="5" goto open_apk_folder
if "%OPCAO%"=="6" goto import_sprites
if "%OPCAO%"=="0" goto end
goto menu

:enable_wifi
cls
echo [Arcadia] Habilitando ADB Wi-Fi pelo USB...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\android_remote_install.ps1" -EnableTcpipFromUsb
echo.
pause
goto menu

:pair_wifi
cls
echo [Arcadia] Parear Wireless Debugging
echo.
set /p DEVICE_IP=IP do celular: 
set /p PAIR_PORT=Porta de pareamento: 
set /p PAIR_CODE=Codigo de pareamento: 
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\android_remote_install.ps1" -Pair -DeviceIp "%DEVICE_IP%" -PairPort %PAIR_PORT% -PairCode "%PAIR_CODE%"
echo.
pause
goto menu

:install_remote
cls
echo [Arcadia] Instalar APK remoto e abrir
echo.
set /p DEVICE_IP=IP do celular: 
set PORT=5555
set /p PORT_INPUT=Porta ADB [5555]: 
if not "%PORT_INPUT%"=="" set PORT=%PORT_INPUT%
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\android_remote_install.ps1" -DeviceIp "%DEVICE_IP%" -Port %PORT% -Launch
echo.
pause
goto menu

:list_devices
cls
echo [Arcadia] Dispositivos ADB
echo.
set ADB_EXE=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
if exist "%ADB_EXE%" (
  "%ADB_EXE%" devices -l
) else (
  adb devices -l
)
echo.
pause
goto menu

:open_apk_folder
start "" "%CD%\build\android"
goto menu

:import_sprites
cls
call ".\tools\importar_sprites_personagens_celular.bat"
goto menu

:end
endlocal
