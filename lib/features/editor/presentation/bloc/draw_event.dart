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
