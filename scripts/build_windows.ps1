# PowerShell Script: Build Windows Release, Portable ZIP, and Inno Setup Installer
param(
    [switch]$SkipInstaller = $false
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Resolve-Path "$PSScriptRoot\.."
Set-Location $ProjectRoot

Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Сборка МедРисунок для Windows (x64 Release)" -ForegroundColor Cyan
Write-Host "====================================================" -ForegroundColor Cyan

# 1. Извлечение версии из pubspec.yaml
$PubspecContent = Get-Content "pubspec.yaml" -Raw
if ($PubspecContent -match "version:\s*([0-9\.\+]+)") {
    $RawVersion = $matches[1]
    $Version = ($RawVersion -split '\+')[0]
} else {
    $Version = "1.0.30"
}
Write-Host "Версия проекта: $Version" -ForegroundColor Green

# 2. Подготовка каталогов вывода
$DistDir = Join-Path $ProjectRoot "dist\windows"
if (!(Test-Path $DistDir)) {
    New-Item -ItemType Directory -Path $DistDir -Force | Out-Null
}

# 3. Компиляция Flutter Windows Release
Write-Host ""
Write-Host "[1/3] Компиляция Flutter Windows x64 Release..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Error "Ошибка при сборке Flutter Windows."
}

$BuildOutputDir = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
if (!(Test-Path "$BuildOutputDir\med_scheme.exe")) {
    Write-Error "Исполняемый файл не найден в $BuildOutputDir"
}

# 4. Создание Portable ZIP-архива
$ZipFile = Join-Path $DistDir "MedRisunok_v${Version}_portable.zip"
Write-Host ""
Write-Host "[2/3] Упаковка Portable архива: $ZipFile..." -ForegroundColor Yellow
if (Test-Path $ZipFile) { Remove-Item $ZipFile -Force }
Compress-Archive -Path "$BuildOutputDir\*" -DestinationPath $ZipFile -CompressionLevel Optimal
Write-Host "Архив успешно создан: $ZipFile" -ForegroundColor Green

# 5. Сборка установщика Inno Setup
if ($SkipInstaller) {
    Write-Host ""
    Write-Host "[3/3] Сборка инсталлятора пропущена флажком -SkipInstaller." -ForegroundColor DarkYellow
} else {
    Write-Host ""
    Write-Host "[3/3] Поиск компилятора Inno Setup (ISCC.exe)..." -ForegroundColor Yellow
    $IsccCandidatePaths = @(
        (Get-Command iscc -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
        "C:\Program Files (x86)\Inno Setup 6\ISCC.exe",
        "C:\Program Files\Inno Setup 6\ISCC.exe",
        "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Antigravity IDE\resources\app\node_modules\innosetup\bin\ISCC.exe",
        "C:\Users\$env:USERNAME\AppData\Local\Programs\Antigravity IDE\_\resources\app\node_modules\innosetup\bin\ISCC.exe"
    )

    $IsccPath = $null
    foreach ($path in $IsccCandidatePaths) {
        if ($path -and (Test-Path $path)) {
            $IsccPath = $path
            break
        }
    }

    if ($IsccPath) {
        Write-Host "Найден Inno Setup компилятор: $IsccPath" -ForegroundColor Green
        $IssScript = Join-Path $ProjectRoot "windows\packaging\inno_setup.iss"
        & "$IsccPath" "/DMyAppVersion=$Version" "$IssScript"
        if ($LASTEXITCODE -eq 0) {
            $SetupExe = Join-Path $DistDir "MedRisunok_Setup_v${Version}.exe"
            Write-Host "Установщик успешно создан: $SetupExe" -ForegroundColor Green
        } else {
            Write-Warning "Inno Setup завершился с ошибкой. Сгенерирован только portable архив."
        }
    } else {
        Write-Warning "ISCC.exe не найден. Для создания единого .exe установщика установите Inno Setup 6 (winget install JRSoftware.InnoSetup)."
        Write-Host "Готов переносимый архив: $ZipFile" -ForegroundColor Cyan
    }
}

Write-Host ""
Write-Host "====================================================" -ForegroundColor Cyan
Write-Host "  Сборка Windows завершена успешно!" -ForegroundColor Green
Write-Host "  Файлы в: $DistDir" -ForegroundColor Green
Write-Host "====================================================" -ForegroundColor Cyan
