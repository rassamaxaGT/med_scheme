# Implementation Plan: Сборка установщиков (Android, Windows, iOS)

## Phases of Development

### Phase 1: Настройка метаданных и брендинга
- Обновление системного названия `android:label` в `AndroidManifest.xml` на «МедРисунок».
- Обновление заголовка окна в `windows/runner/main.cpp` на `L"МедРисунок"`.
- Обновление метаданных в `windows/runner/Runner.rc`.

### Phase 2: Инсталлятор и сборка Windows
- Создание `windows/packaging/inno_setup.iss` с описанием установки, ярлыков и деинсталлятора.
- Создание `scripts/build_windows.ps1` для автоматической сборки `flutter build windows --release`, генерации portable ZIP и компиляции Inno Setup (при наличии `iscc`).

### Phase 3: Сборка Android APK
- Создание `scripts/build_android.ps1` для сборки универсального и ABI-оптимизированных APK с копированием в `dist/android/`.

### Phase 4: Сборка iOS Unsigned IPA
- Создание `scripts/build_ios_unsigned.sh` с командами `flutter build ios --release --no-codesign` и сборки структуры `Payload/Runner.app` в `.ipa`.
- Создание GitHub Actions воркфлоу `.github/workflows/build_installers.yml` для автоматической облачной сборки iOS `.ipa` на раннере `macos-latest` (а также Android и Windows).

### Phase 5: Документация и верификация
- Создание `INSTALLATION_GUIDE.md` с подробными инструкциями по установке APK, Windows-установщика/portable-версии и сайдлоадингу `.ipa` на iPhone/iPad (через Sideloadly / AltStore).
- Проведение сборки локальных компонентов (Android и Windows) и проверка полученных артефактов.

## Risks & Considerations
- **Сборка iOS на Windows**: Локально на Windows невозможно запустить тулчейн Apple Clang/Xcode. Поэтому для iOS предоставляется два готовых пути: автоматический GitHub Actions (облачная сборка на Mac без необходимости иметь собственный Mac) и shell-скрипт для Mac.
- **Установка неподписанного IPA на iOS**: Неподписанный IPA нельзя установить простым тапом в iOS, система безопасности требует подписи. В `INSTALLATION_GUIDE.md` детально описан процесс установки через бесплатные утилиты сайдлоадинга (Sideloadly, AltStore), которые автоматически подписывают приложение бесплатным Apple ID пользователя прямо на ПК/Mac во время заливки на планшет.
