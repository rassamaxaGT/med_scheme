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
  final String patientId;
  final String currentFigoType;
  final bool currentLineDashed;
  final String? customStampPath;
  final List<String> customStamps;

  DrawState({
    required this.history,
    required this.undoStack,
    required this.redoStack,
    required this.currentTool,
    required this.currentColor,
    required this.currentStrokeWidth,
    this.backgroundPath,
    required this.patientId,
    required this.currentFigoType,
    required this.currentLineDashed,
    this.customStampPath,
    required this.customStamps,
  });

  factory DrawState.initial() {
    return DrawState(
      history: [],
      undoStack: [],
      redoStack: [],
      currentTool: ToolType.pencil,
      currentColor: const Color(0xFF000000),
      currentStrokeWidth: 4.0,
      backgroundPath: null,
      patientId: '',
      currentFigoType: '0',
      currentLineDashed: false,
      customStampPath: null,
      customStamps: [],
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
    String? patientId,
    String? currentFigoType,
    bool? currentLineDashed,
    String? customStampPath,
    List<String>? customStamps,
  }) {
    return DrawState(
      history: history ?? this.history,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
      backgroundPath: clearBackground ? null : (backgroundPath ?? this.backgroundPath),
      patientId: patientId ?? this.patientId,
      currentFigoType: currentFigoType ?? this.currentFigoType,
      currentLineDashed: currentLineDashed ?? this.currentLineDashed,
      customStampPath: customStampPath ?? this.customStampPath,
      customStamps: customStamps ?? this.customStamps,
    );
  }
}

