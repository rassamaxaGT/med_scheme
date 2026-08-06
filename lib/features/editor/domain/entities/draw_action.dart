import 'dart:ui';

enum ToolType {
  pencil,
  eraser,
  infiltrate,   // эллипс с фестончатым контуром (инфильтрат)
  adhesions,    // паутина (спайки)
  fibrosis,     // кисть фиброза
  endometrioma, // овал (шоколадный)
  myoma,        // круг
  iud,          // штамп-спираль (ВМС)
  foci,         // штамп-пятно (очаги)
  arrow,        // стрелка с текстом
  customStamp,  // пользовательский штамп из PNG
  move,         // перемещение нарисованных объектов
  // Новые инструменты
  bowelInfiltrate,
  gui,
  follicle,
  adenomyosis,
  polyp
}

abstract class DrawAction {
  final String id;
  final Color color;
  final double strokeWidth;
  final double scaleX;
  final double scaleY;
  final double offsetX;
  final double offsetY;
  final String? targetSchemePath;

  DrawAction({
    required this.id,
    required this.color,
    required this.strokeWidth,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.targetSchemePath,
  });
}

class StrokeAction extends DrawAction {
  final List<Offset> points;
  final bool isEraser;
  final String brushType; // 'pencil', 'adhesions', 'fibrosis'
  final bool isDashed;

  StrokeAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.points,
    this.isEraser = false,
    this.brushType = 'pencil',
    this.isDashed = false,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
    super.targetSchemePath,
  });
}

class ShapeAction extends DrawAction {
  final Offset startPoint;
  final Offset endPoint;
  final String shapeType; // 'endometrioma', 'myoma', 'infiltrate'
  final String? figoType; // для миом: '0','1','2','3','4','5','6','7','8','2-5'
  final double rotation;

  ShapeAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.startPoint,
    required this.endPoint,
    required this.shapeType,
    this.figoType,
    this.rotation = 0.0,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
    super.targetSchemePath,
  });
}

class StampAction extends DrawAction {
  final Offset position;
  final String stampType; // 'iud', 'foci', 'custom'
  final String? customStampPath; // путь к файлу для пользовательского штампа
  final double rotation;

  StampAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.position,
    required this.stampType,
    this.customStampPath,
    this.rotation = 0.0,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
    super.targetSchemePath,
  });
}

class TextAction extends DrawAction {
  final Offset startPoint;
  final Offset endPoint; // направление стрелки / конец линии расстояния
  final String text;
  final bool isDashed; // пунктирная линия расстояния

  TextAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.startPoint,
    required this.endPoint,
    required this.text,
    this.isDashed = false,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
    super.targetSchemePath,
  });
}
