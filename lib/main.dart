import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'core/di/injection.dart';
import 'features/editor/domain/repositories/project_repository.dart';
import 'features/editor/presentation/bloc/draw_bloc.dart';
import 'features/editor/presentation/bloc/project_bloc.dart';
import 'features/editor/presentation/screens/editor_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initInjection();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'МедРисунок - УЗИ Редактор',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F4C81), // Classic Blue
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<DrawBloc>(create: (context) => DrawBloc()),
          BlocProvider<ProjectBloc>(
            create: (context) =>
                ProjectBloc(projectRepository: getIt<ProjectRepository>())..add(
                  InitializeProjectEvent(),
                ), // Инициализируем из сохраненного пути
          ),
        ],
        child: const EditorScreen(),
      ),
    );
  }
}
