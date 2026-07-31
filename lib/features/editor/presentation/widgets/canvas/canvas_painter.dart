import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../../../domain/entities/draw_action.dart';

class CanvasPainter extends CustomPainter {
  final List<DrawAction> history;
  final DrawAction? activeAction;
  final ui.Image? backgroundImage;
  final Map<String, ui.Image> stampImages; // кешированные пользовательские PNG штампы
  final String? selectedActionId;
  final String? patientId;

  CanvasPainter({
    required this.history,
    this.activeAction,
    this.backgroundImage,
    this.stampImages = const {},
    this.selectedActionId,
    this.patientId,
  });


  @override
  void paint(Canvas canvas, Size size) {
    // 1. Отрисовка фонового изображения схемы
    if (backgroundImage != null) {
      paintImage(
        canvas: canvas,
        rect: Rect.fromLTWH(0, 0, size.width, size.height),
        image: backgroundImage!,
        fit: BoxFit.contain,
      );
    } else {
      // Если фона нет, рисуем белый холст
      final bgPaint = Paint()..color = Colors.white;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);
    }

    // 2. Отрисовка слоя рисования (с поддержкой прозрачности/ластика)
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    // Рисуем историю действий (пропуская тот, который перемещается в данный момент)
    for (final action in history) {
      if (action.id == selectedActionId && activeAction != null && activeAction!.id == selectedActionId) {
        continue;
      }
      _drawAction(canvas, action);
    }

    // Рисуем текущее активное действие (в процессе рисования или перетягивания)
    if (activeAction != null) {
      _drawAction(canvas, activeAction!);
    }

    // Отрисовка рамки выделения
    if (selectedActionId != null) {
      DrawAction? selectedAction = activeAction;
      if (selectedAction == null || selectedAction.id != selectedActionId) {
        try {
          selectedAction = history.firstWhere((a) => a.id == selectedActionId);
        } catch (_) {}
      }
      if (selectedAction != null) {
        final bounds = CanvasPainter.getActionBounds(selectedAction);
        if (bounds != Rect.zero) {
          _drawSelectionBorder(canvas, bounds);
        }
      }
    }

    canvas.restore();

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
      return Rect.fromCenter(center: action.position, width: 40.0, height: 40.0).inflate(8.0);
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

