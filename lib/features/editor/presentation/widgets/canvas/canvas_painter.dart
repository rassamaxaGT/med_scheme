import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/entities/draw_action.dart';

class CanvasPainter extends CustomPainter {
  final List<DrawAction> history;
  final DrawAction? activeAction;
  final ui.Image? backgroundImage;
  final List<String> backgroundPaths;
  final String? backgroundPath;
  final Map<String, ui.Image> bgImages; // кешированные фоновые изображения (в т.ч. пользовательские)
  final Map<String, ui.Image> stampImages; // кешированные пользовательские PNG штампы
  final String? selectedActionId;
  final String? patientId;

  CanvasPainter({
    required this.history,
    this.activeAction,
    this.backgroundImage,
    this.backgroundPaths = const [],
    this.backgroundPath,
    this.bgImages = const {},
    this.stampImages = const {},
    this.selectedActionId,
    this.patientId,
  });

  static Size getOriginalSchemeSize(String path) {
    if (path == 'assets/schemes/standart_endo.jpg') {
      return const Size(907.0, 1280.0);
    }
    return const Size(800.0, 600.0);
  }

  static double getSchemeAspectRatio(String path) {
    final size = getOriginalSchemeSize(path);
    return size.width / size.height;
  }

  static Size getCanvasBaseSize(List<String> paths) {
    if (paths.isEmpty) return const Size(800.0, 600.0);
    final count = paths.length;

    final double col0W = 600.0 * getSchemeAspectRatio(paths[0]);
    final double col1W = (paths.length > 1)
        ? 600.0 * getSchemeAspectRatio(paths[1])
        : 0.0;

    final int cols = count <= 1 ? 1 : 2;
    final int rows = count <= 2 ? 1 : (count / 2).ceil();

    final double totalW = cols == 1 ? col0W : (col0W + col1W);
    final double totalH = rows * 600.0;
    return Size(totalW, totalH);
  }

  static Rect getDrawRect(Size containerSize, Size baseSize) {
    final double drawHeight = containerSize.height;
    final double drawWidth = drawHeight * (baseSize.width / baseSize.height);

    final double left = drawWidth < containerSize.width ? (containerSize.width - drawWidth) / 2 : 0.0;
    const double top = 0.0;

    return Rect.fromLTWH(left, top, drawWidth, drawHeight);
  }

  static String getSchemeTitle(String path) {
    if (path.contains('pelvis_ls')) return 'Таз — LS view';
    if (path.contains('pelvis_sagittal')) return 'Таз — Сагиттальный срез';
    if (path.contains('pelvis_anterior')) return 'Таз — Передняя стенка';
    if (path.contains('pelvis_ileocecal')) return 'Таз — Илеоцекальный угол';
    if (path.contains('uterus_sagittal')) return 'Матка — Сагиттально';
    if (path.contains('uterus_frontal')) return 'Матка — Фронтально';
    if (path.contains('uterus_transverse')) return 'Матка — Поперечно';

    final fileName = path.split('/').last.split('\\').last;
    return 'Схема: $fileName';
  }

