import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:archive/archive_io.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
import '../../domain/repositories/project_repository.dart';

import '../models/draw_action_model.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../presentation/widgets/canvas/canvas_painter.dart';

ProjectRepository getProjectRepositoryPlatform() => ProjectRepositoryImpl();

// Вспомогательные классы для изолятов
class ZipTaskData {
  final String outputPath;
  final String jsonContent;
  final String? backgroundImagePath;
  ZipTaskData(this.outputPath, this.jsonContent, this.backgroundImagePath);
}

class UnzipTaskData {
  final String zipPath;
  final String tempDir;
  UnzipTaskData(this.zipPath, this.tempDir);
}

class UnzipResult {
  final String jsonContent;
  final String? extractedBackgroundPath;
  UnzipResult(this.jsonContent, this.extractedBackgroundPath);
}

// Функции верхнего уровня для compute()
void _zipProjectTask(ZipTaskData data) {
  final encoder = ZipFileEncoder();
  encoder.create(data.outputPath);

  // 1. Создаем временный файл JSON во временной директории
  final tempJsonFile = File('${Directory.systemTemp.path}/project.json');
  tempJsonFile.writeAsStringSync(data.jsonContent);

  // 2. Добавляем файлы в архив
  encoder.addFile(tempJsonFile, 'project.json');

  if (data.backgroundImagePath != null && data.backgroundImagePath!.isNotEmpty) {
    final bgFile = File(data.backgroundImagePath!);
    if (bgFile.existsSync()) {
      encoder.addFile(bgFile, 'background.png');
    }
  }

  encoder.close();

  // 3. Удаляем временный файл
  try {
    tempJsonFile.deleteSync();
  } catch (_) {}
}

UnzipResult _unzipProjectTask(UnzipTaskData data) {
  final bytes = File(data.zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  String jsonContent = '[]';
  String? extractedBgPath;

  for (final file in archive) {
    if (file.name == 'project.json') {
      jsonContent = utf8.decode(file.content as List<int>);
    } else if (file.name == 'background.png') {
      final outFile = File('${data.tempDir}/background_${DateTime.now().millisecondsSinceEpoch}.png');
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
      extractedBgPath = outFile.path;
    }
  }

  return UnzipResult(jsonContent, extractedBgPath);
}

class ProjectRepositoryImpl implements ProjectRepository {
  @override
  Future<String?> requestProjectDirectory() async {
    if (Platform.isAndroid) {
      // Использование Storage Access Framework (SAF) через shared_storage
      final uri = await saf.openDocumentTree();
      if (uri != null) {
        return uri.toString(); // Возвращаем URI как строку пути
      }
      return null;
    } else if (Platform.isIOS) {
      // На iOS папка документов доступна из приложения «Файлы» (в Info.plist включен обмен файлами)
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
    // Для других платформ (эмулятор, десктоп) возвращаем временную папку
    final tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  @override
  Future<void> saveProject({
    required String directoryPath,
    required String projectName,
    required List<DrawAction> actions,
    required String? backgroundPath,
  }) async {
    final Map<String, dynamic> projectMap = {
      'projectName': projectName,
      'version': '3.0',
      'actions': actions.map((a) => DrawActionModel.toJson(a)).toList(),
    };

    final jsonContent = jsonEncode(projectMap);

    // Определяем выходной путь для .meddraw файла
    String outputPath = '';
    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      // Сохраняем во временную директорию перед отправкой в SAF
      final tempDir = await getTemporaryDirectory();
      outputPath = '${tempDir.path}/$projectName.meddraw';
    } else {
      outputPath = '$directoryPath/$projectName.meddraw';
    }

    // Запускаем архивацию в фоновом изоляте с помощью compute, чтобы не фризить UI
    final taskData = ZipTaskData(outputPath, jsonContent, backgroundPath);
    await compute(_zipProjectTask, taskData);

    // На Android копируем готовый файл во внешнюю директорию SAF
    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final docUri = Uri.parse(directoryPath);
      final fileBytes = File(outputPath).readAsBytesSync();
      
      // Создаем файл через SAF
      await saf.createFile(
        docUri,
        mimeType: 'application/octet-stream',
        displayName: '$projectName.meddraw',
        bytes: fileBytes,
      );

      // Удаляем временный локальный файл
      try {
        File(outputPath).deleteSync();
      } catch (_) {}
    }
  }

  @override
  Future<ProjectData> loadProject(ProjectFileSource source) async {
    final filePath = source.path;
    if (filePath == null) throw Exception('Путь к файлу на IO-платформе пуст');
    final tempDir = await getTemporaryDirectory();
    
    // Если на Android это SAF Uri, сначала скачиваем его во временный файл
    String localZipPath = filePath;
    if (Platform.isAndroid && filePath.startsWith('content://')) {
      final uri = Uri.parse(filePath);
      final fileBytes = await saf.getDocumentContent(uri);
      if (fileBytes == null) throw Exception('Не удалось прочитать файл');
      
      final tempFile = File('${tempDir.path}/temp_load.meddraw');
      tempFile.writeAsBytesSync(fileBytes);
      localZipPath = tempFile.path;
    }

    // Разархивируем в фоновом изоляте
    final taskData = UnzipTaskData(localZipPath, tempDir.path);
    final result = await compute(_unzipProjectTask, taskData);

    // Удаляем временный загрузочный файл
    if (localZipPath != filePath) {
      try {
        File(localZipPath).deleteSync();
      } catch (_) {}
    }

    final decoded = jsonDecode(result.jsonContent) as Map<String, dynamic>;
    final actionsList = decoded['actions'] as List;

    final actions = actionsList.map((json) => DrawActionModel.fromJson(json as Map<String, dynamic>)).toList();
    return ProjectData(actions: actions, backgroundPath: result.extractedBackgroundPath);
  }

  @override
  Future<String> exportToGallery({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
  }) async {
    // 1. Загружаем фоновое изображение
    ui.Image? bgImage;
    if (backgroundPath != null) {
      final file = File(backgroundPath);
      if (file.existsSync()) {
        final bytes = file.readAsBytesSync();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        bgImage = frame.image;
      }
    }

    // 2. Определяем размеры холста
    final double width = bgImage != null ? bgImage.width.toDouble() : 800.0;
    final double height = bgImage != null ? bgImage.height.toDouble() : 600.0;
    final size = Size(width, height);

    // 3. Рисуем на PictureRecorder
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final painter = CanvasPainter(
      history: actions,
      backgroundImage: bgImage,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());

    // 4. Кодируем в PNG
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Не удалось отрендерить холст');
    final pngBytes = byteData.buffer.asUint8List();

    // 5. Сохраняем в зависимости от платформы
    String outputPath = '';
    final displayName = '$filename.png';

    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final tempDir = await getTemporaryDirectory();
      outputPath = '${tempDir.path}/$displayName';
      final tempFile = File(outputPath);
      tempFile.writeAsBytesSync(pngBytes);

      final docUri = Uri.parse(directoryPath);
      await saf.createFile(
        docUri,
        mimeType: 'image/png',
        displayName: displayName,
        bytes: pngBytes,
      );

      try {
        tempFile.deleteSync();
      } catch (_) {}
      
      return 'рабочую папку';
    } else {
      outputPath = '$directoryPath/$displayName';
      final file = File(outputPath);
      file.writeAsBytesSync(pngBytes);
      return outputPath;
    }
  }

  @override
  Future<void> saveDirectoryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_directory_path', path);
  }

  @override
  Future<String?> getSavedDirectoryPath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_directory_path');
  }
}
