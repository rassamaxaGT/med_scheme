import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

Future<ui.Image?> loadUiImagePlatform(String rawPath) async {
  String path = rawPath.replaceAll(r'\', '/');
  if (path.startsWith('/')) {
    path = path.substring(1);
  }

  if (path.startsWith('assets/')) {
    try {
      final byteData = await rootBundle.load(path);
      final bytes = byteData.buffer.asUint8List();
      final completer = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, (ui.Image img) {
        completer.complete(img);
      });
      return await completer.future;
    } catch (_) {}
  }
  final file = File(rawPath);
  if (await file.exists()) {
    final bytes = await file.readAsBytes();
    final completer = Completer<ui.Image>();
    ui.decodeImageFromList(bytes, (ui.Image img) {
      completer.complete(img);
    });
    return await completer.future;
  }
  return null;
}


