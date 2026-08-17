import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

Future<ui.Image?> loadUiImagePlatform(String path) async {
  if (path.startsWith('assets/')) {
    try {
      final byteData = await rootBundle.load(path);
      final bytes = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {}
  }
  final file = File(path);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
  return null;
}

