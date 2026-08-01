import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_bloc.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_event.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_state.dart';

void main() {
  group('DrawBloc Tests', () {
    late DrawBloc drawBloc;

    setUp(() {
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
      // Infiltrate -> Red
      drawBloc.add(SelectToolEvent(ToolType.infiltrate));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.infiltrate);
      expect(drawBloc.state.currentColor, const Color(0xFFD32F2F));

      // Adhesions -> Green
      drawBloc.add(SelectToolEvent(ToolType.adhesions));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.adhesions);
      expect(drawBloc.state.currentColor, const Color(0xFF388E3C));

      // Endometrioma -> Brown
      drawBloc.add(SelectToolEvent(ToolType.endometrioma));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.endometrioma);
      expect(drawBloc.state.currentColor, const Color(0xFF5C4033));

      // Foci -> Yellow/Amber
      drawBloc.add(SelectToolEvent(ToolType.foci));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.foci);
      expect(drawBloc.state.currentColor, const Color(0xFFFFC107));
    });

    test('ChangeFigoTypeEvent should update myoma default color correctly', () async {
      drawBloc.add(SelectToolEvent(ToolType.myoma));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentTool, ToolType.myoma);
      
      // Default FIGO is '0' -> Pink
      expect(drawBloc.state.currentColor, const Color(0xFFE91E63));

      // Change FIGO to '3' -> Blue
      drawBloc.add(ChangeFigoTypeEvent('3'));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentFigoType, '3');
      expect(drawBloc.state.currentColor, const Color(0xFF1976D2));

      // Change FIGO to '6' -> Green
      drawBloc.add(ChangeFigoTypeEvent('6'));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentFigoType, '6');
      expect(drawBloc.state.currentColor, const Color(0xFF388E3C));

      // Change FIGO to '2-5' -> Purple
      drawBloc.add(ChangeFigoTypeEvent('2-5'));
      await drawBloc.stream.first;
      expect(drawBloc.state.currentFigoType, '2-5');
      expect(drawBloc.state.currentColor, const Color(0xFF9C27B0));
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
  });
}
