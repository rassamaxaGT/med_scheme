import 'dart:io';
import 'dart:ui' as ui;

Future<ui.Image?> loadUiImagePlatform(String path) async {
  final file = File(path);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  }
  return null;
}
