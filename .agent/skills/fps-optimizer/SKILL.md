---
name: fps-optimizer
description: Expert FPS performance analyzer for Flutter and Dart codebases. Scans code for rendering bottlenecks, unnecessary repaints, expensive build cycles, janky animations, and GPU/CPU overload patterns — then delivers prioritized, actionable recommendations to raise frame rate. Use this skill whenever the user asks to improve FPS, reduce jank, optimize performance, speed up animations, fix stutters, audit CustomPainter/Canvas, analyze widget rebuild costs, or mentions laggy UI. Also trigger this skill when the user says "почему тормозит", "оптимизировать FPS", "убрать лаги", "анализ производительности", "почему джанк", "повысить фпс", "оптимизация рендеринга", or similar performance-related phrases.
---

# FPS Optimizer

Expert performance analyst for Flutter/Dart UIs. Your primary mission: raise FPS and eliminate jank by finding the real bottlenecks and explaining concretely how to fix them.

## Your Mindset

Performance work is detective work. Don't just pattern-match on surface anti-patterns — understand *why* something is slow. A single `saveLayer` in a 60-element list is catastrophic; the same `saveLayer` called once on a static image is fine. Context matters enormously. Before recommending anything, understand:
- What is the render pipeline doing per frame?
- Is the problem CPU-side (build/layout/paint) or GPU-side (compositing, texture uploads, overdraw)?
- How often does this code path execute — once, per gesture, per frame?

---

## Phase 1: Scope the Problem

Before diving into code, ask (or infer from context) two things:

1. **What platform/device?** iOS, Android, Web, Desktop. GPU constraints differ drastically.
2. **Where does it feel slow?** During scroll? Animation? Drawing gestures? Transitions? Startup?

If the user gave you specific files, focus there first. Otherwise scan broadly and narrow down.

---

## Phase 2: Code Analysis

Scan for issues in this priority order (most impact first):

### CRITICAL — Frame Budget Killers

These reliably cause dropped frames. Prioritize finding them.

**Canvas / CustomPainter**
- `saveLayer()` called every frame without a flag guard — this is the #1 FPS killer in complex painters. Every `saveLayer` allocates an offscreen buffer on the GPU.
- `paintImage()` with un-cached `ui.Image` — image decoding or format conversion inside `paint()` causes CPU spikes.
- Looping over all history items on every `paint()` call (O(n) paint without spatial culling).
- Creating `TextPainter` and calling `.layout()` inside `paint()` every frame — text layout is expensive.
- Creating `Path()`, `Paint()`, or `TextSpan` objects inside `paint()` — allocations in hot loops trigger GC.
- `shouldRepaint()` always returning `true` — causes the painter to redraw every frame unconditionally.

**Widget Tree**
- `setState()` at the root widget causing full subtree rebuild on every pointer event.
- `build()` methods doing expensive computation (sorting, filtering large lists, string formatting).
- Large list of `CustomPaint` widgets without `RepaintBoundary` wrappers.
- `AnimationController` ticking every frame but driving widgets that don't need per-frame updates.

**Async / IO**
- Image decoding on the UI isolate (not using `compute()` or `Isolate`).
- File I/O on the main thread during animations.

---

### HIGH — Significant Frame Budget Pressure

**Canvas**
- Repeatedly calling `canvas.drawPath()` with a `Path` rebuilt from scratch each frame — cache the `Path` object.
- No dirty-rect culling: drawing the entire history when only one small region changed.
- Using `BoxFit.contain`/`cover` with large images without caching the scaled result — Flutter resamples every frame.
- `MaskFilter.blur()` recalculated per-frame paint call — Gaussian blur on the GPU is expensive; cache or reduce radius.
- Multiple overlapping transparent layers without blending optimization.

**Widget rebuilds**
- Using `context.watch<T>()` (or `BlocBuilder`, `Consumer`) at a high tree node when only a leaf widget needs the update.
- Missing `const` constructors on widgets that never change.

---

### MEDIUM — Latent / Conditional Issues

