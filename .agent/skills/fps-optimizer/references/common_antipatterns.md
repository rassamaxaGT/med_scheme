# Common FPS Anti-Patterns Catalogue

A reference of real-world patterns that reliably drop frames, with approximate costs and fixes.

---

## AP-01: saveLayer in a Loop

**Severity:** CRITICAL  
**Typical cost:** 2–8ms per saveLayer per frame on mid-range mobile  

```dart
// BAD: saveLayer called for every item in history
for (final action in history) {
  final bounds = getActionBounds(action);
  canvas.saveLayer(bounds, Paint()); // GPU allocates texture PER item!
  _drawActionContent(canvas, action);
  canvas.restore();
}

// FIX: Single saveLayer wrapping the whole group
canvas.saveLayer(wholeCanvasBounds, Paint());
for (final action in history) {
  _drawActionContent(canvas, action);
}
canvas.restore();
// Or better: pre-render static content to ui.Image and drawImageRect
```

---

## AP-02: shouldRepaint() → true Always

**Severity:** CRITICAL  
**Typical cost:** Full repaint every frame regardless of state change  

```dart
// BAD
@override
bool shouldRepaint(covariant CustomPainter old) => true;

// FIX
@override
bool shouldRepaint(covariant MyPainter old) {
  return old.history != history ||
      old.activeAction != activeAction ||
      old.selectedId != selectedId;
}
```

If any field is a mutable list, use `listEquals` or maintain a version counter.

---

## AP-03: TextPainter.layout() in paint()

**Severity:** HIGH  
**Typical cost:** 0.5–3ms per text element per frame (scales with text complexity)  

```dart
// BAD
void paint(Canvas canvas, Size size) {
  for (final label in labels) {
    final tp = TextPainter(text: TextSpan(text: label.text))
      ..layout(); // O(n) per character + font shaping
    tp.paint(canvas, label.offset);
  }
}

// FIX: cache TextPainter instances; re-layout only on text/style change
```

---

## AP-04: new Paint() in a Hot Path

**Severity:** HIGH  
**Typical cost:** GC pressure; sporadic 2–5ms GC pauses causing frame drops  

```dart
// BAD: creates Paint object on every call
void _drawLine(Canvas canvas, Offset a, Offset b, Color color) {
  canvas.drawLine(a, b, Paint()..color = color..strokeWidth = 2);
}

// FIX: cache and mutate
final _linePaint = Paint()..strokeWidth = 2;
void _drawLine(Canvas canvas, Offset a, Offset b, Color color) {
  _linePaint.color = color;
  canvas.drawLine(a, b, _linePaint);
}
```

---

## AP-05: setState() on Root During Gesture

**Severity:** CRITICAL during active drawing  
**Typical cost:** Full widget tree rebuild at 60+ Hz while drawing  

```dart
// BAD: setState rebuilds everything including expensive parts of the tree
void _onPointerMove(PointerMoveEvent event) {
  setState(() {
    _activeStrokePoints.add(event.localPosition);
  });
}

// FIX option 1: Use Listenable-driven CustomPainter (no setState)
// FIX option 2: Scope setState to the smallest State that owns the active stroke
// FIX option 3: Use a ValueNotifier<List<Offset>> + ValueListenableBuilder scoped to only the canvas
```

---

## AP-06: Image Decoded Every Frame

**Severity:** HIGH  
**Typical cost:** 10–100ms spike on first decode; repeated if not cached  

```dart
// BAD: loading/decoding image inside paint or on every build
class MyPainter extends CustomPainter {
  final String imagePath;
  
  @override
  void paint(Canvas canvas, Size size) {
    // Can't actually load async here, but devs sometimes store decoded
    // images in maps and re-decode when the map reference changes
    final image = _imageCache[imagePath]; // re-decoded on every new painter instance
  }
}

// FIX: Decode once, keep reference alive in State, pass decoded ui.Image to painter
// Use ImageCache or maintain a Map<String, ui.Image> in a long-lived object
```

---

## AP-07: Opacity Widget on Animated Subtree

**Severity:** MEDIUM–HIGH  
**Typical cost:** Promotes subtree to compositing layer AND triggers saveLayer equivalent  

```dart
// BAD: Opacity with animated opacity
Opacity(
  opacity: _fadeAnimation.value,
  child: ExpensiveWidget(),
)

// FIX: FadeTransition uses engine-level compositing, no saveLayer
FadeTransition(
  opacity: _fadeAnimation,
  child: ExpensiveWidget(),
)
```

