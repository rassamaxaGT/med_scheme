import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:flutter/services.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_bloc.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_event.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_state.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DrawBloc Tests', () {
    late DrawBloc drawBloc;

    setUp(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/path_provider'),
        (MethodCall methodCall) async => '.',
      );
      SharedPreferences.setMockInitialValues({});
      drawBloc = DrawBloc();
    });

    tearDown(() {
      drawBloc.close();
    });

    test('Initial state should be correct', () {
      final state = drawBloc.state;
      expect(state.history, isEmpty);
      expect(state.undoStack, isEmpty);
      expect(state.redoStack, isEmpty);
      expect(state.currentTool, ToolType.pencil);
      expect(state.currentColor, const Color(0xFF000000));
      expect(state.currentStrokeWidth, 4.0);
      expect(state.patientId, isEmpty);
    });

    test('SelectToolEvent should update tool and set clinical default color', () async {
      // Infiltrate -> Brown
      drawBloc.add(SelectToolEvent(ToolType.infiltrate));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.infiltrate);
      expect(drawBloc.state.currentColor, const Color(0xFF5C4033));

      // Adhesions -> Grey, strokeWidth = 2.0
      drawBloc.add(SelectToolEvent(ToolType.adhesions));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.adhesions);
      expect(drawBloc.state.currentColor, const Color(0xFF9E9E9E));
      expect(drawBloc.state.currentStrokeWidth, 2.0);

      // Endometrioma -> Brown
      drawBloc.add(SelectToolEvent(ToolType.endometrioma));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.endometrioma);
      expect(drawBloc.state.currentColor, const Color(0xFF8B5A2B));

      // Foci -> Cherry
      drawBloc.add(SelectToolEvent(ToolType.foci));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.foci);
      expect(drawBloc.state.currentColor, const Color(0xFF880E4F));

      // Cyst -> Saturated Yellow (Color(0xFFFFD600))
      drawBloc.add(SelectToolEvent(ToolType.cyst));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.cyst);
      expect(drawBloc.state.currentColor, const Color(0xFFFFD600));

      // BowelInfiltrate -> Brown, strokeWidth = 3.0 (corresponds to old 2)
      drawBloc.add(SelectToolEvent(ToolType.bowelInfiltrate));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.bowelInfiltrate);
      expect(drawBloc.state.currentColor, const Color(0xFF5C4033));
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // BowelInfiltrate2 -> Brown
      drawBloc.add(SelectToolEvent(ToolType.bowelInfiltrate2));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.bowelInfiltrate2);
      expect(drawBloc.state.currentColor, const Color(0xFF5C4033));

      // Spray -> strokeWidth = 16.0
      drawBloc.add(SelectToolEvent(ToolType.spray));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.spray);
      expect(drawBloc.state.currentStrokeWidth, 16.0);

      // Fibrosis -> Black color, strokeWidth = 3.0
      drawBloc.add(SelectToolEvent(ToolType.fibrosis));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.fibrosis);
      expect(drawBloc.state.currentColor, const Color(0xFF000000));
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // IUD -> Black color, strokeWidth = 3.0 (scale 1..6 with default 3.0)
      drawBloc.add(SelectToolEvent(ToolType.iud));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.iud);
      expect(drawBloc.state.currentColor, const Color(0xFF000000));
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // IUDStamp -> Black color, strokeWidth = 3.0
      drawBloc.add(SelectToolEvent(ToolType.iudStamp));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.iudStamp);
      expect(drawBloc.state.currentColor, const Color(0xFF000000));
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // Myoma -> Pink color
      drawBloc.add(SelectToolEvent(ToolType.myoma));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.myoma);
      expect(drawBloc.state.currentColor, const Color(0xFFFF69B4));

      // MyomaStamp -> strokeWidth = 3.0 (same size grid as bowelInfiltrate)
      drawBloc.add(SelectToolEvent(ToolType.myomaStamp));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.myomaStamp);
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // InfiltrateStamp2 -> Brown, strokeWidth = 3.0
      drawBloc.add(SelectToolEvent(ToolType.infiltrateStamp2));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.infiltrateStamp2);
      expect(drawBloc.state.currentColor, const Color(0xFF5C4033));
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // Polyp -> Orange, strokeWidth = 3.0
      drawBloc.add(SelectToolEvent(ToolType.polyp));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.polyp);
      expect(drawBloc.state.currentColor, const Color(0xFFFF7043));
      expect(drawBloc.state.currentStrokeWidth, 3.0);

      // Eraser -> strokeWidth = 15.0
      drawBloc.add(SelectToolEvent(ToolType.eraser));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.eraser);
      expect(drawBloc.state.currentStrokeWidth, 15.0);
    });



    test('SetFullStateEvent should set the complete state correctly', () async {
      final action = StrokeAction(
        id: '123',
        color: Colors.red,
        strokeWidth: 5.0,
        points: const [Offset(0, 0), Offset(10, 10)],
      );

      drawBloc.add(SetFullStateEvent(
        history: [action],
        patientId: 'PAT-999',
        backgroundPath: 'some/background.png',
      ));
      await drawBloc.stream.first;

      expect(drawBloc.state.history, hasLength(1));
      expect(drawBloc.state.history.first.id, '123');
      expect(drawBloc.state.patientId, 'PAT-999');
      expect(drawBloc.state.backgroundPath, 'some/background.png');
      expect(drawBloc.state.undoStack, isEmpty);
      expect(drawBloc.state.redoStack, isEmpty);
    });

    test('Undo and Redo should work correctly', () async {
      final action1 = StrokeAction(
        id: '1',
        color: Colors.red,
        strokeWidth: 5.0,
        points: const [Offset(0, 0)],
      );
      final action2 = StrokeAction(
        id: '2',
        color: Colors.blue,
        strokeWidth: 5.0,
        points: const [Offset(10, 10)],
      );

      // Add action1
      drawBloc.add(AddActionEvent(action1));
      await drawBloc.stream.first;
      expect(drawBloc.state.history, hasLength(1));
      expect(drawBloc.state.undoStack, hasLength(1));

      // Add action2
      drawBloc.add(AddActionEvent(action2));
      await drawBloc.stream.first;
      expect(drawBloc.state.history, hasLength(2));
      expect(drawBloc.state.undoStack, hasLength(2));

      // Undo -> drops action2
      drawBloc.add(UndoEvent());
      await drawBloc.stream.first;
      expect(drawBloc.state.history, hasLength(1));
      expect(drawBloc.state.history.first.id, '1');
      expect(drawBloc.state.redoStack, hasLength(1));

      // Redo -> restores action2
      drawBloc.add(RedoEvent());
      await drawBloc.stream.first;
      expect(drawBloc.state.history, hasLength(2));
      expect(drawBloc.state.redoStack, isEmpty);
    });

    test('Multi-page events (AddPageEvent, SwitchPageEvent, RemovePageEvent) work correctly', () async {
      expect(drawBloc.state.pages, hasLength(2));
      expect(drawBloc.state.currentPageIndex, 0);
      expect(drawBloc.state.currentPage.pageType, 'pelvis');

      // Add a third page
      drawBloc.add(AddPageEvent(pageType: 'custom', title: 'Лист 3'));
      await drawBloc.stream.first;
      expect(drawBloc.state.pages, hasLength(3));
      expect(drawBloc.state.currentPageIndex, 2);
      expect(drawBloc.state.currentPage.title, 'Лист 3');

      // Switch to page 0 ('Таз')
      drawBloc.add(SwitchPageEvent(0));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentPageIndex, 0);
      expect(drawBloc.state.currentPage.title, 'Таз');

      // Remove page 2
      drawBloc.add(RemovePageEvent(2));
      await drawBloc.stream.first;
      expect(drawBloc.state.pages, hasLength(2));
    });

    test('ToggleSchemeEvent toggles multiple schemes on a page', () async {
      drawBloc.add(SetBackgroundPathsEvent(const ['assets/schemes/pelvis_ls.png']));
      await drawBloc.stream.first;
      expect(drawBloc.state.backgroundPaths, contains('assets/schemes/pelvis_ls.png'));
      expect(drawBloc.state.backgroundPaths, hasLength(1));

      // Toggle second scheme
      drawBloc.add(ToggleSchemeEvent('assets/schemes/pelvis_sagittal.png'));
      await drawBloc.stream.first;
      expect(drawBloc.state.backgroundPaths, hasLength(2));
      expect(drawBloc.state.backgroundPaths, contains('assets/schemes/pelvis_sagittal.png'));

      // Toggle first scheme off
      drawBloc.add(ToggleSchemeEvent('assets/schemes/pelvis_ls.png'));
      await drawBloc.stream.first;
      expect(drawBloc.state.backgroundPaths, hasLength(1));
      expect(drawBloc.state.backgroundPaths.first, 'assets/schemes/pelvis_sagittal.png');
    });

    test('DrawAction preserves targetSchemePath when added to history', () async {
      final actionScheme1 = StrokeAction(
        id: 'stroke_1',
        color: Colors.red,
        strokeWidth: 4.0,
        points: const [Offset(10, 10)],
        targetSchemePath: 'assets/schemes/pelvis_ls.png',
      );

      final actionScheme2 = ShapeAction(
        id: 'shape_2',
        color: Colors.blue,
        strokeWidth: 4.0,
        startPoint: const Offset(20, 20),
        endPoint: const Offset(50, 50),
        shapeType: 'endometrioma',
        targetSchemePath: 'assets/schemes/pelvis_sagittal.png',
      );

      drawBloc.add(AddActionEvent(actionScheme1));
      await drawBloc.stream.first;
      drawBloc.add(AddActionEvent(actionScheme2));
      await drawBloc.stream.first;

      expect(drawBloc.state.history, hasLength(2));
      expect(drawBloc.state.history[0].targetSchemePath, 'assets/schemes/pelvis_ls.png');
      expect(drawBloc.state.history[1].targetSchemePath, 'assets/schemes/pelvis_sagittal.png');
    });

    test('Updating rotated action preserves targetSchemePath', () async {
      final initialShape = ShapeAction(
        id: 'shape_rot',
        color: Colors.red,
        strokeWidth: 4.0,
        startPoint: const Offset(100, 100),
        endPoint: const Offset(200, 200),
        shapeType: 'infiltrate',
        targetSchemePath: 'assets/schemes/pelvis_sagittal.png',
      );

      drawBloc.add(AddActionEvent(initialShape));
      await drawBloc.stream.first;

      final rotatedShape = ShapeAction(
        id: initialShape.id,
        color: initialShape.color,
        strokeWidth: initialShape.strokeWidth,
        startPoint: initialShape.startPoint,
        endPoint: initialShape.endPoint,
        shapeType: initialShape.shapeType,
        rotation: 1.57,
        targetSchemePath: initialShape.targetSchemePath,
      );

      drawBloc.add(UpdateActionEvent(rotatedShape));
      await drawBloc.stream.first;

      expect(drawBloc.state.history.first.targetSchemePath, 'assets/schemes/pelvis_sagittal.png');
      expect((drawBloc.state.history.first as ShapeAction).rotation, 1.57);
    });

    test('AddCustomSchemeEvent and RemoveCustomSchemeEvent handle custom image tabs', () async {
      drawBloc.add(AddCustomSchemeEvent('custom_path_1.jpg'));
      await drawBloc.stream.first;

      expect(drawBloc.state.customSchemes.length, 1);
      expect(drawBloc.state.customSchemes.first.title, 'Своё изображение 1');
      expect(drawBloc.state.customSchemes.first.path, 'custom_path_1.jpg');
      expect(drawBloc.state.backgroundPaths.contains('custom_path_1.jpg'), true);

      drawBloc.add(AddCustomSchemeEvent('custom_path_2.jpg'));
      await drawBloc.stream.first;

      expect(drawBloc.state.customSchemes.length, 2);
      expect(drawBloc.state.customSchemes[1].title, 'Своё изображение 2');

      // Uncheck custom 1 -> stays in customSchemes, removed from backgroundPaths
      drawBloc.add(ToggleSchemeEvent('custom_path_1.jpg'));
      await drawBloc.stream.first;

      expect(drawBloc.state.customSchemes.length, 2);
      expect(drawBloc.state.backgroundPaths.contains('custom_path_1.jpg'), false);

      // Remove custom 1 permanently -> deleted from customSchemes
      drawBloc.add(RemoveCustomSchemeEvent('custom_path_1.jpg'));
      await drawBloc.stream.first;

      expect(drawBloc.state.customSchemes.length, 1);
      expect(drawBloc.state.customSchemes.first.path, 'custom_path_2.jpg');
    });

    test('SetEraserTargetEvent should update eraserTarget in state', () async {
      expect(drawBloc.state.eraserTarget, EraserTarget.annotationsOnly);

      drawBloc.add(SetEraserTargetEvent(EraserTarget.backgroundOnly));
      await drawBloc.stream.first;
      expect(drawBloc.state.eraserTarget, EraserTarget.backgroundOnly);

      drawBloc.add(SetEraserTargetEvent(EraserTarget.everything));
      await drawBloc.stream.first;
      expect(drawBloc.state.eraserTarget, EraserTarget.everything);

      drawBloc.add(SetEraserTargetEvent(EraserTarget.annotationsOnly));
      await drawBloc.stream.first;
      expect(drawBloc.state.eraserTarget, EraserTarget.annotationsOnly);
    });

    test('ResetProjectEvent should reset state to initial state', () async {
      final action = StrokeAction(
        id: '1',
        color: Colors.blue,
        strokeWidth: 4.0,
        points: const [Offset(10, 10), Offset(20, 20)],
      );
      drawBloc.add(AddActionEvent(action));
      await drawBloc.stream.first;
      drawBloc.add(SetPatientIdEvent('PATIENT-123'));
      await drawBloc.stream.first;

      expect(drawBloc.state.history, isNotEmpty);
      expect(drawBloc.state.patientId, 'PATIENT-123');

      drawBloc.add(ResetProjectEvent());
      await drawBloc.stream.first;

      expect(drawBloc.state.history, isEmpty);
      expect(drawBloc.state.patientId, isEmpty);
      expect(drawBloc.state.undoStack, isEmpty);
      expect(drawBloc.state.redoStack, isEmpty);
      expect(drawBloc.state.pages.length, 2);
    });

    test('ToolType.customStamp defaults to strokeWidth 3.0', () async {
      drawBloc.add(SelectToolEvent(ToolType.customStamp));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.customStamp);
      expect(drawBloc.state.currentStrokeWidth, 3.0);
    });

    test('Custom stamp slots initial state has 4 slots', () {
      expect(drawBloc.state.customStampSlots.length, 4);
      expect(drawBloc.state.activeStampSlotIndex, 0);
    });

    test('SelectCustomStampSlotEvent should switch active slot and activate customStamp tool', () async {
      drawBloc.add(SelectCustomStampSlotEvent(2));
      await drawBloc.stream.first;
      expect(drawBloc.state.activeStampSlotIndex, 2);
      expect(drawBloc.state.currentTool, ToolType.customStamp);
      expect(drawBloc.state.currentStrokeWidth, 3.0);
    });

    test('AssignCustomStampSlotEvent with bytes saves slot and ClearCustomStampSlotEvent clears it', () async {
      final fakePngBytes = Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10]);
      drawBloc.add(AssignCustomStampSlotEvent(slotIndex: 1, bytes: fakePngBytes));
      await expectLater(
        drawBloc.stream,
        emitsThrough(predicate<DrawState>((s) => s.customStampSlots[1] != null)),
      );

      expect(drawBloc.state.activeStampSlotIndex, 1);
      expect(drawBloc.state.customStampSlots[1], isNotNull);
      expect(drawBloc.state.customStampPath, isNotNull);
      expect(drawBloc.state.currentTool, ToolType.customStamp);

      drawBloc.add(ClearCustomStampSlotEvent(1));
      await expectLater(
        drawBloc.stream,
        emitsThrough(predicate<DrawState>((s) => s.customStampSlots[1] == null)),
      );
      expect(drawBloc.state.customStampSlots[1], isNull);
    });
  });
}

