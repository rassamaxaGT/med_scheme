import 'package:get_it/get_it.dart';
import '../../features/editor/data/repositories/project_repository_provider.dart';
import '../../features/editor/domain/repositories/project_repository.dart';

final getIt = GetIt.instance;

Future<void> initInjection() async {
  // Repositories
  getIt.registerLazySingleton<ProjectRepository>(() => getProjectRepository());
}