---

## AP-08: ClipRRect with AntiAlias on Animation

**Severity:** MEDIUM  
**Typical cost:** Forces compositing layer allocation  

```dart
// BAD for animations
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  // default clipBehavior is Clip.antiAlias — forces layer
  child: AnimatedContent(),
)

// FIX when perfect AA isn't critical
ClipRRect(
  borderRadius: BorderRadius.circular(12),
  clipBehavior: Clip.hardEdge, // no compositing layer needed
  child: AnimatedContent(),
)
```

---

## AP-09: Missing RepaintBoundary Around Animated Widget

**Severity:** MEDIUM  
**Typical cost:** Parent widget (and siblings) repaint on every animation tick  

```dart
// BAD: spinner animation causes parent to repaint every frame
Column(
  children: [
    ExpensiveStaticWidget(), // repaints every frame because of sibling!
    CircularProgressIndicator(),
  ],
)

// FIX
Column(
  children: [
    ExpensiveStaticWidget(),
    RepaintBoundary(
      child: CircularProgressIndicator(), // isolated repaint
    ),
  ],
)
```

---

## AP-10: Large MaskFilter.blur per Frame

**Severity:** HIGH on mobile GPU  
**Typical cost:** 3–15ms GPU time depending on surface area and blur radius  

```dart
// COSTLY: recomputed each frame
final shadowPaint = Paint()
  ..maskFilter = MaskFilter.blur(BlurStyle.normal, 8.0);
canvas.drawRRect(rRect.shift(Offset(0, 4)), shadowPaint);

// FIX options:
// 1. Pre-render shadow to ui.Image once, drawImageRect each frame
// 2. Simulate shadow with multiple semi-transparent non-blurred fills (cheaper)
// 3. Reduce blur radius — cost is O(r²)
// 4. Only draw shadow on non-animated elements; skip on active/animated ones
```

---

## AP-11: O(n) Search in paint()

**Severity:** HIGH when n > 100  

```dart
// BAD: linear scan per draw call
void _paintDynamicOverlay(Canvas canvas) {
  final selected = history.firstWhere((a) => a.id == selectedId); // O(n)
  _drawAction(canvas, selected);
}

// FIX: maintain a Map<String, DrawAction> indexed by id
// Update it when history changes, not on every paint
Map<String, DrawAction> _actionById = {};
void _onHistoryChanged() {
  _actionById = { for (final a in history) a.id: a };
}
// In paint():
final selected = _actionById[selectedId]; // O(1)
```

---

## AP-12: Redundant Canvas Transform Stack

**Severity:** LOW–MEDIUM  
**Typical cost:** Minor CPU overhead; mostly readability/maintenance issue  

```dart
// AVOID: nested save/translate/scale/restore inside loops when a single transform works
for (final item in items) {
  canvas.save();
  canvas.translate(item.x, item.y);
  canvas.scale(item.scale);
  canvas.save(); // unnecessary inner save
  canvas.translate(0, 0); // no-op
  canvas.drawCircle(Offset.zero, item.radius, paint);
  canvas.restore();
  canvas.restore();
}

// BETTER: minimal transform stack; combine transforms where possible
for (final item in items) {
  canvas.save();
  canvas.translate(item.x, item.y);
  canvas.scale(item.scale);
  canvas.drawCircle(Offset.zero, item.radius, paint);
  canvas.restore();
}
```

---

## Benchmark Summary Table

| Anti-Pattern | Typical Cost | Severity |
|---|---|---|
| saveLayer in loop (n=50 items) | 100–400ms/frame | CRITICAL |
| shouldRepaint always true | ~full repaint cost | CRITICAL |
| setState on root during gesture | full tree rebuild @ 60Hz | CRITICAL |
| TextPainter.layout in paint() | 0.5–3ms per item | HIGH |
| new Paint() in hot path | GC pauses 2–5ms | HIGH |
| Image decoded every frame | 10–100ms spike | HIGH |
| Large MaskFilter.blur | 3–15ms GPU | HIGH |
| O(n) search in paint() | scales with n | HIGH |
| Opacity on animated subtree | layer allocation | MEDIUM |
| ClipRRect antiAlias on animation | layer allocation | MEDIUM |
| Missing RepaintBoundary | cascaded repaints | MEDIUM |

*Costs are approximate for mid-range Android (e.g., Snapdragon 720G class). iOS is typically 2-3x faster.*
