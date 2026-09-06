# Project Context Map: МедРисунок — УЗИ Редактор (med_scheme)

## 1. Executive Summary & Tech Stack
- **Version**: 1.0.26 (Defined in [pubspec.yaml](file:///d:/projects/med_scheme/pubspec.yaml))
- **Language & Framework**: Dart 3.x (SDK `^3.11.3`), Flutter 3.x (Material 3)
- **Primary Purpose**: «МедРисунок» (MedDraw) is a specialized cross-platform medical drawing and annotation application designed for ultrasound (УЗИ) physicians, gynecologists, and surgeons. It functions as a medical scheme annotator, allowing clinicians to mark up standardized anatomical templates (pelvis, sagittal, uterus, abdominal wall, laparoscopic view) or imported scans with clinical pathology markers (endometriosis, myomas, IUDs, adhesions, follicles, bowel infiltrates, polyps, Indian Headdress/ГУИ). It features full off-screen rendering for export, interactive PDF report generation with printable medical forms, Cyrillic font support, user custom stamps organized into custom groups with hardware-accelerated image scaling and in-memory caching, clinic/doctor presets, multi-page canvases, and 100% offline client-side execution.
- **Key Dependencies**:
  - `flutter_bloc` (`^8.1.3`): State management architecture for canvas actions, project operations, and multi-page history.
  - `get_it` (`^7.6.0`): Service locator for dependency injection.
  - `shared_storage` (`^0.8.1`): Android Storage Access Framework (SAF) for persistent directory access.
  - `path_provider` (`^2.1.3`): Resolves local filesystem paths (iOS document sandbox, temporary directories).
  - `archive` (`^3.6.1`): ZIP package serialization/deserialization for proprietary `.meddraw` project files.
  - `file_picker` (`^8.0.0`): Native document/file selection dialog for background schemes and projects.
  - `shared_preferences` (`^2.2.3`): Persistent app preferences (e.g., last-used directory URI, custom stamp groups and slots, report presets).
  - `pdf` (`^3.10.8`) & `printing` (`^5.13.2`): Rendering and printing multi-page PDF medical reports with Cyrillic fonts and clinical legends.
  - `package_info_plus` (`^9.0.1`): Accessing and displaying application versions at runtime.
  - `image` (`^4.3.0`): High-performance C++ / Dart image processing and hardware scaling for custom stamp imports.

---

## 2. Directory Layout & Architecture
- **Architecture Pattern**: Clean Architecture with Feature-First organization centered around the `editor` feature.
- **Directory Structure**:
  - `lib/`:
    - [main.dart](file:///d:/projects/med_scheme/lib/main.dart): Application entry point initializing DI, BlocProviders, and Theme.
    - `core/`:
      - `di/`: [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) — Service locator configuration via `GetIt`.
      - `utils/`:
        - [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart): Universal cross-platform image loading abstraction (native files, bundle assets, Web Blob/Network, base64 Data URIs).
        - [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart): Web-specific browser file download helper.
    - `features/editor/`:
      - `domain/`:
        - `entities/`:
          - [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart): Business entities representing drawing tools (`StrokeAction`, `ShapeAction`, `StampAction`, `TextAction`, `ToolType`).
          - [page_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/page_data.dart): Multi-canvas page entity containing drawing history, background paths, active schemes, and undo/redo stacks.
          - [project_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_data.dart): Root entity encapsulating project metadata (Patient ID, date, pages list).
          - [project_file_source.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_file_source.dart): Metadata abstraction for open project files.
          - [report_config.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/report_config.dart): Configuration model for PDF reports (patient data, clinic, doctor, layout options, legend, probe presets).
        - `repositories/`:
          - [project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart): Interface defining save, load, PDF generation, and export contracts.
      - `data/`:
        - `models/`:
          - [draw_action_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/draw_action_model.dart): JSON serialization & deserialization for vector shapes, stamps, rotation angles, target schemes, and clinical markers.
          - [page_data_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/page_data_model.dart): Serialization helper for multi-canvas page data.
        - `repositories/`:
          - [project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart): IO repository implementation (Android SAF, iOS Sandbox, Windows, zip export, PDF rendering).
          - [project_repository_web.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_web.dart): In-memory Web repository handling ZIP bundling, PDF generation, and browser downloads.
          - [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart): Conditional import provider selecting IO or Web repository.
        - `services/`:
          - [custom_stamps_service.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/custom_stamps_service.dart): Stamp & group management service featuring multi-group support, fast C++ / engine image downscaling, in-memory caching to eliminate UI freezes, and Web QuotaExceededError protection.
          - [report_presets_service.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/report_presets_service.dart): Preferences service managing presets for clinics, doctors, US devices, and probes.
          - [offscreen_canvas_renderer.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/offscreen_canvas_renderer.dart): Headless canvas rasterization pipeline rendering full-resolution PNG images and branded medical cards.
          - [pdf_report_generator_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/pdf_report_generator_impl.dart): Vector and bitmap PDF document generator with Cyrillic font loading (`Roboto-Regular`, `Roboto-Bold`, `Roboto-Italic`), custom layouts (single/multi-page), clinical header, notes, and legend tables.
      - `presentation/`:
        - `bloc/`:
          - [draw_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart): Manages active drawing state (current tool, clinical default colors, rotation, custom stamps, undo/redo, multi-page switching).
          - [project_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart): Manages filesystem workflows (creating, opening, autosaving, exporting files, and SAF folder management).
        - `screens/`:
          - [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart): Main editor view containing top AppBar, tab navigation, preset scheme selector chips, and dialogs.
        - `widgets/`:
          - `canvas/`:
            - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart): `CustomPainter` rendering background schemes in full resolution, clinical overlays, selection boxes, rotation handles, and all `DrawAction` elements.
            - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart): Interactive canvas handling touch/pen stylus gestures, palm rejection, pressure sensitivity, pinch-to-zoom/pan, and object rotation.
          - `dialogs/`:
            - [add_custom_stamp_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/add_custom_stamp_dialog.dart): Dialog for importing, naming, previewing, and assigning custom stamps to existing or new user groups.
            - [print_export_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/print_export_dialog.dart): Fullscreen modal for PDF report customization, live interactive preview, and direct system printing/export.
            - [preset_management_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/preset_management_dialog.dart): Dialog for managing clinic and doctor presets.
          - `toolbox/`:
            - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart): Draggable glassmorphic floating toolbar for clinical tool selection, stroke width, custom stamp groups, and settings.

