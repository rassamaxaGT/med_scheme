// Native (iOS, Android, Desktop) implementation using dart:io
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

/// Загрузка локального файла на нативных платформах (не используется на Web).
Future<ui.Image?> loadNativeFile(String rawPath) async {
  try {
    final file = File(rawPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final c = Completer<ui.Image>();
      ui.decodeImageFromList(bytes, c.complete);
      return c.future;
    }
    return null;
  } catch (e) {
    return null;
  }
}

