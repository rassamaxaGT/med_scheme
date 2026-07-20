import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/draw_action.dart';
import 'draw_event.dart';
import 'draw_state.dart';

class DrawBloc extends Bloc<DrawEvent, DrawState> {
  DrawBloc() : super(DrawState.initial()) {
    on<AddActionEvent>((event, emit) {
      final updatedHistory = List<DrawAction>.from(state.history)..add(event.action);
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(state.history);
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [], // Сбрасываем redoStack при добавлении нового действия
      ));
    });

    on<UpdateActionEvent>((event, emit) {
      final updatedHistory = state.history.map((action) {
        return action.id == event.action.id ? event.action : action;
      }).toList();
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(state.history);
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    on<SetBackgroundEvent>((event, emit) {
      if (event.path == null) {
        emit(state.copyWith(clearBackground: true));
      } else {
        emit(state.copyWith(backgroundPath: event.path));
      }
    });

    on<UndoEvent>((event, emit) {
      if (state.undoStack.isEmpty) return;
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack);
      final previousHistory = updatedUndo.removeLast();
      final updatedRedo = List<List<DrawAction>>.from(state.redoStack)..add(state.history);
      emit(state.copyWith(
        history: previousHistory,
        undoStack: updatedUndo,
        redoStack: updatedRedo,
      ));
    });

    on<RedoEvent>((event, emit) {
      if (state.redoStack.isEmpty) return;
      final updatedRedo = List<List<DrawAction>>.from(state.redoStack);
      final nextHistory = updatedRedo.removeLast();
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(state.history);
      emit(state.copyWith(
        history: nextHistory,
        undoStack: updatedUndo,
        redoStack: updatedRedo,
      ));
    });

    on<ClearCanvasEvent>((event, emit) {
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(state.history);
      emit(state.copyWith(
        history: [],
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    on<SelectToolEvent>((event, emit) {
      emit(state.copyWith(currentTool: event.tool));
    });

    on<ChangeColorEvent>((event, emit) {
      emit(state.copyWith(currentColor: event.color));
    });

    on<ChangeStrokeWidthEvent>((event, emit) {
      emit(state.copyWith(currentStrokeWidth: event.strokeWidth));
    });

    on<DeleteActionEvent>((event, emit) {
      final updatedHistory = state.history.where((a) => a.id != event.actionId).toList();
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(state.history);
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    on<SetHistoryEvent>((event, emit) {
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(state.history);
      emit(state.copyWith(
        history: event.history,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });
  }
}
