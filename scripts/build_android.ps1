# PowerShell Script: Build Android Release APKs (Universal + Split ABI)
param(
    [switch]$UniversalOnly = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $ProjectRoot

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Сборка МедРисунок для Android (Release APK)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Извлечение версии
$PubspecContent = Get-Content "pubspec.yaml" -Raw
if ($PubspecContent -match "version:\s*([0-9\.\+]+)") {
    $RawVersion = $matches[1]
    $Version = ($RawVersion -split '\+')[0]
} else {
    $Version = "1.0.30"
}
Write-Host "Версия проекта: $Version" -ForegroundColor Green

# 2. Подготовка каталогов вывода
$DistDir = Join-Path $ProjectRoot "dist\android"
if (!(Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

$ApkBuildDir = Join-Path $ProjectRoot "build\app\outputs\flutter-apk"

# 3. Сборка Universal APK
Write-Host ""
Write-Host "[1/2] Сборка универсального APK (для всех архитектур)..." -ForegroundColor Yellow
flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Ошибка при сборке универсального APK."
}

$UniversalSrc = Join-Path $ApkBuildDir "app-release.apk"
$UniversalDest = Join-Path $DistDir "MedRisunok_v${Version}_universal.apk"
Copy-Item -Path $UniversalSrc -Destination $UniversalDest -Force
$UniversalSize = "{0:N2} MB" -f ((Get-Item $UniversalDest).Length / 1MB)
Write-Host "Универсальный APK готов: $UniversalDest ($UniversalSize)" -ForegroundColor Green

# 4. Сборка ABI Split APK (при необходимости)
if (!$UniversalOnly) {
    Write-Host ""
    Write-Host "[2/2] Сборка облегчённых APK с разделением по архитектурам (--split-per-abi)..." -ForegroundColor Yellow
    flutter build apk --release --split-per-abi
    if ($LASTEXITCODE -eq 0) {
        $Arm64Src = Join-Path $ApkBuildDir "app-arm64-v8a-release.apk"
        if (Test-Path $Arm64Src) {
            $Arm64Dest = Join-Path $DistDir "MedRisunok_v${Version}_arm64.apk"
            Copy-Item -Path $Arm64Src -Destination $Arm64Dest -Force
            $Arm64Size = "{0:N2} MB" -f ((Get-Item $Arm64Dest).Length / 1MB)
            Write-Host "Оптимизированный arm64 APK готов: $Arm64Dest ($Arm64Size)" -ForegroundColor Green
        }
    } else {
        Write-Warning "Не удалось собрать ABI split, универсальный APK сохранён."
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Сборка Android завершена успешно!" -ForegroundColor Green
Write-Host "  Файлы в: $DistDir" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
