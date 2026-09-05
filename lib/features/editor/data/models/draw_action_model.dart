import 'dart:ui';
import '../../domain/entities/draw_action.dart';

class DrawActionModel {
  /// [pathRemapping] maps original file paths → archive names (for save)
  /// or archive names → extracted local paths (for load).
  static Map<String, dynamic> toJson(DrawAction action,
      {Map<String, String>? pathRemapping}) {
    final rawPath = action.targetSchemePath;
    final mappedPath =
        (rawPath != null && pathRemapping != null)
            ? (pathRemapping[rawPath] ?? rawPath)
            : rawPath;

    final baseMap = <String, dynamic>{
      'id': action.id,
      'color': action.color.toARGB32(),
      'strokeWidth': action.strokeWidth,
      'scaleX': action.scaleX,
      'scaleY': action.scaleY,
      'offsetX': action.offsetX,
      'offsetY': action.offsetY,
      'targetSchemePath': mappedPath,
      if (action.eraserMasks != null && action.eraserMasks!.isNotEmpty)
        'eraserMasks': action.eraserMasks!
            .map((m) => {
                  'localPoints': m.localPoints.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
                  'strokeWidth': m.strokeWidth,
                  'target': m.target.name,
                })
            .toList(),
    };

    if (action is StrokeAction) {
      return {
        ...baseMap,
        'type': 'stroke',
        'points': action.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'isEraser': action.isEraser,
        'brushType': action.brushType,
        'isDashed': action.isDashed,
      };
    } else if (action is ShapeAction) {
      return {
        ...baseMap,
        'type': 'shape',
        'startPoint': {'x': action.startPoint.dx, 'y': action.startPoint.dy},
        'endPoint': {'x': action.endPoint.dx, 'y': action.endPoint.dy},
        'shapeType': action.shapeType,
        'figoType': action.figoType,
        'rotation': action.rotation,
      };
    } else if (action is StampAction) {
      return {
        ...baseMap,
        'type': 'stamp',
        'position': {'x': action.position.dx, 'y': action.position.dy},
        'stampType': action.stampType,
        'customStampPath': action.customStampPath,
        'rotation': action.rotation,
      };
    } else if (action is TextAction) {
      return {
        ...baseMap,
        'type': 'text',
        'startPoint': {'x': action.startPoint.dx, 'y': action.startPoint.dy},
        'endPoint': {'x': action.endPoint.dx, 'y': action.endPoint.dy},
        'text': action.text,
        'isDashed': action.isDashed,
      };
    } else if (action is EraserStrokeAction) {
      return {
        ...baseMap,
        'type': 'eraserStroke',
        'points': action.points.map((p) => {'x': p.dx, 'y': p.dy}).toList(),
        'target': action.target.name,
      };
    }
    throw UnimplementedError('Unknown DrawAction subclass: ${action.runtimeType}');
  }

  static DrawAction fromJson(Map<String, dynamic> json,
      {Map<String, String>? pathRemapping}) {
    final type = json['type'] as String;
    final id = json['id'] as String;
    final color = Color(json['color'] as int);
    final strokeWidth = (json['strokeWidth'] as num).toDouble();
    final scaleX = (json['scaleX'] as num?)?.toDouble() ?? 1.0;
    final scaleY = (json['scaleY'] as num?)?.toDouble() ?? 1.0;
    final offsetX = (json['offsetX'] as num?)?.toDouble() ?? 0.0;
    final offsetY = (json['offsetY'] as num?)?.toDouble() ?? 0.0;
    final rawPath = json['targetSchemePath'] as String?;
    var targetSchemePath =
        (rawPath != null && pathRemapping != null)
            ? (pathRemapping[rawPath] ?? rawPath)
            : rawPath;
    if (targetSchemePath == 'assets/schemes/standart_endo.jpg') {
      targetSchemePath = 'assets/schemes/ls_view.png';
    }

    final rawMasks = json['eraserMasks'] as List?;
    final List<EraserMaskData>? eraserMasks = rawMasks?.map((m) {
      final targetName = m['target'] as String? ?? 'annotationsOnly';
      final target = EraserTarget.values.firstWhere(
        (e) => e.name == targetName,
        orElse: () => EraserTarget.annotationsOnly,
      );
      return EraserMaskData(
        localPoints: (m['localPoints'] as List)
            .map((p) => Offset((p['x'] as num).toDouble(), (p['y'] as num).toDouble()))
            .toList(),
        strokeWidth: (m['strokeWidth'] as num).toDouble(),
        target: target,
      );
    }).toList();

    switch (type) {
      case 'stroke':
        return StrokeAction(
          id: id,
          color: color,
          strokeWidth: strokeWidth,
          points: (json['points'] as List)
              .map((p) => Offset(
                    (p['x'] as num).toDouble(),
                    (p['y'] as num).toDouble(),
                  ))
              .toList(),
          isEraser: json['isEraser'] as bool? ?? false,
          brushType: json['brushType'] as String? ?? 'pencil',
          isDashed: json['isDashed'] as bool? ?? false,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
          targetSchemePath: targetSchemePath,
          eraserMasks: eraserMasks,
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
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
          targetSchemePath: targetSchemePath,
          eraserMasks: eraserMasks,
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
          rotation: (json['rotation'] as num?)?.toDouble() ?? 0.0,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
          targetSchemePath: targetSchemePath,
          eraserMasks: eraserMasks,
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
          targetSchemePath: targetSchemePath,
          eraserMasks: eraserMasks,
        );
      case 'eraserStroke':
        final targetName = json['target'] as String? ?? 'annotationsOnly';
        final eraserTarget = EraserTarget.values.firstWhere(
          (e) => e.name == targetName,
          orElse: () => EraserTarget.annotationsOnly,
        );
        return EraserStrokeAction(
          id: id,
          strokeWidth: strokeWidth,
          points: (json['points'] as List)
              .map((p) => Offset(
                    (p['x'] as num).toDouble(),
                    (p['y'] as num).toDouble(),
                  ))
              .toList(),
          target: eraserTarget,
          scaleX: scaleX,
          scaleY: scaleY,
          offsetX: offsetX,
          offsetY: offsetY,
          targetSchemePath: targetSchemePath,
          eraserMasks: eraserMasks,
        );
      default:
        throw UnimplementedError('Unknown DrawAction type in JSON: $type');
    }
  }

}
