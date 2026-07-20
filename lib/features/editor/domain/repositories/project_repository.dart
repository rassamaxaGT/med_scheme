import '../../domain/entities/draw_action.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';

abstract class ProjectRepository {
  /// Запрашивает у пользователя папку сохранения проектов (для Android SAF)
  Future<String?> requestProjectDirectory();

  /// Сохраняет проект в ZIP-контейнера (.meddraw)
  Future<void> saveProject({
    required String directoryPath,
    required String projectName,
    required List<DrawAction> actions,
    required String? backgroundPath,
  });

  /// Загружает проект из ZIP-контейнера (.meddraw) и возвращает данные проекта
  Future<ProjectData> loadProject(ProjectFileSource source);

  /// Экспортирует плоское изображение холста с разметкой в выбранную директорию
  Future<String> exportToGallery({
    required String directoryPath,
    required String filename,
    required List<DrawAction> actions,
    required String? backgroundPath,
  });

  /// Сохраняет путь к выбранной директории локально
  Future<void> saveDirectoryPath(String path);

  /// Возвращает локально сохраненный путь к директории
  Future<String?> getSavedDirectoryPath();
}
