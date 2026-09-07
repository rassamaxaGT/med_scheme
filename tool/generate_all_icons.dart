// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:image/image.dart' as img;

/// Encodes a list of PNG image buffers and their dimensions into a standard Windows ICO format.
Uint8List encodeIco(List<Uint8List> pngList, List<int> sizes) {
  final count = pngList.length;
  final headerSize = 6 + 16 * count;
  int totalSize = headerSize;
  for (final p in pngList) {
    totalSize += p.length;
  }
  final bytes = Uint8List(totalSize);
  final bd = ByteData.sublistView(bytes);

  // ICO Header
  bd.setUint16(0, 0, Endian.little); // Reserved
  bd.setUint16(2, 1, Endian.little); // Type: 1 = ICO
  bd.setUint16(4, count, Endian.little); // Number of images

  int currentOffset = headerSize;
  for (int i = 0; i < count; i++) {
    final size = sizes[i];
    final pBytes = pngList[i];
    final dirOffset = 6 + i * 16;

    bd.setUint8(dirOffset + 0, size == 256 ? 0 : size); // Width
    bd.setUint8(dirOffset + 1, size == 256 ? 0 : size); // Height
    bd.setUint8(dirOffset + 2, 0); // Color count
    bd.setUint8(dirOffset + 3, 0); // Reserved
    bd.setUint16(dirOffset + 4, 1, Endian.little); // Color planes
    bd.setUint16(dirOffset + 6, 32, Endian.little); // Bits per pixel
    bd.setUint32(dirOffset + 8, pBytes.length, Endian.little); // Size in bytes
    bd.setUint32(dirOffset + 12, currentOffset, Endian.little); // File offset

    bytes.setRange(currentOffset, currentOffset + pBytes.length, pBytes);
    currentOffset += pBytes.length;
  }
  return bytes;
}

