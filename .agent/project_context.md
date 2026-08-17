# Project Context Map: МедРисунок — УЗИ Редактор (med_scheme)

## 1. Executive Summary & Tech Stack
- **Version**: 1.0.14 (Defined in [pubspec.yaml](file:///d:/projects/med_scheme/pubspec.yaml))
- **Language & Framework**: Dart 3.x (SDK `^3.11.3`), Flutter 3.x
- **Primary Purpose**: «МедРисунок» (MedDraw) is a specialized cross-platform drawing and annotation application designed for ultrasound (УЗИ) physicians, gynecologists, and surgeons. It functions as a "medical coloring book", allowing clinicians to manually mark up standardized anatomical templates (pelvis, sagittal, uterus) or imported scans with clinical pathology markers (endometriosis, myomas, IUDs, adhesions, follicles, bowel infiltrates, polyps, Indian Headdress). It operates 100% locally on the client device without sending personal patient data over external networks.
- **Key Dependencies**:
  - [flutter_bloc](https://pub.dev/packages/flutter_bloc) (`^8.1.3`): State management architecture for canvas actions and project operations.
  - [get_it](https://pub.dev/packages/get_it) (`^7.6.0`): Service locator for dependency injection.
  - [shared_storage](https://pub.dev/packages/shared_storage) (`^0.8.1`): Android Storage Access Framework (SAF) for persistent directory access.
  - [path_provider](https://pub.dev/packages/path_provider) (`^2.1.3`): Resolves local filesystem paths (iOS document sandbox, temp dirs).
  - [archive](https://pub.dev/packages/archive) (`^3.6.1`): ZIP package serialization/deserialization for proprietary `.meddraw` project files.
  - [file_picker](https://pub.dev/packages/file_picker) (`^8.0.0`): Native document/file selection dialog for background schemes and projects.
  - [shared_preferences](https://pub.dev/packages/shared_preferences) (`^2.2.3`): Persistent app preferences (e.g., last-used directory URI).
  - [pdf](https://pub.dev/packages/pdf) (`^3.10.8`): Rendering and exporting completed multi-page schemes to PDF reports.
  - [package_info_plus](https://pub.dev/packages/package_info_plus) (`^9.0.1`): Accessing and formatting package versions at runtime.

---

## 2. Directory Layout & Architecture
- **Architecture Pattern**: Clean Architecture with Feature-First organization. The application is centered around the core `editor` feature.
- **Directory Structure**:
  - `/lib`:
    - [main.dart](file:///d:/projects/med_scheme/lib/main.dart): Entry point initializing DI, BlocProviders, and Theme.
    - `/core`:
      - `/di`: [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) — Service locator configuration via `GetIt`.
      - `/utils`:
        - [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart): Conditional imports abstraction for loading images across IO and Web platforms.
        - [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart): Web-specific browser file download helper.
    - `/features/editor`:
      - `/domain`:
        - [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart): Business entities representing drawing tools (`StrokeAction`, `ShapeAction`, `StampAction`, `TextAction`, `ToolType`).
        - [page_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/page_data.dart): Multi-canvas page entity containing drawing history, background paths, active schemes, and undo/redo stacks.
        - [project_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_data.dart): Root entity encapsulating project metadata (Patient ID, date, pages list).
        - [project_file_source.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_file_source.dart): Metadata abstraction for open project files.
        - [project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart): Interface defining save, load, and export contracts.
      - `/data`:
        - [draw_action_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/draw_action_model.dart): JSON serialization & deserialization for vector shapes and clinical markers.
        - [page_data_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/page_data_model.dart): Serialization helper for multi-canvas page data.
        - [project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart): IO repository implementation (Android SAF, iOS Sandbox, Windows, zip export).
        - [project_repository_web.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_web.dart): In-memory Web repository handling ZIP bundling and browser downloads.
      - `/presentation`:
        - `/bloc`:
          - [draw_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart): Manages active drawing state (current tool, clinical default colors, rotation, custom stamps, undo/redo, multi-page switching).
          - [project_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart): Manages filesystem workflows (creating, opening, autosaving, exporting files, and SAF folder management).
        - `/screens`:
          - [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart): Main editor view containing top AppBar, tab navigation, preset scheme selector chips, and dialogs.
        - `/widgets/canvas`:
          - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart): `CustomPainter` rendering background schemes, clinical overlays, selection boxes, and all `DrawAction` elements.
          - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart): Interactive canvas handling touch/pen stylus gestures, palm rejection, pressure sensitivity, pinch-to-zoom/pan, and object rotation.
        - `/widgets/toolbox`:
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

## 4. Core Domain Model (DrawAction)
File: [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart)

| Entity Class | Represented Tools / Types | Primary Fields |
|---|---|---|
| [StrokeAction] | `pencil`, `adhesions` (spiderweb), `fibrosis` (crosshatch) | `points: List<Offset>`, `isEraser: bool`, `brushType: String`, `isDashed: bool`, `targetSchemePath: String?` |
| [ShapeAction] | `endometrioma` (oval), `myoma` (circle), `infiltrate`, `bowelInfiltrate`, `follicle`, `adenomyosis` | `startPoint: Offset`, `endPoint: Offset`, `shapeType: String`, `rotation: double`, `targetSchemePath: String?` |
| [StampAction] | `iud` (IUD), `foci` (lesions), `polyp`, `gui` (Indian Headdress), `customStamp` | `position: Offset`, `stampType: String`, `customStampPath: String?`, `rotation: double`, `targetSchemePath: String?` |
| [TextAction] | distance line (`distance`), pointer line (`arrow`) | `startPoint: Offset`, `endPoint: Offset`, `text: String`, `isDashed: bool`, `targetSchemePath: String?` |

---

## 5. Key Workflows & Commands
- **Run local development app**: `flutter run`
- **Run web app locally**: `flutter run -d chrome`
- **Build production web target**: `flutter build web`
- **Build production Android target**: `flutter build apk`
- **Run automated test suites**: `flutter test` (Tests located at [test/](file:///d:/projects/med_scheme/test))
- **Static analysis**: `flutter analyze`
- **Format code**: `dart format .`
- **Vercel Deploy Pipeline**: `.\deploy.ps1` (powershell script compiling web release and deploying to Vercel).

---

## 6. Development Conventions & Guidelines
- **State Isolation**: Business state flows strictly through BLoC classes ([DrawBloc], [ProjectBloc]). Ephemeral canvas touch gestures are managed inside [CanvasWidget] and committed to `DrawBloc` on gesture completion.
- **Crossplatform Facades**: Platform-specific logic (e.g. mobile vs. web file downloads, image loading) is encapsulated via conditional imports:
  - Repositories: [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart)
  - Image Loading: [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart)
  - Web Helpers: [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart)
- **Serialization Safety**: Proprietary `.meddraw` project format is a ZIP archive storing `project.json` (metadata, pages, and vectorized draw actions) and associated background image assets.
- **Stylus & Touch Handling**:
  - Palm Rejection: When stylus/pen input is active, touch input is filtered out.
  - Interactive Rotation: Selected shapes/stamps support rotation handles and hit-testing in rotated coordinate space.
- **Predefined Schemes**: Default asset templates reside under `assets/schemes/` (`standart_endo.jpg`, `sagittally.jpg`, `uterus.jpg`).

---

## 7. Active Development Context
- **Current Version**: 1.0.14
- **Current Status**: All 7 planned development phases (114/114 tasks) completed and verified in [TASK_TRACKER.md](file:///d:/projects/med_scheme/TASK_TRACKER.md).
- **Recent Commits**:
  - `65026c1` — исправление ассетов для фона v3 (v1.0.14)
  - `bd8ece2` — fix: web image loading - rootBundle direct, retry on null, asset manifest explicit
  - `46d7ca2` — исправление ассетов для фона v2 (v1.0.13)
  - `fb8cf13` — исправление ассетов для фона (v1.0.12)
  - `311686d` — добавление новый ассетов для фона (v1.0.11)
- **Verification Status**: All 14 test cases pass cleanly via `flutter test`.
