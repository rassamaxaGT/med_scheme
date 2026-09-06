import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_storage/shared_storage.dart' as saf;
import 'package:archive/archive_io.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
import '../../domain/entities/report_config.dart';
import '../../domain/repositories/project_repository.dart';
import '../services/offscreen_canvas_renderer.dart';
import '../services/pdf_report_generator_impl.dart';

import '../models/draw_action_model.dart';
import '../models/page_data_model.dart';
import '../../presentation/bloc/draw_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import '../../presentation/widgets/canvas/canvas_painter.dart';

ProjectRepository getProjectRepositoryPlatform() => ProjectRepositoryImpl();

// Вспомогательные классы для изолятов
class ZipTaskData {
  final String outputPath;
  final String jsonContent;
  final Map<String, String> customBackgroundFiles;
  ZipTaskData(this.outputPath, this.jsonContent, this.customBackgroundFiles);
}

class UnzipTaskData {
  final String zipPath;
  final String tempDir;
  UnzipTaskData(this.zipPath, this.tempDir);
}

class UnzipResult {
  final String jsonContent;
  final Map<String, String> extractedBackgrounds;
  UnzipResult(this.jsonContent, this.extractedBackgrounds);
}

// Функции верхнего уровня для compute()
void _zipProjectTask(ZipTaskData data) {
  final encoder = ZipFileEncoder();
  encoder.create(data.outputPath);

  final tempJsonFile = File('${Directory.systemTemp.path}/project_${DateTime.now().millisecondsSinceEpoch}.json');
  tempJsonFile.writeAsStringSync(data.jsonContent);
  encoder.addFile(tempJsonFile, 'project.json');

  data.customBackgroundFiles.forEach((origPath, archiveName) {
    final bgFile = File(origPath);
    if (bgFile.existsSync()) {
      encoder.addFile(bgFile, archiveName);
    }
  });

  encoder.close();

  try {
    tempJsonFile.deleteSync();
  } catch (_) {}
}

UnzipResult _unzipProjectTask(UnzipTaskData data) {
  final bytes = File(data.zipPath).readAsBytesSync();
  final archive = ZipDecoder().decodeBytes(bytes);

  String jsonContent = '[]';
  final Map<String, String> extractedMap = {};

  for (final file in archive) {
    if (file.name == 'project.json') {
      jsonContent = utf8.decode(file.content as List<int>);
    } else if (file.name.endsWith('.png') || file.name.endsWith('.jpg') || file.name.endsWith('.jpeg')) {
      final safeName = file.name.replaceAll('/', '_').replaceAll('\\', '_');
      final outFile = File('${data.tempDir}/${DateTime.now().millisecondsSinceEpoch}_$safeName');
      outFile.createSync(recursive: true);
      outFile.writeAsBytesSync(file.content as List<int>);
      extractedMap[file.name] = outFile.path;
      if (file.name == 'background.png') {
        extractedMap['legacy_bg'] = outFile.path;
      }
    }
  }

  return UnzipResult(jsonContent, extractedMap);
}

class ProjectRepositoryImpl implements ProjectRepository {
  @override
  Future<String?> requestProjectDirectory() async {
    if (Platform.isAndroid) {
      final uri = await saf.openDocumentTree();
      if (uri != null) {
        return uri.toString();
      }
      return null;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      return directory.path;
    }
    final tempDir = await getTemporaryDirectory();
    return tempDir.path;
  }

