# Canvas & CustomPainter — FPS Patterns Reference

## The Static Cache Pattern (Most Impactful for Canvas-Heavy UIs)

The single most effective pattern for canvas with large, rarely-changing history:

```dart
// In State or ViewModel: pre-render static content to a GPU texture
ui.Image? _staticCache;

Future<void> _rebuildStaticCache() async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  // Draw all static content (history items, backgrounds)
  _drawAllStaticContent(canvas, size);
  final picture = recorder.endRecording();
  final newImage = await picture.toImage(width.toInt(), height.toInt());
  // or synchronously: picture.toImageSync(w, h)
  picture.dispose();
  _staticCache?.dispose(); // prevent GPU memory leak
  setState(() => _staticCache = newImage);
}

// In CustomPainter.paint():
@override
void paint(Canvas canvas, Size size) {
  if (_staticCache != null) {
    // Single GPU texture blit — essentially free
    canvas.drawImageRect(
      _staticCache!,
      Rect.fromLTWH(0, 0, _staticCache!.width.toDouble(), _staticCache!.height.toDouble()),
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint(),
    );
  }
  // Only draw the dynamic overlay (active stroke, selection handles)
  _drawDynamicOverlay(canvas, size);
}
```

**When to invalidate the cache:** When history changes (add/remove/modify an item). NOT on every pointer move.

**Memory warning:** Always `.dispose()` the old image before replacing it. GPU texture memory is scarce.

---

## Caching Paint Objects

```dart
// BAD: Allocates on every paint() call
void paint(Canvas canvas, Size size) {
  final paint = Paint()  // allocation!
    ..color = Colors.red
    ..strokeWidth = 2.0;
  canvas.drawLine(p1, p2, paint);
}

// GOOD: Cache as final field
class MyPainter extends CustomPainter {
  final _strokePaint = Paint()
    ..color = Colors.red
    ..strokeWidth = 2.0
    ..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(p1, p2, _strokePaint); // no allocation
  }
}
```

For `Paint` objects where properties change per item (e.g., different colors per shape), reuse a single `Paint` instance and mutate its properties rather than creating new ones:

```dart
final _reusablePaint = Paint();

void _drawShape(Canvas canvas, ShapeAction action) {
  _reusablePaint
    ..color = action.color
    ..strokeWidth = action.strokeWidth
    ..style = PaintingStyle.stroke;
  canvas.drawRect(action.rect, _reusablePaint);
}
```

---

## Caching Path Objects

```dart
// BAD: Rebuilds Path every frame
void paint(Canvas canvas, Size size) {
  final path = Path();
  for (final point in points) {
    path.lineTo(point.dx, point.dy);
  }
  canvas.drawPath(path, paint);
}

// GOOD: Cache path; rebuild only when points change
Path? _cachedPath;
List<Offset>? _lastPoints;

Path _getPath(List<Offset> points) {
  if (_cachedPath != null && points == _lastPoints) return _cachedPath!;
  final path = Path();
  if (points.isNotEmpty) {
    path.moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
  }
  _lastPoints = points;
  return _cachedPath = path;
}
```

---

## TextPainter Caching

```dart
// BAD: Layout computed on every paint() frame
void paint(Canvas canvas, Size size) {
  final tp = TextPainter(
    text: TextSpan(text: label, style: style),
    textDirection: TextDirection.ltr,
  );
  tp.layout();  // expensive!
  tp.paint(canvas, offset);
}

// GOOD: Cache TextPainter; re-layout only when text/style changes
TextPainter? _labelPainter;
String? _lastLabel;

TextPainter _getTextPainter(String text, TextStyle style, double maxWidth) {
  if (_labelPainter != null && text == _lastLabel) return _labelPainter!;
  _labelPainter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
  )..layout(maxWidth: maxWidth);
  _lastLabel = text;
  return _labelPainter!;
}
```

---

## Dirty Rect Culling

When only part of the canvas changed, clip paint to the dirty region:

