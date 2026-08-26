# Project Context Map: МедРисунок — УЗИ Редактор (med_scheme)

## 1. Executive Summary & Tech Stack
- **Version**: 1.0.17 (Defined in [pubspec.yaml](file:///d:/projects/med_scheme/pubspec.yaml))
- **Language & Framework**: Dart 3.x (SDK `^3.11.3`), Flutter 3.x (Material 3)
- **Primary Purpose**: «МедРисунок» (MedDraw) is a specialized cross-platform medical drawing and annotation application designed for ultrasound (УЗИ) physicians, gynecologists, and surgeons. It functions as a medical scheme annotator, allowing clinicians to mark up standardized anatomical templates (pelvis, sagittal, uterus, abdominal wall) or imported scans with clinical pathology markers (endometriosis, myomas, IUDs, adhesions, follicles, bowel infiltrates, polyps, Indian Headdress/ГУИ). It features full off-screen rendering for export, interactive PDF report generation with printable medical forms, multi-page canvases, and 100% offline client-side execution.
- **Key Dependencies**:
  - `flutter_bloc` (`^8.1.3`): State management architecture for canvas actions, project operations, and multi-page history.
  - `get_it` (`^7.6.0`): Service locator for dependency injection.
  - `shared_storage` (`^0.8.1`): Android Storage Access Framework (SAF) for persistent directory access.
  - `path_provider` (`^2.1.3`): Resolves local filesystem paths (iOS document sandbox, temporary directories).
  - `archive` (`^3.6.1`): ZIP package serialization/deserialization for proprietary `.meddraw` project files.
  - `file_picker` (`^8.0.0`): Native document/file selection dialog for background schemes and projects.
  - `shared_preferences` (`^2.2.3`): Persistent app preferences (e.g., last-used directory URI).
  - `pdf` (`^3.10.8`) & `printing` (`^5.13.2`): Rendering and printing multi-page PDF medical reports with Cyrillic fonts and clinical legends.
  - `package_info_plus` (`^9.0.1`): Accessing and displaying application versions at runtime.

---

## 2. Directory Layout & Architecture
- **Architecture Pattern**: Clean Architecture with Feature-First organization centered around the `editor` feature.
- **Directory Structure**:
  - `lib/`:
    - [main.dart](file:///d:/projects/med_scheme/lib/main.dart): Entry point initializing DI, BlocProviders, and Theme.
    - `core/`:
      - `di/`: [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) — Service locator configuration via `GetIt`.
      - `utils/`:
        - [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart): Conditional imports abstraction for loading images across IO and Web platforms.
        - [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart): Web-specific browser file download helper.
    - `features/editor/`:
      - `domain/`:
        - `entities/`:
          - [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart): Business entities representing drawing tools (`StrokeAction`, `ShapeAction`, `StampAction`, `TextAction`, `ToolType`).
          - [page_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/page_data.dart): Multi-canvas page entity containing drawing history, background paths, active schemes, and undo/redo stacks.
          - [project_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_data.dart): Root entity encapsulating project metadata (Patient ID, date, pages list).
          - [project_file_source.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_file_source.dart): Metadata abstraction for open project files.
          - [report_config.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/report_config.dart): Configuration model for PDF reports (patient data, clinic, doctor, layout options, legend).
        - `repositories/`:
          - [project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart): Interface defining save, load, PDF generation, and export contracts.
      - `data/`:
        - `models/`:
          - [draw_action_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/draw_action_model.dart): JSON serialization & deserialization for vector shapes and clinical markers.
          - [page_data_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/page_data_model.dart): Serialization helper for multi-canvas page data.
        - `repositories/`:
          - [project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart): IO repository implementation (Android SAF, iOS Sandbox, Windows, zip export, PDF rendering).
          - [project_repository_web.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_web.dart): In-memory Web repository handling ZIP bundling, PDF generation, and browser downloads.
          - [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart): Conditional import provider selecting IO or Web repository.
        - `services/`:
          - [offscreen_canvas_renderer.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/offscreen_canvas_renderer.dart): Headless canvas rasterization pipeline rendering full-resolution PNG images and branded medical cards.
          - [pdf_report_generator_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/pdf_report_generator_impl.dart): Vector and bitmap PDF document generator with Cyrillic font loading, custom layouts (single/multi-page), clinical header, notes, and legend tables.
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
            - [print_export_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/print_export_dialog.dart): Fullscreen modal for PDF report customization, live interactive preview, and direct system printing/export.
          - `toolbox/`:
            - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart): Draggable glassmorphic floating toolbar for clinical tool selection, stroke width, and settings.

---

## 3. Core Entry Points & Initialization Flow
- **Entry Point File**: [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
- **Initialization Steps**:
  1. `WidgetsFlutterBinding.ensureInitialized()` initializes Flutter engine bindings.
  2. `await initInjection()` registers service dependencies via [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) (platform-specific `ProjectRepository`).
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
- **Run Automated Test Suites**: `flutter test` (19/19 tests passing in [test/](file:///d:/projects/med_scheme/test))
- **Static Lint Analysis**: `flutter analyze` (0 issues found)
- **Format Code**: `dart format .`
- **Vercel Deploy Pipeline**: `.\deploy.ps1` (PowerShell script compiling web release and deploying to Vercel).

---

## 5. Development Conventions & Guidelines
- **State Isolation**: Business state flows strictly through BLoC classes ([DrawBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart), [ProjectBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart)). Ephemeral canvas touch gestures are managed inside [CanvasWidget](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart) and committed to `DrawBloc` on gesture completion.
- **Cross-Platform Facades**: Platform-specific logic (e.g. mobile vs. web file downloads, image loading) is encapsulated via conditional imports:
  - Repositories: [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart)
  - Image Loading: [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart)
  - Web Helpers: [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart)
- **Serialization Safety**: Proprietary `.meddraw` project format is a ZIP archive storing `project.json` (metadata, pages, and vectorized draw actions) and associated background image assets, maintaining full backwards compatibility with legacy single-page files.
- **Stylus & Touch Handling**:
  - Palm Rejection: When stylus/pen input is active, touch input is filtered out.
  - Interactive Rotation: Selected shapes/stamps support rotation handles and hit-testing in rotated coordinate space.
- **Predefined Schemes**: Default asset templates reside under `assets/schemes/` (`standart_endo.jpg`, `sagittally.jpg`, `uretus.png`, `abdominal_wall_cross_section.png`).
- **Offscreen & PDF Generation**: `OffscreenCanvasRenderer` uses pure `dart:ui` `PictureRecorder` to render high-DPI canvases independent of device viewport dimensions.

---

## 6. Active Development Context
- **Current Version**: 1.0.17
- **Current Status**: All 7 planned stages completed + canvas geometry standardized to 907x1280 base cell dimensions. Full test coverage (27 unit/widget tests passing) and zero static analysis warnings.
- **Recent Git Commits & Updates**:
  - Standardized single canvas base size to 907x1280 for all backgrounds and empty sheets with BoxFit.contain scaling
  - `d452939` — рендер фонов в полном разрешении (v1.0.17)
  - `b3e1faa` — исправление масштабов, координат и отображения объектов при скрытии фона и повторном показе (v1.0.16)
  - `e89ca16` — штамп инфильтрата, новые фоны, функционал печати, оптимизация кода и интерфейса(аппбар) (v1.0.16)
  - `6ad8ab5` — fix: include web assets in build for Vercel deploy (v1.0.15)
  - `65026c1` — исправление ассетов для фона v3 (v1.0.14)
- **Active / Key Files**:
  - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart)
  - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart)
  - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart)
  - [print_export_dialog.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/dialogs/print_export_dialog.dart)
  - [pdf_report_generator_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/pdf_report_generator_impl.dart)
  - [offscreen_canvas_renderer.dart](file:///d:/projects/med_scheme/lib/features/editor/data/services/offscreen_canvas_renderer.dart)
