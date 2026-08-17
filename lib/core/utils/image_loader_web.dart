import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/painting.dart';

Future<ui.Image?> loadUiImagePlatform(String path) async {
  try {
    if (path.startsWith('assets/')) {
      final byteData = await rootBundle.load(path);
      final bytes = byteData.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    }
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
    debugPrint('Error loading web image: $e');
    return null;
  }
}

