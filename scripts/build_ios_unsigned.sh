#!/usr/bin/env bash
# Bash Script: Сборка неподписанного iOS IPA на macOS (для macOS VM или хоста)
set -e

echo "===================================================="
echo "  Сборка МедРисунок для iOS (Unsigned IPA)"
echo "===================================================="

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR/.."
cd "$PROJECT_ROOT"

# 1. Извлечение версии из pubspec.yaml
VERSION=$(grep 'version:' pubspec.yaml | head -n 1 | awk '{print $2}' | cut -d '+' -f 1)
if [ -z "$VERSION" ]; then
    VERSION="1.0.30"
fi
echo "Версия проекта: $VERSION"

# 2. Подготовка каталогов вывода
DIST_DIR="$PROJECT_ROOT/dist/ios"
mkdir -p "$DIST_DIR"

# 3. Подготовка окружения
echo ""
echo "[1/3] Установка зависимостей Flutter и CocoaPods..."
flutter pub get
if [ -d "ios" ]; then
    cd ios
    pod install || true
    cd ..
fi

# 4. Сборка приложения под iOS без подписи
echo ""
echo "[2/3] Компиляция Flutter iOS Release (--no-codesign)..."
flutter build ios --release --no-codesign

APP_PATH="$PROJECT_ROOT/build/ios/iphoneos/Runner.app"
if [ ! -d "$APP_PATH" ]; then
    echo "Ошибка: $APP_PATH не найден."
    exit 1
fi

# 5. Упаковка Runner.app в структуру Payload/ -> .ipa
echo ""
echo "[3/3] Упаковка в структуру IPA (Payload)..."
TEMP_PAYLOAD="$DIST_DIR/Payload"
rm -rf "$TEMP_PAYLOAD"
mkdir -p "$TEMP_PAYLOAD"

cp -R "$APP_PATH" "$TEMP_PAYLOAD/"

IPA_NAME="MedRisunok_v${VERSION}_unsigned.ipa"
IPA_PATH="$DIST_DIR/$IPA_NAME"
rm -f "$IPA_PATH"

cd "$DIST_DIR"
zip -r -y -q "$IPA_NAME" Payload
rm -rf "$TEMP_PAYLOAD"

echo ""
echo "===================================================="
echo "  Сборка iOS IPA завершена успешно!"
echo "  Готовый файл: $IPA_PATH"
echo "  Размер: $(du -sh "$IPA_PATH" | cut -f1)"
echo "===================================================="
