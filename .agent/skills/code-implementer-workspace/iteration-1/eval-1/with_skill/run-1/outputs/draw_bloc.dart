import 'package:flutter_bloc/flutter_bloc.dart';
import 'draw_event.dart';
import 'draw_state.dart';

class DrawBloc extends Bloc<DrawEvent, DrawState> {
  DrawBloc() : super(DrawState.initial()) {
    on<AddStrokeEvent>((event, emit) {
      final updatedHistory = List<DrawAction>.from(state.history)..add(event.action);
      emit(state.copyWith(
        history: updatedHistory,
        redoStack: [], // Clear redo stack on new action
      ));
    });

    on<UndoEvent>((event, emit) {
      if (state.history.isEmpty) return;
      final updatedHistory = List<DrawAction>.from(state.history);
      final lastAction = updatedHistory.removeLast();
      final updatedRedo = List<DrawAction>.from(state.redoStack)..add(lastAction);
      emit(state.copyWith(
        history: updatedHistory,
        redoStack: updatedRedo,
      ));
    });

    on<RedoEvent>((event, emit) {
      if (state.redoStack.isEmpty) return;
      final updatedRedo = List<DrawAction>.from(state.redoStack);
      final actionToRedo = updatedRedo.removeLast();
      final updatedHistory = List<DrawAction>.from(state.history)..add(actionToRedo);
      emit(state.copyWith(
        history: updatedHistory,
        redoStack: updatedRedo,
      ));
    });

    on<ClearCanvasEvent>((event, emit) {
      emit(DrawState.initial());
    });
  }
}
