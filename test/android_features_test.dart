import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:med_scheme/features/editor/domain/entities/draw_action.dart';
import 'package:med_scheme/features/editor/domain/entities/page_data.dart';
import 'package:med_scheme/features/editor/domain/entities/project_data.dart';
import 'package:med_scheme/features/editor/domain/entities/project_file_source.dart';
import 'package:med_scheme/features/editor/domain/entities/report_config.dart';
import 'package:med_scheme/features/editor/domain/repositories/project_repository.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_bloc.dart';
import 'package:med_scheme/features/editor/presentation/bloc/draw_state.dart';
import 'package:med_scheme/features/editor/presentation/bloc/project_bloc.dart';
import 'package:med_scheme/features/editor/presentation/screens/editor_screen.dart';
import 'dart:typed_data';

class MockProjectRepository implements ProjectRepository {
  bool requestDirectoryCalled = false;

  @override
  Future<String?> requestProjectDirectory() async {
    requestDirectoryCalled = true;
    return 'content://com.android.externalstorage.documents/tree/primary%3AMedDraw';
  }

  @override
  Future<String?> getSavedDirectoryPath() async => null;

  @override
  Future<void> saveDirectoryPath(String path) async {}

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
  }) async => 'test.png';

  @override
  Future<String> exportToPdf({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  }) async => 'test.pdf';

  @override
  Future<Uint8List> generateReportPdf({
    required ProjectData project,
    required ReportConfig config,
    bool isForPreview = false,
  }) async => Uint8List(0);

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
  }) async => 'test.pdf';

  @override
  Future<String> exportReportPng({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
    PageData? singlePage,
  }) async => 'test.png';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('requestDirectoryWithNotice shows interactive first-run dialog and handles selection', (tester) async {
    final mockRepo = MockProjectRepository();
    final projectBloc = ProjectBloc(projectRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DrawBloc>(create: (_) => DrawBloc()),
            BlocProvider<ProjectBloc>.value(value: projectBloc),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      EditorScreen.requestDirectoryWithNotice(context, isFirstRun: true);
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to open dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify first-run dialog contents
    expect(find.text('Добро пожаловать в МедРисунок!'), findsOneWidget);
    expect(find.byIcon(Icons.folder_special_rounded), findsOneWidget);
    expect(find.text('Позже'), findsOneWidget);
    expect(find.text('Выбрать'), findsOneWidget);

    // Tap "Выбрать"
    await tester.tap(find.text('Выбрать'));
    await tester.pumpAndSettle();

    // Dialog should be dismissed
    expect(find.text('Добро пожаловать в МедРисунок!'), findsNothing);

    // Mock repo should have been requested
    expect(mockRepo.requestDirectoryCalled, isTrue);
  });

  testWidgets('requestDirectoryWithNotice dismisses on "Позже"', (tester) async {
    final mockRepo = MockProjectRepository();
    final projectBloc = ProjectBloc(projectRepository: mockRepo);

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<DrawBloc>(create: (_) => DrawBloc()),
            BlocProvider<ProjectBloc>.value(value: projectBloc),
          ],
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () {
                      EditorScreen.requestDirectoryWithNotice(context, isFirstRun: true);
                    },
                    child: const Text('Show Dialog'),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    expect(find.text('Позже'), findsOneWidget);
    await tester.tap(find.text('Позже'));
    await tester.pumpAndSettle();

    expect(find.text('Добро пожаловать в МедРисунок!'), findsNothing);
    expect(mockRepo.requestDirectoryCalled, isFalse);
  });
}
