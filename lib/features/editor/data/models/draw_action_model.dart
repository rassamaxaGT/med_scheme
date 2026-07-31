import 'dart:ui';
import '../../domain/entities/draw_action.dart';

class DrawActionModel {
  static Map<String, dynamic> toJson(DrawAction action) {
    if (action is StrokeAction) {
      return {
        'type': 'stroke',
        'id': action.id,
        'color': action.color.toARGB32(),
        'strokeWidth': action.strokeWidth,
        'points': action.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'isEraser': action.isEraser,
        'brushType': action.brushType,
        'scaleX': action.scaleX,
        'scaleY': action.scaleY,
        'offsetX': action.offsetX,
        'offsetY': action.offsetY,
      };
    } else if (action is ShapeAction) {
      return {
        'type': 'shape',
        'id': action.id,
        'color': action.color.toARGB32(),
        'strokeWidth': action.strokeWidth,
        'startPoint': {'x': action.startPoint.dx, 'y': action.startPoint.dy},
        'endPoint': {'x': action.endPoint.dx, 'y': action.endPoint.dy},
        'shapeType': action.shapeType,
        'figoType': action.figoType,
        'scaleX': action.scaleX,
        'scaleY': action.scaleY,
        'offsetX': action.offsetX,
        'offsetY': action.offsetY,
      };
    } else if (action is StampAction) {
      return {
        'type': 'stamp',
        'id': action.id,
        'color': action.color.toARGB32(),
        'strokeWidth': action.strokeWidth,
        'position': {'x': action.position.dx, 'y': action.position.dy},
        'stampType': action.stampType,
        'customStampPath': action.customStampPath,
        'scaleX': action.scaleX,
        'scaleY': action.scaleY,
        'offsetX': action.offsetX,
        'offsetY': action.offsetY,
      };
    } else if (action is TextAction) {
      return {
        'type': 'text',
        'id': action.id,
        'color': action.color.toARGB32(),
        'strokeWidth': action.strokeWidth,
        'startPoint': {'x': action.startPoint.dx, 'y': action.startPoint.dy},
        'endPoint': {'x': action.endPoint.dx, 'y': action.endPoint.dy},
        'text': action.text,
        'isDashed': action.isDashed,
        'scaleX': action.scaleX,
        'scaleY': action.scaleY,
        'offsetX': action.offsetX,
        'offsetY': action.offsetY,
      };
    }
    throw UnimplementedError('Unknown DrawAction subclass: ${action.runtimeType}');
  }

  static DrawAction fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    final id = json['id'] as String;
    final color = Color(json['color'] as int);
    final strokeWidth = (json['strokeWidth'] as num).toDouble();
    final scaleX = (json['scaleX'] as num?)?.toDouble() ?? 1.0;
    final scaleY = (json['scaleY'] as num?)?.toDouble() ?? 1.0;
    final offsetX = (json['offsetX'] as num?)?.toDouble() ?? 0.0;
    final offsetY = (json['offsetY'] as num?)?.toDouble() ?? 0.0;

    switch (type) {
      case 'stroke':
        return StrokeAction(
          id: id,
          color: color,
          strokeWidth: strokeWidth,
          points: (json['points'] as List)
              .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
              .toList(),
          isEraser: json['isEraser'] as bool? ?? false,
          brushType: json['brushType'] as String? ?? 'pencil',
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
        );
      case 'shape':
        return ShapeAction(
          id: id,
          color: color,
          strokeWidth: strokeWidth,
          startPoint: Offset(
            (json['startPoint']['x'] as num).toDouble(),
            (json['startPoint']['y'] as num).toDouble(),
          ),
          endPoint: Offset(
            (json['endPoint']['x'] as num).toDouble(),
            (json['endPoint']['y'] as num).toDouble(),
          ),
          shapeType: json['shapeType'] as String,
          figoType: json['figoType'] as String?,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
        );
      case 'stamp':
        return StampAction(
          id: id,
          color: color,
          strokeWidth: strokeWidth,
          position: Offset(
            (json['position']['x'] as num).toDouble(),
            (json['position']['y'] as num).toDouble(),
          ),
          stampType: json['stampType'] as String,
          customStampPath: json['customStampPath'] as String?,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
        );
      case 'text':
        return TextAction(
          id: id,
          color: color,
          strokeWidth: strokeWidth,
          startPoint: Offset(
            (json['startPoint']['x'] as num).toDouble(),
            (json['startPoint']['y'] as num).toDouble(),
          ),
          endPoint: Offset(
            (json['endPoint']['x'] as num).toDouble(),
            (json['endPoint']['y'] as num).toDouble(),
          ),
          text: json['text'] as String,
          isDashed: json['isDashed'] as bool? ?? false,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
        );
      default:
        throw UnimplementedError('Unknown DrawAction type in JSON: $type');
    }
  }
}
