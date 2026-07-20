import 'draw_action.dart';

abstract class DrawEvent {}

class AddStrokeEvent extends DrawEvent {
  final DrawAction action;
  AddStrokeEvent(this.action);
}

class UndoEvent extends DrawEvent {}

class RedoEvent extends DrawEvent {}

class ClearCanvasEvent extends DrawEvent {}
