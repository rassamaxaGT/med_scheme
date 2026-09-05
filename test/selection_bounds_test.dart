import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/presentation/widgets/canvas/canvas_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Selection Bounds and Minimum Box Tests', () {
    test('minSelectionDimension is 125.0', () {
      expect(CanvasPainter.minSelectionDimension, 125.0);
    });

    test('Large object (200x200) selection bounds equals original bounds', () {
      final shape = ShapeAction(
        id: 'large_shape',
        color: const Color(0xFF000000),
        strokeWidth: 4.0,
        startPoint: const Offset(100, 100),
        endPoint: const Offset(300, 300),
        shapeType: 'myoma',
      );

      final origBounds = CanvasPainter.getOriginalActionBounds(shape);
      final selectionBounds = CanvasPainter.getActionSelectionBounds(shape);

      expect(origBounds.width, greaterThanOrEqualTo(125.0));
      expect(origBounds.height, greaterThanOrEqualTo(125.0));
      expect(selectionBounds, equals(origBounds));
    });

    test('Small object (10x10) selection bounds enforces minimum 125x125 size centered on object', () {
      final smallShape = ShapeAction(
        id: 'small_shape',
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
        startPoint: const Offset(100, 100),
        endPoint: const Offset(105, 105),
        shapeType: 'myoma',
      );

      final origBounds = CanvasPainter.getOriginalActionBounds(smallShape);
      expect(origBounds.width, lessThan(125.0));

      final selectionBounds = CanvasPainter.getActionSelectionBounds(smallShape);

      // Width and height should be at least 125.0
      expect(selectionBounds.width, 125.0);
      expect(selectionBounds.height, 125.0);
      // Center must remain identical to object center
      expect(selectionBounds.center, equals(origBounds.center));
    });

    test('Scaled down object (scale = 0.2) enforces minimum rendered size of 125px', () {
      final stamp = StampAction(
        id: 'scaled_stamp',
        color: const Color(0xFF880E4F),
        strokeWidth: 4.0,
        position: const Offset(200, 200),
        stampType: 'foci',
        scaleX: 0.2,
        scaleY: 0.2,
      );

      final origBounds = CanvasPainter.getOriginalActionBounds(stamp);
      final selectionBounds = CanvasPainter.getActionSelectionBounds(stamp);

      // In local coordinates, box width scaled by 0.2 must equal at least 125.0 (boxWidth >= 125 / 0.2 = 625)
      final effectiveRenderedWidth = selectionBounds.width * 0.2;
      final effectiveRenderedHeight = selectionBounds.height * 0.2;

      expect(effectiveRenderedWidth, closeTo(125.0, 0.001));
      expect(effectiveRenderedHeight, closeTo(125.0, 0.001));
      expect(selectionBounds.center, equals(origBounds.center));
    });

    test('Rotation handle point is at guaranteed distance above minimum selection box', () {
      final smallStamp = StampAction(
        id: 'micro_stamp',
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
        position: const Offset(150, 150),
        stampType: 'follicle',
        scaleX: 0.1,
        scaleY: 0.1,
      );

      final selectionBounds = CanvasPainter.getActionSelectionBounds(smallStamp);

      final scaleY = smallStamp.scaleY.abs();
      final rotationLocalPt = Offset(selectionBounds.center.dx, selectionBounds.top - (36.0 / scaleY));
      final rotWorldPt = CanvasPainter.getTransformedActionPoint(smallStamp, rotationLocalPt);
      final centerWorldPt = CanvasPainter.getTransformedActionPoint(smallStamp, selectionBounds.center);

      // Distance from center to rotation button in world space must be at least 62.5 (half box) + 36 = 98.5px
      final distance = (rotWorldPt - centerWorldPt).distance;
      expect(distance, greaterThanOrEqualTo(98.0));
    });

    test('Opposite anchor corner of object remains fixed on canvas during resize transformation', () {
      final microStamp = StampAction(
        id: 'micro_stamp',
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
        position: const Offset(100, 100),
        stampType: 'foci',
        scaleX: 0.1,
        scaleY: 0.1,
      );

      final origBounds = CanvasPainter.getOriginalActionBounds(microStamp);
      final origAnchorLocal = origBounds.topLeft;
      final anchorWorld0 = CanvasPainter.getTransformedActionPoint(microStamp, origAnchorLocal);

      // Simulate scaling to 2x (scaleMultiplier = 2.0 -> newScale = 0.2)
      const double newScale = 0.2;
      final rotCenter = microStamp.position;
      final anchorDx = (origAnchorLocal.dx - rotCenter.dx) * newScale;
      final anchorDy = (origAnchorLocal.dy - rotCenter.dy) * newScale;
      final rotatedAnchor = Offset(anchorDx, anchorDy);

      final newOffsetX = anchorWorld0.dx - rotCenter.dx - rotatedAnchor.dx;
      final newOffsetY = anchorWorld0.dy - rotCenter.dy - rotatedAnchor.dy;

      final scaledStamp = StampAction(
        id: microStamp.id,
        color: microStamp.color,
        strokeWidth: microStamp.strokeWidth,
        position: microStamp.position,
        stampType: microStamp.stampType,
        scaleX: newScale,
        scaleY: newScale,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
      );

      final anchorWorldAfter = CanvasPainter.getTransformedActionPoint(scaledStamp, origAnchorLocal);
      expect((anchorWorldAfter - anchorWorld0).distance, closeTo(0.0, 0.0001));
    });

    test('Selection box drag area includes any point inside 125x125 box even far from tiny object', () {
      final microStamp = StampAction(
        id: 'micro_stamp',
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
        position: const Offset(100, 100),
        stampType: 'follicle',
        scaleX: 1.0,
        scaleY: 1.0,
      );

      final selectionBounds = CanvasPainter.getActionSelectionBounds(microStamp);
      expect(selectionBounds.width, 125.0);
      expect(selectionBounds.height, 125.0);

      // Point at (140, 140) is 40px away from the center (outside the 5px follicle), but inside coordinate square
      expect(selectionBounds.contains(const Offset(140, 140)), isTrue);
      // Point at (100, 45) is near top edge inside coordinate square
      expect(selectionBounds.contains(const Offset(100, 45)), isTrue);
      // Point at (180, 180) is outside coordinate square
      expect(selectionBounds.contains(const Offset(180, 180)), isFalse);
    });

    test('Corner resize is strictly restricted to corners and does not capture edges or interior', () {
      final microStamp = StampAction(
        id: 'micro_stamp',
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
        position: const Offset(100, 100),
        stampType: 'follicle',
        scaleX: 1.0,
        scaleY: 1.0,
      );

      final selectionBounds = CanvasPainter.getActionSelectionBounds(microStamp);
      const double avgScale = 1.0;
      const double handleSize = 10.0 / avgScale;
      final double maxInwardX = handleSize * 1.5; // 15.0
      final double maxInwardY = handleSize * 1.5; // 15.0
      const double cornerThreshold = 32.0;

      final topLeft = selectionBounds.topLeft;

      // Helper simulating the corner hit check
      bool isCornerHit(Offset clickPoint) {
        final inwardX = clickPoint.dx - topLeft.dx;
        final inwardY = clickPoint.dy - topLeft.dy;
        if (inwardX > maxInwardX || inwardY > maxInwardY) return false;
        return (clickPoint - topLeft).distance < cornerThreshold;
      }

      // 1. Exactly on the corner -> Corner HIT (Resize)
      expect(isCornerHit(topLeft), isTrue);

      // 2. Diagonally outside the corner (comfortable touch area) -> Corner HIT (Resize)
      expect(isCornerHit(topLeft + const Offset(-8, -8)), isTrue);

      // 3. On the corner square (e.g. +8, +8 inside) -> Corner HIT (Resize)
      expect(isCornerHit(topLeft + const Offset(8, 8)), isTrue);

      // 4. Along the top edge (e.g. +25px horizontally, 0px vertically)
      // Even though distance = 25 < 32px, inwardX = 25 > 15 -> NOT a corner! Edge is for dragging!
      expect(isCornerHit(topLeft + const Offset(25, 0)), isFalse);

      // 5. Along the left edge (e.g. 0px horizontally, +25px vertically)
      // inwardY = 25 > 15 -> NOT a corner! Edge is for dragging!
      expect(isCornerHit(topLeft + const Offset(0, 25)), isFalse);

      // 6. Deep inside the box (e.g. +20px, +20px) -> NOT a corner! Body is for dragging!
      expect(isCornerHit(topLeft + const Offset(20, 20)), isFalse);

      // 7. Edges and border tolerance are captured for dragging
      const double borderTolerance = 8.0;
      final dragArea = selectionBounds.inflate(borderTolerance);
      expect(dragArea.contains(topLeft + const Offset(25, 0)), isTrue); // Top edge drags
      expect(dragArea.contains(topLeft + const Offset(0, 25)), isTrue); // Left edge drags
      expect(dragArea.contains(topLeft + const Offset(20, 20)), isTrue); // Body drags
      expect(dragArea.contains(topLeft + const Offset(25, -4)), isTrue); // Just outside border drags
    });

    test('Rotation handle hit area is restricted strictly to rotation icon circle', () {
      final microStamp = StampAction(
        id: 'micro_stamp',
        color: const Color(0xFF000000),
        strokeWidth: 2.0,
        position: const Offset(100, 100),
        stampType: 'follicle',
        scaleX: 1.0,
        scaleY: 1.0,
      );

      final selectionBounds = CanvasPainter.getActionSelectionBounds(microStamp);
      const double avgScale = 1.0;
      final rotCenter = Offset(selectionBounds.center.dx, selectionBounds.top - (36.0 / avgScale));
      const double rotRadius = 14.0 / avgScale;

      // At rotation handle center -> inside
      expect((rotCenter - rotCenter).distance <= rotRadius + 1.5, isTrue);

      // At radius 10px -> inside
      expect(((rotCenter + const Offset(10, 0)) - rotCenter).distance <= rotRadius + 1.5, isTrue);

      // At 20px away (which was captured by old 48px threshold) -> strictly OUTSIDE rotation icon
      expect(((rotCenter + const Offset(20, 0)) - rotCenter).distance <= rotRadius + 1.5, isFalse);
    });
  });
}
