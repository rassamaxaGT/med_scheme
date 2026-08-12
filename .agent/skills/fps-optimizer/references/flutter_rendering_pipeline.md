# Flutter Rendering Pipeline — Deep Reference

## The Six Phases of a Flutter Frame

Every Flutter frame goes through six phases. FPS problems live in one (or more) of them.

```
User Input / Timer
       ↓
1. BUILD      — Dart: widget.build() → Element tree diffing
       ↓
2. LAYOUT     — Dart: RenderObject.performLayout() → size + position
       ↓
3. PAINT      — Dart: CustomPainter.paint() → build display list (SkCanvas calls)
       ↓
4. COMPOSITE  — Flutter Engine: merge layers into scene
       ↓
5. RASTERIZE  — Skia/Impeller on GPU thread: convert display list to pixels
       ↓
6. PRESENT    — GPU: flip buffer to screen
```

**Budget: 16.67ms** for 60 FPS, **8.33ms** for 120 FPS.

The Dart side (phases 1-4) runs on the UI isolate. Phases 5-6 run on a separate GPU/raster thread.
Both threads have their own 16ms budget — both must stay green.

---

## Phase 1: BUILD

### What triggers a rebuild?
- `setState()` — rebuilds the widget subtree from the State
- `markNeedsBuild()` — called by InheritedWidget, Provider, BLoC, etc.
- `ChangeNotifier.notifyListeners()` propagating to `AnimatedBuilder`, `ListenableBuilder`

### What makes BUILD expensive?
- Large subtrees rebuilding when only one leaf changed
- Expensive computation inside `build()` — sorting, filtering, JSON parsing
- Creating heavy objects on every build (lots of `TextPainter`, `BoxDecoration`, etc.)

### Fixes
- `const` constructors — the widget is never rebuilt unless parents force it
- `RepaintBoundary` — creates an independent repaint boundary; doesn't stop rebuilds but stops *repaints* from propagating
- Precise `setState()` scope — call it on the smallest possible State
- `ValueListenableBuilder` / `AnimatedBuilder` — rebuilds only the builder's subtree
- Selectors: `context.select<T, R>()` in Provider, `BlocSelector` in flutter_bloc

---

## Phase 3: PAINT

This is where `CustomPainter.paint()` executes. The canvas calls here build a **display list** — a serialized list of drawing commands sent to Skia/Impeller. The display list itself is cheap to build; the cost comes when Skia *rasterizes* it (Phase 5).

### What makes PAINT expensive on the CPU?
- `TextPainter.layout()` — text shaping is O(n²) for complex scripts
- `Path` construction with many `lineTo()` calls
- Dart object allocations that trigger GC (GC pauses = dropped frames)
- `saveLayer()` — doesn't rasterize immediately, but marks a layer boundary

### What makes RASTERIZE expensive on the GPU?
- `saveLayer()` — allocates offscreen framebuffer, draws into it, then composites back
- Large blur filters (`MaskFilter.blur`, `ImageFilter.blur`)
- Overdraw — drawing the same pixel many times in one frame
- Large textures uploaded per-frame
- Many draw calls in a single frame (CPU→GPU command overhead)

---

## shouldRepaint() Contract

```dart
@override
bool shouldRepaint(covariant MyPainter oldDelegate) {
  // Return true ONLY if the visual output would differ.
  // Flutter calls this every time the parent rebuilds.
  // Returning true unnecessarily wastes 100% of the paint work.
  return oldDelegate.color != color || oldDelegate.progress != progress;
}
```

**Common mistake:** `return true;` — causes re-paint on every parent rebuild, even when nothing changed visually.

---

## saveLayer() — The GPU Allocator

```dart
canvas.saveLayer(bounds, paint);
// ... draw stuff into the layer ...
canvas.restore(); // composites the layer back
```

Each `saveLayer()` call:
1. Allocates an offscreen texture (same size as `bounds` or larger)
2. Redirects all subsequent draw calls into that texture
3. On `restore()`, composites the texture back with the given `paint` blendMode/opacity/filter

**When saveLayer is necessary:**
- BlendMode.clear (eraser)
- Per-group opacity when you need the group to blend as a unit
- Complex clip paths with anti-aliasing

**When saveLayer is avoidable:**
- Simple opacity: use `Color.withOpacity()` on `Paint.color` instead
- Static content: pre-render to `ui.Image` via `PictureRecorder`, then `drawImageRect` every frame

---

## Layers and Compositing

Flutter automatically promotes widgets to their own compositing layer when they use:
- `Transform` (in some configurations)
- `Opacity`
- `RepaintBoundary`
- `BackdropFilter`

Each compositing layer has a GPU cost. The goal: minimize layer count while ensuring independently-animating parts are on separate layers so they don't cause cascade repaints.

---

## Impeller vs Skia

Since Flutter 3.10+ (stable), **Impeller** is the default renderer on iOS; on Android it's opt-in.

Key differences:
- Impeller pre-compiles all shaders at startup → no shader jank mid-session
- Impeller has stricter GPU memory management
- Some Skia-specific behaviors (blur radii, certain blend modes) may differ slightly

When analyzing code, note whether the user is on Skia or Impeller — `MaskFilter.blur` performance characteristics differ.
