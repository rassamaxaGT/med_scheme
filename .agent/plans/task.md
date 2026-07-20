# Список задач (Task List): Медицинский графический редактор

- [x] **Фаза 1: Базовая настройка проекта и архитектурная структура**
  - [x] Добавить зависимости `flutter_bloc`, `shared_storage`, `archive`, `path_provider`, `get_it` в `pubspec.yaml`
  - [x] Создать структуру папок по слоям Clean Architecture (`core`, `features/editor/domain`, `features/editor/data`, `features/editor/presentation`)
  - [x] Настроить ключи `UIFileSharingEnabled` и `LSSupportsOpeningDocumentsInPlace` в `ios/Runner/Info.plist`
  - [x] Создать базовый доменный класс `DrawAction` и его наследников в `lib/features/editor/domain/entities/draw_action.dart`
  - [x] Реализовать JSON-сериализацию для `DrawActionModel` в `lib/features/editor/data/models/draw_action_model.dart`

- [x] **Фаза 2: Движок рисования и базовый холст**
  - [x] Реализовать `DrawBloc`, события добавления штриха, Undo и Redo в `lib/features/editor/presentation/bloc/draw_bloc.dart`
  - [x] Написать `CanvasPainter` (наследник `CustomPainter`) в `lib/features/editor/presentation/widgets/canvas/canvas_painter.dart`
  - [x] Создать `CanvasWidget` с `GestureDetector` для сбора локальных точек штриха и вызова BLoC эвентов в `lib/features/editor/presentation/widgets/canvas/canvas_widget.dart`
  - [x] Добавить поддержку чувствительности к силе нажатия стилуса и Palm Rejection в `CanvasWidget`

- [x] **Фаза 3: Сложные маркеры и специализированные кисти**
  - [x] Реализовать кисть «колючая проволока» с помощью `PathMetrics` в `CanvasPainter`
  - [x] Реализовать кисть «паутина» с помощью `PathMetrics` в `CanvasPainter`
  - [x] Реализовать рисование овалов (эндометриома, миома)
  - [x] Реализовать инструмент "Стрелка с текстом" с диалоговым окном ввода при завершении жеста

- [x] **Фаза 4: Работа с файлами и сохранение в .meddraw**
  - [x] Настроить работу с Android Scoped Storage через пакет `shared_storage` (сохранение постоянного URI папки)
  - [x] Реализовать архивацию/разархивацию ZIP-файла `.meddraw` с фоном и JSON через `compute()` (изоляты)
  - [x] Добавить логику сохранения проектов в локальные документы на iOS
  - [x] Реализовать экспорт холста в плоский JPEG/PNG для сохранения в галерею устройства

- [x] **Фаза 5: Пользовательские штампы, интерфейс и полировка**
  - [x] Разработать импорт пользовательских PNG штампов из галереи в память приложения
  - [x] Сверстать планшетный интерфейс редактора (боковая панель управления, холст)
  - [x] Оптимизировать производительность CustomPainter на больших холстах (кеширование путей)
  - [x] Протестировать Undo/Redo и экспорт файлов проекта на реальных устройствах (планшетах)
