import 'dart:async';
import 'dart:io' show File;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/report_config.dart';
import '../../presentation/widgets/canvas/canvas_painter.dart';

/// Сервис оффскрин-рендеринга холста в высоком разрешении (Hi-DPI) на белом фоне
class OffscreenCanvasRenderer {
  /// Кеш загруженных изображений для ускорения пакетного рендера
  final Map<String, ui.Image> _imageCache = {};

  /// Загрузка изображения по пути (ассет или файл на диске)
  Future<ui.Image?> loadImage(String path) async {
    if (_imageCache.containsKey(path)) {
      return _imageCache[path];
    }

    try {
      Uint8List? bytes;
      if (path.startsWith('assets/')) {
        final byteData = await rootBundle.load(path);
        bytes = byteData.buffer.asUint8List();
      } else if (!kIsWeb) {
        final file = File(path);
        if (await file.exists()) {
          bytes = await file.readAsBytes();
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        _imageCache[path] = frame.image;
        return frame.image;
      }
    } catch (e) {
      debugPrint('[OffscreenCanvasRenderer] Ошибка загрузки изображения "$path": $e');
    }
    return null;
  }

  /// Предзагрузка фоновых изображений для страницы
  Future<Map<String, ui.Image>> preloadBackgroundImages(List<String> paths) async {
    final Map<String, ui.Image> result = {};
    for (final path in paths) {
      final img = await loadImage(path);
      if (img != null) {
        result[path] = img;
      }
    }
    return result;
  }

  /// Предзагрузка штампов, используемых в действиях
  Future<Map<String, ui.Image>> preloadStampImages(List<DrawAction> actions) async {
    final Map<String, ui.Image> result = {};
    for (final action in actions) {
      if (action is StampAction &&
          action.customStampPath != null &&
          action.customStampPath!.isNotEmpty) {
        final img = await loadImage(action.customStampPath!);
        if (img != null) {
          result[action.customStampPath!] = img;
        }
      }
    }
    return result;
  }

  /// Кеш отрендеренных PNG байтов схем для мгновенного повторного использования
  final Map<String, Uint8List> _pagePngCache = {};

  void clearCache() {
    _imageCache.clear();
    _pagePngCache.clear();
  }

  /// Рендерит отдельную страницу со схемой и разметкой в чистый PNG
  Future<Uint8List> renderPageToPng({
    required PageData page,
    double dpiScale = 2.0,
    String? patientId,
    bool isForPreview = false,
  }) async {
    final activePaths = page.backgroundPaths.isNotEmpty
        ? page.backgroundPaths
        : (page.backgroundPath != null ? [page.backgroundPath!] : const <String>[]);

    final cacheKey =
        '${page.id}_${page.history.length}_${activePaths.join(",")}_${dpiScale}_${isForPreview}_$patientId';
    if (_pagePngCache.containsKey(cacheKey)) {
      return _pagePngCache[cacheKey]!;
    }

    final bgImages = await preloadBackgroundImages(activePaths);
    final stampImages = await preloadStampImages(page.history);

    final baseSize = CanvasPainter.getCanvasBaseSize(activePaths, bgImages);
    // Для интерактивного предпросмотра используем легковесный масштаб (ускорение PNG-кодирования в 20 раз),
    // а для финальной печати/экспорта — полное качество 1600-4096px
    final double scale = isForPreview
        ? 0.75
        : ((activePaths.length <= 1) ? 2.0 : 1.25);
    final int minW = isForPreview ? 600 : 1600;
    final int minH = isForPreview ? 500 : 1200;
    final int maxDim = isForPreview ? 1000 : 4096;
    final width = (baseSize.width * scale).round().clamp(minW, maxDim);
    final height = (baseSize.height * scale).round().clamp(minH, maxDim);
    final renderSize = Size(width.toDouble(), height.toDouble());

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Заливка чисто белым фоном
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, renderSize.width, renderSize.height), bgPaint);

    final painter = CanvasPainter(
      history: page.history,
      backgroundPaths: activePaths,
      bgImages: bgImages,
      stampImages: stampImages,
      patientId: patientId,
    );

