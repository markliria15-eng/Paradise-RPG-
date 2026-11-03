@echo off
title Paradise RPG - Teste Offline
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tools\run_pc.ps1" -Environment local -MobilePreview -Offline
