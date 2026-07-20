# Project Onboarding & Architecture Summary

Hello! I have analyzed the codebase and here is a detailed overview of the frameworks, main entry points, and architectural patterns in the project.

## 1. Framework & Language
- **Framework**: **Flutter** (Mobile/Web/Desktop cross-platform SDK)
- **Language**: **Dart** (version `^3.11.3` as configured in `pubspec.yaml`)
- **Key Project Purpose**: The application is **МедРисунок - УЗИ Редактор** (MedRisunok - Ultrasound Editor), which is a drawing/annotation editor for medical ultrasound images.

## 2. Core Entry Points
- **Primary Entry Point**: [lib/main.dart](file:///d:/projects/med_scheme/lib/main.dart)
  - The `main()` function initializes Flutter widget bindings, runs `initInjection()` for dependency injection, and runs `MyApp`.
  - Configures the global `ThemeData` (classic blue theme with Material 3).
  - Sets up global state management providers (`DrawBloc` and `ProjectBloc`) and navigates to the `EditorScreen` home page.

## 3. Architecture & Directory Structure
The project follows a structured **Clean Architecture** pattern, organized feature-by-feature inside the `lib/` folder:

- **`/lib/core`**: Common code shared across multiple features.
  - `/di`: Dependency injection configuration using the `get_it` package (configured in [injection.dart](file:///d:/projects/med_scheme/lib/core/di/injection.dart)).
  - `/utils`: Common utilities and helper classes.
- **`/lib/features`**: Contains the functional features of the app.
  - `/editor`: The main drawing editor module, divided into the standard Clean Architecture layers:
    - **`domain`**: Entities, use cases, and repository interfaces defining business rules (framework-independent).
    - **`data`**: Concrete implementations of repositories, data sources, and models.
    - **`presentation`**: UI components, widgets, and state management using the **BLoC (Business Logic Component)** pattern.
