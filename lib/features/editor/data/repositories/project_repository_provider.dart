import '../../domain/repositories/project_repository.dart';
import 'project_repository_stub.dart'
    if (dart.library.io) 'project_repository_impl.dart'
    if (dart.library.html) 'project_repository_web.dart'
    if (dart.library.js_interop) 'project_repository_web.dart';

ProjectRepository getProjectRepository() => getProjectRepositoryPlatform();
