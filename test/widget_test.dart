import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:med_scheme/main.dart';
import 'package:med_scheme/features/editor/domain/repositories/project_repository.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/domain/entities/page_data.dart';
import 'package:med_scheme/features/editor/domain/entities/project_data.dart';
import 'package:med_scheme/features/editor/domain/entities/project_file_source.dart';
import 'package:med_scheme/features/editor/domain/entities/report_config.dart';
import 'package:med_scheme/features/editor/presentation/widgets/toolbox/floating_toolbox.dart';
import 'package:med_scheme/features/editor/presentation/widgets/canvas/canvas_widget.dart';
import 'package:flutter/material.dart';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_bloc.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_event.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_state.dart';
import 'package:med_scheme/features/editor/presentation/screens/editor_screen.dart';

class FakeProjectRepository implements ProjectRepository {
  @override
  Future<String?> requestProjectDirectory() async => 'test_dir';

  @override
  Future<void> saveProject({
    required String directoryPath,
    required String projectName,
    required List<PageData> pages,
    required String? patientId,
    List<CustomSchemeItem>? customSchemes,
  }) async {}

  @override
  Future<ProjectData> loadProject(ProjectFileSource source) async {
    return ProjectData(pages: [], patientId: null);
  }

  @override
  Future<String> exportToGallery({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  }) async => 'test_output_path.png';

  @override
  Future<String> exportToPdf({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  }) async => 'test_output_path.pdf';

  @override
  Future<Uint8List> generateReportPdf({
    required ProjectData project,
    required ReportConfig config,
    bool isForPreview = false,
  }) async => Uint8List.fromList([0, 1, 2]);

  @override
  Future<void> printReport({
    required ProjectData project,
    required ReportConfig config,
  }) async {}

  @override
  Future<String> exportReportPdf({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
  }) async => 'test_report_path.pdf';

  @override
  Future<String> exportReportPng({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
    PageData? singlePage,
  }) async => 'test_report_path.png';

  @override
  Future<void> saveDirectoryPath(String path) async {}

  @override
  Future<String?> getSavedDirectoryPath() async => 'test_dir';
}


void main() {
  setUp(() {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<ProjectRepository>()) {
      getIt.registerLazySingleton<ProjectRepository>(
        () => FakeProjectRepository(),
      );
    }
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets('EditorScreen loads and displays tools', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump(); // Allow frames and async operations to resolve

    // Verify that the title of the editor is displayed
    expect(find.text('Новый проект • Сохранено'), findsOneWidget);

    // Verify that the new toolbox elements (with labels) are present
    expect(find.text('Кисть'), findsOneWidget);
    expect(find.text('Ластик'), findsOneWidget);
  });

  testWidgets('FloatingToolbox is rendered and interacts correctly', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Verify that the FloatingToolbox is rendered
    expect(find.byType(FloatingToolbox), findsOneWidget);

    // Verify that the drag indicator icon is present
    expect(find.byIcon(Icons.drag_indicator), findsOneWidget);

    // Verify that we have the tool icons (only one instance each since sidebar is removed)
    expect(find.byIcon(Icons.open_with), findsOneWidget);
    expect(find.text('Кисть'), findsOneWidget);
    
    // Verify that the menu button is present in the AppBar
    expect(find.byIcon(Icons.folder), findsOneWidget);
  });

  testWidgets('Drag toolbox to right, select pencil, draw and finish - should not throw and keep toolbox', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    final dragHandleFinder = find.byIcon(Icons.drag_indicator);
    expect(dragHandleFinder, findsOneWidget);
    
    // Drag to the right edge
    await tester.drag(dragHandleFinder, const Offset(50.0, 20.0));
    await tester.pumpAndSettle();

    // Select the pencil tool
    final pencilToolFinder = find.text('Кисть');
    await tester.tap(pencilToolFinder, warnIfMissed: false);
    await tester.pumpAndSettle();

    // Draw on the canvas
    final canvasFinder = find.byType(CanvasWidget);
    expect(canvasFinder, findsOneWidget);

    final gesture = await tester.startGesture(const Offset(100.0, 100.0));
    await tester.pump();
    await gesture.moveBy(const Offset(50.0, 50.0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();

    // Verify no exception was thrown and the toolbox is still visible
    expect(find.byType(FloatingToolbox), findsOneWidget);
  });

  testWidgets('Selecting bowelInfiltrate displays SettingsBubble with size slider', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    // Select ToolType.bowelInfiltrate via DrawBloc
    final BuildContext context = tester.element(find.byType(EditorScreen));
    context.read<DrawBloc>().add(SelectToolEvent(ToolType.bowelInfiltrate));
    await tester.pumpAndSettle();

    // Verify SettingsBubble is shown
    expect(find.byType(SettingsBubble), findsOneWidget);
    // Verify size slider is present (text starts with "Размер:")
    expect(find.textContaining('Размер:'), findsOneWidget);
  });
}