---

## 3. Core Entry Points & Initialization Flow
- **Entry Point File**: [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
- **Initialization Steps**:
  1. `WidgetsFlutterBinding.ensureInitialized()` initializes Flutter engine bindings.
  2. `await initInjection()` registers service dependencies via [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) (platform-specific `ProjectRepository`, `CustomStampsService`, `ReportPresetsService`, etc.).
  3. `runApp(const MyApp())` mounts the UI tree configured with dark Material 3 theme (`#0F4C81` Classic Blue seed).
  4. Global BLoCs (`DrawBloc` and `ProjectBloc`) are provided at the root level via `MultiBlocProvider`.
  5. `ProjectBloc` dispatches `InitializeProjectEvent()` to restore previous directory URI if configured.
  6. [EditorScreen](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart) displays the multi-tab canvas with default schemes ("Таз", "Матка").

---

## 4. Key Workflows & Commands
- **Run Application Locally**: `flutter run`
- **Run Web App Locally**: `flutter run -d chrome`
- **Build Production Web Target**: `flutter build web`
- **Build Production Android Target**: `flutter build apk`
- **Run Automated Test Suites**: `flutter test` (59/59 tests passing in [test/](file:///d:/projects/med_scheme/test))
- **Static Lint Analysis**: `flutter analyze` (0 issues)
- **Format Code**: `dart format .`
- **Vercel Deploy Pipeline**: `.\deploy.ps1` (PowerShell script compiling web release and deploying to Vercel).

---

## 5. Development Conventions & Guidelines
- **State Isolation**: Business state flows strictly through BLoC classes ([DrawBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart), [ProjectBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart)). Ephemeral canvas touch gestures are managed inside [CanvasWidget](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart) and committed to `DrawBloc` on gesture completion.
- **Cross-Platform Facades**: Platform-specific logic (e.g., mobile vs. web file downloads, image loading) is encapsulated via conditional imports:
  - Repositories: [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart)
  - Image Loading: [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart)
  - Web Helpers: [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart)
- **Serialization Safety**: Proprietary `.meddraw` project format is a ZIP archive storing `project.json` (metadata, pages, and vectorized draw actions) and associated background image assets, maintaining full backwards compatibility with legacy single-page files.
- **Stylus & Touch Handling**:
  - Palm Rejection: When stylus/pen input is active, touch input is filtered out.
  - Interactive Rotation: Selected shapes/stamps support rotation handles and hit-testing in rotated coordinate space.
- **Custom Stamp System v4**:
  - Grouped stamps (user-created folders/groups) are placed dynamically in the floating toolbar before the stamp addition button.
  - In-memory caching and engine-level image downscaling ensure 0-lag addition and deletion of custom stamps without freezing the UI thread.
- **Offscreen & PDF Generation**: `OffscreenCanvasRenderer` uses pure `dart:ui` `PictureRecorder` to render high-DPI canvases independent of device viewport dimensions. `PdfReportGenerator` embeds Roboto Cyrillic fonts for clean Russian text rendering on all platforms.

---

## 6. Active Development Context
- **Current Version**: 1.0.26
- **Current Status**: Core editor, multi-canvas workflow, clinical markers, custom stamp groups v4 with in-memory caching and engine scaling, clinic/doctor presets, and Cyrillic PDF reports are completely implemented and verified. 59/59 unit and widget tests pass, 0 lint issues.
- **Recent Git Commits & Updates**:
  - `185919d` — Группировки кастомных штампов v4 (v1.0.26)
  - `45489f7` — Устранение 5-7 сек зависания при добавлении/удалении штампов: аппаратное C++ масштабирование и in-memory кэширование
  - `f4a00ad` — Порядок отображения: добавляемые группы штампов располагаются перед инструментом добавления штампов
  - `5d18cf6` — Fix QuotaExceededError and lag in custom stamp groups on web (v1.0.25)
  - `a2b1cfe` — Группировки кастомных штампов v3 (v1.0.25)
- **Key Working Files**:
  - [custom_stamps_service.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/custom_stamps_service.dart)
  - [add_custom_stamp_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/add_custom_stamp_dialog.dart)
  - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart)
  - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart)
  - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart)
  - [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart)
  - [pdf_report_generator_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/pdf_report_generator_impl.dart)
  - [print_export_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/print_export_dialog.dart)
