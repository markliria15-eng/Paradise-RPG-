@echo off
setlocal
cd /d "%~dp0\.."
echo.
echo [Arcadia] Importar sprites pixeladas do celular
echo.
echo Coloque os arquivos no celular em:
echo /sdcard/Download/ArcadiaSprites
echo.
echo Nomes aceitos:
echo guerreiro_front.png, guerreiro_side.png, guerreiro_back.png
echo mago_front.png, mago_side.png, mago_back.png
echo arqueiro_front.png, arqueiro_side.png, arqueiro_back.png
echo.
pause
powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\import_phone_character_sprites.ps1"
echo.
pause