  @override
  Future<void> saveProject({
    required String directoryPath,
    required String projectName,
    required List<PageData> pages,
    required String? patientId,
    List<CustomSchemeItem>? customSchemes,
  }) async {
    final customBgFiles = <String, String>{};
    final pathToArchiveMap = <String, String>{};
    int bgCounter = 0;

    final allCustomPaths = <String>{};
    for (final p in pages) {
      for (final path in p.backgroundPaths) {
        if (!path.startsWith('assets/')) {
          allCustomPaths.add(path);
        }
      }
    }
    if (customSchemes != null) {
      for (final cs in customSchemes) {
        if (!cs.path.startsWith('assets/')) {
          allCustomPaths.add(cs.path);
        }
      }
    }

    for (final path in allCustomPaths) {
      final ext = path.toLowerCase().endsWith('.jpg') || path.toLowerCase().endsWith('.jpeg') ? 'jpg' : 'png';
      final archiveName = 'custom_bg_$bgCounter.$ext';
      customBgFiles[path] = archiveName;
      pathToArchiveMap[path] = archiveName;
      bgCounter++;
    }

    final remappedPages = pages.map((p) {
      final newBgPaths = p.backgroundPaths.map((path) => pathToArchiveMap[path] ?? path).toList();
      return p.copyWith(backgroundPaths: newBgPaths);
    }).toList();

    final remappedCustomSchemes = (customSchemes ?? []).map((cs) {
      return {
        'title': cs.title,
        'path': pathToArchiveMap[cs.path] ?? cs.path,
      };
    }).toList();

    final Map<String, dynamic> projectMap = {
      'projectName': projectName,
      'version': '3.0',
      'patientId': patientId,
      'pages': remappedPages
          .map((p) => PageDataModel.toJson(p, pathRemapping: pathToArchiveMap))
          .toList(),
      'customSchemes': remappedCustomSchemes,
      'actions': remappedPages.isNotEmpty
          ? remappedPages.first.history
              .map((a) => DrawActionModel.toJson(a, pathRemapping: pathToArchiveMap))
              .toList()
          : [],
    };

    final jsonContent = jsonEncode(projectMap);

    String outputPath = '';
    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final tempDir = await getTemporaryDirectory();
      outputPath = '${tempDir.path}/$projectName.meddraw';
    } else {
      outputPath = '$directoryPath/$projectName.meddraw';
    }

    final taskData = ZipTaskData(outputPath, jsonContent, customBgFiles);
    await compute(_zipProjectTask, taskData);

    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final docUri = Uri.parse(directoryPath);
      final fileBytes = File(outputPath).readAsBytesSync();
      await saf.createFile(
        docUri,
        mimeType: 'application/octet-stream',
        displayName: '$projectName.meddraw',
        bytes: fileBytes,
      );
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
    
    String localZipPath = filePath;
    if (Platform.isAndroid && filePath.startsWith('content://')) {
      final uri = Uri.parse(filePath);
      final fileBytes = await saf.getDocumentContent(uri);
      if (fileBytes == null) throw Exception('Не удалось прочитать файл');
      
      final tempFile = File('${tempDir.path}/temp_load.meddraw');
      tempFile.writeAsBytesSync(fileBytes);
      localZipPath = tempFile.path;
    }

    final taskData = UnzipTaskData(localZipPath, tempDir.path);
    final result = await compute(_unzipProjectTask, taskData);

    if (localZipPath != filePath) {
      try {
        File(localZipPath).deleteSync();
      } catch (_) {}
    }

    final decoded = jsonDecode(result.jsonContent) as Map<String, dynamic>;
    final patientId = decoded['patientId'] as String?;
    final extractedMap = result.extractedBackgrounds;

    List<PageData> pages = [];
    if (decoded.containsKey('pages') && decoded['pages'] is List) {
      final pagesList = decoded['pages'] as List;
      pages = pagesList.map((j) {
        final page = PageDataModel.fromJson(
          j as Map<String, dynamic>,
          pathRemapping: extractedMap,
        );
        final remappedPaths = page.backgroundPaths.map((path) {
          if (extractedMap.containsKey(path)) {
            return extractedMap[path]!;
          } else if (path == 'background.png' && extractedMap.containsKey('legacy_bg')) {
            return extractedMap['legacy_bg']!;
          }
          return path;
        }).toList();
        return page.copyWith(backgroundPaths: remappedPaths);
      }).toList();
    } else if (decoded.containsKey('actions') && decoded['actions'] is List) {
      final actionsList = decoded['actions'] as List;
      final actions = actionsList.map((json) => DrawActionModel.fromJson(json as Map<String, dynamic>)).toList();
      final legacyPath = extractedMap['legacy_bg'] ?? (extractedMap.isNotEmpty ? extractedMap.values.first : null);
      pages = [
        PageData(
          id: 'page_legacy',
          pageType: 'custom',
          title: 'Схема',
          backgroundPath: legacyPath,
          history: actions,
        ),
      ];
    } else {
      final legacyPath = extractedMap['legacy_bg'] ?? (extractedMap.isNotEmpty ? extractedMap.values.first : null);
      pages = [
        PageData(
          id: 'page_default',
          pageType: 'custom',
          title: 'Схема',
          backgroundPath: legacyPath,
        ),
      ];
    }

