import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/project_data.dart';
import '../../domain/entities/project_file_source.dart';
import '../../domain/repositories/project_repository.dart';

// --- Events ---
abstract class ProjectEvent {}

class InitializeProjectEvent extends ProjectEvent {}

class RequestDirectoryEvent extends ProjectEvent {}

class SaveProjectEvent extends ProjectEvent {
  final String projectName;
  final List<DrawAction> actions;
  final String? backgroundPath;

  SaveProjectEvent({
    required this.projectName,
    required this.actions,
    this.backgroundPath,
  });
}

class ExportProjectEvent extends ProjectEvent {
  final String projectName;
  final List<DrawAction> actions;
  final String? backgroundPath;

  ExportProjectEvent({
    required this.projectName,
    required this.actions,
    this.backgroundPath,
  });
}

class LoadProjectEvent extends ProjectEvent {
  final ProjectFileSource source;
  LoadProjectEvent(this.source);
}

// --- States ---
abstract class ProjectState {}

class ProjectInitial extends ProjectState {}

class ProjectDirectoryNotSelected extends ProjectState {}

class ProjectDirectorySelected extends ProjectState {
  final String directoryPath;
  ProjectDirectorySelected(this.directoryPath);
}

class ProjectLoading extends ProjectState {}

class ProjectLoaded extends ProjectState {
  final List<DrawAction> actions;
  final String? backgroundPath;
  final String filePath;
  ProjectLoaded(this.actions, this.backgroundPath, this.filePath);
}

class ProjectSaved extends ProjectState {
  final String filePath;
  ProjectSaved(this.filePath);
}

class ProjectExported extends ProjectState {
  final String outputPath;
  ProjectExported(this.outputPath);
}

class ProjectError extends ProjectState {
  final String message;
  ProjectError(this.message);
}

// --- BLoC ---
class ProjectBloc extends Bloc<ProjectEvent, ProjectState> {
  final ProjectRepository projectRepository;
  String? _selectedDirectoryPath;
  String? currentProjectFilePath; // Путь к текущему открытому файлу проекта

  ProjectBloc({required this.projectRepository}) : super(ProjectInitial()) {
    on<InitializeProjectEvent>((event, emit) async {
      try {
        final path = await projectRepository.getSavedDirectoryPath();
        if (path != null) {
          _selectedDirectoryPath = path;
          emit(ProjectDirectorySelected(path));
        } else {
          emit(ProjectDirectoryNotSelected());
        }
      } catch (e) {
        debugPrint('Ошибка инициализации сохраненной директории: $e');
        emit(ProjectDirectoryNotSelected());
      }
    });

    on<RequestDirectoryEvent>((event, emit) async {
      try {
        final path = await projectRepository.requestProjectDirectory();
        if (path != null) {
          _selectedDirectoryPath = path;
          await projectRepository.saveDirectoryPath(path);
          emit(ProjectDirectorySelected(path));
        } else {
          emit(ProjectError('Папка не была выбрана'));
        }
      } catch (e) {
        emit(ProjectError('Ошибка при выборе папки: $e'));
      }
    });

    on<SaveProjectEvent>((event, emit) async {
      if (_selectedDirectoryPath == null) {
        emit(ProjectError('Сначала выберите рабочую папку'));
        return;
      }
      emit(ProjectLoading());
      try {
        await projectRepository.saveProject(
          directoryPath: _selectedDirectoryPath!,
          projectName: event.projectName,
          actions: event.actions,
          backgroundPath: event.backgroundPath,
        );
        final filePath = '$_selectedDirectoryPath/${event.projectName}.meddraw';
        currentProjectFilePath = filePath;
        emit(ProjectSaved(filePath));
        // Возвращаем состояние выбранной папки
        emit(ProjectDirectorySelected(_selectedDirectoryPath!));
      } catch (e) {
        emit(ProjectError('Ошибка сохранения проекта: $e'));
      }
    });

    on<ExportProjectEvent>((event, emit) async {
      if (_selectedDirectoryPath == null) {
        emit(ProjectError('Сначала выберите рабочую папку'));
        return;
      }
      emit(ProjectLoading());
      try {
        final outputPath = await projectRepository.exportToGallery(
          directoryPath: _selectedDirectoryPath!,
          filename: event.projectName,
          actions: event.actions,
          backgroundPath: event.backgroundPath,
        );
        emit(ProjectExported(outputPath));
        // Возвращаем состояние выбранной папки
        emit(ProjectDirectorySelected(_selectedDirectoryPath!));
      } catch (e) {
        emit(ProjectError('Ошибка экспорта: $e'));
      }
    });

    on<LoadProjectEvent>((event, emit) async {
      emit(ProjectLoading());
      try {
        final ProjectData projectData = await projectRepository.loadProject(event.source);
        final path = event.source.path ?? event.source.name;
        currentProjectFilePath = path;
        emit(ProjectLoaded(projectData.actions, projectData.backgroundPath, path));
      } catch (e) {
        emit(ProjectError('Ошибка загрузки проекта: $e'));
      }
    });
  }
}
