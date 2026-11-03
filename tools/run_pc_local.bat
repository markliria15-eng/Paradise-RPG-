@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0run_pc.ps1" -Environment local -MobilePreview
