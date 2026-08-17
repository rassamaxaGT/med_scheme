// Заглушка для Web платформ — нативная загрузка файлов не нужна
import 'dart:ui' as ui;

Future<ui.Image?> loadNativeFile(String path) async => null;