  void _drawSchemePlaceholderBadge(Canvas canvas, Rect drawRect, String path) {
    final borderPaint = Paint()
      ..color = const Color(0xFF90CAF9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final outerBounds = drawRect.deflate(12.0);
    canvas.drawRect(outerBounds, borderPaint);

    final double badgeWidth = math.min(380.0, drawRect.width - 32.0);
    final double badgeHeight = 120.0;
    final badgeRect = Rect.fromCenter(
      center: drawRect.center,
      width: badgeWidth,
      height: badgeHeight,
    );
    final badgeRRect = RRect.fromRectAndRadius(badgeRect, const Radius.circular(14.0));

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.08)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
    canvas.drawRRect(badgeRRect.shift(const Offset(0, 4)), shadowPaint);

    final fillPaint = Paint()..color = const Color(0xFFF4F8FB);
    canvas.drawRRect(badgeRRect, fillPaint);

    final strokePaint = Paint()
      ..color = const Color(0xFF0F4C81)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRRect(badgeRRect, strokePaint);

    final schemeTitle = getSchemeTitle(path);

    final titlePainter = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '📐 СХЕМА ПРОТОКОЛА УЗИ\n',
            style: TextStyle(
              color: Color(0xFF0F4C81),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.8,
            ),
          ),
          TextSpan(
            text: '$schemeTitle\n',
            style: const TextStyle(
              color: Color(0xFF1565C0),
              fontSize: 16,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const TextSpan(
            text: '[ Техническая заглушка • TODO: загрузить PNG ]\n',
            style: TextStyle(
              color: Color(0xFF757575),
              fontSize: 10,
              fontStyle: FontStyle.italic,
              height: 1.2,
            ),
          ),
          TextSpan(
            text: 'Файл: $path',
            style: const TextStyle(
              color: Color(0xFF9E9E9E),
              fontSize: 9,
              fontFamily: 'monospace',
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    titlePainter.layout(maxWidth: badgeWidth - 20.0);
    final textOffset = Offset(
      badgeRect.center.dx - titlePainter.width / 2,
      badgeRect.center.dy - titlePainter.height / 2,
    );
    titlePainter.paint(canvas, textOffset);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final activePaths = backgroundPaths.isNotEmpty
        ? backgroundPaths
        : (backgroundPath != null ? [backgroundPath!] : const <String>[]);

    final bgSize = getCanvasBaseSize(activePaths);
    final drawRect = getDrawRect(size, bgSize);

    // 1. Отрисовка фонового слоя схем
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(drawRect, bgPaint);

    if (activePaths.isNotEmpty) {
      final count = activePaths.length;
      final int cols = count == 1 ? 1 : 2;
      final int rows = count <= 2 ? 1 : (count / 2).ceil();
      final double cellH = drawRect.height / rows;

      // Вычисляем ширину каждой колонки на экране
      final double col0W = cellH * getSchemeAspectRatio(activePaths[0]);
      final double col1W = (activePaths.length > 1)
          ? cellH * getSchemeAspectRatio(activePaths[1])
          : 0.0;

      final gridDividerPaint = Paint()
        ..color = const Color(0xFFB0BEC5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;

      for (int i = 0; i < activePaths.length; i++) {
        final int col = i % cols;
        final int row = i ~/ cols;
        final double cellW = col == 0 ? col0W : col1W;
        final double cellLeft = col == 0 ? drawRect.left : (drawRect.left + col0W);
        final double cellTop = drawRect.top + row * cellH;

        final cellRect = Rect.fromLTWH(
          cellLeft,
          cellTop,
          cellW,
          cellH,
        );

        final path = activePaths[i];
        final ui.Image? bgImg = bgImages[path] ?? backgroundImage;
        if (bgImg != null && (bgImages.containsKey(path) || path == 'assets/schemes/standart_endo.jpg' || !path.startsWith('assets/schemes/'))) {
          paintImage(
            canvas: canvas,
            rect: cellRect,
            image: bgImg,
            fit: BoxFit.fill,
          );
        } else {
          _drawSchemePlaceholderBadge(canvas, cellRect, path);
        }
        canvas.drawRect(cellRect, gridDividerPaint);
      }
    }

    // 2. Отрисовка слоя рисования (с поддержкой прозрачности/ластика)
    canvas.save();
    canvas.clipRect(drawRect);
    canvas.translate(drawRect.left, drawRect.top);
    canvas.scale(drawRect.width / bgSize.width, drawRect.height / bgSize.height);

    canvas.saveLayer(Rect.fromLTWH(0, 0, bgSize.width, bgSize.height), Paint());

    final count = activePaths.length;
    final int cols = count <= 1 ? 1 : 2;

    // В оригинальном пространстве 600-height ширина первой колонки:
    final double col0W_orig = 600.0 * getSchemeAspectRatio(activePaths.isEmpty ? '' : activePaths[0]);

    // A. Отрисовка действий, привязанных к конкретным схемам
    for (int i = 0; i < activePaths.length; i++) {
      final path = activePaths[i];
      final int col = i % cols;
      final int row = i ~/ cols;
      
      final double cellLeft = col == 0 ? 0.0 : col0W_orig;
      final double cellTop = row * 600.0;
      
      final double origHeight = getOriginalSchemeSize(path).height;

      canvas.save();
      canvas.translate(cellLeft, cellTop);
      canvas.scale(600.0 / origHeight);

      for (final action in history) {
        if (action.targetSchemePath == path) {
          if (action.id == selectedActionId && activeAction != null && activeAction!.id == selectedActionId) {
            continue;
          }
          _drawAction(canvas, action);
        }
      }

      if (activeAction != null && activeAction!.targetSchemePath == path) {
        _drawAction(canvas, activeAction!);
      }

      canvas.restore();
    }

    // B. Отрисовка обычных (несвязанных со схемой) действий
    for (final action in history) {
      if (action.targetSchemePath == null) {
        if (action.id == selectedActionId && activeAction != null && activeAction!.id == selectedActionId) {
          continue;
        }
        _drawAction(canvas, action);
      }
    }

    if (activeAction != null && activeAction!.targetSchemePath == null) {
      _drawAction(canvas, activeAction!);
    }

    // C. Отрисовка рамки выделения
    if (selectedActionId != null) {
      DrawAction? selectedAction = activeAction;
      if (selectedAction == null || selectedAction.id != selectedActionId) {
        try {
          selectedAction = history.firstWhere((a) => a.id == selectedActionId);
        } catch (_) {}
      }
      if (selectedAction != null) {
        if (selectedAction.targetSchemePath != null) {
          final schemeIndex = activePaths.indexOf(selectedAction.targetSchemePath!);
          if (schemeIndex != -1) {
            final int col = schemeIndex % cols;
            final int row = schemeIndex ~/ cols;
            final cellOffset = Offset(col == 0 ? 0.0 : col0W_orig, row * 600.0);

            final double origHeight = getOriginalSchemeSize(selectedAction.targetSchemePath!).height;

            canvas.save();
            canvas.translate(cellOffset.dx, cellOffset.dy);
            canvas.scale(600.0 / origHeight);
            _drawSelectionBorder(canvas, selectedAction);
            canvas.restore();
          }
        } else {
          _drawSelectionBorder(canvas, selectedAction);
        }
      }
    }

    canvas.restore(); // for saveLayer
    canvas.restore(); // for clipping and translating

    if (patientId != null && patientId!.isNotEmpty) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: 'Пациент: $patientId',
          style: TextStyle(
            color: Colors.black,
            fontSize: 16.0,
            fontWeight: FontWeight.bold,
            backgroundColor: Colors.white.withValues(alpha: 0.7),
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(canvas, const Offset(16.0, 16.0));
    }
  }


  static Rect getOriginalActionBounds(DrawAction action) {
    if (action is StrokeAction) {
      if (action.points.isEmpty) return Rect.zero;
      double minX = action.points.first.dx;
      double maxX = action.points.first.dx;
      double minY = action.points.first.dy;
      double maxY = action.points.first.dy;
      for (final p in action.points) {
        if (p.dx < minX) minX = p.dx;
        if (p.dx > maxX) maxX = p.dx;
        if (p.dy < minY) minY = p.dy;
        if (p.dy > maxY) maxY = p.dy;
      }
      return Rect.fromLTRB(minX, minY, maxX, maxY).inflate(8.0);
    } else if (action is ShapeAction) {
      return Rect.fromPoints(action.startPoint, action.endPoint).inflate(8.0);
    } else if (action is StampAction) {
      double w = 40.0;
      double h = 40.0;
      if (action.stampType == 'iud') {
        w = 29.0;
        h = 36.0;
      } else if (action.stampType == 'foci') {
        final radius = action.strokeWidth * 2;
        w = radius * 2;
        h = radius * 2;
      } else if (action.stampType == 'follicle') {
        final radius = action.strokeWidth * 1.5;
        w = radius * 2;
        h = radius * 2;
      } else if (action.stampType == 'gui') {
        final size = action.strokeWidth * 2.5;
        w = size * 1.5;
        h = size * 1.5;
      } else if (action.stampType == 'polyp') {
        final size = action.strokeWidth * 2.0;
        w = size * 1.2;
        h = size * 1.8;
      }
      return Rect.fromCenter(center: action.position, width: w, height: h).inflate(8.0);
    } else if (action is TextAction) {
      final pointsRect = Rect.fromPoints(action.startPoint, action.endPoint);
      return pointsRect.inflate(15.0);
    }
    return Rect.zero;
  }

  static Rect getActionBounds(DrawAction action) {
    final original = getOriginalActionBounds(action);
    final double x1 = original.left * action.scaleX + action.offsetX;
    final double y1 = original.top * action.scaleY + action.offsetY;
    final double x2 = original.right * action.scaleX + action.offsetX;
    final double y2 = original.bottom * action.scaleY + action.offsetY;
    
    return Rect.fromLTRB(
      math.min(x1, x2),
      math.min(y1, y2),
      math.max(x1, x2),
      math.max(y1, y2),
    );
  }

  static Offset getTransformedActionPoint(DrawAction action, Offset localPoint) {
    final originalBounds = getOriginalActionBounds(action);
    double rotation = 0.0;
    Offset rotationCenter = originalBounds.center;

    if (action is ShapeAction) {
      rotation = action.rotation;
      rotationCenter = Rect.fromPoints(action.startPoint, action.endPoint).center;
    } else if (action is StampAction) {
      rotation = action.rotation;
      rotationCenter = action.position;
    }

    Offset p = localPoint;
    if (rotation != 0.0) {
      final dx = p.dx - rotationCenter.dx;
      final dy = p.dy - rotationCenter.dy;
      final cosA = math.cos(rotation);
      final sinA = math.sin(rotation);
      p = Offset(
        rotationCenter.dx + dx * cosA - dy * sinA,
        rotationCenter.dy + dx * sinA + dy * cosA,
      );
    }

    return Offset(
      p.dx * action.scaleX + action.offsetX,
      p.dy * action.scaleY + action.offsetY,
    );
  }

  void _drawSelectionBorder(Canvas canvas, DrawAction action) {
    final originalBounds = getOriginalActionBounds(action);
    if (originalBounds == Rect.zero) return;

    double rotation = 0.0;
    Offset rotationCenter = originalBounds.center;

    if (action is ShapeAction) {
      rotation = action.rotation;
      rotationCenter = Rect.fromPoints(action.startPoint, action.endPoint).center;
    } else if (action is StampAction) {
      rotation = action.rotation;
      rotationCenter = action.position;
    }

    canvas.save();
    canvas.translate(action.offsetX, action.offsetY);
    canvas.scale(action.scaleX, action.scaleY);

    if (rotation != 0.0) {
      canvas.translate(rotationCenter.dx, rotationCenter.dy);
      canvas.rotate(rotation);
      canvas.translate(-rotationCenter.dx, -rotationCenter.dy);
    }

    final double avgScale = ((action.scaleX.abs() + action.scaleY.abs()) / 2).clamp(0.1, 10.0);

    final borderPaint = Paint()
      ..color = const Color(0xFF0F4C81) // Classic Blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 / avgScale;

    canvas.drawRect(originalBounds, borderPaint);

    // Ножка для кнопки вращения
    final topCenter = Offset(originalBounds.center.dx, originalBounds.top);
    final rotationHandleCenter = Offset(topCenter.dx, originalBounds.top - (30.0 / avgScale));
    canvas.drawLine(topCenter, rotationHandleCenter, borderPaint);

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = const Color(0xFF0F4C81)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / avgScale;

    final rotationHandlePaint = Paint()
      ..color = const Color(0xFF4CAF50) // Зеленый для вращения
      ..style = PaintingStyle.fill;
    final rotationHandleBorder = Paint()
      ..color = const Color(0xFF2E7D32)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 / avgScale;

    final double handleSize = 10.0 / avgScale;
    final corners = [
      originalBounds.topLeft,
      originalBounds.topRight,
      originalBounds.bottomLeft,
      originalBounds.bottomRight,
    ];

    for (final corner in corners) {
      canvas.drawCircle(corner, handleSize / 2, handlePaint);
      canvas.drawCircle(corner, handleSize / 2, handleBorderPaint);
    }

    // Маркер вращения
    canvas.drawCircle(rotationHandleCenter, handleSize / 2, rotationHandlePaint);
    canvas.drawCircle(rotationHandleCenter, handleSize / 2, rotationHandleBorder);

    canvas.restore();
  }

  void _drawAction(Canvas canvas, DrawAction action) {
    // TextAction рисуется целиком ВНЕ трансформации — в экранных координатах,
    // чтобы толщина линии и размер текста оставались постоянными при масштабировании.
    if (action is TextAction) {
      _drawArrowInScreenSpace(canvas, action);
      return;
    }

    canvas.save();
    // Трансформация: rendered_p = p * scale + offset
    canvas.translate(action.offsetX, action.offsetY);
    canvas.scale(action.scaleX, action.scaleY);

    if (action is StrokeAction) {
      _drawStroke(canvas, action);
    } else if (action is ShapeAction) {
      _drawShape(canvas, action);
    } else if (action is StampAction) {
      _drawStamp(canvas, action);
    }

    canvas.restore();
  }

  // Рисует всю стрелку (линия + наконечник + текст) в экранных координатах,
  // минуя canvas.scale — толщина линии и текст не зависят от масштаба объекта.
  void _drawArrowInScreenSpace(Canvas canvas, TextAction action) {
    // Переводим start/end из объектного пространства в экранное
    final screenStart = Offset(
      action.startPoint.dx * action.scaleX + action.offsetX,
      action.startPoint.dy * action.scaleY + action.offsetY,
    );
    final screenEnd = Offset(
      action.endPoint.dx * action.scaleX + action.offsetX,
      action.endPoint.dy * action.scaleY + action.offsetY,
    );

    final paint = Paint()
      ..color = action.color
      ..strokeWidth = action.strokeWidth  // оригинальная толщина — без масштабирования
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (action.isDashed) {
      // Рисуем пунктирную линию расстояния
      final double dashWidth = 6.0;
      final double dashSpace = 4.0;
      double distance = 0.0;
      final double totalLength = (screenEnd - screenStart).distance;
      final double angle = math.atan2(screenEnd.dy - screenStart.dy, screenEnd.dx - screenStart.dx);
      
      while (distance < totalLength) {
        final start = screenStart + Offset(math.cos(angle) * distance, math.sin(angle) * distance);
        distance += dashWidth;
        final end = screenStart + Offset(
          math.cos(angle) * (distance < totalLength ? distance : totalLength),
          math.sin(angle) * (distance < totalLength ? distance : totalLength),
        );
        canvas.drawLine(start, end, paint);
        distance += dashSpace;
      }
    } else {
      // Линия стрелки
      canvas.drawLine(screenStart, screenEnd, paint);

      // Наконечник стрелки (в экранных координатах)
      const double arrowSize = 12.0;
      final double angle = math.atan2(screenEnd.dy - screenStart.dy, screenEnd.dx - screenStart.dx);
      canvas.drawLine(
        screenEnd,
        Offset(screenEnd.dx - arrowSize * math.cos(angle - math.pi / 6),
               screenEnd.dy - arrowSize * math.sin(angle - math.pi / 6)),
        paint,
      );
      canvas.drawLine(
        screenEnd,
        Offset(screenEnd.dx - arrowSize * math.cos(angle + math.pi / 6),
               screenEnd.dy - arrowSize * math.sin(angle + math.pi / 6)),
        paint,
      );
    }


    // Текст — тоже в экранных координатах, фиксированный размер
    if (action.text.isNotEmpty) {
      _drawTextLabel(canvas, action, screenStart);
    }
  }


  void _drawStroke(Canvas canvas, StrokeAction stroke) {
    if (stroke.points.length < 2) return;

    final paint = Paint()
      ..color = stroke.isEraser ? Colors.transparent : stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (stroke.isEraser) {
      paint.blendMode = BlendMode.clear;
    }

    // Создаем путь из точек
    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);
    for (int i = 1; i < stroke.points.length; i++) {
      path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
    }

    // Рендеринг в зависимости от типа кисти
    if (stroke.brushType == 'infiltrate' && !stroke.isEraser) {
      // Рисуем инфильтрат («колючую проволоку»)
      canvas.drawPath(path, paint); // основная линия

      // Рисуем колючки вдоль пути с помощью PathMetrics
      final double barbSpacing = 30.0;
      final double barbLength = 8.0;
      final barbPaint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth * 0.8
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final ui.PathMetric metric in path.computeMetrics()) {
        double distance = 0.0;
        while (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            final pos = tangent.position;
            final vec = tangent.vector; // направление касательной

            // Вектор перпендикуляра к касательной
            final normal = Offset(-vec.dy, vec.dx);

            // Рисуем крестообразную колючку
            canvas.drawLine(
              pos - normal * barbLength,
              pos + normal * barbLength,
              barbPaint,
            );
            canvas.drawLine(
              pos - (normal + vec).normalize() * barbLength,
              pos + (normal + vec).normalize() * barbLength,
              barbPaint,
            );
          }
          distance += barbSpacing;
        }
      }
    } else if (stroke.brushType == 'adhesions' && !stroke.isEraser) {
      // Рисуем спайки («паутину») без основной линии
      final double webStrokeWidth = stroke.strokeWidth * 0.3;
      final webPaint = Paint()
        ..color = stroke.color.withValues(alpha: 0.5)
        ..strokeWidth = webStrokeWidth
        ..style = PaintingStyle.stroke;

      // Соединяем точки паутиной
      for (int i = 0; i < stroke.points.length; i += 4) {
        final currentPoint = stroke.points[i];
        final int limit = math.min(stroke.points.length, i + 48);
        for (int j = i + 8; j < limit; j += 8) {
          final targetPoint = stroke.points[j];
          final distance = (currentPoint - targetPoint).distance;
          if (distance > 10.0 && distance < 60.0) {
            canvas.drawLine(currentPoint, targetPoint, webPaint);
          }
        }
      }
    } else if (stroke.brushType == 'fibrosis' && !stroke.isEraser) {
      // Рисуем фиброз (сплошная линия с хаотично направленными отростками/тяжами)
      canvas.drawPath(path, paint);

      final double hatchSpacing = 10.0;
      final double baseLength = 7.5;
      final hatchPaint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth * 0.75
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final ui.PathMetric metric in path.computeMetrics()) {
        double distance = 5.0;
        int step = 0;
        while (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            final pos = tangent.position;
            final vec = tangent.vector;
            final baseAngle = math.atan2(vec.dy, vec.dx);

            // Использование детерминированных хаотических углов и длин
            final seed = (distance * 137 + stroke.id.hashCode + step * 31).toInt();
            
            // Хаотичные отклонения углов
            final double dev1 = math.sin(seed * 0.17) * 1.5;
            final double dev2 = math.cos(seed * 0.29) * 1.9;
            final double dev3 = math.sin(seed * 0.43) * 2.3;

            // Вариативная длина отростков
            final double len1 = baseLength * (0.6 + 0.8 * math.sin(seed * 0.11).abs());
            final double len2 = baseLength * (0.6 + 0.9 * math.cos(seed * 0.23).abs());
            final double len3 = baseLength * (0.5 + 0.7 * math.sin(seed * 0.37).abs());

            // Отросток 1
            final a1 = baseAngle + dev1;
            canvas.drawLine(
              pos,
              pos + Offset(math.cos(a1) * len1, math.sin(a1) * len1),
              hatchPaint,
            );

            // Отросток 2
            final a2 = baseAngle + dev2;
            canvas.drawLine(
              pos,
              pos + Offset(math.cos(a2) * len2, math.sin(a2) * len2),
              hatchPaint,
            );

            // Отросток 3 (через один шаг для органичности)
            if (step % 2 == 0) {
              final a3 = baseAngle + dev3;
              canvas.drawLine(
                pos,
                pos + Offset(math.cos(a3) * len3, math.sin(a3) * len3),
                hatchPaint,
              );
            }
          }
          distance += hatchSpacing;
          step++;
        }
      }
    } else {
      // Обычная кисть (карандаш) или ластик
      if (stroke.brushType == 'pencil' && stroke.isDashed == true && !stroke.isEraser) {
        final dashPaint = Paint()
          ..color = stroke.color
          ..strokeWidth = stroke.strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final double dashLength = 10.0;
        final double spaceLength = 8.0;

        for (final ui.PathMetric metric in path.computeMetrics()) {
          double distance = 0.0;
          while (distance < metric.length) {
            final double nextDistance = math.min(distance + dashLength, metric.length);
            final ui.Path extract = metric.extractPath(distance, nextDistance);
            canvas.drawPath(extract, dashPaint);
            distance += dashLength + spaceLength;
          }
        }
      } else {
        canvas.drawPath(path, paint);
      }
    }
  }


  void _drawShape(Canvas canvas, ShapeAction shape) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromPoints(shape.startPoint, shape.endPoint);

    canvas.save();
    if (shape.rotation != 0.0) {
      final center = rect.center;
      canvas.translate(center.dx, center.dy);
      canvas.rotate(shape.rotation);
      canvas.translate(-center.dx, -center.dy);
    }

    if (shape.shapeType == 'endometrioma') {
      // Эндометриома («шоколадная киста»): полупрозрачный охристо-коричневый диск
      // с внутренним аморфным темным пятном содержимого и двойным контуром (как на фото)
      final center = rect.center;
      final radius = math.min(rect.width, rect.height) / 2;
      if (radius <= 0) return;

      // 1. Основная полупрозрачная коричнево-охристая заливка диска
      final fillPaint = Paint()
        ..color = const Color(0xDD7B3F35) // Насыщенный красновато-коричневый / охристый
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, fillPaint);

      // 2. Внутреннее неравномерное темное «шоколадное» пятно (содержимое кисты)
      final spotPaint = Paint()
        ..color = const Color(0xFF381210) // Темно-шоколадный / бордовый
        ..style = PaintingStyle.fill;

      final spotPath = Path();
      final int numPoints = 14;
      final double innerR = radius * 0.62;

      for (int i = 0; i < numPoints; i++) {
        final angle = (i * 2 * math.pi) / numPoints;
        final wave = 0.7 + 0.3 * math.sin(i * 2.3 + (shape.id.hashCode % 7));
        final r = innerR * wave;
        final x = center.dx + math.cos(angle) * r;
        final y = center.dy + math.sin(angle) * r;
        if (i == 0) {
          spotPath.moveTo(x, y);
        } else {
          spotPath.lineTo(x, y);
        }
      }
      spotPath.close();
      canvas.drawPath(spotPath, spotPaint);

      // 3. Красный ободок (как на фото)
      final redRingPaint = Paint()
        ..color = const Color(0xFFD32F2F) // Красный акцентный ободок
        ..strokeWidth = math.max(2.0, radius * 0.07)
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, redRingPaint);

      // 4. Тонкая черная внешняя линия
      final blackBorderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(center, radius, blackBorderPaint);
    } else if (shape.shapeType == 'myoma') {
      // Обычная миома (без FIGO-классификации)
      final fillPaint = Paint()
        ..color = shape.color.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      canvas.drawOval(rect, fillPaint);

      paint.color = shape.color;
      paint.strokeWidth = 3.0;
      canvas.drawOval(rect, paint);
    } else if (shape.shapeType == 'infiltrate') {
      // Глубокий эндометриоидный инфильтрат: коричневая заливка + фестончатый черный контур
      final fillPaint = Paint()
        ..color = shape.color
        ..style = PaintingStyle.fill;
      canvas.drawOval(rect, fillPaint);

      // Рисуем фестончатую границу
      final baseOvalPath = Path()..addOval(rect);
      final scallopedPath = Path();
      bool first = true;

      for (final ui.PathMetric metric in baseOvalPath.computeMetrics()) {
        double distance = 0.0;
        final double step = 6.0;
        final double frequency = 0.2;
        final double amplitude = 3.5;

        while (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            final pos = tangent.position;
            final vec = tangent.vector;
            final normal = Offset(-vec.dy, vec.dx);
            
            final wave = math.sin(distance * frequency) * amplitude;
            final point = pos + normal * wave;

            if (first) {
              scallopedPath.moveTo(point.dx, point.dy);
              first = false;
            } else {
              scallopedPath.lineTo(point.dx, point.dy);
            }
          }
          distance += step;
        }
      }
      scallopedPath.close();

      final borderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(scallopedPath, borderPaint);
    } else if (shape.shapeType == 'bowelInfiltrate') {
      // Инфильтрат кишки: нижняя половина эллипса с коричневой заливкой и фестончатым контуром
      final segmentPath = Path();
      segmentPath.addArc(rect, 0.0, math.pi);
      segmentPath.close();

      final fillPaint = Paint()
        ..color = const Color(0xFF5C4033) // Коричневая заливка
        ..style = PaintingStyle.fill;
      canvas.drawPath(segmentPath, fillPaint);

      final scallopedPath = Path();
      bool first = true;

      for (final ui.PathMetric metric in segmentPath.computeMetrics()) {
        double distance = 0.0;
        final double step = 6.0;
        final double frequency = 0.2;
        final double amplitude = 3.5;

        while (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            final pos = tangent.position;
            final vec = tangent.vector;
            final normal = Offset(-vec.dy, vec.dx);
            
            final wave = math.sin(distance * frequency) * amplitude;
            final point = pos + normal * wave;

            if (first) {
              scallopedPath.moveTo(point.dx, point.dy);
              first = false;
            } else {
              scallopedPath.lineTo(point.dx, point.dy);
            }
          }
          distance += step;
        }
      }
      scallopedPath.close();

      final borderPaint = Paint()
        ..color = Colors.black
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      canvas.drawPath(scallopedPath, borderPaint);
    } else if (shape.shapeType == 'adenomyosis') {
      // Наложение прошлой версии (гладкий размытый вишневый эллипс) и новой версии (рваный зубчатый край)
      final center = rect.center;
      final rx = rect.width / 2;
      final ry = rect.height / 2;
      if (rx <= 0 || ry <= 0) return;

      // 1. Прошлая версия (гладкое размытое ядро эллипса)
      final baseBlurPaint = Paint()
        ..color = const Color(0xFF880E4F).withValues(alpha: 0.85)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12.0);
      canvas.drawOval(rect, baseBlurPaint);

      final baseBorderPaint = Paint()
        ..color = const Color(0xFF880E4F)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);
      canvas.drawOval(rect, baseBorderPaint);

      // 2. Новая версия (наложенные внешние рваные зубчато-лепестковые края)
      final int numPoints = 28;
      final Path raggedPath = Path();

      for (int i = 0; i < numPoints; i++) {
        final angle = (i * 2 * math.pi) / numPoints;
        final wave1 = math.sin(i * 3.7 + (shape.id.hashCode % 7)) * 0.18;
        final wave2 = math.cos(i * 5.3 + (shape.id.hashCode % 11)) * 0.12;
        final factor = 0.92 + wave1 + wave2;

        final px = center.dx + math.cos(angle) * rx * factor;
        final py = center.dy + math.sin(angle) * ry * factor;

        if (i == 0) {
          raggedPath.moveTo(px, py);
        } else {
          final prevAngle = ((i - 1) * 2 * math.pi) / numPoints;
          final midAngle = (prevAngle + angle) / 2;
          final midWave = math.sin(midAngle * 4.1 + (shape.id.hashCode % 5)) * 0.22;
          final midFactor = 1.0 + midWave;

          final cx = center.dx + math.cos(midAngle) * rx * midFactor;
          final cy = center.dy + math.sin(midAngle) * ry * midFactor;

          raggedPath.quadraticBezierTo(cx, cy, px, py);
        }
      }
      raggedPath.close();

      // Внешнее размытое рваное ореольное поле
      final outerGlowPaint = Paint()
        ..color = const Color(0x99B83B52)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8.0);
      canvas.drawPath(raggedPath, outerGlowPaint);

      // Средний рваный контурный слой
      final midLayerPaint = Paint()
        ..color = const Color(0xCCBA3850)
        ..style = PaintingStyle.fill
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0);
      canvas.drawPath(raggedPath, midLayerPaint);
    } else if (shape.shapeType == 'gui') {
      // ГУИ (Головной убор индейца как форма с закругленными язычками)
      final strokePaint = Paint()
        ..color = const Color(0xFF4A148C)
        ..strokeWidth = shape.strokeWidth > 0 ? shape.strokeWidth : 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      final fillPaint = Paint()
        ..color = const Color(0xFF6A4C7D).withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;

      _drawGuiShape(canvas, rect, fillPaint, strokePaint);
    } else {
      // Дефолтный овал
      canvas.drawOval(rect, paint);
    }
    canvas.restore();
  }

  void _drawGuiShape(Canvas canvas, Rect bounds, Paint fillPaint, Paint strokePaint) {
    Rect rect = bounds;
    if (rect.width < 10.0 || rect.height < 10.0) {
      final center = rect.center;
      rect = Rect.fromCenter(center: center, width: 60.0, height: 36.0);
    }

    final double left = math.min(rect.left, rect.right);
    final double right = math.max(rect.left, rect.right);
    final double top = math.min(rect.top, rect.bottom);
    final double bottom = math.max(rect.top, rect.bottom);
    final double w = right - left;
    final double h = bottom - top;

    final path = Path();

    // 1. Левый округлый хвостик
    path.moveTo(left, top + h * 0.35);

    // 2. Верхняя вогнутая дуга (выемка по центру)
    path.cubicTo(
      left + w * 0.25, top + h * 0.6,
      left + w * 0.6, top + h * 0.1,
      right - w * 0.1, top + h * 0.05,
    );

    // 3. Заокругленный правый верхний край
    path.quadraticBezierTo(right, top + h * 0.1, right, top + h * 0.3);

    // 4. Первый зубчик справа (с округлым язычком)
    path.quadraticBezierTo(right - w * 0.05, top + h * 0.6, right - w * 0.12, top + h * 0.62);
    path.quadraticBezierTo(right - w * 0.2, top + h * 0.45, right - w * 0.25, top + h * 0.4);

    // 5. Второй зубчик справа (с округлым язычком)
    path.quadraticBezierTo(right - w * 0.22, top + h * 0.85, right - w * 0.32, top + h * 0.88);
    path.quadraticBezierTo(right - w * 0.42, top + h * 0.6, right - w * 0.48, top + h * 0.5);

    // 6. Центральный крупный округлый язычок/зубец
    path.quadraticBezierTo(left + w * 0.45, top + h * 0.98, left + w * 0.35, top + h * 1.0);
    path.quadraticBezierTo(left + w * 0.28, top + h * 0.65, left + w * 0.25, top + h * 0.5);

    // 7. Левый зубчик (с округлым язычком)
    path.quadraticBezierTo(left + w * 0.18, top + h * 0.75, left + w * 0.12, top + h * 0.72);
    path.quadraticBezierTo(left + w * 0.08, top + h * 0.5, left + w * 0.05, top + h * 0.42);

    // 8. Замыкание к левому хвостику
    path.quadraticBezierTo(left + w * 0.02, top + h * 0.38, left, top + h * 0.35);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }


  void _drawStamp(Canvas canvas, StampAction stamp) {
    canvas.save();
    if (stamp.rotation != 0.0) {
      canvas.translate(stamp.position.dx, stamp.position.dy);
      canvas.rotate(stamp.rotation);
      canvas.translate(-stamp.position.dx, -stamp.position.dy);
    }

    if (stamp.stampType == 'iud') {
      // Рисуем ВМС
      final paint = Paint()
        ..color = stamp.color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final center = stamp.position;
      final double width = 29.0;
      final double height = 36.0;

      canvas.drawLine(Offset(center.dx - width / 2, center.dy), Offset(center.dx + width / 2, center.dy), paint);
      canvas.drawLine(center, Offset(center.dx, center.dy + height), paint);
    } else if (stamp.stampType == 'foci') {
      // Эндометриоидный очаг
      final paint = Paint()
        ..color = stamp.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      final center = stamp.position;
      final double rOuter = stamp.strokeWidth * 2;
      final double rInner = rOuter / 2;

      final path = Path();
      for (int i = 0; i < 16; i++) {
        final angle = (i * math.pi) / 8;
        final r = (i % 2 == 0) ? rOuter : rInner;
        final x = center.dx + math.cos(angle) * r;
        final y = center.dy + math.sin(angle) * r;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
    } else if (stamp.stampType == 'follicle') {
      final paint = Paint()
        ..color = const Color(0xFF03A9F4)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final center = stamp.position;
      final double radius = stamp.strokeWidth * 1.5;
      canvas.drawCircle(center, radius, paint);
    } else if (stamp.stampType == 'gui') {
      final center = stamp.position;
      final double size = stamp.strokeWidth * 2.5;
      final rect = Rect.fromCenter(center: center, width: size * 2.2, height: size * 1.2);

      final strokePaint = Paint()
        ..color = const Color(0xFF4A148C)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round;

      final fillPaint = Paint()
        ..color = const Color(0xFF6A4C7D).withValues(alpha: 0.65)
        ..style = PaintingStyle.fill;

      _drawGuiShape(canvas, rect, fillPaint, strokePaint);
    } else if (stamp.stampType == 'polyp') {
      // Полип эндометрия (округлая капля на ножке со штриховкой, масштабируемый)
      final center = stamp.position;
      final double size = stamp.strokeWidth * 2.0;

      final paint = Paint()
        ..color = const Color(0xFFFF7043) // Peach
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      final fillPaint = Paint()
        ..color = const Color(0xFFFF7043).withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;

      // Ножка
      canvas.drawLine(center, Offset(center.dx, center.dy - size * 0.8), paint);

      // Головка
      final headRect = Rect.fromCenter(
        center: Offset(center.dx, center.dy - size * 1.3),
        width: size * 1.2,
        height: size * 1.0,
      );
      canvas.drawOval(headRect, fillPaint);
      canvas.drawOval(headRect, paint);

      // Внутренняя штриховка
      final hatchPaint = Paint()
        ..color = const Color(0xFFFF7043).withValues(alpha: 0.7)
        ..strokeWidth = 1.0;

      final double headCenterY = center.dy - size * 1.3;
      canvas.drawLine(
        Offset(center.dx - size * 0.3, headCenterY - size * 0.1),
        Offset(center.dx + size * 0.3, headCenterY + size * 0.3),
        hatchPaint,
      );
      canvas.drawLine(
        Offset(center.dx - size * 0.4, headCenterY - size * 0.3),
        Offset(center.dx + size * 0.2, headCenterY + size * 0.1),
        hatchPaint,
      );
      canvas.drawLine(
        Offset(center.dx - size * 0.2, headCenterY + size * 0.1),
        Offset(center.dx + size * 0.4, headCenterY - size * 0.3),
        hatchPaint,
      );
    } else if (stamp.stampType == 'custom' && stamp.customStampPath != null) {
      // Рисуем пользовательский PNG штамп
      final image = stampImages[stamp.customStampPath];
      if (image != null) {
        final double size = 40.0;
        final rect = Rect.fromCenter(center: stamp.position, width: size, height: size);
        canvas.drawImageRect(
          image,
          Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
          rect,
          Paint(),
        );
      }
    }
    canvas.restore();
  }

  // Устаревший метод _drawArrow удалён — вместо него используется _drawArrowInScreenSpace

  // Рисует текст стрелки в фиксированном масштабе — вызывается ПОСЛЕ canvas.restore()
  void _drawTextLabel(Canvas canvas, TextAction textAction, Offset screenStart) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: textAction.text,
        style: TextStyle(
          color: textAction.color,
          fontSize: 13.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();

    final double shelfLength = textPainter.width + 10;
    final double textX = screenStart.dx + 5;
    final double textY = screenStart.dy - textPainter.height - 2;

    final paint = Paint()
      ..color = textAction.color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Горизонтальная полка под текстом
    canvas.drawLine(
      screenStart,
      Offset(screenStart.dx + shelfLength, screenStart.dy),
      paint,
    );

    textPainter.paint(canvas, Offset(textX, textY));
  }


  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.activeAction != activeAction ||
        oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.stampImages != stampImages ||
        oldDelegate.selectedActionId != selectedActionId ||
        oldDelegate.patientId != patientId;
  }
}

extension OffsetNormalize on Offset {
  Offset normalize() {
    final d = distance;
    if (d == 0.0) return Offset.zero;
    return Offset(dx / d, dy / d);
  }
}
