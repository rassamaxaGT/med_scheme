import 'dart:ui' as ui;
import '_image_loader_impl.dart'
    if (dart.library.html) '_image_loader_web_impl.dart';

Future<ui.Image?> loadUiImage(String path) => loadUiImageImpl(path);
