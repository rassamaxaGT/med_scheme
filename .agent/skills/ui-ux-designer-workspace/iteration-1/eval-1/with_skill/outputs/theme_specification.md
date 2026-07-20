# Technical Specification: Dark Medical Theme Implementation

This document outlines the theme changes for a unified, low-fatigue medical dark design system.

## 1. Theme Configuration Code

We will create a custom theme utility that returns a custom `ThemeData` package.

### Color Scheme Definitions:
```dart
const Color mBackground = Color(0xFF121824);
const Color mSurface = Color(0xFF1E293B);
const Color mPrimary = Color(0xFF0EA5E9);
const Color mOnPrimary = Color(0xFFFFFFFF);
const Color mSecondary = Color(0xFF64748B);
```

---

## 2. Proposed File Changes

### [NEW] [app_theme.dart](file:///d:/projects/med_scheme/lib/core/utils/app_theme.dart)
Create a helper class to define the dark theme configuration:
- Define `ThemeData darkMedicalTheme`.
- Set Material 3 text theme using `Inter` font weights.
- Configure component themes for `CardTheme`, `IconButtonThemeData`, and `AppBarTheme`.

### [MODIFY] [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
Import the new `app_theme.dart` and modify `MaterialApp` parameters:
- Change `theme` to `appTheme.darkMedicalTheme`.

---

## 3. Developer Task List
- [ ] Create `lib/core/utils/app_theme.dart` with custom color definitions.
- [ ] Define card elevation, border-radius (defaulting to M3 medium: `12.0 dp`), and input borders.
- [ ] Update `MaterialApp` in [main.dart](file:///d:/projects/med_scheme/lib/main.dart) to apply `darkMedicalTheme`.
- [ ] Verify that all text layouts adapt automatically using appropriate theme-based colors (e.g. `Theme.of(context).colorScheme.onSurface`).

## 4. Verification Plan
- Run the app and visually inspect all screens to ensure no hardcoded white backgrounds or dark text on dark background exist.
- Run `flutter analyze` to check for theme-related lint issues.