void main() {
  print('--- Starting Comprehensive Icon Generation ---');

  final sourceFile = File('assets/images/app_icon_source.jpg');
  if (!sourceFile.existsSync()) {
    throw Exception('Source icon file not found at ${sourceFile.path}');
  }
  final src = img.decodeImage(sourceFile.readAsBytesSync())!;

  const size = 726;
  const startX = 149;
  const startY = 149;
  final cropped = img.copyCrop(src, x: startX, y: startY, width: size, height: size);

  // 1. Generate Transparent Squircle
  final squircle = img.Image(width: size, height: size, numChannels: 4);
  final half = size / 2.0;
  const n = 4.3;

  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = (x - half + 0.5).abs() / (half - 1.0);
      final dy = (y - half + 0.5).abs() / (half - 1.0);
      final d = pow(dx, n) + pow(dy, n);
      final p = cropped.getPixel(x, y);

      if (d <= 1.0) {
        final dist = (1.0 - d) * half;
        final alpha = (dist.clamp(0.0, 1.5) / 1.5 * 255).round();
        squircle.setPixelRgba(x, y, p.r, p.g, p.b, alpha);
      } else {
        squircle.setPixelRgba(x, y, 0, 0, 0, 0);
      }
    }
  }

  // 2. Generate Solid Full-Bleed 1024x1024 (iOS / Marketing / App Store)
  final solidBase = img.Image(width: size, height: size, numChannels: 4);
  for (int y = 0; y < size; y++) {
    for (int x = 0; x < size; x++) {
      final dx = (x - half + 0.5).abs() / (half - 1.0);
      final dy = (y - half + 0.5).abs() / (half - 1.0);
      final d = pow(dx, n) + pow(dy, n);
      final p = cropped.getPixel(x, y);

      if (d <= 0.98) {
        solidBase.setPixelRgba(x, y, p.r, p.g, p.b, 255);
      } else {
        final t = y / size;
        final r = (18 * (1 - t) + 10 * t).round();
        final g = (86 * (1 - t) + 24 * t).round();
        final b = (145 * (1 - t) + 48 * t).round();
        solidBase.setPixelRgba(x, y, r, g, b, 255);
      }
    }
  }
  final solid1024 = img.copyResize(solidBase, width: 1024, height: 1024, interpolation: img.Interpolation.cubic);

  // Save Master Assets
  File('assets/images/app_icon.png').writeAsBytesSync(img.encodePng(solid1024));
  File('assets/images/app_icon_transparent.png').writeAsBytesSync(img.encodePng(squircle));
  print('Saved master assets to assets/images/');

  // 3. Android Mipmaps
  final androidSizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
  };

  for (final entry in androidSizes.entries) {
    final folder = 'android/app/src/main/res/${entry.key}';
    Directory(folder).createSync(recursive: true);
    final resized = img.copyResize(squircle, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    File('$folder/ic_launcher.png').writeAsBytesSync(img.encodePng(resized));
    print('Generated Android $folder/ic_launcher.png (${entry.value}x${entry.value})');
  }

  // 4. iOS AppIcon set (solid square per Apple requirements)
  final iosIcons = {
    'Icon-App-20x20@1x.png': 20,
    'Icon-App-20x20@2x.png': 40,
    'Icon-App-20x20@3x.png': 60,
    'Icon-App-29x29@1x.png': 29,
    'Icon-App-29x29@2x.png': 58,
    'Icon-App-29x29@3x.png': 87,
    'Icon-App-40x40@1x.png': 40,
    'Icon-App-40x40@2x.png': 80,
    'Icon-App-40x40@3x.png': 120,
    'Icon-App-60x60@2x.png': 120,
    'Icon-App-60x60@3x.png': 180,
    'Icon-App-76x76@1x.png': 76,
    'Icon-App-76x76@2x.png': 152,
    'Icon-App-83.5x83.5@2x.png': 167,
    'Icon-App-1024x1024@1x.png': 1024,
  };

  const iosFolder = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
  Directory(iosFolder).createSync(recursive: true);
  for (final entry in iosIcons.entries) {
    final resized = img.copyResize(solid1024, width: entry.value, height: entry.value, interpolation: img.Interpolation.cubic);
    File('$iosFolder/${entry.key}').writeAsBytesSync(img.encodePng(resized));
    print('Generated iOS $iosFolder/${entry.key} (${entry.value}x${entry.value})');
  }

  // 5. Web Icons
  Directory('web/icons').createSync(recursive: true);
  // favicon.png (32x32 standard)
  final fav32 = img.copyResize(squircle, width: 32, height: 32, interpolation: img.Interpolation.cubic);
  File('web/favicon.png').writeAsBytesSync(img.encodePng(fav32));

  // Icon-192.png & Icon-512.png (squircle)
  final icon192 = img.copyResize(squircle, width: 192, height: 192, interpolation: img.Interpolation.cubic);
  final icon512 = img.copyResize(squircle, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  File('web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));
  File('web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon512));

  // Maskable icons (must be solid full-bleed with safe zone)
  final maskable192 = img.copyResize(solid1024, width: 192, height: 192, interpolation: img.Interpolation.cubic);
  final maskable512 = img.copyResize(solid1024, width: 512, height: 512, interpolation: img.Interpolation.cubic);
  File('web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(maskable192));
  File('web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(maskable512));
  print('Generated all web/ icons (favicon, 192, 512, maskable)');

  // Also update build/web if it exists
  if (Directory('build/web').existsSync()) {
    File('build/web/favicon.png').writeAsBytesSync(img.encodePng(fav32));
    if (Directory('build/web/icons').existsSync()) {
      File('build/web/icons/Icon-192.png').writeAsBytesSync(img.encodePng(icon192));
      File('build/web/icons/Icon-512.png').writeAsBytesSync(img.encodePng(icon512));
      File('build/web/icons/Icon-maskable-192.png').writeAsBytesSync(img.encodePng(maskable192));
      File('build/web/icons/Icon-maskable-512.png').writeAsBytesSync(img.encodePng(maskable512));
      print('Updated build/web icons');
    }
  }

  // 6. Windows app_icon.ico (multi-size: 16, 32, 48, 64, 128, 256)
  const icoSizes = [16, 32, 48, 64, 128, 256];
  final icoPngBuffers = <Uint8List>[];
  for (final s in icoSizes) {
    final resized = img.copyResize(squircle, width: s, height: s, interpolation: img.Interpolation.cubic);
    icoPngBuffers.add(Uint8List.fromList(img.encodePng(resized)));
  }
  final icoBytes = encodeIco(icoPngBuffers, icoSizes);
  const winFolder = 'windows/runner/resources';
  Directory(winFolder).createSync(recursive: true);
  File('$winFolder/app_icon.ico').writeAsBytesSync(icoBytes);
  print('Generated Windows $winFolder/app_icon.ico with sizes: $icoSizes');

  print('--- All Icons Generated Successfully! ---');
}
