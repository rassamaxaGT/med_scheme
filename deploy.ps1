param (
    [Parameter(Mandatory=$true)]
    [string]$Version,

    [Parameter(Mandatory=$true)]
    [string]$Message
)

$ErrorActionPreference = "Stop"

Write-Host "=== Шаг 1: Обновление версии в pubspec.yaml ===" -ForegroundColor Cyan
$PubspecPath = "pubspec.yaml"
if (-not (Test-Path $PubspecPath)) {
    Write-Error "Файл pubspec.yaml не найден!"
}

$Content = Get-Content $PubspecPath -Raw
# Регулярное выражение для поиска строки version: x.x.x+x
$Pattern = "(?m)^version:\s+(\S+)"
if ($Content -match $Pattern) {
    Write-Host "Текущая версия: $($Matches[1])" -ForegroundColor Gray
    $Content = $Content -replace $Pattern, "version: $Version"
    Set-Content $PubspecPath $Content
    Write-Host "Версия обновлена на: $Version" -ForegroundColor Green
} else {
    Write-Error "Не удалось найти строку 'version:' в pubspec.yaml"
}

Write-Host "`n=== Шаг 2: Очистка и получение зависимостей ===" -ForegroundColor Cyan
flutter clean
flutter pub get

Write-Host "`n=== Шаг 3: Сборка Web ===" -ForegroundColor Cyan
flutter build web --release

Write-Host "`n=== Шаг 4: Сборка Android ===" -ForegroundColor Cyan
flutter build apk --release

Write-Host "`n=== Шаг 5: Отправка изменений в Git ===" -ForegroundColor Cyan
git add -A
git commit -m "$Message (v$Version)"
git push

Write-Host "`n=== Сборка и деплой успешно завершены! ===" -ForegroundColor Green