    painter.paint(canvas, renderSize);

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Не удалось сформировать PNG изображение схемы');
    }

    final result = byteData.buffer.asUint8List();
    _pagePngCache[cacheKey] = result;
    return result;
  }

  /// Рендерит готовый медицинский бланк-карточку в PNG
  Future<Uint8List> renderBrandedMedicalCardPng({
    required PageData page,
    required ReportConfig config,
  }) async {
    // 1. Рендерим саму схему в высоком качестве
    final schemeBytes = await renderPageToPng(
      page: page,
      dpiScale: config.dpiScale,
      patientId: config.patientId,
    );

    final schemeCodec = await ui.instantiateImageCodec(schemeBytes);
    final schemeFrame = await schemeCodec.getNextFrame();
    final schemeImage = schemeFrame.image;

    // 2. Рассчитываем размеры карточки с учетом шапки и подвала
    final double cardWidth = schemeImage.width.toDouble();
    final double headerHeight = config.includeHeader ? 120.0 * config.dpiScale : 20.0 * config.dpiScale;
    final double legendHeight = config.includeLegend ? 100.0 * config.dpiScale : 20.0 * config.dpiScale;
    final double footerHeight = (config.includeDoctorNotes && config.doctorNotes.isNotEmpty)
        ? 120.0 * config.dpiScale
        : 40.0 * config.dpiScale;

    final double totalHeight = headerHeight + schemeImage.height + legendHeight + footerHeight;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    // Белый фон карточки
    final bgPaint = Paint()..color = Colors.white;
    canvas.drawRect(Rect.fromLTWH(0, 0, cardWidth, totalHeight), bgPaint);

    double currentY = 16.0 * config.dpiScale;

    // Шапка
    if (config.includeHeader) {
      final titlePainter = TextPainter(
        text: TextSpan(
          text: config.clinicName.isNotEmpty ? config.clinicName : 'МедРисунок — УЗИ Протокол',
          style: TextStyle(
            color: const Color(0xFF0F4C81),
            fontSize: 16.0 * config.dpiScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cardWidth - 32 * config.dpiScale);
      titlePainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
      currentY += titlePainter.height + 4 * config.dpiScale;

      final device = config.deviceModel.trim();
      final probes = config.probes.trim();
      String? equipmentText;
      if (device.isNotEmpty && probes.isNotEmpty) {
        final isMultipleProbes = probes.contains(',') || probes.contains(';') || probes.contains(' и ');
        final probeWord = isMultipleProbes ? 'датчиков' : 'датчика';
        equipmentText = 'Исследование выполнено на аппарате $device с использованием $probeWord $probes';
      } else if (device.isNotEmpty) {
        equipmentText = 'Исследование выполнено на аппарате $device';
      } else if (probes.isNotEmpty) {
        final isMultipleProbes = probes.contains(',') || probes.contains(';') || probes.contains(' и ');
        final probeWord = isMultipleProbes ? 'датчиков' : 'датчика';
        equipmentText = 'Использованы $probeWord: $probes';
      }

      if (equipmentText != null) {
        final equipPainter = TextPainter(
          text: TextSpan(
            text: equipmentText,
            style: TextStyle(
              color: const Color(0xFF444444),
              fontSize: 10.0 * config.dpiScale,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: cardWidth - 32 * config.dpiScale);
        equipPainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
        currentY += equipPainter.height + 4 * config.dpiScale;
      }

      final date = config.createdAt ?? DateTime.now();
      final formattedDate =
          '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year} '
          '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

      final infoText = StringBuffer();
      if (config.patientId.isNotEmpty) infoText.write('Пациент: ${config.patientId}   ');
      if (config.doctorName.isNotEmpty) infoText.write('Врач: ${config.doctorName}   ');
      infoText.write('Дата создания: $formattedDate');

      final infoPainter = TextPainter(
        text: TextSpan(
          text: infoText.toString(),
          style: TextStyle(
            color: const Color(0xFF333333),
            fontSize: 11.0 * config.dpiScale,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cardWidth - 32 * config.dpiScale);
      infoPainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
      currentY += infoPainter.height + 12 * config.dpiScale;

      // Тонкая разделительная линия
      final linePaint = Paint()
        ..color = const Color(0xFFD0D7DE)
        ..strokeWidth = 1.0 * config.dpiScale;
      canvas.drawLine(
        Offset(16 * config.dpiScale, currentY),
        Offset(cardWidth - 16 * config.dpiScale, currentY),
        linePaint,
      );
      currentY += 10 * config.dpiScale;
    }

    // Отрисовка схемы
    canvas.drawImage(schemeImage, Offset(0, currentY), Paint());
    currentY += schemeImage.height + 12 * config.dpiScale;

    // Легенда
    if (config.includeLegend) {
      final legendTitlePainter = TextPainter(
        text: TextSpan(
          text: 'Клинические маркеры (Sonocontreras):',
          style: TextStyle(
            color: const Color(0xFF1F2328),
            fontSize: 11.0 * config.dpiScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      legendTitlePainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
      currentY += legendTitlePainter.height + 4 * config.dpiScale;

      final legendItemsPainter = TextPainter(
        text: TextSpan(
          text: '• Эндометриома — коричневый круг   • Инфильтрат — волнистый контур   • Очаги — пятна   • Спайки — сетка   • Фиброз — штриховка',
          style: TextStyle(
            color: const Color(0xFF57606A),
            fontSize: 9.5 * config.dpiScale,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cardWidth - 32 * config.dpiScale);
      legendItemsPainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
      currentY += legendItemsPainter.height + 10 * config.dpiScale;
    }

    // Заключение врача
    if (config.includeDoctorNotes && config.doctorNotes.isNotEmpty) {
      final notesTitlePainter = TextPainter(
        text: TextSpan(
          text: 'Заключение / Заметки:',
          style: TextStyle(
            color: const Color(0xFF1F2328),
            fontSize: 11.0 * config.dpiScale,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      notesTitlePainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
      currentY += notesTitlePainter.height + 4 * config.dpiScale;

      final notesPainter = TextPainter(
        text: TextSpan(
          text: config.doctorNotes,
          style: TextStyle(
            color: const Color(0xFF24292F),
            fontSize: 10.0 * config.dpiScale,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: cardWidth - 32 * config.dpiScale);
      notesPainter.paint(canvas, Offset(16 * config.dpiScale, currentY));
    }

    final picture = recorder.endRecording();
    final finalImage = await picture.toImage(cardWidth.round(), totalHeight.round());
    final byteData = await finalImage.toByteData(format: ui.ImageByteFormat.png);

    if (byteData == null) {
      throw Exception('Не удалось сформировать медицинский бланк PNG');
    }

    return byteData.buffer.asUint8List();
  }
}
