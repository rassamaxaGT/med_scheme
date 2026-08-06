import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
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

  /// Экспортирует плоское изображение холста с разметкой в выбранную директорию
  Future<String> exportToGallery({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  });

  /// Экспортирует холст с разметкой в PDF-отчет
  Future<String> exportToPdf({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
    required String? patientId,
  });

  /// Сохраняет путь к выбранной директории локально
  Future<void> saveDirectoryPath(String path);

  /// Возвращает локально сохраненный путь к директории
  Future<String?> getSavedDirectoryPath();
}
