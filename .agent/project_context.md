# Project Context Map: МедРисунок — УЗИ Редактор (med_scheme)

_Last updated: 2026-08-01_

---

## 1. Executive Summary & Tech Stack

- **Language & Framework**: Dart 3.x (SDK ^3.11.3), Flutter 3.x
- **Primary Purpose**: «МедРисунок» is a specialized cross-platform drawing and annotation app for ultrasound (УЗИ) physicians. Works like a "medical coloring book" — doctors place standardized markers for pathologies (endometriosis, myomas, IUDs, adhesions) on anatomical schemes or imported scan images. Fully local; no patient data transmitted.
- **Target Platforms**: Android / iOS (stylus-first) and Web (browser, deployed on Vercel).
- **Version**: `1.0.0+3`
- **Key Dependencies**:
  - `flutter_bloc ^8.1.3`: BLoC state management.
  - `get_it ^7.6.0`: Service locator / dependency injection.
  - `shared_storage ^0.8.1`: Android SAF (Scoped Storage) for persistable directory URIs.
  - `path_provider ^2.1.3`: Platform filesystem paths (iOS sandbox, Documents, etc.).
  - `archive ^3.6.1`: ZIP encoding/decoding for `.meddraw` project files.
  - `file_picker ^8.0.0`: Cross-platform file selection dialog.
  - `shared_preferences ^2.2.3`: Lightweight persistent prefs (last directory URI, etc.).
  - `pdf ^3.10.8`: PDF export of completed annotation sheets.

---

## 2. Directory Layout & Architecture

- **Architecture Pattern**: Clean Architecture with Feature-First organization (single feature: `editor`).
- **Directory Structure**:

```
lib/
├── main.dart                        # App entry point + EditorScreen (~47 KB, refactor candidate)
├── core/
│   ├── di/injection.dart            # GetIt DI registration
│   └── utils/
│       ├── image_loader.dart        # Conditional import facade
│       ├── image_loader_io.dart     # dart:io implementation
│       ├── image_loader_web.dart    # Blob URL / dart:html implementation
│       ├── image_loader_stub.dart   # Stub for unsupported platforms
│       ├── web_helper.dart          # Conditional import facade (browser downloads)
│       ├── web_helper_web.dart      # dart:html / JS interop
│       └── web_helper_stub.dart     # No-op stub for mobile
└── features/editor/
    ├── domain/
    │   ├── entities/
    │   │   ├── draw_action.dart     # ToolType enum + DrawAction class hierarchy
    │   │   ├── project_data.dart    # ProjectData entity (metadata + actions list)
    │   │   └── project_file_source.dart
    │   └── repositories/
    │       └── project_repository.dart  # Abstract repository interface
    ├── data/
    │   ├── models/draw_action_model.dart     # JSON serialization for DrawAction subtypes
    │   └── repositories/
    │       ├── project_repository_provider.dart  # Conditional import router
    │       ├── project_repository_impl.dart      # IO impl (Android SAF + iOS sandbox)
    │       ├── project_repository_web.dart       # Web impl (ZIP in-memory + browser download)
    │       └── project_repository_stub.dart      # Stub
    └── presentation/
        ├── bloc/
        │   ├── draw_bloc.dart       # Drawing history, undo/redo, active tool
        │   ├── draw_event.dart
        │   ├── draw_state.dart
        │   └── project_bloc.dart    # File I/O state: save/load/export
        ├── screens/                 # (empty; EditorScreen is still in main.dart)
        └── widgets/
            ├── canvas/
            │   ├── canvas_painter.dart  # CustomPainter: renders all DrawActions (~22 KB)
            │   └── canvas_widget.dart   # Pointer/gesture handler + pan/zoom (~33 KB)
            └── toolbox/
                └── floating_toolbox.dart  # Draggable floating tool selection panel (~30 KB)
```

- **Assets**: `assets/images/myoma_legend.png`, `assets/images/endo_legend.png`

---

## 3. Core Entry Points & Initialization Flow

- **Entry Point**: lib/main.dart
- **Steps**:
  1. `WidgetsFlutterBinding.ensureInitialized()`
  2. `await initInjection()` — registers `ProjectRepository` (conditional import) and singletons via GetIt.
  3. `runApp(MyApp())` — mounts `MultiBlocProvider` with `DrawBloc` + `ProjectBloc`, routes to `EditorScreen`.
  4. `ProjectBloc` dispatches `InitializeProjectEvent()` on creation to restore last saved directory.
  5. `EditorScreen` — single screen, uses a `Stack`: `CanvasWidget` (full-screen), `FloatingToolbox` (positioned overlay), top AppBar actions.

---

## 4. Core Domain Model

File: lib/features/editor/domain/entities/draw_action.dart

