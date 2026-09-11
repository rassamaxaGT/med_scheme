# Task List: Сборка установщиков (Android, Windows, iOS)

- [x] **Phase 1: Метаданные и брендинг платформ**
  - [x] Обновить `android:label` на «МедРисунок» в [AndroidManifest.xml](file:///d:/projects/med_scheme/android/app/src/main/AndroidManifest.xml)
  - [x] Обновить заголовок окна на «МедРисунок» в [main.cpp](file:///d:/projects/med_scheme/windows/runner/main.cpp)
  - [x] Обновить метаданные приложения в [Runner.rc](file:///d:/projects/med_scheme/windows/runner/Runner.rc)
- [x] **Phase 2: Инфраструктура сборщика Windows**
  - [x] Создать сценарий Inno Setup в [windows/packaging/inno_setup.iss](file:///d:/projects/med_scheme/windows/packaging/inno_setup.iss)
  - [x] Создать скрипт сборщика [scripts/build_windows.ps1](file:///d:/projects/med_scheme/scripts/build_windows.ps1) (Release сборка, Portable ZIP, Inno Setup)
  - [x] Скомпилирован полноценный `MedRisunok_Setup_v1.0.30.exe` и `MedRisunok_v1.0.30_portable.zip`
- [x] **Phase 3: Инфраструктура сборщика Android**
  - [x] Создать скрипт сборщика [scripts/build_android.ps1](file:///d:/projects/med_scheme/scripts/build_android.ps1) (Universal APK, ABI split, каталогизация в `dist/android/`)
  - [x] Скомпилированы `MedRisunok_v1.0.30_universal.apk` и `MedRisunok_v1.0.30_arm64.apk`
- [x] **Phase 4: Инфраструктура сборщика iOS и CI/CD**
  - [x] Создать скрипт для macOS [scripts/build_ios_unsigned.sh](file:///d:/projects/med_scheme/scripts/build_ios_unsigned.sh) (`flutter build ios --no-codesign`, сборка `Payload/*.ipa`)
  - [x] Создать облачный workflow [.github/workflows/build_installers.yml](file:///d:/projects/med_scheme/.github/workflows/build_installers.yml) для компиляции iOS на `macos-latest`, а также Android и Windows
- [x] **Phase 5: Документация и запуск сборки**
  - [x] Создать руководство [INSTALLATION_GUIDE.md](file:///d:/projects/med_scheme/INSTALLATION_GUIDE.md) по установке на Android, Windows и iOS
  - [x] Создать мастер-скрипт [scripts/build_all_windows.ps1](file:///d:/projects/med_scheme/scripts/build_all_windows.ps1)
  - [x] Проверены артефакты в каталоге `dist/` (все установщики сгенерированы без ошибок)
