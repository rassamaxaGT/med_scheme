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

    on<SetPatientIdEvent>((event, emit) {
      emit(state.copyWith(patientId: event.patientId));
    });

    on<ChangeFigoTypeEvent>((event, emit) {
      emit(state.copyWith(currentFigoType: event.figoType));
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

    on<UpdateHistoryWithoutUndoEvent>((event, emit) {
      emit(state.copyWith(
        history: event.history,
      ));
    });

    on<SaveUndoStateEvent>((event, emit) {
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack)..add(event.undoState);
      emit(state.copyWith(
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });
  }
}