```dart
@override
void paint(Canvas canvas, Size size) {
  // Cull: skip drawing items outside the visible/dirty rect
  final visibleRect = Offset.zero & size;
  for (final action in history) {
    final bounds = getActionBounds(action);
    if (!bounds.overlaps(visibleRect)) continue; // skip invisible items
    _drawAction(canvas, action);
  }
}
```

For scroll views, pass the `scrollOffset` to the painter and adjust culling accordingly.

---

## saveLayer() Control

```dart
// Necessary: eraser uses BlendMode.clear — needs a layer to clear into
canvas.saveLayer(drawRect, Paint());
_drawBackground(canvas);
_drawEraserStrokes(canvas); // BlendMode.clear strokes
canvas.restore();

// Avoidable: group opacity without blend mode
// BAD
canvas.saveLayer(bounds, Paint()..color = Color.fromARGB(128, 0, 0, 0));
_drawContent(canvas);
canvas.restore();

// GOOD: apply opacity directly to Paint color
final paint = Paint()..color = baseColor.withOpacity(0.5);
canvas.drawRect(bounds, paint);
```

**Counting your saveLayer calls:**
Add a debug counter in development:
```dart
int _layerCount = 0;
// Before each saveLayer: _layerCount++;
// In paint(): reset _layerCount = 0 at start, print at end
```
For 60 FPS on mobile, aim for < 3 `saveLayer` calls per frame on a complex canvas.

---

## RepaintBoundary Placement Strategy

```dart
// Wrap independently-animating widgets:
RepaintBoundary(
  child: AnimatedWidget(...), // repaints independently, doesn't trigger parent repaint
)

// Wrap expensive static widgets:
RepaintBoundary(
  child: ComplexStaticDiagram(), // cached as its own layer, not repainted by parent
)

// DON'T wrap every widget — each RepaintBoundary = one GPU compositing layer
// Too many layers = more compositing overhead than repaints you saved
```

Rule of thumb: use `RepaintBoundary` when a subtree:
1. Animates at a different cadence than its parent, OR
2. Is expensive to paint and rarely changes

---

## InteractiveViewer / GestureDetector Performance

For canvas with pan/zoom:

```dart
// BAD: rebuilding widget tree on every scale/pan update
InteractiveViewer(
  onInteractionUpdate: (details) {
    setState(() { _matrix = details.matrix; }); // forces full rebuild!
  },
  ...
)

// GOOD: use TransformationController — Flutter handles matrix internally
// without triggering setState on the parent
final _controller = TransformationController();

InteractiveViewer(
  transformationController: _controller,
  child: CustomPaint(painter: myPainter),
)
```

---

## Gesture → Paint Latency

For drawing apps, the latency between finger movement and paint update is critical.

Use `Listener` (lower level than `GestureDetector`) for pointer events during active drawing:

```dart
Listener(
  onPointerMove: (event) {
    // Directly update the active stroke — don't go through setState on root
    _activePainter.addPoint(event.localPosition);
    _repaintKey.currentState?.markNeedsPaint(); // triggers only painter repaint
  },
)
```

Better: use `CustomPainter` with a `Listenable` as the repaint signal:

```dart
class DrawingPainter extends CustomPainter {
  DrawingPainter({required this.stroke, required Listenable repaint})
      : super(repaint: repaint);
  
  final ActiveStroke stroke;
  
  @override
  void paint(Canvas canvas, Size size) => _drawStroke(canvas, stroke);
  
  @override
  bool shouldRepaint(covariant DrawingPainter old) => old.stroke != stroke;
}

// Drive repaints via a ChangeNotifier — no setState needed
final _strokeNotifier = ChangeNotifier();
_activePainter = DrawingPainter(stroke: _stroke, repaint: _strokeNotifier);

// In gesture handler:
_stroke.addPoint(position);
_strokeNotifier.notifyListeners(); // triggers only the painter, not the widget tree
```
