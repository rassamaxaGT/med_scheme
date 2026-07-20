# Technical UI/UX Specification: Tablet Layout Redesign

This specification implements the tablet-optimized, card-grouped sidebar layout (Option A).

## 1. Design Tokens
- **Sidebar Width**: `120.0 dp`
- **Hitbox Sizing**: Minimum button size `56x56 dp` with a margin of `8 dp` (`IconButton` default with padding).
- **Colors**:
  - Background: `Theme.of(context).colorScheme.surface` (Dark Gray)
  - Card/Toolbar Background: `Theme.of(context).colorScheme.surfaceContainer`
  - Active Selection: `Theme.of(context).colorScheme.primaryContainer` with `Theme.of(context).colorScheme.onPrimaryContainer` icon color.

## 2. Proposed File Changes

### [MODIFY] [main.dart](file:///d:/projects/med_scheme/lib/main.dart)
Modify `EditorScreen` structure:
- Replace current layout with a `Row` containing the custom sidebar on the left and the `CanvasWidget` on the right (wrapped in an `Expanded` widget).

### [NEW] [editor_sidebar.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/editor_sidebar.dart)
Create a new widget representing the sidebar toolbar:
- Organize buttons into three distinct `Card` sections:
  1. *Operations* (Undo, Redo, Export)
  2. *Tools* (Pen, Eraser, Shamps)
  3. *Path Types* (Infiltrate, Adhesions, etc.)

---

## 3. Developer Task List
- [ ] Create [editor_sidebar.dart](file:///d:/projects/med_scheme/lib/features/editor/presentation/widgets/editor_sidebar.dart) with Material 3 styling.
- [ ] Implement responsive behavior: Hide sidebar and display a floating action button menu if screen width is less than 600 dp (mobile layout).
- [ ] Integrate BLoC state: Bind sidebar tool buttons to emit `SelectToolEvent` to `DrawBloc`.
- [ ] Modify `EditorScreen` in [main.dart](file:///d:/projects/med_scheme/lib/main.dart) to display the new sidebar row structure.

## 4. Verification Plan
- Verify on tablet emulators that the canvas size adjusts dynamically when sidebar toggles.
- Verify touch targets are at least `48x48 dp` using Flutter DevTools.
