# Project Context Map: med_scheme

## 1. Executive Summary & Tech Stack
- **Language & Framework**: Dart 3.x, Flutter 3.x
- **Primary Purpose**: МедРисунок - УЗИ Редактор (MedRisunok - Ultrasound Editor). A drawing and annotation application for medical ultrasound (US/УЗИ) images.
- **Key Dependencies**:
  - `flutter_bloc`: State management using the BLoC pattern.
  - `get_it`: Service locator for dependency injection.
  - `shared_storage`: Android Storage Access Framework (SAF) integration for saving/reading files.
  - `path_provider`: Access to local filesystem directories (temp, documents, etc.).
  - `archive`: Library for encoding/decoding archive formats (zip, tar, etc.).

## 2. Directory Layout & Architecture
- **Architecture Pattern**: Clean Architecture (feature-based separation)
- **Directory Structure**:
  - `/lib`: Source code root
    - `/core`: Shared core modules
      - `/di`: Dependency injection config ([injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart))
      - `/utils`: Common utility classes
    - `/features`: Feature modules
      - `/editor`: Main drawing editor feature
        - `/data`: Repositories implementation and models
          - `/models`: JSON serialization models ([draw_action_model.dart](file:///d:/projects/med_scheme/lib/features/editor/data/models/draw_action_model.dart))
          - `/repositories`: Concrete repositories ([project_repository_impl.dart](file:///d:/projects/med_scheme/lib/features/editor/data/repositories/project_repository_impl.dart))
        - `/domain`: Business logic entities, use cases, and repository interfaces
          - `/entities`: Domain models/actions ([draw_action.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/draw_action.dart), [project_data.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/entities/project_data.dart))
          - `/repositories`: Repository interfaces ([project_repository.dart](file:///d:/projects/med_scheme/lib/features/editor/domain/repositories/project_repository.dart))
        - `/presentation`: UI components and BLoC controllers
          - `/bloc`: Application state BLoCs ([draw_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart), [project_bloc.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart))
          - `/widgets/canvas`: Interactive drawing canvas ([canvas_widget.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart), [canvas_painter.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart))
  - `/test`: Unit and widget test suite ([widget_test.dart](file:///d:/projects/med_scheme/test/widget_test.dart))
  - `/android`, `/ios`, `/web`, `/windows`: Platform-specific configurations and runner code

## 3. Core Entry Points & Initialization Flow
- **Entry Point File**: [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
- **Initialization Steps**:
  1. Initialize Flutter framework bindings via `WidgetsFlutterBinding.ensureInitialized()`.
  2. Setup dependency injection containers via `initInjection()` defined in [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart).
  3. Run `MyApp`, which registers global BLoC providers ([DrawBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/draw_bloc.dart) and [ProjectBloc](file:///d:/projects/med_scheme/lib/features/editor/presentation/bloc/project_bloc.dart)) and presents `EditorScreen` (defined in [main.dart](file:///d:/projects/med_scheme/lib/main.dart)) as the home screen.

## 4. Key Workflows & Commands
- **Run Application**: `flutter run`
- **Build Production**: `flutter build <platform>` (e.g., `flutter build apk` or `flutter build windows`)
- **Run Tests**: `flutter test`
- **Lint/Format**: `flutter analyze` and `dart format .`

## 5. Development Conventions & Guidelines
- **State Management**: **BLoC (Business Logic Component)**. All presentation logic must be structured in BLoCs (Events, States, Blocs) rather than inline widget state.
- **Styling & Design System**: Material 3 dark theme with custom classic blue seed color (`0xFF0F4C81`).
- **Dependency Injection**: Use `getIt<Type>()` to resolve dependencies. Declare registrations in [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart).
- **Interactive Painting**:
  - [CanvasWidget](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_widget.dart) handles gestures, stylus pressure sensitivity, palm rejection, and panning/zooming.
  - [CanvasPainter](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/canvas/canvas_painter.dart) is a custom painter that renders background images and dynamic path effects like `infiltrate` (barbed wire) and `adhesions` (spiderweb) using path metrics.

## 6. Active Development Context
- **Current Goals/Tasks**: Completed onboarding, analyzing project architecture, and validating active layout.
- **Recent Changes**: Refined project context map with comprehensive file links.
- **Known Challenges/Notes**: Platform-specific storage permissions (Scoped Storage / SAF on Android) require caution when reading/writing projects using the `shared_storage` package.
