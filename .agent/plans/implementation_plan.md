# Implementation Plan: Печать и вёрстка медицинских отчетов (PDF & PNG)

## Phases of Development

### Phase 1: Подготовка инфраструктуры и зависимостей (Foundation & Setup)
1. Добавить `printing: ^5.13.2` в [pubspec.yaml](file:///d:/projects/med_scheme/pubspec.yaml).
2. Загрузить локальные ttf-шрифты кириллицы (Roboto/OpenSans) в `assets/fonts/` для офлайн-печати в изолированных медицинских учреждениях и зарегистрировать их в `pubspec.yaml`.
3. Создать доменные сущности [report_config.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/report_config.dart).
4. Обновить интерфейс репозитория [project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart).

### Phase 2: Сервисы генерации отчетов и рендеринга (Core Logic & Services)
1. Разработать [offscreen_canvas_renderer.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/offscreen_canvas_renderer.dart):
   - Отрисовка `DrawAction` и фонов схем на чисто белом фоне.
   - Поддержка масштабирования DPI (150/300 DPI) без артефактов и мыла.
   - Поддержка многостраничного пакетного рендера всех страниц проекта.
2. Разработать [pdf_report_generator_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/pdf_report_generator_impl.dart):
   - Загрузка кириллических шрифтов с fallback.
   - Вёрстка медицинского бланка:
     - Шапка с метаданными (клиника, пациент, дата исследования, врач).
     - Блок со схемами: автоподбор сетки (1 схема на страницу, 2 схемы рядом, или постраничный многостраничный буклет).
     - Динамическая клиническая легенда: автоанализ типов инструментов, использованных врачом на холсте, и отображение аккуратных векторных/растровых миниатюр маркеров.
     - Блок врачебных заметок / заключения с динамическим переносом строк.
     - Нижний колонтитул с нумерацией и штампом времени.
3. Реализовать методы экспорта и печати в [project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart) и [project_repository_web.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_web.dart).
4. Зарегистрировать сервисы в DI ([injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart)).

### Phase 3: Управление состоянием и пользовательский интерфейс (UI & Presentation)
1. Обновить [project_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart):
   - Добавить события `PrintReportEvent`, `ExportReportPdfEvent`, `ExportReportPngEvent`, `ShareReportEvent`.
   - Обработка состояний загрузки/успеха/ошибки при печати и экспорте.
2. Разработать [print_export_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/print_export_dialog.dart):
   - Интерактивный диалог / полноэкранный модал с живым предпросмотром `PdfPreview`.
   - Вкладки настроек:
     - Параметры документа (Ориентация Альбомная/Книжная, Формат А4, Выбор страниц).
     - Блок данных (ФИО врача, Клиника, Заключение).
     - Параметры легенды (Показывать легенду, только активные маркеры).
     - Настройки PNG (Разрешение 1x/2x/3x, Тип бланка: чистый срез / полный медицинский бланк).
   - Кнопки быстрых действий: «Печать на принтер», «Сохранить PDF», «Экспорт PNG», «Поделиться».
3. Интегрировать кнопку вызова в верхний тулбар [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart) (`🖨️ Печать и экспорт`).

### Phase 4: Тестирование и валидация (Verification & Edge Cases)
1. Написать unit-тесты для `PdfReportGenerator` и `OffscreenCanvasRenderer`.
2. Написать widget-тесты для `PrintExportDialog` и обновленного меню.
3. Проверить печать на реальных кейсах:
   - Отчет с 1 схемой ("Таз").
   - Многостраничный отчет (2-4 схемы: "Таз", "Матка", кастомные УЗИ-снимки).
   - Корректность кириллических символов во всех полях (ФИО, Заключение, Легенда).
   - Четкость при печати на физическом принтере / PDF-виртуальном принтере.
   - Экспорт качественного PNG без темных темных полос/рамок.

---

## Risks & Considerations

1. **Отсутствие интернета на медицинских рабочих станциях**:
   - Стандартный `PdfGoogleFonts` в `printing` пытается скачать шрифт по HTTP при первом запуске. Если ПК врача отключен от интернета (закрытый контур ЛВС больницы), это приведет к ошибке.
   - *Решение*: Включить локальные TTF-шрифты (`assets/fonts/Roboto-Regular.ttf`, `Roboto-Bold.ttf`) в ассеты приложения и использовать их в качестве гарантированного локального fallback.
2. **Память и производительность при оффскрин-рендеринге 300 DPI**:
   - При 300 DPI изображение A4 занимает ~2480x3508 пикселей (~35 МБ в памяти на кадр).
   - *Решение*: Использовать `compute` (изоляты) для кодирования PNG и освобождать `ui.Image` и `PictureRecorder` сразу после извлечения байтов.
3. **Платформенные различия Web / Mobile / Desktop**:
   - На Web прямая печать идет через `window.print()` / blob iframe, а сохранение через browser download.
   - На Android сохранение требует SAF или Documents provider.
   - *Решение*: Четкое разделение через `ProjectRepository` и фасады `printing`.
