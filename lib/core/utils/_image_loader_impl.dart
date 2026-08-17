// Default (native: iOS, Android, desktop) implementation using dart:io
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

Future<ui.Image?> loadUiImageImpl(String rawPath) async {
  try {
    String path = rawPath.replaceAll(r'\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }

    // Встроенные ассеты (pubspec.yaml assets:)
    if (path.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(path);
        final bytes = byteData.buffer.asUint8List();
        return await _decode(bytes);
      } catch (e) {
        // ignore
      }
    }

    // Локальный файл
    final file = File(rawPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      return await _decode(bytes);
    }
    return null;
  } catch (e) {
    return null;
  }
}

Future<ui.Image?> _decode(Uint8List bytes) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, c.complete);
  return c.future;
}
