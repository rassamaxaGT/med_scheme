import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/domain/entities/page_data.dart';
import 'package:med_scheme/features/editor/domain/entities/project_data.dart';
import 'package:med_scheme/features/editor/domain/entities/report_config.dart';
import 'package:med_scheme/features/editor/data/services/offscreen_canvas_renderer.dart';
import 'package:med_scheme/features/editor/data/services/pdf_report_generator_impl.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Report Generator and Offscreen Renderer Tests', () {
    late OffscreenCanvasRenderer renderer;
    late PdfReportGeneratorImpl pdfGenerator;

    setUp(() {
      renderer = OffscreenCanvasRenderer();
      pdfGenerator = PdfReportGeneratorImpl(renderer: renderer);
    });

    test('ReportConfig copyWith works as expected', () {
      final config = const ReportConfig();
      final updated = config.copyWith(
        patientId: 'PT-1001',
        doctorName: 'Dr. Smith',
        clinicName: 'MedClinic',
        doctorNotes: 'Всё в норме',
        orientation: PageOrientation.portrait,
        includeHeader: false,
        includeLegend: true,
      );

      expect(updated.patientId, 'PT-1001');
      expect(updated.doctorName, 'Dr. Smith');
      expect(updated.clinicName, 'MedClinic');
      expect(updated.doctorNotes, 'Всё в норме');
      expect(updated.orientation, PageOrientation.portrait);
      expect(updated.includeHeader, false);
      expect(updated.includeLegend, true);
    });

    test('OffscreenCanvasRenderer renders page to PNG bytes', () async {
      final page = PageData(
        id: 'test_page_1',
        pageType: 'pelvis',
        title: 'Таз',
        history: [
          StrokeAction(
            id: 'stroke_1',
            color: const Color(0xFFFF0000),
            strokeWidth: 4.0,
            points: const [Offset(10, 10), Offset(50, 50)],
          ),
          ShapeAction(
            id: 'shape_1',
            color: const Color(0xFF7B3F35),
            strokeWidth: 2.0,
            startPoint: const Offset(100, 100),
            endPoint: const Offset(160, 160),
            shapeType: 'endometrioma',
          ),
        ],
      );

      final pngBytes = await renderer.renderPageToPng(
        page: page,
        dpiScale: 1.0,
        patientId: 'PT-1001',
      );

      expect(pngBytes, isNotEmpty);
      expect(pngBytes.length, greaterThan(100));
    });

    test('OffscreenCanvasRenderer renders branded medical card PNG bytes', () async {
      final page = PageData(
        id: 'test_page_1',
        pageType: 'pelvis',
        title: 'Таз',
        history: [
          StrokeAction(
            id: 'stroke_1',
            color: const Color(0xFF000000),
            strokeWidth: 3.0,
            points: const [Offset(20, 20), Offset(80, 80)],
          ),
        ],
      );

      final config = const ReportConfig(
        patientId: 'PT-2002',
        doctorName: 'Dr. Brown',
        doctorNotes: 'Очаги не выявлены',
        pngExportType: PngExportType.fullMedicalCard,
      );

      final pngBytes = await renderer.renderBrandedMedicalCardPng(
        page: page,
        config: config,
      );

      expect(pngBytes, isNotEmpty);
      expect(pngBytes.length, greaterThan(100));
    });

    test('PdfReportGenerator generates PDF bytes with Cyrillic support and clinical legend', () async {
      final page1 = PageData(
        id: 'p1',
        pageType: 'pelvis',
        title: 'Таз',
        history: [
          ShapeAction(
            id: 'endometrioma_1',
            color: const Color(0xFF7B3F35),
            strokeWidth: 2.0,
            startPoint: const Offset(50, 50),
            endPoint: const Offset(120, 120),
            shapeType: 'endometrioma',
          ),
          StrokeAction(
            id: 'adhesions_1',
            color: const Color(0xFF4A707A),
            strokeWidth: 2.0,
            brushType: 'adhesions',
            points: const [Offset(150, 150), Offset(200, 200)],
          ),
        ],
      );

      final project = ProjectData(
        patientId: 'Пациент Иванов',
        pages: [page1],
      );

      final config = const ReportConfig(
        clinicName: 'Клинический госпиталь УЗИ',
        doctorName: 'Врач Петрова А.А.',
        doctorNotes: 'Эндометриома левого яичника 35 мм. Спаечный процесс в малом тазу.',
        orientation: PageOrientation.landscape,
        includeHeader: true,
        includeLegend: true,
        includeOnlyActiveMarkersInLegend: true,
        includeDoctorNotes: true,
      );

      final pdfBytes = await pdfGenerator.generatePdf(
        project: project,
        config: config,
      );

      expect(pdfBytes, isNotEmpty);
      expect(pdfBytes.length, greaterThan(500));
    });

    test('PdfReportGenerator handles multi-page allOnSinglePage and separatePages layout modes', () async {
      final page1 = PageData(id: 'p1', pageType: 'pelvis', title: 'Таз');
      final page2 = PageData(id: 'p2', pageType: 'uterus', title: 'Матка');
      final project = ProjectData(
        patientId: 'PT-3003',
        pages: [page1, page2],
      );

      // 1. All on single page
      final configSingle = const ReportConfig(
        patientId: 'PT-3003',
        layoutMode: SchemeLayoutMode.allOnSinglePage,
      );
      final pdfSingleBytes = await pdfGenerator.generatePdf(
        project: project,
        config: configSingle,
      );
      expect(pdfSingleBytes, isNotEmpty);

      // 2. Separate pages
      final configSeparate = const ReportConfig(
        patientId: 'PT-3003',
        layoutMode: SchemeLayoutMode.separatePages,
      );
      final pdfSeparateBytes = await pdfGenerator.generatePdf(
        project: project,
        config: configSeparate,
      );
      expect(pdfSeparateBytes, isNotEmpty);
    });
  });
}
