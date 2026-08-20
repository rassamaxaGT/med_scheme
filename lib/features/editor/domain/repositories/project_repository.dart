import 'dart:typed_data';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
import '../../domain/entities/report_config.dart';
import '../../presentation/bloc/draw_state.dart';

abstract class ProjectRepository {
  /// Запрашивает у пользователя папку сохранения проектов (для Android SAF)
  Future<String?> requestProjectDirectory();

  /// Сохраняет проект в ZIP-контейнер (.meddraw)
  Future<void> saveProject({
    required String directoryPath,
    required String projectName,
    required List<PageData> pages,
    required String? patientId,
    List<CustomSchemeItem>? customSchemes,
  });

  /// Загружает проект из ZIP-контейнера (.meddraw) и возвращает данные проекта
  Future<ProjectData> loadProject(ProjectFileSource source);

  /// Экспортирует плоское изображение холста с разметкой в выбранную директорию (legacy)
  Future<String> exportToGallery({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  });

  /// Экспортирует холст с разметкой в PDF-отчет (legacy)
  Future<String> exportToPdf({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  });

  /// Генерирует байты медицинского PDF-отчета
  Future<Uint8List> generateReportPdf({
    required ProjectData project,
    required ReportConfig config,
  });

  /// Отправляет медицинский отчет на печать через системную службу печати
  Future<void> printReport({
    required ProjectData project,
    required ReportConfig config,
  });

  /// Экспортирует полноценный медицинский PDF-отчет в выбранную папку
  Future<String> exportReportPdf({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
  });

  /// Экспортирует высокое разрешение PNG (чистую схему или готовый медицинский бланк)
  Future<String> exportReportPng({
    required String directoryPath,
    required String filename,
    required ProjectData project,
    required ReportConfig config,
    PageData? singlePage,
  });

  /// Сохраняет путь к выбранной директории локально
  Future<void> saveDirectoryPath(String path);

  /// Возвращает локально сохраненный путь к директории
  Future<String?> getSavedDirectoryPath();
}
