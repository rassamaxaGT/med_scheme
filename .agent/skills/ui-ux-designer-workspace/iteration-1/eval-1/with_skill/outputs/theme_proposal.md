# UI/UX Concept: Low-Fatigue Medical Dark Theme

## 1. Interface Audit & Environment Constraints
Currently, the application uses a basic Material 3 dark theme with a classic blue seed color (`0xFF0F4C81`) configured in [main.dart](file:///d:/projects/med_scheme/lib/main.dart).
- **Clinical Environment Context**: Doctors use ultrasound machines in darkened exam rooms. Standard bright elements or high-saturation colors cause eye strain and distract from the ultrasound screen.
- **Friction**: Standard Flutter dark theme defaults can feel either too black (high screen glare) or too low-contrast for markers/annotations to stand out.

---

## 2. Design System Proposal
We propose a **Charcoal & Slate Dark Theme** with high-contrast, specialized semantic accents:

### Design Tokens
- **Background (Low-Glare)**: Slate Gray (`0xFF121824`) - reduces eye fatigue better than pitch black.
- **Surface (Containers/Cards)**: Dark Graphite (`0xFF1E293B`) - provides subtle elevation shadows.
- **Primary Accent**: Clean Cyan / Blue-Teal (`0xFF0EA5E9`) - highly visible annotation accent.
- **Path Semantics**:
  - *Endometrioma*: Chocolate Brown (`0xFFB45309`)
  - *Infiltration (Barbed Wire)*: Crimson Red (`0xFFDC2626`)
  - *Adhesions (Spiderweb)*: Amber Gold (`0xFFD97706`)

---

## 3. Collaborative Theme Questions
1. **Contrast Ratio**: Do you prefer the background to be standard OLED black (`0xFF000000`) for high-contrast contrast under a stylus, or the proposed low-fatigue slate gray (`0xFF121824`)?
2. **Typography**: We suggest using `Outfit` or `Inter` as the primary font family for clinical reading clarity. Would you like us to bundle Google Fonts?
