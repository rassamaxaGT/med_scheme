import 'dart:ui';

abstract class DrawAction {
  final String id;
  final Color color;
  final double strokeWidth;

  DrawAction({
    required this.id,
    required this.color,
    required this.strokeWidth,
  });

  Map<String, dynamic> toJson();
}
