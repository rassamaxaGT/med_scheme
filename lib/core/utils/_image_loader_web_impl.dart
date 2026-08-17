// Web implementation — dart:html is available, dart:io is NOT
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

Future<ui.Image?> loadUiImageImpl(String rawPath) async {
  try {
    String path = rawPath.replaceAll(r'\', '/');
    while (path.startsWith('/')) {
      path = path.substring(1);
    }

    // 1. Встроенные ассеты (pubspec.yaml assets:)
    if (path.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(path);
        final bytes = byteData.buffer.asUint8List();
        return await _decode(bytes);
      } catch (e) {
        // Fallback через AssetImage
        try {
          return await _provider(AssetImage(path));
        } catch (_) {
          return null;
        }
      }
    }

    // 2. blob: URL и сетевые ресурсы
    return await _provider(NetworkImage(rawPath));
  } catch (e) {
    return null;
  }
}

Future<ui.Image?> _decode(Uint8List bytes) {
  final c = Completer<ui.Image>();
  ui.decodeImageFromList(bytes, c.complete);
  return c.future;
}

Future<ui.Image?> _provider(ImageProvider p) async {
  final c = Completer<ui.Image>();
  final stream = p.resolve(const ImageConfiguration());
  late ImageStreamListener lst;
  lst = ImageStreamListener(
    (info, _) { c.complete(info.image); stream.removeListener(lst); },
    onError: (e, st) { c.completeError(e, st); stream.removeListener(lst); },
  );
  stream.addListener(lst);
  return c.future;
}