- `Opacity` widget with `opacity < 1.0` on a subtree that animates — use `FadeTransition` instead.
- `ClipRect`/`ClipRRect` without `clipBehavior: Clip.hardEdge` — `antiAlias` variants push to GPU compositing.
- `DecoratedBox` with `BoxShadow` on animated widgets — shadows are expensive to composite.
- `ShaderMask` on every frame without caching the shader.

---

### LOW / BEST PRACTICES

- Object pools for frequently allocated `Paint`, `Rect`, `Offset` instances in hot paths.
- Prefer `drawImageRect` over `drawImage` with manual matrix math.
- Use `picture.toImageSync()` for static content, then `drawImageRect` each frame.
- Use `RepaintBoundary` around independently-animating subtrees.

---

## Phase 3: Produce the Report

Structure your output exactly like this template:

```
# FPS Performance Audit — [FileName or Feature Name]

## Summary
[2-3 sentences: biggest problem and what fixing it achieves. Be specific: "saveLayer called inside a loop over 40 history items costs ~8ms/frame — reducing it to 1 static call will recover ~12 FPS on mid-range Android."]

## Critical Issues (Fix First)

### [Issue Name] · CRITICAL
File: path/to/file.dart · Lines: 42-67
Why it hurts FPS: [mechanistic explanation — what the GPU/CPU does and how many ms it wastes]
Fix: [before/after code snippet]
Expected gain: [concrete estimate: "+10 FPS", "eliminates 8ms GPU spike per gesture"]

## High Priority
[Same format, briefer. One paragraph per issue + minimal code diff.]

## Medium Priority
[Issue name, file+line, one-line fix recommendation.]

## Quick Wins
[Bulleted list: const, RepaintBoundary placements, etc.]

## What Looks Good
[Explicitly acknowledge well-implemented patterns. Builds trust, reinforces good habits.]

## Recommended Next Steps
[Ordered by impact. Include specific Flutter DevTools steps to validate.]
```

---

## Important Rules

**Be specific, not generic.** "Consider using RepaintBoundary" is useless without pointing to the exact widget tree node. Always reference exact file paths and line numbers.

**Distinguish theory from observation.** If you see the issue in the code, state it directly. If you're inferring from a pattern that *might* be slow depending on data size, qualify it: "If history grows beyond ~50 items, this O(n) loop will exceed frame budget."

**Rank by impact, not by ease.** If there's one `saveLayer` in a hot loop causing 80% of the jank, lead with that even if the fix is complex.

**Don't invent problems.** Only report what you can see or clearly infer from the code. Don't speculate about dependencies unless there's clear evidence.

**Explain the mechanism.** A developer who understands *why* `saveLayer` is expensive will prevent future regressions. Don't just say "avoid saveLayer" — explain: "saveLayer allocates an offscreen framebuffer on the GPU, then composites it back during rasterization, costing ~2-5ms per call on mobile GPUs."

**Validate with DevTools.** Always close with specific Flutter DevTools steps to confirm the gains.

---

## Flutter DevTools Quick Reference

Always include this at the end of every report:

### How to Validate Your Gains
```
flutter run --profile
```
- **Performance overlay**: DevTools → Performance. Green bars = GPU thread, blue = UI thread. Both must stay under 16ms for 60 FPS.
- **Repaint Rainbow**: `debugRepaintRainbowEnabled = true` — flickering colors reveal unexpected repaints.
- **Timeline**: DevTools → Performance → Record. Look for Paint/Layout/Build events exceeding 16ms.
- **Widget Rebuild Stats**: DevTools → Performance → "Track widget builds" — shows rebuild count per widget per second.

---

## Reference Files

For deeper knowledge on specific topics, read these files as needed:
- `references/flutter_rendering_pipeline.md` — Build → Layout → Paint → Composite → Rasterize pipeline internals
- `references/canvas_patterns.md` — CustomPainter-specific caching, dirty rects, layer management
- `references/common_antipatterns.md` — Anti-pattern catalogue with benchmark data
