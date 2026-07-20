import 'draw_action.dart';

class DrawState {
  final List<DrawAction> history;
  final List<DrawAction> redoStack;

  DrawState({
    required this.history,
    required this.redoStack,
  });

  factory DrawState.initial() {
    return DrawState(history: [], redoStack: []);
  }

  DrawState copyWith({
    List<DrawAction>? history,
    List<DrawAction>? redoStack,
  }) {
    return DrawState(
      history: history ?? this.history,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}
