import '../../domain/entities/draw_action.dart';
import 'dart:ui';

abstract class DrawEvent {}

class AddActionEvent extends DrawEvent {
  final DrawAction action;
  AddActionEvent(this.action);
}

class UpdateActionEvent extends DrawEvent {
  final DrawAction action;
  UpdateActionEvent(this.action);
}

class SetBackgroundEvent extends DrawEvent {
  final String? path;
  SetBackgroundEvent(this.path);
}

class UndoEvent extends DrawEvent {}

class RedoEvent extends DrawEvent {}

class ClearCanvasEvent extends DrawEvent {}

class SelectToolEvent extends DrawEvent {
  final ToolType tool;
  SelectToolEvent(this.tool);
}

class ChangeColorEvent extends DrawEvent {
  final Color color;
  ChangeColorEvent(this.color);
}

class ChangeStrokeWidthEvent extends DrawEvent {
  final double strokeWidth;
  ChangeStrokeWidthEvent(this.strokeWidth);
}

class DeleteActionEvent extends DrawEvent {
  final String actionId;
  DeleteActionEvent(this.actionId);
}

class SetHistoryEvent extends DrawEvent {
  final List<DrawAction> history;
  SetHistoryEvent(this.history);
}

class SetPatientIdEvent extends DrawEvent {
  final String patientId;
  SetPatientIdEvent(this.patientId);
}

class ChangeFigoTypeEvent extends DrawEvent {
  final String figoType;
  ChangeFigoTypeEvent(this.figoType);
}

class ToggleLineDashedEvent extends DrawEvent {
  final bool isDashed;
  ToggleLineDashedEvent(this.isDashed);
}

class ImportCustomStampEvent extends DrawEvent {
  final String path;
  ImportCustomStampEvent(this.path);
}

class SelectCustomStampEvent extends DrawEvent {
  final String path;
  SelectCustomStampEvent(this.path);
}

class UpdateHistoryWithoutUndoEvent extends DrawEvent {
  final List<DrawAction> history;
  UpdateHistoryWithoutUndoEvent(this.history);
}

class SaveUndoStateEvent extends DrawEvent {
  final List<DrawAction> undoState;
  SaveUndoStateEvent(this.undoState);
}

class SetFullStateEvent extends DrawEvent {
  final List<DrawAction> history;
  final String patientId;
  final String? backgroundPath;
  SetFullStateEvent({required this.history, required this.patientId, this.backgroundPath});
}