    List<CustomSchemeItem> customSchemes = [];
    if (decoded.containsKey('customSchemes') && decoded['customSchemes'] is List) {
      final csList = decoded['customSchemes'] as List;
      for (final item in csList) {
        if (item is Map) {
          final rawPath = item['path'] as String? ?? '';
          final title = item['title'] as String? ?? 'Своё изображение';
          final remappedPath = extractedMap[rawPath] ?? (rawPath == 'background.png' ? extractedMap['legacy_bg'] ?? rawPath : rawPath);
          customSchemes.add(CustomSchemeItem(title: title, path: remappedPath));
        }
      }
    }

    return ProjectData(
      pages: pages,
      patientId: patientId,
      customSchemes: customSchemes,
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
                'Дата исследования: ${DateTime.now().toLocal().toString().split('.')[0]}',
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

    // 6. Сохраняем в PDF
    String outputPath = '';
    final displayName = '$filename.pdf';

    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final tempDir = await getTemporaryDirectory();
      outputPath = '${tempDir.path}/$displayName';
      final tempFile = File(outputPath);
      tempFile.writeAsBytesSync(pdfBytes);

      final docUri = Uri.parse(directoryPath);
      await saf.createFile(
        docUri,
        mimeType: 'application/pdf',
        displayName: displayName,
        bytes: pdfBytes,
      );

      try {
        tempFile.deleteSync();
      } catch (_) {}
      
      return 'рабочую папку';
    } else {
      outputPath = '$directoryPath/$displayName';
      final file = File(outputPath);
      file.writeAsBytesSync(pdfBytes);
      return outputPath;
    }
  }

  final OffscreenCanvasRenderer _renderer = OffscreenCanvasRenderer();
  late final PdfReportGeneratorImpl _pdfGenerator = PdfReportGeneratorImpl(renderer: _renderer);

  @override
  Future<Uint8List> generateReportPdf({
    required ProjectData project,
    required ReportConfig config,
    bool isForPreview = false,
  }) async {
    return _pdfGenerator.generatePdf(project: project, config: config, isForPreview: isForPreview);
  }

  @override
  Future<void> printReport({
    required ProjectData project,
    required ReportConfig config,
  }) async {
    final pdfBytes = await generateReportPdf(project: project, config: config);
    final patient = config.patientId.isNotEmpty ? config.patientId : (project.patientId ?? '');
    final docName = formatReportPdfFilename(
      patientId: patient,
      date: config.createdAt,
    );

    await Printing.layoutPdf(
      name: docName,
      onLayout: (PdfPageFormat format) async => pdfBytes,
    );
  }

  @override
  Future<String> exportReportPdf({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
  }) async {
    final effectiveFilename = filename.trim().isNotEmpty
        ? filename.trim()
        : formatReportPdfFilename(
            patientId: config.patientId.isNotEmpty ? config.patientId : project.patientId,
            date: config.createdAt,
          );
    final pdfBytes = await generateReportPdf(project: project, config: config);
    final displayName = effectiveFilename.endsWith('.pdf') ? effectiveFilename : '$effectiveFilename.pdf';

    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final docUri = Uri.parse(directoryPath);
      await saf.createFile(
        docUri,
        mimeType: 'application/pdf',
        displayName: displayName,
        bytes: pdfBytes,
      );
      return 'рабочую папку';
    } else {
      final outputPath = '$directoryPath/$displayName';
      final file = File(outputPath);
      file.writeAsBytesSync(pdfBytes);
      return outputPath;
    }
  }

  @override
  Future<String> exportReportPng({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
    PageData? singlePage,
  }) async {
    final targetPage = singlePage ?? (project.pages.isNotEmpty ? project.pages.first : PageData(id: 'page_1', pageType: 'custom', title: 'Схема'));
    Uint8List pngBytes;

    if (config.pngExportType == PngExportType.fullMedicalCard) {
      pngBytes = await _renderer.renderBrandedMedicalCardPng(page: targetPage, config: config);
    } else {
      pngBytes = await _renderer.renderPageToPng(
        page: targetPage,
        dpiScale: config.dpiScale,
        patientId: config.patientId.isNotEmpty ? config.patientId : project.patientId,
      );
    }

    final displayName = filename.endsWith('.png') ? filename : '$filename.png';

    if (Platform.isAndroid && directoryPath.startsWith('content://')) {
      final docUri = Uri.parse(directoryPath);
      await saf.createFile(
        docUri,
        mimeType: 'image/png',
        displayName: displayName,
        bytes: pngBytes,
      );
      return 'рабочую папку';
    } else {
      final outputPath = '$directoryPath/$displayName';
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

