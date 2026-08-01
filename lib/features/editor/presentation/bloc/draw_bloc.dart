import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/draw_action.dart';
import 'draw_event.dart';
import 'draw_state.dart';

/// Максимальная глубина стека Undo/Redo. Ограничивает потребление памяти.
const int _maxUndoSteps = 50;

/// Обрезает стек до последних [_maxUndoSteps] записей.
List<List<DrawAction>> _limited(List<List<DrawAction>> stack) {
  if (stack.length <= _maxUndoSteps) return stack;
  return stack.sublist(stack.length - _maxUndoSteps);
}

class DrawBloc extends Bloc<DrawEvent, DrawState> {
  DrawBloc() : super(DrawState.initial()) {
    // ── Добавить действие ──────────────────────────────────────────────────
    on<AddActionEvent>((event, emit) {
      final updatedHistory = List<DrawAction>.from(state.history)..add(event.action);
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Обновить существующее действие (перемещение/ресайз) ───────────────
    on<UpdateActionEvent>((event, emit) {
      final updatedHistory = state.history.map((action) {
        return action.id == event.action.id ? event.action : action;
      }).toList();
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Установить фоновое изображение ────────────────────────────────────
    on<SetBackgroundEvent>((event, emit) {
      if (event.path == null) {
        emit(state.copyWith(clearBackground: true));
      } else {
        emit(state.copyWith(backgroundPath: event.path));
      }
    });

    // ── Undo ──────────────────────────────────────────────────────────────
    on<UndoEvent>((event, emit) {
      if (state.undoStack.isEmpty) return;
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack);
      final previousHistory = updatedUndo.removeLast();
      final updatedRedo = _limited(
        List<List<DrawAction>>.from(state.redoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: previousHistory,
        undoStack: updatedUndo,
        redoStack: updatedRedo,
      ));
    });

    // ── Redo ──────────────────────────────────────────────────────────────
    on<RedoEvent>((event, emit) {
      if (state.redoStack.isEmpty) return;
      final updatedRedo = List<List<DrawAction>>.from(state.redoStack);
      final nextHistory = updatedRedo.removeLast();
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: nextHistory,
        undoStack: updatedUndo,
        redoStack: updatedRedo,
      ));
    });

    // ── Очистить холст ────────────────────────────────────────────────────
    on<ClearCanvasEvent>((event, emit) {
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: [],
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    on<SelectToolEvent>((event, emit) {
      final defaultColor = _getColorForTool(event.tool, state.currentFigoType);
      emit(state.copyWith(
        currentTool: event.tool,
        currentColor: defaultColor ?? state.currentColor,
      ));
    });

    on<ChangeColorEvent>((event, emit) {
      emit(state.copyWith(currentColor: event.color));
    });

    on<ChangeStrokeWidthEvent>((event, emit) {
      emit(state.copyWith(currentStrokeWidth: event.strokeWidth));
    });

    // ── Удалить конкретное действие ───────────────────────────────────────
    on<DeleteActionEvent>((event, emit) {
      final updatedHistory =
          state.history.where((a) => a.id != event.actionId).toList();
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Загрузить историю из проекта (Fix #2) ─────────────────────────────
    // При загрузке — ПОЛНОСТЬЮ СБРАСЫВАЕМ оба стека,
    // чтобы Undo не позволял вернуться к предыдущему проекту.
    on<SetHistoryEvent>((event, emit) {
      emit(state.copyWith(
        history: event.history,
        undoStack: [],
        redoStack: [],
      ));
    });

    on<SetPatientIdEvent>((event, emit) {
      emit(state.copyWith(patientId: event.patientId));
    });

    on<ChangeFigoTypeEvent>((event, emit) {
      final defaultColor = _getColorForTool(state.currentTool, event.figoType);
      emit(state.copyWith(
        currentFigoType: event.figoType,
        currentColor: defaultColor ?? state.currentColor,
      ));
    });

    on<ToggleLineDashedEvent>((event, emit) {
      emit(state.copyWith(currentLineDashed: event.isDashed));
    });

    on<ImportCustomStampEvent>((event, emit) {
      final updatedStamps = List<String>.from(state.customStamps);
      if (!updatedStamps.contains(event.path)) {
        updatedStamps.add(event.path);
      }
      emit(state.copyWith(
        customStamps: updatedStamps,
        customStampPath: event.path,
        currentTool: ToolType.customStamp,
      ));
    });

    on<SelectCustomStampEvent>((event, emit) {
      emit(state.copyWith(
        customStampPath: event.path,
        currentTool: ToolType.customStamp,
      ));
    });

    // ── Тихое обновление истории (используется ластиком, без undoStack) ───
    on<UpdateHistoryWithoutUndoEvent>((event, emit) {
      emit(state.copyWith(history: event.history));
    });

    // ── Сохранить точку Undo (ластик фиксирует состояние перед стиранием) ─
    on<SaveUndoStateEvent>((event, emit) {
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(event.undoState),
      );
      emit(state.copyWith(
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Установка полного состояния (автосохранение) ──────────────────────
    on<SetFullStateEvent>((event, emit) {
      emit(state.copyWith(
        history: event.history,
        patientId: event.patientId,
        backgroundPath: event.backgroundPath,
        clearBackground: event.backgroundPath == null,
        undoStack: [],
        redoStack: [],
      ));
    });
  }

  Color? _getColorForTool(ToolType tool, String figoType) {
    switch (tool) {
      case ToolType.infiltrate:
        return const Color(0xFFD32F2F); // Red
      case ToolType.adhesions:
        return const Color(0xFF388E3C); // Green
      case ToolType.endometrioma:
        return const Color(0xFF5C4033); // Brown
      case ToolType.myoma:
        if (figoType == '0' || figoType == '1' || figoType == '2') {
          return const Color(0xFFE91E63); // Pink
        } else if (figoType == '3' || figoType == '4') {
          return const Color(0xFF1976D2); // Blue
        } else if (figoType == '5' || figoType == '6' || figoType == '7') {
          return const Color(0xFF388E3C); // Green
        } else if (figoType == '8') {
          return const Color(0xFF757575); // Grey
        } else {
          return const Color(0xFF9C27B0); // Purple/Hybrid
        }
      case ToolType.foci:
        return const Color(0xFFFFC107); // Yellow/Amber
      case ToolType.iud:
        return const Color(0xFF1976D2); // Blue
      default:
        return null;
    }
  }
}
