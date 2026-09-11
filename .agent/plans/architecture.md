# Architecture Design: Сборка установщиков (Android, Windows, iOS)

## Overview
Проект расширяется инфраструктурными компонентами для сборки готовых пользовательских дистрибутивов без подписи разработчика (ad-hoc / side-loading). 
Включает локальные сценарии автоматизации (PowerShell, Bash), конфигурацию инсталлятора Inno Setup, облачный CI/CD воркфлоу GitHub Actions для платформ, требующих специфического окружения (macOS для iOS), и подробное руководство по установке.

## Components & File Structure

### 1. Метаданные и брендинг платформ
- [AndroidManifest.xml](file:///d:/projects/med_scheme/android/app/src/main/AndroidManifest.xml) — замена системного имени приложения на «МедРисунок».
- [Runner.rc](file:///d:/projects/med_scheme/windows/runner/Runner.rc) — актуализация метаданных исполняемого файла Windows (`CompanyName`, `ProductName`, `FileDescription`).
- [main.cpp](file:///d:/projects/med_scheme/windows/runner/main.cpp) — корректный заголовок нативного окна Windows (`L"МедРисунок"`).

### 2. Конфигурация инсталлятора Windows
- [windows/packaging/inno_setup.iss](file:///d:/projects/med_scheme/windows/packaging/inno_setup.iss) — сценарий сборки автономного установщика `Setup.exe` на базе Inno Setup:
  - Упаковка дерева `Release/`
  - Создание ярлыков Рабочего стола и меню «Пуск»
  - Регистрация приложения в списке установленных программ Windows с возможностью удаления.

### 3. Скрипты автоматизации сборки
- [scripts/build_android.ps1](file:///d:/projects/med_scheme/scripts/build_android.ps1) — сценарий сборки универсального и архитектурных APK.
- [scripts/build_windows.ps1](file:///d:/projects/med_scheme/scripts/build_windows.ps1) — сценарий сборки релизного Windows-бинарника, portable ZIP-архива и вызова Inno Setup (при наличии компилятора).
- [scripts/build_ios_unsigned.sh](file:///d:/projects/med_scheme/scripts/build_ios_unsigned.sh) — сценарий сборки неподписанного iOS `.ipa` через `--no-codesign` и упаковку структуры `Payload/Runner.app`.

### 4. Облачный CI/CD пайплайн
- [.github/workflows/build_installers.yml](file:///d:/projects/med_scheme/.github/workflows/build_installers.yml) — многоплатформенная матрица сборки на GitHub Actions:
  - `ubuntu-latest` → Android APKs
  - `windows-latest` → Windows Release + Inno Setup installer
  - `macos-latest` → iOS Runner.app `--no-codesign` + упаковка в `MedRisunok_unsigned.ipa`.

### 5. Документация пользователя
- [INSTALLATION_GUIDE.md](file:///d:/projects/med_scheme/INSTALLATION_GUIDE.md) — пошаговое руководство по установке файлов на Android, Windows и iOS (с помощью Sideloadly / AltStore / TrollStore).

## Data Models / Schemas
Выходная структура сгенерированных дистрибутивов в каталоге `dist/`:
```
dist/
├── android/
│   ├── MedRisunok_v1.0.30_universal.apk
│   └── MedRisunok_v1.0.30_arm64.apk
├── windows/
│   ├── MedRisunok_Setup_v1.0.30.exe
│   └── MedRisunok_v1.0.30_portable.zip
└── ios/
    └── MedRisunok_v1.0.30_unsigned.ipa
```
