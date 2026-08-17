import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'web_helper.dart';

Future<ui.Image?> loadUiImagePlatform(String rawPath) async {
  try {
    String path = rawPath.replaceAll(r'\', '/');
    if (path.startsWith('/')) {
      path = path.substring(1);
    }

    // 1. Стандартные и встроенные ассеты
    if (path.startsWith('assets/')) {
      try {
        final byteData = await rootBundle.load(path);
        final bytes = byteData.buffer.asUint8List();
        final completer = Completer<ui.Image>();
        ui.decodeImageFromList(bytes, (ui.Image img) {
          completer.complete(img);
        });
        return await completer.future;
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
        final completer = Completer<ui.Image>();
        ui.decodeImageFromList(cachedBytes, (ui.Image img) {
          completer.complete(img);
        });
        return await completer.future;
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
    debugPrint('Error loading web image ($rawPath): $e');
    return null;
  }
}



