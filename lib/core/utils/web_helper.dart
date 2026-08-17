import 'dart:typed_data';
import 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart'
    if (dart.library.js_interop) 'web_helper_web.dart';

bool get isWebPlatform => isWebPlatformImpl;
String createBlobUrl(Uint8List bytes) => createBlobUrlImpl(bytes);
void triggerDownload(Uint8List bytes, String filename) => triggerDownloadImpl(bytes, filename);
void cacheBlobBytes(String url, Uint8List bytes) => cacheBlobBytesImpl(url, bytes);
Uint8List? getBlobBytes(String url) => getBlobBytesImpl(url);
