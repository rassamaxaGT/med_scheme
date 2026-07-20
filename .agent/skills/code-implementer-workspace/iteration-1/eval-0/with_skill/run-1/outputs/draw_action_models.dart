import 'dart:ui';
import 'draw_action.dart';

class StrokeAction extends DrawAction {
  final List<Offset> points;
  final bool isEraser;

  StrokeAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.points,
    this.isEraser = false,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'stroke',
      'id': id,
      'color': color.value,
      'strokeWidth': strokeWidth,
      'points': points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
      'isEraser': isEraser,
    };
  }

  factory StrokeAction.fromJson(Map<String, dynamic> json) {
    return StrokeAction(
      id: json['id'] as String,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      points: (json['points'] as List)
          .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
          .toList(),
      isEraser: json['isEraser'] as bool? ?? false,
    );
  }
}

class ShapeAction extends DrawAction {
  final Offset startPoint;
  final Offset endPoint;
  final String shapeType; // e.g., 'oval', 'arrow'

  ShapeAction({
    required super.id,
    required super.color,
    required super.strokeWidth,
    required this.startPoint,
    required this.endPoint,
    required this.shapeType,
  });

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'shape',
      'id': id,
      'color': color.value,
      'strokeWidth': strokeWidth,
      'startPoint': {'x': startPoint.dx, 'y': startPoint.dy},
      'endPoint': {'x': endPoint.dx, 'y': endPoint.dy},
      'shapeType': shapeType,
    };
  }

  factory ShapeAction.fromJson(Map<String, dynamic> json) {
    return ShapeAction(
      id: json['id'] as String,
      color: Color(json['color'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      startPoint: Offset(
        (json['startPoint']['x'] as num).toDouble(),
        (json['startPoint']['y'] as num).toDouble(),
      ),
      endPoint: Offset(
        (json['endPoint']['x'] as num).toDouble(),
        (json['endPoint']['y'] as num).toDouble(),
      ),
      shapeType: json['shapeType'] as String,
    );
  }
}
