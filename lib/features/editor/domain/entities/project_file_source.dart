import 'dart:typed_data';

class ProjectFileSource {
  final String? path;       // Для IO платформ
  final Uint8List? bytes;   // Для Web платформы
  final String name;        // Имя файла

  ProjectFileSource({this.path, this.bytes, required this.name});
}
