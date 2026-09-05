import 'dart:ui';

enum ToolType {
  pencil,
  eraser,
  infiltrate,   // эллипс с фестончатым контуром (инфильтрат)
  adhesions,    // паутина (спайки)
  fibrosis,     // кисть фиброза
  endometrioma, // овал (шоколадный)
  myoma,        // условное обозначение миомы (круг/овал)
  myomaStamp,   // штамп миомы (PNG)
  iud,          // условное обозначение ВМС (Т-образный штамп)
  iudStamp,     // штамп Мирена / ВМС (PNG)
  foci,         // штамп-пятно (очаги)
  arrow,        // стрелка с текстом
  customStamp,  // пользовательский штамп из PNG
  move,         // перемещение нарисованных объектов
  // Новые инструменты
  bowelInfiltrate,  // штамп инфильтрата кишки (PNG infiltrat.png)
  infiltrateStamp2, // штамп инфильтрата 2 (PNG infiltrat2.png)
  bowelInfiltrate2, // прежний инфильтрат кишки (дуга с фестонами)
  gui,
  follicle,
  cyst, // киста (измеряемая по размеру, без заливки)
  adenomyosis,
  polyp,
  spray // баллончик / спрей
}

class EraserMaskData {
  final List<Offset> localPoints;
  final double strokeWidth;
  final EraserTarget target;

  EraserMaskData({
    required this.localPoints,
    required this.strokeWidth,
    this.target = EraserTarget.annotationsOnly,
  });
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
  final List<EraserMaskData>? eraserMasks;

  DrawAction({
    required this.id,
    required this.color,
    required this.strokeWidth,
    this.scaleX = 1.0,
    this.scaleY = 1.0,
    this.offsetX = 0.0,
    this.offsetY = 0.0,
    this.targetSchemePath,
    this.eraserMasks,
  });

  DrawAction copyWithEraserMasks(List<EraserMaskData> masks);
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
    super.eraserMasks,
  });

  @override
  StrokeAction copyWithEraserMasks(List<EraserMaskData> masks) {
    return StrokeAction(
      id: id,
      color: color,
      strokeWidth: strokeWidth,
      points: points,
      isEraser: isEraser,
      brushType: brushType,
      isDashed: isDashed,
      scaleX: scaleX,
      scaleY: scaleY,
      offsetX: offsetX,
      offsetY: offsetY,
      targetSchemePath: targetSchemePath,
      eraserMasks: masks,
    );
  }
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
    super.eraserMasks,
  });

  @override
  ShapeAction copyWithEraserMasks(List<EraserMaskData> masks) {
    return ShapeAction(
      id: id,
      color: color,
      strokeWidth: strokeWidth,
      startPoint: startPoint,
      endPoint: endPoint,
      shapeType: shapeType,
      figoType: figoType,
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
      offsetX: offsetX,
      offsetY: offsetY,
      targetSchemePath: targetSchemePath,
      eraserMasks: masks,
    );
  }
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
    super.eraserMasks,
  });

  @override
  StampAction copyWithEraserMasks(List<EraserMaskData> masks) {
    return StampAction(
      id: id,
      color: color,
      strokeWidth: strokeWidth,
      position: position,
      stampType: stampType,
      customStampPath: customStampPath,
      rotation: rotation,
      scaleX: scaleX,
      scaleY: scaleY,
      offsetX: offsetX,
      offsetY: offsetY,
      targetSchemePath: targetSchemePath,
      eraserMasks: masks,
    );
  }
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
    super.eraserMasks,
  });

  @override
  TextAction copyWithEraserMasks(List<EraserMaskData> masks) {
    return TextAction(
      id: id,
      color: color,
      strokeWidth: strokeWidth,
      startPoint: startPoint,
      endPoint: endPoint,
      text: text,
      isDashed: isDashed,
      scaleX: scaleX,
      scaleY: scaleY,
      offsetX: offsetX,
      offsetY: offsetY,
      targetSchemePath: targetSchemePath,
      eraserMasks: masks,
    );
  }
}

enum EraserTarget {
  /// Стирает только условные обозначения (маркеры, линии, фигуры), не трогая фоновый рисунок
  annotationsOnly,

  /// Стирает только фоновый рисунок схемы, не трогая нанесенные объекты
  backgroundOnly,

  /// Стирает всё, включая линии фонового рисунка медицинской схемы и нанесенные объекты
  everything,
}

class EraserStrokeAction extends DrawAction {
  final List<Offset> points;
  final EraserTarget target;

  EraserStrokeAction({
    required super.id,
    required super.strokeWidth,
    required this.points,
    this.target = EraserTarget.annotationsOnly,
    super.scaleX,
    super.scaleY,
    super.offsetX,
    super.offsetY,
    super.targetSchemePath,
    super.eraserMasks,
  }) : super(color: const Color(0x00000000));

  @override
  EraserStrokeAction copyWithEraserMasks(List<EraserMaskData> masks) {
    return EraserStrokeAction(
      id: id,
      strokeWidth: strokeWidth,
      points: points,
      target: target,
      scaleX: scaleX,
      scaleY: scaleY,
      offsetX: offsetX,
      offsetY: offsetY,
      targetSchemePath: targetSchemePath,
      eraserMasks: masks,
    );
  }
}

