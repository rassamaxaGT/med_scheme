import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/presentation/widgets/canvas/canvas_painter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Canvas Geometry and Scheme Sizing Tests', () {
    test('Standard canvas constants are 907x1280', () {
      expect(CanvasPainter.standardCellWidth, 907.0);
      expect(CanvasPainter.standardCellHeight, 1280.0);
      expect(CanvasPainter.standardSingleCanvasSize, const Size(907.0, 1280.0));
    });

    test('getBowelInfiltrateScale maps levels 1..6 with level 3 matching legacy size 2', () {
      // Legacy size 2 had scale = 2.0 / 5.0 = 0.4 (height = 36.0 px)
      expect(CanvasPainter.getBowelInfiltrateScale(3.0), closeTo(0.4, 0.0001));

      // Level 1 -> 0.2 (height = 18.0 px)
      expect(CanvasPainter.getBowelInfiltrateScale(1.0), closeTo(0.2, 0.0001));

      // Level 6 -> 0.7 (height = 63.0 px)
      expect(CanvasPainter.getBowelInfiltrateScale(6.0), closeTo(0.7, 0.0001));
    });

    test('getMyomaStampScale maps levels 1..6 with level 3 matching legacy size 6', () {
      // Size 3 must correspond to previous size 6 (scale 0.7, height = 63.0 px)
      expect(CanvasPainter.getMyomaStampScale(3.0), closeTo(CanvasPainter.getBowelInfiltrateScale(6.0), 0.0001));
      expect(CanvasPainter.getMyomaStampScale(3.0), closeTo(0.7, 0.0001));
      expect(90.0 * CanvasPainter.getMyomaStampScale(3.0), closeTo(63.0, 0.0001));

      // Level 1 -> 0.35 (height = 31.5 px)
      expect(CanvasPainter.getMyomaStampScale(1.0), closeTo(0.35, 0.0001));

      // Level 6 -> 1.225 (height = 110.25 px)
      expect(CanvasPainter.getMyomaStampScale(6.0), closeTo(1.225, 0.0001));
    });

    test('getInfiltrateStamp2Scale maps levels 1..6 with level 3 matching legacy size 3.5', () {
      // Size 3 must correspond to previous size 3.5 (scale 0.45, height = 40.5 px)
      expect(CanvasPainter.getInfiltrateStamp2Scale(3.0), closeTo(CanvasPainter.getBowelInfiltrateScale(3.5), 0.0001));
      expect(CanvasPainter.getInfiltrateStamp2Scale(3.0), closeTo(0.45, 0.0001));
      expect(90.0 * CanvasPainter.getInfiltrateStamp2Scale(3.0), closeTo(40.5, 0.0001));

      // Level 1 -> 0.225 (height = 20.25 px)
      expect(CanvasPainter.getInfiltrateStamp2Scale(1.0), closeTo(0.225, 0.0001));

      // Level 6 -> 0.7875 (height = 70.875 px)
      expect(CanvasPainter.getInfiltrateStamp2Scale(6.0), closeTo(0.7875, 0.0001));
    });

    test('getIudScale maps levels 1..6 with 2.5x enlarged base dimensions', () {
      // Level 3 -> 3.0 * (20/24) * 2.5 = 6.25 (height = 225 px)
      expect(CanvasPainter.getIudScale(3.0), closeTo(6.25, 0.0001));
      expect(36.0 * CanvasPainter.getIudScale(3.0), closeTo(225.0, 0.0001));

      // Level 1 -> 1.0 * (20/24) * 2.5 = 2.0833 (height = 75 px)
      expect(CanvasPainter.getIudScale(1.0), closeTo(25.0 / 12.0, 0.0001));
      expect(36.0 * CanvasPainter.getIudScale(1.0), closeTo(75.0, 0.0001));

      // Level 6 -> 6.0 * (20/24) * 2.5 = 12.5 (height = 450 px)
      expect(CanvasPainter.getIudScale(6.0), closeTo(12.5, 0.0001));
      expect(36.0 * CanvasPainter.getIudScale(6.0), closeTo(450.0, 0.0001));
    });

    test('getCanvasBaseSize returns standard size for empty paths (blank sheet)', () {
      final size = CanvasPainter.getCanvasBaseSize(const []);
      expect(size.width, 907.0);
      expect(size.height, 1280.0);
    });

    test('getCanvasBaseSize returns 907x1280 for any single scheme', () {
      final lsSize = CanvasPainter.getCanvasBaseSize(const ['assets/schemes/ls_view.png']);
      expect(lsSize, const Size(907.0, 1280.0));

      final uterusSize = CanvasPainter.getCanvasBaseSize(const ['assets/schemes/uretus.png']);
      expect(uterusSize, const Size(907.0, 1280.0));

      final sagittalSize = CanvasPainter.getCanvasBaseSize(const ['assets/schemes/sagittally.jpg']);
      expect(sagittalSize, const Size(907.0, 1280.0));

      final customSize = CanvasPainter.getCanvasBaseSize(const ['/custom/photo.png']);
      expect(customSize, const Size(907.0, 1280.0));
    });

    test('getCanvasBaseSize returns multi-column and multi-row sizes for grid', () {
      // 2 schemes (1x2 grid)
      final twoSchemes = CanvasPainter.getCanvasBaseSize(const [
        'assets/schemes/ls_view.png',
        'assets/schemes/uretus.png',
      ]);
      expect(twoSchemes.width, 907.0 * 2);
      expect(twoSchemes.height, 1280.0);

      // 3 schemes (2x2 grid)
      final threeSchemes = CanvasPainter.getCanvasBaseSize(const [
        'assets/schemes/ls_view.png',
        'assets/schemes/uretus.png',
        'assets/schemes/sagittally.jpg',
      ]);
      expect(threeSchemes.width, 907.0 * 2);
      expect(threeSchemes.height, 1280.0 * 2);

      // 4 schemes (2x2 grid)
      final fourSchemes = CanvasPainter.getCanvasBaseSize(const [
        'assets/schemes/ls_view.png',
        'assets/schemes/uretus.png',
        'assets/schemes/sagittally.jpg',
        'assets/schemes/abdominal_wall_cross_section.png',
      ]);
      expect(fourSchemes.width, 907.0 * 2);
      expect(fourSchemes.height, 1280.0 * 2);
    });

    test('getSchemeImageRect for ls_view (1055x1490) fits cell vertically with centered horizontal margin', () {
      final rect = CanvasPainter.getSchemeImageRect(
        path: 'assets/schemes/ls_view.png',
        activePaths: const ['assets/schemes/ls_view.png'],
      );

      const expectedScale = 1280.0 / 1490.0;
      final expectedWidth = 1055.0 * expectedScale;
      final expectedLeft = (907.0 - expectedWidth) / 2;

      expect(rect.left, closeTo(expectedLeft, 0.001));
      expect(rect.top, 0.0);
      expect(rect.width, closeTo(expectedWidth, 0.001));
      expect(rect.height, 1280.0);
    });

    test('getSchemeImageRect for wide scheme (uretus 1280x905) scales to cell width (907.0) with zero horizontal gap and centered vertically', () {
      final rect = CanvasPainter.getSchemeImageRect(
        path: 'assets/schemes/uretus.png',
        activePaths: const ['assets/schemes/uretus.png'],
      );

      // Scale factor s = 907.0 / 1280.0
      const expectedScale = 907.0 / 1280.0;
      final expectedWidth = 1280.0 * expectedScale;
      final expectedHeight = 905.0 * expectedScale;
      final expectedTop = (1280.0 - expectedHeight) / 2;

      expect(rect.left, 0.0);
      expect(rect.width, closeTo(expectedWidth, 0.001));
      expect(rect.width, closeTo(907.0, 0.001)); // Attached directly to left and right edges!
      expect(rect.height, closeTo(expectedHeight, 0.001));
      expect(rect.top, closeTo(expectedTop, 0.001));
    });

    test('getSchemeImageRect for wide scheme (sagittally 800x566) scales to cell width (907.0)', () {
      final rect = CanvasPainter.getSchemeImageRect(
        path: 'assets/schemes/sagittally.jpg',
        activePaths: const ['assets/schemes/sagittally.jpg'],
      );

      // Scale factor s = 907.0 / 800.0 (since 800/566 = 1.413 > 907/1280 = 0.7086)
      const expectedScale = 907.0 / 800.0;
      final expectedWidth = 800.0 * expectedScale;
      final expectedHeight = 566.0 * expectedScale;
      final expectedTop = (1280.0 - expectedHeight) / 2;

      expect(rect.left, 0.0);
      expect(rect.width, closeTo(expectedWidth, 0.001));
      expect(rect.width, closeTo(907.0, 0.001));
      expect(rect.height, closeTo(expectedHeight, 0.001));
      expect(rect.top, closeTo(expectedTop, 0.001));
    });

    test('getSchemeImageRect in multi-scheme grid calculates correct column and row offsets', () {
      final activePaths = const [
        'assets/schemes/ls_view.png',
        'assets/schemes/uretus.png',
        'assets/schemes/sagittally.jpg',
      ];

      // Item 0: col 0, row 0
      final rect0 = CanvasPainter.getSchemeImageRect(
        path: activePaths[0],
        activePaths: activePaths,
      );
      expect(rect0.top, 0.0);
      expect(rect0.height, 1280.0);

      // Item 1: col 1, row 0
      final rect1 = CanvasPainter.getSchemeImageRect(
        path: activePaths[1],
        activePaths: activePaths,
      );
      expect(rect1.left, closeTo(907.0, 0.001)); // Col 1 starts at 907.0
      expect(rect1.width, closeTo(907.0, 0.001)); // Width touches column edges

      // Item 2: col 0, row 1
      final rect2 = CanvasPainter.getSchemeImageRect(
        path: activePaths[2],
        activePaths: activePaths,
      );
      expect(rect2.left, 0.0);
      expect(rect2.top, greaterThanOrEqualTo(1280.0)); // Row 1 starts at 1280.0
    });

    test('CanvasPainter paints with active EraserStrokeAction in realtime without error', () {
      final activeNotifier = ValueNotifier<DrawAction?>(
        EraserStrokeAction(
          id: 'test_eraser',
          strokeWidth: 20.0,
          points: const [Offset(100, 100), Offset(150, 150)],
          target: EraserTarget.everything,
          targetSchemePath: 'assets/schemes/ls_view.png',
        ),
      );

      final painter = CanvasPainter(
        history: const [],
        activeActionNotifier: activeNotifier,
        backgroundPaths: const ['assets/schemes/ls_view.png'],
      );

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      expect(() => painter.paint(canvas, const Size(800, 600)), returnsNormally);
      final picture = recorder.endRecording();
      picture.dispose();
      activeNotifier.dispose();
    });
  });
}
