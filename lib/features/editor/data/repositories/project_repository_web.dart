import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
import '../../domain/repositories/project_repository.dart';
import '../models/draw_action_model.dart';
import '../models/page_data_model.dart';
import '../../presentation/widgets/canvas/canvas_painter.dart';
import '../../../../core/utils/web_helper.dart';
import '../../../../core/utils/image_loader.dart';

ProjectRepository getProjectRepositoryPlatform() => ProjectRepositoryWebImpl();

class ProjectRepositoryWebImpl implements ProjectRepository {
  @override
  Future<String?> requestProjectDirectory() async {
    return 'browser'; // На Web папка сохранения не выбирается напрямую, эмулируем выбор
  }

  @override
  Future<void> saveProject({
    required String directoryPath,
    required String projectName,
    required List<PageData> pages,
    required String? patientId,
  }) async {
    final firstBg = pages.isNotEmpty ? pages.first.backgroundPath : null;
    final Map<String, dynamic> projectMap = {
      'projectName': projectName,
      'version': '3.0',
      'patientId': patientId,
      'pages': pages.map((p) => PageDataModel.toJson(p)).toList(),
      'actions': pages.isNotEmpty ? pages.first.history.map((a) => DrawActionModel.toJson(a)).toList() : [],
    };

    final jsonString = jsonEncode(projectMap);
    final jsonBytes = utf8.encode(jsonString);

    final archive = Archive();
    archive.addFile(ArchiveFile('project.json', jsonBytes.length, jsonBytes));

    if (firstBg != null) {
      final bgBytes = getBlobBytes(firstBg);
      if (bgBytes != null) {
        archive.addFile(ArchiveFile('background.png', bgBytes.length, bgBytes));
      }
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes != null) {
      triggerDownload(Uint8List.fromList(zipBytes), '$projectName.meddraw');
    }
  }

  @override
  Future<ProjectData> loadProject(ProjectFileSource source) async {
    final bytes = source.bytes;
    if (bytes == null) {
      throw Exception('Данные файла проекта отсутствуют (Web)');
    }

    final archive = ZipDecoder().decodeBytes(bytes);
    String jsonContent = '[]';
    String? extractedBgPath;

    for (final file in archive) {
      if (file.name == 'project.json') {
        jsonContent = utf8.decode(file.content as List<int>);
      } else if (file.name == 'background.png') {
        final bgBytes = Uint8List.fromList(file.content as List<int>);
        // Создаем локальный Blob URL для веба
        extractedBgPath = createBlobUrl(bgBytes);
      }
    }

    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final patientId = decoded['patientId'] as String?;

    List<PageData> pages = [];
    if (decoded.containsKey('pages') && decoded['pages'] is List) {
      final pagesList = decoded['pages'] as List;
      pages = pagesList
          .map((j) => PageDataModel.fromJson(j as Map<String, dynamic>))
          .toList();
    } else if (decoded.containsKey('actions') && decoded['actions'] is List) {
      // Обратная совместимость с версией 1.0/2.0
      final actionsList = decoded['actions'] as List;
      final actions = actionsList
          .map((json) => DrawActionModel.fromJson(json as Map<String, dynamic>))
          .toList();
      pages = [
        PageData(
          id: 'page_legacy',
          pageType: 'custom',
          title: 'Схема',
          backgroundPath: extractedBgPath,
          history: actions,
        ),
      ];
    } else {
      pages = [
        PageData(
          id: 'page_default',
          pageType: 'custom',
          title: 'Схема',
          backgroundPath: extractedBgPath,
        ),
      ];
    }

    return ProjectData(
      pages: pages,
      patientId: patientId,
    );
  }

  @override
  Future<String> exportToGallery({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  }) async {
    // 1. Загружаем фоновое изображение
    ui.Image? bgImage;
    if (backgroundPath != null) {
      bgImage = await loadUiImage(backgroundPath);
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
      backgroundPath: backgroundPath,
      patientId: patientId,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());

    // 4. Кодируем в PNG
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Не удалось отрендерить холст');
    final pngBytes = byteData.buffer.asUint8List();

    // 5. Скачиваем файл в браузере
    triggerDownload(pngBytes, '$filename.png');

    return 'загрузки браузера';
  }

  @override
  Future<String> exportToPdf({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  }) async {
    // 1. Загружаем фоновое изображение
    ui.Image? bgImage;
    if (backgroundPath != null) {
      bgImage = await loadUiImage(backgroundPath);
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
      backgroundPath: backgroundPath,
      patientId: patientId,
    );
    painter.paint(canvas, size);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());

    // 4. Кодируем в PNG для встраивания в PDF
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw Exception('Не удалось отрендерить холст');
    final pngBytes = byteData.buffer.asUint8List();

    // 5. Генерируем PDF
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [

              pw.Text(
                'Медицинский отчет УЗИ',
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 8),
              pw.Text(
                'Пациент: ${patientId ?? "Не указан"}',
                style: pw.TextStyle(fontSize: 16),
              ),
              pw.Text(
                'Дата экспорта: ${DateTime.now().toLocal().toString().split('.')[0]}',
                style: pw.TextStyle(fontSize: 12),
              ),
              pw.SizedBox(height: 16),
              pw.Expanded(
                child: pw.Center(
                  child: pw.Image(
                    pw.MemoryImage(pngBytes),
                    fit: pw.BoxFit.contain,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );


    // Добавляем страницу легенды
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Легенда условных обозначений (Sonocontreras)',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 16),
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  // Эндометриоз Column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('КАРТА ЭНДОМЕТРИОЗА', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.SizedBox(height: 8),
                        pw.Text('• Инфильтрат — коричневый волнистый эллипс'),
                        pw.Text('• Эндометриома — сплошной коричневый круг'),
                        pw.Text('• Очаги — мелкие коричневые пятна'),
                        pw.Text('• Спайки — тонкая сеточка ("паутина")'),
                        pw.Text('• Фиброз — сплошная линия со штриховкой'),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 32),
                  // Миомы Column
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('КЛАССИФИКАЦИЯ МИОМ (FIGO)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                        pw.SizedBox(height: 8),
                        pw.Text('• FIGO 0, 1, 2 (Субмукозные) — Розовые круги с ID'),
                        pw.Text('• FIGO 3, 4 (Интрамуральные) — Синие круги с ID'),
                        pw.Text('• FIGO 5, 6, 7 (Субсерозные) — Зеленые круги с ID'),
                        pw.Text('• FIGO 8 (Другие) — Серые круги с ID'),
                        pw.Text('• FIGO 2-5 (Гибрид) — Диагональные розово-зеленые полосы'),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );


    final pdfBytes = await pdf.save();
    triggerDownload(pdfBytes, '$filename.pdf');

    return 'загрузки браузера';
  }

  @override
  Future<void> saveDirectoryPath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_directory_path', path);
  }

  @override
  Future<String?> getSavedDirectoryPath() async {
    if (kIsWeb) {
      return 'browser'; // На Web всегда эмулируем выбранную папку
    }
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('selected_directory_path');
  }
}

