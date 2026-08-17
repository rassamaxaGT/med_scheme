import 'dart:ui' as ui;
import 'image_loader_web.dart'
    if (dart.library.io) 'image_loader_io.dart';

Future<ui.Image?> loadUiImage(String path) => loadUiImagePlatform(path);

