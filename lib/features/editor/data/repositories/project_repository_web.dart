import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:archive/archive.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
import '../../domain/entities/report_config.dart';
import '../../domain/repositories/project_repository.dart';
import '../models/draw_action_model.dart';
import '../models/page_data_model.dart';
import '../services/offscreen_canvas_renderer.dart';
import '../services/pdf_report_generator_impl.dart';
import '../../presentation/bloc/draw_state.dart';
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
    List<CustomSchemeItem>? customSchemes,
  }) async {
    final customBgFiles = <String, Uint8List>{};
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
      final bgBytes = getBlobBytes(path);
      if (bgBytes != null) {
        customBgFiles[archiveName] = bgBytes;
        pathToArchiveMap[path] = archiveName;
        bgCounter++;
      }
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

    final jsonString = jsonEncode(projectMap);
    final jsonBytes = utf8.encode(jsonString);

    final archive = Archive();
    archive.addFile(ArchiveFile('project.json', jsonBytes.length, jsonBytes));

    customBgFiles.forEach((archiveName, bytes) {
      archive.addFile(ArchiveFile(archiveName, bytes.length, bytes));
    });

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
    final Map<String, String> extractedMap = {};

    for (final file in archive) {
      if (file.name == 'project.json') {
        jsonContent = utf8.decode(file.content as List<int>);
      } else if (file.name.endsWith('.png') || file.name.endsWith('.jpg') || file.name.endsWith('.jpeg')) {
        final bgBytes = Uint8List.fromList(file.content as List<int>);
        final blobUrl = createBlobUrl(bgBytes);
        extractedMap[file.name] = blobUrl;
        if (file.name == 'background.png') {
          extractedMap['legacy_bg'] = blobUrl;
        }
      }
    }

    final decoded = jsonDecode(jsonContent) as Map<String, dynamic>;
    final patientId = decoded['patientId'] as String?;

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

  final OffscreenCanvasRenderer _renderer = OffscreenCanvasRenderer();
  late final PdfReportGeneratorImpl _pdfGenerator = PdfReportGeneratorImpl(renderer: _renderer);

  @override
  Future<Uint8List> generateReportPdf({
    required ProjectData project,
    required ReportConfig config,
  }) async {
    return _pdfGenerator.generatePdf(project: project, config: config);
  }

  @override
  Future<void> printReport({
    required ProjectData project,
    required ReportConfig config,
  }) async {
    final pdfBytes = await generateReportPdf(project: project, config: config);
    final patient = config.patientId.isNotEmpty ? config.patientId : (project.patientId ?? 'report');
    final docName = 'УЗИ_${patient}_${DateTime.now().millisecondsSinceEpoch}';

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
    final pdfBytes = await generateReportPdf(project: project, config: config);
    final displayName = filename.endsWith('.pdf') ? filename : '$filename.pdf';
    triggerDownload(pdfBytes, displayName);
    return 'загрузки браузера';
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
    triggerDownload(pngBytes, displayName);
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

