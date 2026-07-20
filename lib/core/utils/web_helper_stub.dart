import 'dart:typed_data';

bool get isWebPlatformImpl => false;

String createBlobUrlImpl(Uint8List bytes) {
  throw UnimplementedError('createBlobUrlImpl is not implemented.');
}

void triggerDownloadImpl(Uint8List bytes, String filename) {
  throw UnimplementedError('triggerDownloadImpl is not implemented.');
}

void cacheBlobBytesImpl(String url, Uint8List bytes) {
  // Игнорируем на мобилке
}

Uint8List? getBlobBytesImpl(String url) {
  return null;
}
