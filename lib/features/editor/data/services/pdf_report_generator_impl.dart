import 'dart:io' show File, Platform;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/report_config.dart';
import 'offscreen_canvas_renderer.dart';

/// Сервис генерации качественного медицинского PDF-отчета (A4, кириллица, легенда, заключение)
class PdfReportGeneratorImpl {
  final OffscreenCanvasRenderer renderer;

  PdfReportGeneratorImpl({required this.renderer});

  static pw.ThemeData? _cachedTheme;

  /// Загрузка шрифтов с поддержкой кириллицы (офлайн системные шрифты 0 мс)
  Future<pw.ThemeData> _loadTheme() async {
    if (_cachedTheme != null) return _cachedTheme!;

    // 1. Мгновенная загрузка системных шрифтов ОС (0 мс, офлайн)
    if (!kIsWeb) {
      try {
        if (Platform.isWindows) {
          const arial = r'C:\Windows\Fonts\arial.ttf';
          const arialBd = r'C:\Windows\Fonts\arialbd.ttf';
          const arialIt = r'C:\Windows\Fonts\ariali.ttf';

          if (File(arial).existsSync()) {
            final regBytes = await File(arial).readAsBytes();
            final regular = pw.Font.ttf(regBytes.buffer.asByteData());
            pw.Font? bold;
            pw.Font? italic;

            if (File(arialBd).existsSync()) {
              final bdBytes = await File(arialBd).readAsBytes();
              bold = pw.Font.ttf(bdBytes.buffer.asByteData());
            }
            if (File(arialIt).existsSync()) {
              final itBytes = await File(arialIt).readAsBytes();
              italic = pw.Font.ttf(itBytes.buffer.asByteData());
            }

            _cachedTheme = pw.ThemeData.withFont(
              base: regular,
              bold: bold ?? regular,
              italic: italic ?? regular,
            );
            return _cachedTheme!;
          }
        } else if (Platform.isAndroid) {
          const roboto = '/system/fonts/Roboto-Regular.ttf';
          const robotoBd = '/system/fonts/Roboto-Bold.ttf';
          const robotoIt = '/system/fonts/Roboto-Italic.ttf';

          if (File(roboto).existsSync()) {
            final regBytes = await File(roboto).readAsBytes();
            final regular = pw.Font.ttf(regBytes.buffer.asByteData());
            pw.Font? bold;
            pw.Font? italic;

            if (File(robotoBd).existsSync()) {
              final bdBytes = await File(robotoBd).readAsBytes();
              bold = pw.Font.ttf(bdBytes.buffer.asByteData());
            }
            if (File(robotoIt).existsSync()) {
              final itBytes = await File(robotoIt).readAsBytes();
              italic = pw.Font.ttf(itBytes.buffer.asByteData());
            }

            _cachedTheme = pw.ThemeData.withFont(
              base: regular,
              bold: bold ?? regular,
              italic: italic ?? regular,
            );
            return _cachedTheme!;
          }
        }
      } catch (e) {
        debugPrint('[PdfReportGeneratorImpl] Системный шрифт не загрузился: $e');
      }
    }

    // 2. Попытка загрузить Google Fonts с коротким таймаутом (500мс)
    try {
      final results = await Future.wait([
        PdfGoogleFonts.robotoRegular(),
        PdfGoogleFonts.robotoBold(),
        PdfGoogleFonts.robotoItalic(),
      ]).timeout(const Duration(milliseconds: 500));

      _cachedTheme = pw.ThemeData.withFont(
        base: results[0],
        bold: results[1],
        italic: results[2],
      );
      return _cachedTheme!;
    } catch (_) {
      // 3. Мгновенный fallback
      _cachedTheme = pw.ThemeData.withFont(
        base: pw.Font.helvetica(),
        bold: pw.Font.helveticaBold(),
        italic: pw.Font.helveticaOblique(),
      );
      return _cachedTheme!;
    }
  }

