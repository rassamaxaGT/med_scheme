# Master PowerShell Script: Сборка всех установщиков для платформ, доступных на Windows (Android + Windows)
$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "============================================================" -ForegroundColor Magenta
Write-Host "  МедРисунок: Запуск полного пайплайна сборки на Windows" -ForegroundColor Magenta
Write-Host "  1. Windows Release + Portable ZIP + Inno Setup Installer" -ForegroundColor Magenta
Write-Host "  2. Android Release APK (Universal + Arm64)" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Magenta

# Сборка Windows
& "$ScriptDir\build_windows.ps1"

# Сборка Android
& "$ScriptDir\build_android.ps1"

Write-Host "`n============================================================" -ForegroundColor Magenta
Write-Host "  Все локальные сборки успешно завершены!" -ForegroundColor Green
Write-Host "  Все готовые файлы находятся в каталоге: dist/" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Magenta