| Class | Description |
|---|---|
| `DrawAction` (abstract) | Base: `id`, `color`, `strokeWidth`, transform: `scaleX/Y`, `offsetX/Y` |
| `StrokeAction` | Freehand paths. `points: List<Offset>`, `brushType` ('pencil' / 'adhesions' / 'fibrosis') |
| `ShapeAction` | Geometric shapes (endometrioma oval, myoma circle). `figoType` for FIGO classification |
| `StampAction` | Point stamps: IUD (ВМС), foci, custom PNG |
| `TextAction` | Arrow-with-label annotation. `isDashed` for distance lines |

**ToolType enum** (12 values): `pencil`, `eraser`, `infiltrate`, `adhesions`, `fibrosis`, `endometrioma`, `myoma`, `iud`, `foci`, `arrow`, `customStamp`, `move`.

---

## 5. Rendering Architecture

- **CanvasWidget** (canvas_widget.dart): `Listener` + `GestureDetector`. Stylus pressure (`PointerEvent.pressure`), palm rejection (ignores fingers when stylus active), pinch-to-zoom/pan. Dispatches draw events to `DrawBloc`.
- **CanvasPainter** (canvas_painter.dart): `CustomPainter`. Renders `backgroundImage`, then iterates `DrawBloc` state actions. Uses `ui.PathMetrics` for `infiltrate` barbed-wire effect and `adhesions` spiderweb effect. Text/arrows are drawn in screen-space (not canvas-space) so label size stays constant at any zoom level.

---

## 6. Crossplatform Strategy (Conditional Imports)

| Abstraction File | Mobile/Desktop impl | Web impl |
|---|---|---|
| image_loader.dart | `image_loader_io.dart` | `image_loader_web.dart` |
| web_helper.dart | `web_helper_stub.dart` (no-ops) | `web_helper_web.dart` (JS interop) |
| project_repository_provider.dart | `project_repository_impl.dart` | `project_repository_web.dart` |

---

## 7. File Format: `.meddraw`

A ZIP archive (via `archive` package) containing:
- `background.png` — Imported ultrasound image or blank canvas.
- `project.json` — Serialized `DrawAction` list (via `DrawActionModel`) + patient ID + metadata.

Serialization runs in a Dart isolate via `compute()` to avoid UI jank.

---

## 8. Key Workflows & Commands

- **Run (dev)**: `flutter run`
- **Run on Chrome**: `flutter run -d chrome`
- **Build Web (Vercel)**: `flutter build web`
- **Build APK**: `flutter build apk`
- **Run Tests**: `flutter test`
- **Analyze**: `flutter analyze`
- **Format**: `dart format .`
- **Deploy**: `.\deploy.ps1` (PowerShell script — builds web + deploys to Vercel)

---

## 9. Development Conventions & Guidelines

- **State Management**: BLoC exclusively. No `setState` for business logic.
- **DI**: Register in lib/core/di/injection.dart, resolve with `getIt<Type>()`.
- **Design Theme**: Material 3 dark, seed color `Color(0xFF0F4C81)` (medical blue).
- **Toolbox**: floating_toolbox.dart — draggable, glassmorphism-styled, minimum 48dp touch targets.
- **Linting**: `flutter_lints` via analysis_options.yaml.
- **Canvas local state**: Current stroke points are held locally in `CanvasWidget`; committed to `DrawBloc` only on `onPanEnd` / pointer-up.

---

## 10. Active Development Context

- **Status**: All 5 implementation phases are **complete**. Working tree is clean. Branch: `main`.
- **Recent git commits**:
  1. `e5a24da` — Fix Android build settings and test deployment script (v1.0.0+3)
  2. `3f66b16` — Add deployment script and update project (v1.0.0+2)
  3. `65df3bf` — docs: added plain-text PROJECT_DOCUMENTATION.txt
  4. `8d3bb5b` — docs: added PROJECT_DOCUMENTATION.md with architecture and spec
  5. `c86a075` — build: Web release for Vercel deployment
- **Active Plans** (in `.agent/plans/`):
  - task.md — All phases complete.
  - ui_ux_specification.md — Floating toolbox design spec.
  - implementation_plan.md — Full implementation plan.
  - architecture.md — Architecture reference.
- **Known Challenges / Refactor Candidates**:
  - `main.dart` is ~47 KB — `EditorScreen` and all dialogs should be extracted to `presentation/screens/`.
  - `canvas_widget.dart` (~33 KB) and `canvas_painter.dart` (~22 KB) are large; splitting is a future improvement.
  - `presentation/screens/` directory exists but is currently empty.
  - Android SAF (`shared_storage`) requires careful persistable URI handling.
  - Web: no `dart:io` — all file I/O uses browser Blob/download APIs via `web_helper_web.dart`.
