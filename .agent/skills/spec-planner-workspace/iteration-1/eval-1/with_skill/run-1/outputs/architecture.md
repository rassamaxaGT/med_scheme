# Архитектура: Сервис синхронизации SQLite с удаленным API

## Общее описание
Сервис обеспечивает синхронизацию локальной базы данных SQLite с удаленным REST API. Синхронизация выполняется при старте приложения, а также в фоновом режиме каждые 15 минут (с использованием WorkManager на Android и BackgroundTasks на iOS / пакета `workmanager` во Flutter). В случае конфликтов версий применяется стратегия "сервер всегда выигрывает" (Server Wins).

## Компоненты и структура файлов
- [db_helper.dart](file:///d:/projects/med_scheme/lib/database/db_helper.dart): Низкоуровневый помощник для работы с SQLite (создание таблиц, миграции).
- [sync_service.dart](file:///d:/projects/med_scheme/lib/services/sync_service.dart): Основной класс бизнес-логики синхронизации.
- [sync_api_client.dart](file:///d:/projects/med_scheme/lib/services/sync_api_client.dart): HTTP-клиент для взаимодействия с сервером.
- [background_sync_manager.dart](file:///d:/projects/med_scheme/lib/services/background_sync_manager.dart): Планировщик периодических фоновых задач.

## Схемы данных / Модели
### SyncMetadata (в SQLite)
- `table_name`: String (Primary Key)
- `last_sync_timestamp`: Integer (Unix Epoch)
- `version`: Integer

## API и внешние интеграции
- `GET /sync/changes?since={timestamp}`: Получение изменений с сервера с момента последней синхронизации.
- `POST /sync/push`: Отправка локальных изменений на сервер.