  /// Генерация байтов PDF документа
  Future<Uint8List> generatePdf({
    required ProjectData project,
    required ReportConfig config,
  }) async {
    final pdf = pw.Document(
      theme: await _loadTheme(),
      title: 'УЗИ Отчет - ${config.patientId.isNotEmpty ? config.patientId : "Пациент"}',
      author: config.doctorName.isNotEmpty ? config.doctorName : 'МедРисунок',
    );

    final pageFormat = config.orientation == PageOrientation.landscape
        ? PdfPageFormat.a4.landscape
        : PdfPageFormat.a4.portrait;

    // Фильтруем страницы для отчета
    final List<PageData> targetPages = config.selectedPageIds.isNotEmpty
        ? project.pages.where((p) => config.selectedPageIds.contains(p.id)).toList()
        : project.pages;

    final initialPages = targetPages.isNotEmpty ? targetPages : project.pages;

    // Формируем список страниц в зависимости от режима:
    // Если "на отдельных листах" и на холсте несколько фонов, разбиваем именно эти фоны холста на отдельные листы!
    final List<PageData> pagesToRender = [];
    if (config.layoutMode == SchemeLayoutMode.separatePages) {
      for (final page in initialPages) {
        if (page.backgroundPaths.length > 1) {
          for (final bgPath in page.backgroundPaths) {
            pagesToRender.add(
              PageData(
                id: '${page.id}_$bgPath',
                pageType: page.pageType,
                title: _getSchemeTitle(bgPath),
                backgroundPaths: [bgPath],
                history: page.history
                    .where((a) => a.targetSchemePath == bgPath || a.targetSchemePath == null)
                    .toList(),
              ),
            );
          }
        } else {
          pagesToRender.add(page);
        }
      }
    } else {
      pagesToRender.addAll(initialPages);
    }

    // Рендерим изображения схем
    final List<Uint8List> renderedImages = [];
    for (final page in pagesToRender) {
      final pngBytes = await renderer.renderPageToPng(
        page: page,
        dpiScale: config.dpiScale,
        patientId: config.patientId.isNotEmpty ? config.patientId : project.patientId,
      );
      renderedImages.add(pngBytes);
    }

    if (config.layoutMode == SchemeLayoutMode.allOnSinglePage || pagesToRender.length <= 1) {
      // ── РЕЖИМ 1: Все схемы на одной странице А4 (ровно то, что на холсте) ──
      pdf.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                if (config.includeHeader) ...[
                  _buildHeader(config, project, pagesToRender.first.title),
                  pw.SizedBox(height: 8),
                ],

                // Зона схем (сетка в зависимости от количества)
                pw.Expanded(
                  child: _buildSchemesGrid(pagesToRender, renderedImages),
                ),
                pw.SizedBox(height: 6),

                if (config.includeLegend) ...[
                  _buildCombinedLegend(pagesToRender, config.includeOnlyActiveMarkersInLegend),
                  pw.SizedBox(height: 6),
                ],

                if (config.includeDoctorNotes && config.doctorNotes.isNotEmpty) ...[
                  _buildDoctorNotes(config.doctorNotes),
                  pw.SizedBox(height: 6),
                ],

                _buildFooter(context),
              ],
            );
          },
        ),
      );
    } else {
      // ── РЕЖИМ 2: Каждая схема на отдельной странице А4 ──
      for (int i = 0; i < pagesToRender.length; i++) {
        final pageData = pagesToRender[i];
        final imageBytes = renderedImages[i];
        final isLastPage = i == pagesToRender.length - 1;

        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: const pw.EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            build: (pw.Context context) {
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (config.includeHeader) ...[
                    _buildHeader(config, project, pageData.title),
                    pw.SizedBox(height: 10),
                  ],

                  pw.Expanded(
                    child: pw.Container(
                      alignment: pw.Alignment.center,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.white,
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                        border: pw.Border.all(color: PdfColor.fromHex('E1E4E8'), width: 1),
                      ),
                      child: pw.Image(
                        pw.MemoryImage(imageBytes),
                        fit: pw.BoxFit.contain,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 8),

                  if (config.includeLegend) ...[
                    _buildLegend(pageData, config.includeOnlyActiveMarkersInLegend),
                    pw.SizedBox(height: 6),
                  ],

                  if (config.includeDoctorNotes && config.doctorNotes.isNotEmpty && isLastPage) ...[
                    _buildDoctorNotes(config.doctorNotes),
                    pw.SizedBox(height: 6),
                  ],

                  _buildFooter(context),
                ],
              );
            },
          ),
        );
      }
    }

    return pdf.save();
  }

  String _getSchemeTitle(String path) {
    if (path.contains('standart_endo')) return 'Обзорная схема таза';
    if (path.contains('sagittally')) return 'Сагиттальный срез';
    if (path.contains('uretus')) return 'Матка и придатки';
    if (path.contains('abdominal_wall')) return 'Брюшная стенка';
    final name = path.split(RegExp(r'[/\\]')).last.split('.').first;
    return name.isNotEmpty ? name : 'Схема';
  }

  /// Сетка для одновременного отображения нескольких схем на одной странице
  pw.Widget _buildSchemesGrid(List<PageData> pages, List<Uint8List> images) {
    if (pages.length == 1) {
      return pw.Container(
        alignment: pw.Alignment.center,
        decoration: pw.BoxDecoration(
          color: PdfColors.white,
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
          border: pw.Border.all(color: PdfColor.fromHex('E1E4E8'), width: 1),
        ),
        child: pw.Image(pw.MemoryImage(images[0]), fit: pw.BoxFit.contain),
      );
    }

    if (pages.length == 2) {
      return pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          pw.Expanded(
            child: _buildSchemeCard(pages[0].title, images[0]),
          ),
          pw.SizedBox(width: 10),
          pw.Expanded(
            child: _buildSchemeCard(pages[1].title, images[1]),
          ),
        ],
      );
    }

    // 3 или 4 схемы: сетка 2x2
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(child: _buildSchemeCard(pages[0].title, images[0])),
              pw.SizedBox(width: 8),
              pw.Expanded(child: _buildSchemeCard(pages[1].title, images[1])),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Expanded(
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              pw.Expanded(child: _buildSchemeCard(pages[2].title, images[2])),
              pw.SizedBox(width: 8),
              pw.Expanded(
                child: pages.length > 3
                    ? _buildSchemeCard(pages[3].title, images[3])
                    : pw.SizedBox(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _buildSchemeCard(String title, Uint8List imageBytes) {
    return pw.Container(
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColor.fromHex('E1E4E8'), width: 1),
      ),
      padding: const pw.EdgeInsets.all(4),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('0F4C81')),
          ),
          pw.SizedBox(height: 2),
          pw.Expanded(
            child: pw.Image(
              pw.MemoryImage(imageBytes),
              fit: pw.BoxFit.contain,
            ),
          ),
        ],
      ),
    );
  }

  /// Шапка медицинского протокола
  pw.Widget _buildHeader(ReportConfig config, ProjectData project, String pageTitle) {
    final patient = config.patientId.isNotEmpty
        ? config.patientId
        : (project.patientId?.isNotEmpty == true ? project.patientId! : 'Не указан');

    return pw.Container(
      padding: const pw.EdgeInsets.only(bottom: 6),
      decoration: pw.BoxDecoration(
        border: pw.Border(
          bottom: pw.BorderSide(color: PdfColor.fromHex('0F4C81'), width: 2),
        ),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                config.clinicName.isNotEmpty ? config.clinicName : 'МедРисунок — УЗИ Протокол',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('0F4C81'),
                ),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                'Протокол: $pageTitle',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.end,
            children: [
              pw.Row(
                children: [
                  pw.Text('Пациент: ', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                  pw.Text(patient, style: const pw.TextStyle(fontSize: 9.5)),
                ],
              ),
              if (config.doctorName.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Row(
                  children: [
                    pw.Text('Врач: ', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
                    pw.Text(config.doctorName, style: const pw.TextStyle(fontSize: 8.5)),
                  ],
                ),
              ],
              pw.SizedBox(height: 2),
              pw.Text(
                'Дата: ${DateTime.now().toLocal().toString().split('.')[0]}',
                style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey700),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Клиническая легенда для одной страницы
  pw.Widget _buildLegend(PageData page, bool onlyActive) {
    return _buildCombinedLegend([page], onlyActive);
  }

  /// Объединенная клиническая легенда по всем страницам
  pw.Widget _buildCombinedLegend(List<PageData> pages, bool onlyActive) {
    final actions = pages.expand((p) => p.history).toList();

    final hasEndometrioma = actions.any((a) => a is ShapeAction && a.shapeType == 'endometrioma');
    final hasInfiltrate = actions.any((a) => (a is ShapeAction && a.shapeType == 'infiltrate') || (a is StrokeAction && a.brushType == 'infiltrate'));
    final hasAdhesions = actions.any((a) => a is StrokeAction && a.brushType == 'adhesions');
    final hasFibrosis = actions.any((a) => a is StrokeAction && a.brushType == 'fibrosis');
    final hasSpots = actions.any((a) => a is StampAction && a.stampType == 'foci');
    final hasIud = actions.any((a) => a is StampAction && a.stampType == 'iud');
    final hasFollicle = actions.any((a) => a is ShapeAction && a.shapeType == 'follicle');
    final hasPolyp = actions.any((a) => a is ShapeAction && a.shapeType == 'polyp');

    final List<pw.Widget> legendBadges = [];

    void addBadge(String label, PdfColor color) {
      legendBadges.add(
        pw.Row(
          mainAxisSize: pw.MainAxisSize.min,
          children: [
            pw.Container(
              width: 7,
              height: 7,
              decoration: pw.BoxDecoration(
                color: color,
                shape: pw.BoxShape.circle,
              ),
            ),
            pw.SizedBox(width: 3),
            pw.Text(label, style: const pw.TextStyle(fontSize: 7.5)),
          ],
        ),
      );
    }

    if (!onlyActive || hasEndometrioma) {
      addBadge('Эндометриома', PdfColor.fromHex('7B3F35'));
    }
    if (!onlyActive || hasInfiltrate) {
      addBadge('Инфильтрат', PdfColor.fromHex('5C3D2E'));
    }
    if (!onlyActive || hasSpots) {
      addBadge('Очаги', PdfColor.fromHex('8B4513'));
    }
    if (!onlyActive || hasAdhesions) {
      addBadge('Спайки', PdfColor.fromHex('4A707A'));
    }
    if (!onlyActive || hasFibrosis) {
      addBadge('Фиброз', PdfColor.fromHex('2F4F4F'));
    }
    if (!onlyActive || hasIud) {
      addBadge('ВМС', PdfColor.fromHex('D35400'));
    }
    if (!onlyActive || hasFollicle) {
      addBadge('Фолликул', PdfColor.fromHex('2980B9'));
    }
    if (!onlyActive || hasPolyp) {
      addBadge('Полип', PdfColor.fromHex('8E44AD'));
    }

    if (legendBadges.isEmpty) {
      return pw.SizedBox();
    }

    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F6F8FA'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColor.fromHex('E1E4E8'), width: 0.5),
      ),
      child: pw.Row(
        children: [
          pw.Text(
            'Легенда: ',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('24292F')),
          ),
          pw.SizedBox(width: 6),
          pw.Expanded(
            child: pw.Wrap(
              spacing: 10,
              runSpacing: 3,
              children: legendBadges,
            ),
          ),
        ],
      ),
    );
  }

  /// Блок заключения / заметок врача
  pw.Widget _buildDoctorNotes(String notes) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromHex('F9FAFB'),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        border: pw.Border.all(color: PdfColor.fromHex('D1D5DB'), width: 0.5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'Заключение / Заметки врача:',
            style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('111827')),
          ),
          pw.SizedBox(height: 2),
          pw.Text(
            notes,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.black),
          ),
        ],
      ),
    );
  }

  /// Нижний колонтитул
  pw.Widget _buildFooter(pw.Context context) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Сформировано в системе МедРисунок',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
        pw.Text(
          'Страница ${context.pageNumber} из ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
        ),
      ],
    );
  }
}
