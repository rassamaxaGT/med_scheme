import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

// Нативная загрузка файлов (только не-web платформы)
import '_image_loader_impl.dart'
    if (dart.library.html) '_image_loader_null_impl.dart'
    if (dart.library.js_interop) '_image_loader_null_impl.dart'
    as native_loader;

/// Универсальная загрузка изображений.
/// Работает на Web (assets + blob/network) и на native (assets + локальный файл).
Future<ui.Image?> loadUiImage(String rawPath) async {
  // Нормализуем путь
  final path = rawPath.replaceAll(r'\', '/').replaceAll(RegExp(r'^/+'), '');

  // ── 1. Встроенные ассеты ──────────────────────────────────────────────────
  // rootBundle.load работает ВЕЗДЕ: Flutter Web, iOS, Android, Desktop
  if (path.startsWith('assets/')) {
    try {
      debugPrint('[ImageLoader] rootBundle.load: $path');
      final byteData = await rootBundle.load(path);
      final bytes = byteData.buffer.asUint8List();
      debugPrint('[ImageLoader] Loaded ${bytes.length} bytes from $path');
      return await _decodeBytes(bytes);
    } catch (e) {
      debugPrint('[ImageLoader] rootBundle.load failed for $path: $e');
      // Fallback: AssetImage (работает через WidgetsBinding)
      try {
        return await _loadViaProvider(AssetImage(path));
      } catch (e2) {
        debugPrint('[ImageLoader] AssetImage fallback also failed for $path: $e2');
        return null;
      }
    }
  }

  // ── 2. На Web: blob: и http/https URL ─────────────────────────────────────
  if (kIsWeb) {
    try {
      return await _loadViaProvider(NetworkImage(rawPath));
    } catch (e) {
      debugPrint('[ImageLoader] NetworkImage failed for $rawPath: $e');
      return null;
    }
  }

  // ── 3. На native: локальный файл ──────────────────────────────────────────
  return await native_loader.loadNativeFile(rawPath);
}

Future<ui.Image?> _decodeBytes(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    return frame.image;
  } catch (e) {
    debugPrint('[ImageLoader] instantiateImageCodec failed: $e');
    final c = Completer<ui.Image?>();
    ui.decodeImageFromList(bytes, (img) => c.complete(img));
    return c.future;
  }
}

Future<ui.Image?> _loadViaProvider(ImageProvider p) async {
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
