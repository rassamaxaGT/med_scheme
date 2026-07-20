# UI/UX Design Concept: Tablet-Optimized Material 3 Editor

## 1. Interface Audit & Usability Analysis
Currently, the main editor screen ([main.dart](file:///d:/projects/med_scheme/lib/main.dart)) renders drawing buttons, color selectors, and canvas options in a clustered, unstructured layout.
- **Pain Points**:
  - Buttons are scattered, reducing the active canvas drawing area.
  - Controls lack consistent sizing, making stylus interactions error-prone.
  - No clear visual grouping between tool selection (eraser, brushes) and project operations (undo, redo, save).
- **Ultrasound Room Constraints**: Ultrasound specialists work in low-light environments. Interfaces must have clear high-contrast borders and large clickable zones so they can operate the app using a stylus without excessive concentration.

---

## 2. Proposing the Concept
We propose a **2-Column Layout** optimized for tablets:
- **Left/Right Collapsible Tool Drawer**: A vertical command panel containing tool groups:
  - **Draw Actions**: Undo, Redo, Eraser, Trash.
  - **Path Tools**: Endometrioma (Chocolate Oval), Infiltration (Barbed Wire), Adhesions (Spiderweb), Myoma.
  - **Drawing Attributes**: Color selector, line thickness.
- **Main Editor Canvas**: Expands to take up all remaining screen space.

### Modern Material 3 Design
- Use `NavigationRail` or a custom sidebar panel with card-based groupings.
- Active states should use clear filled tonal indicators.
- Minimum hitbox size: `48x48 dp` for stylus accuracy.

---

## 3. Design Options for the User
1. **Option A (Persistent Sidebar)**: The toolbar is docked to the left of the screen, occupying 15% width. Best for larger tablets (10"+) where canvas size is sufficient.
2. **Option B (Floating Expandable Toolbelt)**: A floating drawer that can be dragged to any corner of the screen. Maximize drawing space; recommended for smaller tablets or phone screens.

*Please let me know which option you prefer, and if you have any feedback on the tool grouping!*
