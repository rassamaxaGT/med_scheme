# Project Context Map: МедРисунок — УЗИ Редактор (med_scheme)

## 1. Executive Summary & Tech Stack
- **Language & Framework**: Dart 3.x (SDK `^3.11.3`), Flutter 3.x
- **Primary Purpose**: «МедРисунок» (MedDraw) is a specialized cross-platform drawing and annotation application designed for ultrasound (УЗИ) physicians. It operates like a "medical coloring book", enabling doctors to manually annotate standardized anatomical templates or imported scan images with markers for pathologies (endometriosis, myomas, IUDs, adhesions, follicles, bowel infiltrates, polyps). It works fully locally on the client device.
- **Key Dependencies**:
  - [flutter_bloc](https://pub.dev/packages/flutter_bloc) (`^8.1.3`): State management library.
  - [get_it](https://pub.dev/packages/get_it) (`^7.6.0`): Service locator for dependency injection.
  - [shared_storage](https://pub.dev/packages/shared_storage) (`^0.8.1`): Android Storage Access Framework (SAF) for persistent directory access.
  - [path_provider](https://pub.dev/packages/path_provider) (`^2.1.3`): Handles filesystem paths (iOS document sandbox, etc.).
  - [archive](https://pub.dev/packages/archive) (`^3.6.1`): ZIP package serialization/deserialization for proprietary `.meddraw` files.
  - [file_picker](https://pub.dev/packages/file_picker) (`^8.0.0`): Native document/file selection dialog.
  - [shared_preferences](https://pub.dev/packages/shared_preferences) (`^2.2.3`): Persistent app configurations (e.g. last-saved directory URI).
  - [pdf](https://pub.dev/packages/pdf) (`^3.10.8`): Rendering and exporting completed schemes/canvases to PDF documents.
  - [package_info_plus](https://pub.dev/packages/package_info_plus) (`^9.0.1`): Accessing and formatting package versions at runtime.

---

## 2. Directory Layout & Architecture
- **Architecture Pattern**: Clean Architecture with Feature-First organization. The project focuses on a single feature area: `editor`.
- **Directory Structure**:
  - `/lib`: Main source directory containing:
    - [main.dart](file:///d:/projects/med_scheme/lib/main.dart): Application entry point.
    - `/core`: Shared configurations and utilities:
      - [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart): Service locator configuration.
      - [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart): Conditional import interface for loading image assets.
      - [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart): Conditional import interface for web-specific browser downloads.
    - `/features/editor`: Core module of the application:
      - `/domain`: Business logic boundaries (entities and interfaces):
        - [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart): Defines [DrawAction] objects representing tools (pencil, shape, stamp, text/arrow annotations).
        - [page_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/page_data.dart): Multi-canvas entity containing canvas properties, canvas history (draw actions list), and local undo/redo stacks.
        - [project_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_data.dart): Entity aggregating metadata (e.g. Patient ID) and multiple page targets.
        - [project_file_source.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_file_source.dart): abstraction for active file storage info.
        - [project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart): Interface defining save, load, and export endpoints.
      - `/data`: Implementations of domain models and repositories:
        - [draw_action_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/draw_action_model.dart): JSON mapping/serialization layer for [DrawAction] shapes and markers.
        - [page_data_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/page_data_model.dart): JSON serialization helper for multi-canvas page data.
        - [project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart): IO repository implementation handling directory permissions, iOS file sharing, and zip exports on mobile/desktop.
        - [project_repository_web.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_web.dart): Web repository implementation wrapping zip processes in-memory and dispatching standard browser downloads.
      - `/presentation`: Screen view layouts and state BLoCs:
        - [draw_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart): Managing canvas active state (selected tools, clinical default colors, custom stamps, undo/redo buffers, page switcher logic).
        - [project_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart): Manages filesystem actions (opening, saving, autosaving, exporting files, and directory permission flow).
        - [editor_screen.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart): Desktop/tablet main screen structure containing canvas navigation, toolbar configurations, and action buttons.
        - `/widgets/canvas`: Painting canvas logic:
          - [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart): [CustomPainter] implementation rendering imported background templates and [DrawAction] sequences.
          - [canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart): Interactive drawing surface handling touch/pointer/stylus gestures, palm rejection, rotation overlays, and pinch-to-zoom.
        - `/widgets/toolbox`: Toolbar controls:
          - [floating_toolbox.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/toolbox/floating_toolbox.dart): Draggable glassmorphic floating toolbar.

---

## 3. Core Entry Points & Initialization Flow
- **Entry Point File**: [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
- **Initialization Steps**:
  1. `WidgetsFlutterBinding.ensureInitialized()` is executed to wire up engine services.
  2. `await initInjection()` loads dependency maps in [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart) (registers platform-specific [ProjectRepository] implementations).
  3. `runApp(const MyApp())` mounts the widget tree.
  4. Global providers [DrawBloc] and [ProjectBloc] are created.
  5. `ProjectBloc` immediately dispatches `InitializeProjectEvent()` to read and verify previous storage directories.
  6. The app displays [EditorScreen](file:///d:/projects/med_scheme/lib/features/editor/presentation/screens/editor_screen.dart), checking for any existing draft and displaying default schemes ("Таз", "Матка").

---

## 4. Core Domain Model (DrawAction)
File: [draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart)

| Entity Class | Represented Tools / Types | Primary Fields |
|---|---|---|
| [StrokeAction] | `pencil`, `adhesions` (spiderweb), `fibrosis` (crosshatch) | `points: List<Offset>`, `isEraser: bool`, `brushType: String`, `isDashed: bool` |
| [ShapeAction] | `endometrioma` (oval), `myoma` (circle), `infiltrate`, `bowelInfiltrate`, `follicle`, `adenomyosis` | `startPoint: Offset`, `endPoint: Offset`, `shapeType: String`, `rotation: double` |
| [StampAction] | `iud` (IUD), `foci` (lesions), `polyp`, `gui`, `customStamp` | `position: Offset`, `stampType: String`, `customStampPath: String?`, `rotation: double` |
| [TextAction] | distance lines, arrows with tags | `startPoint: Offset`, `endPoint: Offset`, `text: String`, `isDashed: bool` |

---

## 5. Key Workflows & Commands
- **Run local development server/app**: `flutter run`
- **Run web project locally**: `flutter run -d chrome`
- **Build production web target**: `flutter build web`
- **Build production Android target**: `flutter build apk`
- **Run automated test suites**: `flutter test` (Tests located at [test/](file:///d:/projects/med_scheme/test))
- **Static analysis checklist**: `flutter analyze`
- **Auto-format source files**: `dart format .`
- **Vercel Deploy Pipeline**: `.\deploy.ps1` (powershell script compiling web release and uploading artifacts to Vercel).

---

## 6. Development Conventions & Guidelines
- **State Isolation**: Business state flows strictly through BLoC classes ([DrawBloc], [ProjectBloc]). Avoid local widget state mutations except for transient drawing lines/points inside [CanvasWidget] which are pushed to BLoC on gesture completion.
- **Crossplatform Facades**: Platform-specific logic (e.g. mobile vs. web file downloads) must be written via conditional imports:
  - Repositories: [project_repository_provider.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_provider.dart)
  - Image Loading: [image_loader.dart](file:///d:/projects/med_scheme/lib/core/utils/image_loader.dart)
  - Web Helpers: [web_helper.dart](file:///d:/projects/med_scheme/lib/core/utils/web_helper.dart)
- **Serialization Safety**: Project saves are encoded as standard ZIP archives containing a flat layout: `background.png` (optional blank scheme background) and `project.json` (containing patient metadata and drawing states). Saving processes are scheduled inside standard background compute isolates to maintain 60 FPS UI rendering.
- **Drawing Details**:
  - `infiltrate` uses `ui.PathMetrics` to draw custom wave elements.
  - `adhesions` renders custom spiderwebs based on standard point paths.
  - `fibrosis` draws crosshatched patterns under a 90-degree slant.
- **Layout guidelines**: Floating toolbar uses glassmorphic blur with custom touch limits to prevent layout collisions under different device profiles.

---

## 7. Active Development Context
- **Current Goals/Tasks**: The core feature set (v2.0 Upgrade Plan) has been fully implemented, covering:
  - Multi-canvas tab navigation.
  - Advanced shape drawing and stamp rotation tools.
  - Specific clinical markings (Indian Headress, follicles, adenomyosis, polyps, bowel infiltrates).
  - Web deployments and platform sandboxing.
- **Recent Modifying Commits**:
  - `d5106e5` — Relocated project configuration controls to the global AppBar.
  - `3cc4d81` — Render optimization for canvas spikes.
  - `e9c2414` — Cleaned up build/runtime version labels.
- **Verification Status**: High coverage unit and widget tests pass successfully via `flutter test`.
