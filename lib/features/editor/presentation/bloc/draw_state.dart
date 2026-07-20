import 'dart:ui';
import '../../domain/entities/draw_action.dart';

class DrawState {
  final List<DrawAction> history;
  final List<List<DrawAction>> undoStack;
  final List<List<DrawAction>> redoStack;
  final ToolType currentTool;
  final Color currentColor;
  final double currentStrokeWidth;
  final String? backgroundPath;

  DrawState({
    required this.history,
    required this.undoStack,
    required this.redoStack,
    required this.currentTool,
    required this.currentColor,
    required this.currentStrokeWidth,
    this.backgroundPath,
  });

  factory DrawState.initial() {
    return DrawState(
      history: [],
      undoStack: [],
      redoStack: [],
      currentTool: ToolType.pencil,
      currentColor: const Color(0xFF000000), // По умолчанию черный цвет
      currentStrokeWidth: 4.0,
      backgroundPath: null,
    );
  }

  DrawState copyWith({
    List<DrawAction>? history,
    List<List<DrawAction>>? undoStack,
    List<List<DrawAction>>? redoStack,
    ToolType? currentTool,
    Color? currentColor,
    double? currentStrokeWidth,
    String? backgroundPath,
    bool clearBackground = false,
  }) {
    return DrawState(
      history: history ?? this.history,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
      backgroundPath: clearBackground ? null : (backgroundPath ?? this.backgroundPath),
    );
  }
}
