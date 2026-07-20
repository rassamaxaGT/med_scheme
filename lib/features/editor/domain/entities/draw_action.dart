import 'dart:ui';

enum ToolType {
  pencil,
  eraser,
  infiltrate,   // колючая проволока (инфильтрат)
  adhesions,    // паутина (спайки)
  endometrioma, // овал (шоколадный)
  myoma,        // овал (бледно-розовый)
  iud,          // штамп-спираль (ВМС)
  foci,         // штамп-пятно (очаги)
  arrow,        // стрелка с текстом
  customStamp,  // пользовательский штамп из PNG
  move          // перемещение нарисованных объектов
}

abstract class DrawAction {
  final String id;
  final Color color;
  final double strokeWidth;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;

  DrawAction({
    required this.id,
    required this.color,
    required this.strokeWidth,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
  });
}

class StrokeAction extends DrawAction {
  final List<Offset> points;
  final bool isEraser;
  final String brushType; // 'pencil', 'infiltrate', 'adhesions'

  StrokeAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.points,
    this.isEraser = false,
    this.brushType = 'pencil',
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
  });
}

class ShapeAction extends DrawAction {
  final Offset startPoint;
  final Offset endPoint;
  final String shapeType; // 'endometrioma', 'myoma'

  ShapeAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.startPoint,
    required this.endPoint,
    required this.shapeType,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
  });
}

class StampAction extends DrawAction {
  final Offset position;
  final String stampType; // 'iud', 'foci', 'custom'
  final String? customStampPath; // путь к файлу для пользовательского штампа

  StampAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.position,
    required this.stampType,
    this.customStampPath,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
  });
}

class TextAction extends DrawAction {
  final Offset startPoint;
  final Offset endPoint; // направление стрелки
  final String text;

  TextAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.startPoint,
    required this.endPoint,
    required this.text,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
  });
}