  void _drawSelectionBorder(Canvas canvas, Rect bounds) {
    final borderPaint = Paint()
      ..color = const Color(0xFF0F4C81) // Classic Blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRect(bounds, borderPaint);

    final handlePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final handleBorderPaint = Paint()
      ..color = const Color(0xFF0F4C81)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final double handleSize = 6.0;
    final corners = [
      bounds.topLeft,
      bounds.topRight,
      bounds.bottomLeft,
      bounds.bottomRight,
    ];

    for (final corner in corners) {
      final rect = Rect.fromCenter(center: corner, width: handleSize, height: handleSize);
      canvas.drawRect(rect, handlePaint);
      canvas.drawRect(rect, handleBorderPaint);
    }
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
      // Рисуем спайки («паутину»)
      canvas.drawPath(path, paint); // основная линия

      final double webStrokeWidth = stroke.strokeWidth * 0.3;
      final webPaint = Paint()
        ..color = stroke.color.withValues(alpha: 0.5)
        ..strokeWidth = webStrokeWidth
        ..style = PaintingStyle.stroke;

      // Соединяем точки паутиной
      for (int i = 0; i < stroke.points.length; i += 4) {
        final currentPoint = stroke.points[i];
        for (int j = i + 8; j < stroke.points.length; j += 8) {
          final targetPoint = stroke.points[j];
          final distance = (currentPoint - targetPoint).distance;
          if (distance > 10.0 && distance < 60.0) {
            canvas.drawLine(currentPoint, targetPoint, webPaint);
          }
        }
      }
    } else if (stroke.brushType == 'fibrosis' && !stroke.isEraser) {
      // Рисуем фиброз (сплошная линия со штриховкой)
      canvas.drawPath(path, paint);

      final double hatchSpacing = 15.0;
      final double hatchLength = 6.0;
      final hatchPaint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.strokeWidth * 0.7
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      for (final ui.PathMetric metric in path.computeMetrics()) {
        double distance = 0.0;
        while (distance < metric.length) {
          final tangent = metric.getTangentForOffset(distance);
          if (tangent != null) {
            final pos = tangent.position;
            final vec = tangent.vector;
            final normal = Offset(-vec.dy, vec.dx); // перпендикуляр

            // Рисуем штрих перпендикулярно пути
            canvas.drawLine(
              pos - normal * hatchLength,
              pos + normal * hatchLength,
              hatchPaint,
            );
          }
          distance += hatchSpacing;
        }
      }
    } else {
      // Обычная кисть (карандаш) или ластик
      canvas.drawPath(path, paint);
    }
  }


  void _drawShape(Canvas canvas, ShapeAction shape) {
    final paint = Paint()
      ..color = shape.color
      ..strokeWidth = shape.strokeWidth
      ..style = PaintingStyle.stroke;

    final rect = Rect.fromPoints(shape.startPoint, shape.endPoint);

    if (shape.shapeType == 'endometrioma') {
      // Шоколадная эндометриома: овал с коричневой штриховкой/заливкой
      final fillPaint = Paint()
        ..color = const Color(0x665C4033) // Прозрачный шоколадный цвет
        ..style = PaintingStyle.fill;
      canvas.drawOval(rect, fillPaint);

      paint.color = const Color(0xFF5C4033); // Темно-коричневая граница
      paint.strokeWidth = 3.0;
      canvas.drawOval(rect, paint);
    } else if (shape.shapeType == 'myoma') {
      final figo = shape.figoType ?? '0';
      
      Color getFigoColor(String type) {
        if (type == '0' || type == '1' || type == '2') return const Color(0xFFE91E63);
        if (type == '3' || type == '4') return const Color(0xFF1976D2);
        if (type == '5' || type == '6' || type == '7') return const Color(0xFF388E3C);
        return const Color(0xFF757575); // FIGO 8
      }

      final color = getFigoColor(figo);

      if (figo == '2-5') {
        // Гибрид: закраска в диагональную полоску (розовый + зеленый)
        canvas.save();
        canvas.clipPath(Path()..addOval(rect));
        
        // Розовый фон
        final pinkPaint = Paint()
          ..color = const Color(0xFFE91E63)
          ..style = PaintingStyle.fill;
        canvas.drawRect(rect, pinkPaint);

        // Зеленые диагональные полосы
        final stripePaint = Paint()
          ..color = const Color(0xFF388E3C)
          ..strokeWidth = 6.0
          ..style = PaintingStyle.stroke;
        
        for (double i = -rect.height; i < rect.width + rect.height; i += 16) {
          canvas.drawLine(
            Offset(rect.left + i, rect.top),
            Offset(rect.left + i + rect.height, rect.bottom),
            stripePaint,
          );
        }
        canvas.restore();
        
        paint.color = const Color(0xFF9C27B0);
        paint.strokeWidth = 3.0;
        canvas.drawOval(rect, paint);
      } else {
        // Обычная миома
        final fillPaint = Paint()
          ..color = color.withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawOval(rect, fillPaint);

        paint.color = color;
        paint.strokeWidth = 3.0;
        canvas.drawOval(rect, paint);
      }

      // Отрисовка номера FIGO по центру круга
      final textPainter = TextPainter(
        text: TextSpan(
          text: figo,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12.0,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black,
                offset: Offset(1, 1),
                blurRadius: 2,
              )
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        rect.center - Offset(textPainter.width / 2, textPainter.height / 2),
      );
    } else if (shape.shapeType == 'infiltrate') {
      // Инфильтрат: коричневая заливка + фестончатый контур
      final fillPaint = Paint()
        ..color = const Color(0x665C4033) // Коричневая заливка
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
    } else {
      // Дефолтный овал
      canvas.drawOval(rect, paint);
    }
  }


  void _drawStamp(Canvas canvas, StampAction stamp) {
    if (stamp.stampType == 'iud') {
      // Рисуем ВМС (спираль Т-образной формы)
      final paint = Paint()
        ..color = stamp.color
        ..strokeWidth = 3.0
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final center = stamp.position;
      final double width = 24.0;
      final double height = 30.0;

      // Т-образная форма
      canvas.drawLine(Offset(center.dx - width / 2, center.dy), Offset(center.dx + width / 2, center.dy), paint);
      canvas.drawLine(center, Offset(center.dx, center.dy + height), paint);

      // Спираль вокруг ножки
      final spiralPath = Path();
      for (double y = center.dy + 5; y < center.dy + height - 5; y += 1) {
        final double factor = (y - center.dy) / height;
        final double xOffset = center.dx + math.sin(y * 1.5) * (4.0 * (1.0 - factor * 0.5));
        if (y == center.dy + 5) {
          spiralPath.moveTo(xOffset, y);
        } else {
          spiralPath.lineTo(xOffset, y);
        }
      }
      canvas.drawPath(spiralPath, paint);
    } else if (stamp.stampType == 'foci') {
      // Эндометриоидный очаг (нерегулярная форма - пятно)
      final paint = Paint()
        ..color = stamp.color.withValues(alpha: 0.8)
        ..style = PaintingStyle.fill;

      final center = stamp.position;
      final double r = 8.0;

      // Рисуем органическую кляксу
      final path = Path();
      for (int i = 0; i < 8; i++) {
        final angle = (i * math.pi * 2) / 8;
        final double variance = 0.7 + 0.6 * math.sin(i * 3.0); // волнистость
        final x = center.dx + math.cos(angle) * r * variance;
        final y = center.dy + math.sin(angle) * r * variance;
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, paint);
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
  }

  // Устаревший метод _drawArrow удалён — вместо него используется _drawArrowInScreenSpace

  // Рисует текст стрелки в фиксированном масштабе — вызывается ПОСЛЕ canvas.restore()
  void _drawTextLabel(Canvas canvas, TextAction textAction, Offset screenStart) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: textAction.text,
        style: TextStyle(
          color: textAction.color,
          fontSize: 14.0,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.white.withValues(alpha: 0.8),
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    // Смещение текста немного в сторону от начала стрелки
    textPainter.paint(canvas, Offset(screenStart.dx + 5, screenStart.dy - 20));
  }


  @override
  bool shouldRepaint(covariant CanvasPainter oldDelegate) {
    return oldDelegate.history != history ||
        oldDelegate.activeAction != activeAction ||
        oldDelegate.backgroundImage != backgroundImage ||
        oldDelegate.stampImages != stampImages ||
        oldDelegate.selectedActionId != selectedActionId;
  }
}

extension OffsetNormalize on Offset {
  Offset normalize() {
    final d = distance;
    if (d == 0.0) return Offset.zero;
    return Offset(dx / d, dy / d);
  }
}
