import 'dart:ui' as ui;
import 'image_loader_stub.dart'
    if (dart.library.io) 'image_loader_io.dart'
    if (dart.library.js_interop) 'image_loader_web.dart';

Future<ui.Image?> loadUiImage(String path) => loadUiImagePlatform(path);
