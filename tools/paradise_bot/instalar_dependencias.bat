@echo off
chcp 65001 >nul
title Paradise Bot - Instalacao
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0instalar_dependencias.ps1"
