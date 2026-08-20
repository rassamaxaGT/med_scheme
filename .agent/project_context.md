# Project Context Map: МедРисунок — УЗИ Редактор (med_scheme)

## 1. Executive Summary & Tech Stack
- **Version**: 1.0.15 (Defined in [pubspec.yaml](file:///d:/projects/med_scheme/pubspec.yaml))
- **Language & Framework**: Dart 3.x (SDK `^3.11.3`), Flutter 3.x
- **Primary Purpose**: «МедРисунок» (MedDraw) is a specialized cross-platform drawing and annotation application designed for ultrasound (УЗИ) physicians, gynecologists, and surgeons. It functions as a medical scheme annotator, allowing clinicians to manually mark up standardized anatomical templates (pelvis, sagittal, uterus, abdominal wall) or imported scans with clinical pathology markers (endometriosis, myomas, IUDs, adhesions, follicles, bowel infiltrates, polyps, Indian Headdress). It operates 100% locally on the client device without sending patient data over external networks.
- **Key Dependencies**:
  - `flutter_bloc` (`^8.1.3`): State management architecture for canvas actions and project operations.
  - `get_it` (`^7.6.0`): Service locator for dependency injection.
  - `shared_storage` (`^0.8.1`): Android Storage Access Framework (SAF) for persistent directory access.
  - `path_provider` (`^2.1.3`): Resolves local filesystem paths (iOS document sandbox, temp dirs).
  - `archive` (`^3.6.1`): ZIP package serialization/deserialization for proprietary `.meddraw` project files.
  - `file_picker` (`^8.0.0`): Native document/file selection dialog for background schemes and projects.
  - `shared_preferences` (`^2.2.3`): Persistent app preferences (e.g., last-used directory URI).
  - `pdf` (`^3.10.8`): Rendering and exporting completed multi-page schemes to PDF reports.
  - `package_info_plus` (`^9.0.1`): Accessing and formatting package versions at runtime.

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
        - [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart): Business entities representing drawing tools (`StrokeAction`, `ShapeAction`, `StampAction`, `TextAction`, `ToolType`).
        - [page_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/page_data.dart): Multi-canvas page entity containing drawing history, background paths, active schemes, and undo/redo stacks.
        - [project_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_data.dart): Root entity encapsulating project metadata (Patient ID, date, pages list).
        - [project_file_source.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_file_source.dart): Metadata abstraction for open project files.
        - [project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart): Interface defining save, load, and export contracts.
      - `data/`:
        - [draw_action_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/draw_action_model.dart): JSON serialization & deserialization for vector shapes and clinical markers.
        - [page_data_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/page_data_model.dart): Serialization helper for multi-canvas page data.
        - [project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart): IO repository implementation (Android SAF, iOS Sandbox, Windows, zip export).
        - [project_repository_web.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_web.dart): In-memory Web repository handling ZIP bundling and browser downloads.
      - `presentation/`:
        - `bloc/`:
          - [draw_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart): Manages active drawing state (current tool, clinical default colors, rotation, custom stamps, undo/redo, multi-page switching).
          - [project_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart): Manages filesystem workflows (creating, opening, autosaving, exporting files, and SAF folder management).
        - `screens/`:
          - [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart): Main editor view containing top AppBar, tab navigation, preset scheme selector chips, and dialogs.
        - `widgets/canvas/`:
          - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart): `CustomPainter` rendering background schemes, clinical overlays, selection boxes, and all `DrawAction` elements.
          - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart): Interactive canvas handling touch/pen stylus gestures, palm rejection, pressure sensitivity, pinch-to-zoom/pan, and object rotation.
        - `widgets/toolbox/`:
          - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart): Draggable glassmorphic floating toolbar for clinical tool selection, stroke width, and settings.

---

## 3. Core Entry Points & Initialization Flow
- **Entry Point File**: [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
- **Initialization Steps**:
  1. `WidgetsFlutterBinding.ensureInitialized()` initializes Flutter engine bindings.
  2. `await initInjection()` registers service dependencies via [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) (platform-specific `ProjectRepository`).
  3. `runApp(const MyApp())` mounts the UI tree configured with dark Material 3 theme.
  4. Global BLoCs (`DrawBloc` and `ProjectBloc`) are provided at the root level.
  5. `ProjectBloc` dispatches `InitializeProjectEvent()` to restore previous directory URI if configured.
  6. [EditorScreen](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart) displays the multi-tab canvas with default schemes ("Таз", "Матка").

---

## 4. Key Workflows & Commands
- **Run local development app**: `flutter run`
- **Run web app locally**: `flutter run -d chrome`
- **Build production web target**: `flutter build web`
- **Build production Android target**: `flutter build apk`
- **Run automated test suites**: `flutter test` (14/14 tests passing in [test/](file:///d:/projects/med_scheme/test))
- **Static analysis**: `flutter analyze`
- **Format code**: `dart format .`
- **Vercel Deploy Pipeline**: `.\deploy.ps1` (powershell script compiling web release and deploying to Vercel).

---

## 5. Development Conventions & Guidelines
- **State Isolation**: Business state flows strictly through BLoC classes ([DrawBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart), [ProjectBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart)). Ephemeral canvas touch gestures are managed inside [CanvasWidget](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart) and committed to `DrawBloc` on gesture completion.
- **Crossplatform Facades**: Platform-specific logic (e.g. mobile vs. web file downloads, image loading) is encapsulated via conditional imports:
  - Repositories: [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart)
  - Image Loading: [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart)
  - Web Helpers: [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart)
- **Serialization Safety**: Proprietary `.meddraw` project format is a ZIP archive storing `project.json` (metadata, pages, and vectorized draw actions) and associated background image assets.
- **Stylus & Touch Handling**:
  - Palm Rejection: When stylus/pen input is active, touch input is filtered out.
  - Interactive Rotation: Selected shapes/stamps support rotation handles and hit-testing in rotated coordinate space.
- **Predefined Schemes**: Default asset templates reside under `assets/schemes/` (`standart_endo.jpg`, `sagittally.jpg`, `uretus.png`, `abdominal_wall_cross_section.png`).

---

## 6. Active Development Context
- **Current Version**: 1.0.15
- **Current Status**: Codebase is fully operational with 14 passing automated unit & widget tests (`flutter test`).
- **Uncommitted Changes / Active Files**:
  - [draw_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart)
  - [draw_state.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_state.dart)
  - [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart)
  - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart)
  - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart)
  - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart)
  - [pubspec.yaml](file:///d:/projects/med_scheme/pubspec.yaml)
  - [draw_bloc_test.dart](file:///d:/projects/med_scheme/test/draw_bloc_test.dart)
- **Recent Git Commits**:
  - `6ad8ab5` — fix: include web assets in build for Vercel deploy (v1.0.15)
  - `65026c1` — исправление ассетов для фона v3 (v1.0.14)
  - `bd8ece2` — fix: web image loading - rootBundle direct, retry on null, asset manifest explicit
