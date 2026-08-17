import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/painting.dart';
import 'web_helper.dart';

Future<ui.Image?> loadUiImagePlatform(String path) async {
  try {
    // 1. Стандартные и встроенные ассеты
    if (path.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(path);
        final bytes = byteData.buffer.asUint8List();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      } catch (e) {
        debugPrint('rootBundle.load failed for $path: $e. Trying AssetImage...');
        final provider = AssetImage(path);
        final completer = Completer<ui.Image>();
        final stream = provider.resolve(const ImageConfiguration());
        late ImageStreamListener listener;
        listener = ImageStreamListener(
          (ImageInfo info, bool _) {
            completer.complete(info.image);
            stream.removeListener(listener);
          },
          onError: (dynamic exception, StackTrace? stackTrace) {
            completer.completeError(exception, stackTrace);
            stream.removeListener(listener);
          },
        );
        stream.addListener(listener);
        return await completer.future;
      }
    }

    // 2. Blob-ссылки (с локальным кэшем байтов)
    if (path.startsWith('blob:')) {
      final cachedBytes = getBlobBytes(path);
      if (cachedBytes != null) {
        final codec = await ui.instantiateImageCodec(cachedBytes);
        final frame = await codec.getNextFrame();
        return frame.image;
      }
    }

    // 3. Сетевые URL / Data URL / Blob URL через NetworkImage
    final provider = NetworkImage(path);
    final completer = Completer<ui.Image>();
    final stream = provider.resolve(const ImageConfiguration());
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (ImageInfo info, bool _) {
        completer.complete(info.image);
        stream.removeListener(listener);
      },
      onError: (dynamic exception, StackTrace? stackTrace) {
        completer.completeError(exception, stackTrace);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    return await completer.future;
  } catch (e) {
    debugPrint('Error loading web image ($path): $e');
    return null;
  }
}


