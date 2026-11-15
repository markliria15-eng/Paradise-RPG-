@echo off
title Paradise RPG - Teste automatico
cd /d "%~dp0"
set "GODOT=%~dp0.tools\godot-4.6.3\Godot_v4.6.3-stable_win64_console.exe"
if not exist "%GODOT%" (
  echo Nao achei o Godot 4.6.3 em .tools\godot-4.6.3
  pause
  exit /b 1
)
echo Rodando o teste automatico (uns 2 minutos, sem abrir janela)...
set PARADISE_MMO_ENV=local
"%GODOT%" --headless --path . res://tests/teste_automatico.tscn -- --offline-test %*
if errorlevel 1 (
  echo.
  echo Alguma coisa falhou. Tire um print desta janela e mande para o Claude.
) else (
  echo.
  echo Tudo certo!
)
pause
