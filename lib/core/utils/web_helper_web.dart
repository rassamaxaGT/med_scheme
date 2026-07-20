// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:typed_data';

bool get isWebPlatformImpl => true;

final Map<String, Uint8List> _blobCache = {};

String createBlobUrlImpl(Uint8List bytes) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  _blobCache[url] = bytes;
  return url;
}

void triggerDownloadImpl(Uint8List bytes, String filename) {
  final blob = html.Blob([bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute("download", filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void cacheBlobBytesImpl(String url, Uint8List bytes) {
  _blobCache[url] = bytes;
}

Uint8List? getBlobBytesImpl(String url) {
  return _blobCache[url];
}
