import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'core/di/injection.dart';
import 'core/utils/web_helper.dart';
import 'features/editor/domain/entities/draw_action.dart';
import 'features/editor/domain/entities/project_file_source.dart';
import 'features/editor/domain/repositories/project_repository.dart';
import 'features/editor/presentation/bloc/draw_bloc.dart';
import 'features/editor/presentation/bloc/draw_event.dart';
import 'features/editor/presentation/bloc/draw_state.dart';
import 'features/editor/presentation/bloc/project_bloc.dart';
import 'features/editor/presentation/widgets/canvas/canvas_widget.dart';
import 'features/editor/presentation/widgets/toolbox/floating_toolbox.dart';


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
            create: (context) => ProjectBloc(
              projectRepository: getIt<ProjectRepository>(),
            )..add(InitializeProjectEvent()), // Инициализируем из сохраненного пути
          ),
        ],
        child: const EditorScreen(),
      ),
    );
  }
}

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});

  static void requestDirectoryWithNotice(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Выбор рабочей папки'),
          content: const Text(
            'Для сохранения и загрузки ваших проектов, а также экспорта размеченных схем, необходимо выбрать рабочую папку на устройстве.\n\n'
            'В следующем системном окне выберите существующую папку или создайте новую (например, "МедРисунки") и подтвердите доступ кнопкой "Использовать эту папку".'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ProjectBloc>().add(RequestDirectoryEvent());
              },
              child: const Text('Выбрать'),
            ),
          ],
        );
      },
    );
  }

  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  Offset? _toolboxOffset;
  Offset? _dragPosition;
  int _lastSavedActionsCount = 0;
  String? _lastSavedBackgroundPath;
  ToolboxOrientation _toolboxOrientation = ToolboxOrientation.horizontal;

  double _safeClamp(double value, double min, double max) {
    if (min > max) return min;
    return value.clamp(min, max);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: const Icon(
          Icons.healing,
          color: Color(0xFF0F4C81),
          size: 24,
        ),
        title: BlocBuilder<ProjectBloc, ProjectState>(
          builder: (context, projectState) {
            final projectBloc = context.read<ProjectBloc>();
            final filePath = projectBloc.currentProjectFilePath;
            final projectName = filePath != null 
                ? _getProjectNameFromPath(filePath) 
                : 'Новый проект';
            
            return BlocBuilder<DrawBloc, DrawState>(
              builder: (context, drawState) {
                final isModified = drawState.history.length != _lastSavedActionsCount ||
                    drawState.backgroundPath != _lastSavedBackgroundPath;
                
                return Text(
                  isModified ? '$projectName • Изменен' : '$projectName • Сохранено',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                );
              },
            );
          },
        ),
        centerTitle: true,
        backgroundColor: const Color(0x99181818),
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.transparent),
          ),
        ),
        actions: [
          // Правая часть: группы кнопок управления
          BlocBuilder<DrawBloc, DrawState>(
            builder: (context, drawState) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.undo, size: 20),
                      tooltip: 'Отмена (Undo)',
                      onPressed: drawState.history.isEmpty
                          ? null
                          : () => context.read<DrawBloc>().add(UndoEvent()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.redo, size: 20),
                      tooltip: 'Повтор (Redo)',
                      onPressed: drawState.redoStack.isEmpty
                          ? null
                          : () => context.read<DrawBloc>().add(RedoEvent()),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, size: 20),
                      tooltip: 'Очистить холст',
                      color: drawState.history.isEmpty ? null : Colors.redAccent.withValues(alpha: 0.8),
                      onPressed: drawState.history.isEmpty
                          ? null
                          : () => context.read<DrawBloc>().add(ClearCanvasEvent()),
                    ),
                  ],
                ),
              );
            },
          ),
          
          // Быстрая кнопка сохранения
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить проект',
            onPressed: () => _showSaveDialog(context),
          ),
          
          // Кнопка экспорта
          Padding(
            padding: const EdgeInsets.only(right: 16, left: 8),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.photo_library, size: 16),
              label: const Text('Экспорт', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              onPressed: () => _exportCanvas(context),
            ),
          ),
        ],
      ),
      body: BlocListener<ProjectBloc, ProjectState>(
        listener: (context, state) {
          if (state is ProjectDirectoryNotSelected) {
            EditorScreen.requestDirectoryWithNotice(context);
          } else if (state is ProjectSaved) {
            setState(() {
              _lastSavedActionsCount = context.read<DrawBloc>().state.history.length;
              _lastSavedBackgroundPath = context.read<DrawBloc>().state.backgroundPath;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Проект успешно сохранен!')),
            );
          } else if (state is ProjectExported) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Схема экспортирована в ${state.outputPath}')),
            );
          } else if (state is ProjectLoaded) {
            // Загружаем действия в DrawBloc холста
            context.read<DrawBloc>().add(ClearCanvasEvent());
            for (final action in state.actions) {
              context.read<DrawBloc>().add(AddActionEvent(action));
            }
            // Загружаем фоновое изображение
            context.read<DrawBloc>().add(SetBackgroundEvent(state.backgroundPath));
            setState(() {
              _lastSavedActionsCount = state.actions.length;
              _lastSavedBackgroundPath = state.backgroundPath;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Проект успешно загружен!')),
            );
          } else if (state is ProjectError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message), backgroundColor: Colors.redAccent),
            );
          }
        },
        child: Stack(
          children: [
            // Задний слой: холст на весь экран
            const Positioned.fill(
              child: CanvasWidget(),
            ),
            // Плавающий перемещаемый тулбар
            // Панель настроек (Settings Bubble) - рендерится отдельно, чтобы избежать блокировки касаний
            BlocBuilder<DrawBloc, DrawState>(
              builder: (context, drawState) {
                final mediaQuery = MediaQuery.sizeOf(context);
                final screenWidth = mediaQuery.width;
                final screenHeight = mediaQuery.height;

                final tool = drawState.currentTool;
                if (tool == ToolType.move) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());

                final bool showColor = tool == ToolType.pencil ||
                    tool == ToolType.infiltrate ||
                    tool == ToolType.adhesions ||
                    tool == ToolType.arrow ||
                    tool == ToolType.foci;

                final bool showThickness = tool == ToolType.pencil ||
                    tool == ToolType.infiltrate ||
                    tool == ToolType.adhesions ||
                    tool == ToolType.arrow ||
                    tool == ToolType.eraser ||
                    tool == ToolType.endometrioma ||
                    tool == ToolType.myoma ||
                    tool == ToolType.iud;

                if (!showColor && !showThickness) return const Positioned(left: 0, top: 0, child: SizedBox.shrink());

                // Размеры панели
                final double statusBarHeight = MediaQuery.paddingOf(context).top;
                final double horizontalWidth = screenWidth > 700 ? 700.0 : screenWidth - 32;
                final double verticalWidth = 76.0;
                final bool hasSettings = drawState.currentTool != ToolType.move;
                final double horizontalHeight = hasSettings ? 110.0 : 60.0;
                final double verticalHeight = (screenHeight - kToolbarHeight - statusBarHeight - 32.0).clamp(100.0, 520.0);

                final double initialX = (screenWidth - horizontalWidth) / 2;
                final double initialY = screenHeight - horizontalHeight - 32;

                final currentOffset = _toolboxOffset ?? Offset(initialX, initialY);
                final bubbleWidth = horizontalWidth.clamp(200.0, 340.0);

                // Вычисляем зажатые координаты для рендеринга без мутации состояния
                Offset clampedOffset = currentOffset;
                if (_toolboxOffset != null) {
                  final double currentWidth = (_toolboxOrientation == ToolboxOrientation.horizontal) ? horizontalWidth : verticalWidth;
                  final double currentHeight = (_toolboxOrientation == ToolboxOrientation.horizontal) ? horizontalHeight : verticalHeight;
                  
                  final double minX = 16.0;
                  final double maxX = _safeClamp(screenWidth - currentWidth - 16.0, minX, screenWidth);
                  final double minY = kToolbarHeight + statusBarHeight + 16.0;
                  final double maxY = _safeClamp(screenHeight - currentHeight - 16.0, minY, screenHeight);
                  
                  clampedOffset = Offset(
                    _safeClamp(_toolboxOffset!.dx, minX, maxX),
                    _safeClamp(_toolboxOffset!.dy, minY, maxY),
                  );
                }

                if (_toolboxOrientation == ToolboxOrientation.horizontal) {
                  // Позиционируем над тулбаром
                  return Positioned(
                    left: clampedOffset.dx + (horizontalWidth - bubbleWidth) / 2, // Центрируем баббл над горизонтальным тулбаром
                    top: clampedOffset.dy - 48.0, // Высота баббла ~40px + отступ 8px
                    child: Container(
                      constraints: BoxConstraints(maxWidth: bubbleWidth),
                      child: SettingsBubble(
                        currentColor: drawState.currentColor,
                        currentStrokeWidth: drawState.currentStrokeWidth,
                        currentTool: drawState.currentTool,
                        onColorChanged: (color) {
                          context.read<DrawBloc>().add(ChangeColorEvent(color));
                        },
                        onThicknessChanged: (width) {
                          context.read<DrawBloc>().add(ChangeStrokeWidthEvent(width));
                        },
                        orientation: _toolboxOrientation,
                      ),
                    ),
                  );
                } else if (_toolboxOrientation == ToolboxOrientation.verticalLeft) {
                  // Справа от тулбара
                  return Positioned(
                    left: clampedOffset.dx + verticalWidth + 8.0,
                    top: clampedOffset.dy,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: verticalWidth),
                      child: SettingsBubble(
                        currentColor: drawState.currentColor,
                        currentStrokeWidth: drawState.currentStrokeWidth,
                        currentTool: drawState.currentTool,
                        onColorChanged: (color) {
                          context.read<DrawBloc>().add(ChangeColorEvent(color));
                        },
                        onThicknessChanged: (width) {
                          context.read<DrawBloc>().add(ChangeStrokeWidthEvent(width));
                        },
                        orientation: _toolboxOrientation,
                      ),
                    ),
                  );
                } else {
                  // Слева от тулбара (verticalRight)
                  return Positioned(
                    left: clampedOffset.dx - verticalWidth - 8.0,
                    top: clampedOffset.dy,
                    child: Container(
                      constraints: BoxConstraints(maxWidth: verticalWidth),
                      child: SettingsBubble(
                        currentColor: drawState.currentColor,
                        currentStrokeWidth: drawState.currentStrokeWidth,
                        currentTool: drawState.currentTool,
                        onColorChanged: (color) {
                          context.read<DrawBloc>().add(ChangeColorEvent(color));
                        },
                        onThicknessChanged: (width) {
                          context.read<DrawBloc>().add(ChangeStrokeWidthEvent(width));
                        },
                        orientation: _toolboxOrientation,
                      ),
                    ),
                  );
                }
              },
            ),

            // Плавающий перемещаемый тулбар
            BlocBuilder<DrawBloc, DrawState>(
              builder: (context, drawState) {
                final mediaQuery = MediaQuery.sizeOf(context);
                final screenWidth = mediaQuery.width;
                final screenHeight = mediaQuery.height;

                // Размеры панели
                final double statusBarHeight = MediaQuery.paddingOf(context).top;
                final double horizontalWidth = screenWidth > 700 ? 700.0 : screenWidth - 32;
                final double verticalWidth = 76.0;
                final bool hasSettings = drawState.currentTool != ToolType.move;
                final double horizontalHeight = hasSettings ? 110.0 : 60.0;
                final double verticalHeight = (screenHeight - kToolbarHeight - statusBarHeight - 32.0).clamp(100.0, 520.0);

                final double initialX = (screenWidth - horizontalWidth) / 2;
                final double initialY = screenHeight - horizontalHeight - 32;

                final currentOffset = _toolboxOffset ?? Offset(initialX, initialY);

                // Вычисляем зажатые координаты для рендеринга и перетаскивания без мутации состояния
                Offset clampedOffset = currentOffset;
                if (_toolboxOffset != null) {
                  final double currentWidth = (_toolboxOrientation == ToolboxOrientation.horizontal) ? horizontalWidth : verticalWidth;
                  final double currentHeight = (_toolboxOrientation == ToolboxOrientation.horizontal) ? horizontalHeight : verticalHeight;
                  
                  final double minX = 16.0;
                  final double maxX = _safeClamp(screenWidth - currentWidth - 16.0, minX, screenWidth);
                  final double minY = kToolbarHeight + statusBarHeight + 16.0;
                  final double maxY = _safeClamp(screenHeight - currentHeight - 16.0, minY, screenHeight);
                  
                  clampedOffset = Offset(
                    _safeClamp(_toolboxOffset!.dx, minX, maxX),
                    _safeClamp(_toolboxOffset!.dy, minY, maxY),
                  );
                }

                void handleDragUpdate(Offset delta) {
                  setState(() {
                    _dragPosition = (_dragPosition ?? clampedOffset) + delta;

                    final targetX = _dragPosition!.dx;
                    final targetY = _dragPosition!.dy;

                    // Проверяем прилипание (snapping) к левой/правой границе экрана
                    ToolboxOrientation orientation = ToolboxOrientation.horizontal;
                    const double snapThreshold = 60.0;

                    double newX = targetX;
                    if (targetX < snapThreshold) {
                      orientation = ToolboxOrientation.verticalLeft;
                      newX = 16.0;
                    } else if (targetX > screenWidth - verticalWidth - snapThreshold) {
                      orientation = ToolboxOrientation.verticalRight;
                      newX = screenWidth - verticalWidth - 16.0;
                    }

                    // Ограничиваем координаты
                    final double currentWidth = (orientation == ToolboxOrientation.horizontal) ? horizontalWidth : verticalWidth;
                    final double currentHeight = (orientation == ToolboxOrientation.horizontal) ? horizontalHeight : verticalHeight;

                    final double minX = 16.0;
                    final double maxX = _safeClamp(screenWidth - currentWidth - 16.0, minX, screenWidth);
                    final double minY = kToolbarHeight + statusBarHeight + 16.0;
                    final double maxY = _safeClamp(screenHeight - currentHeight - 16.0, minY, screenHeight);

                    _toolboxOffset = Offset(
                      _safeClamp(newX, minX, maxX),
                      _safeClamp(targetY, minY, maxY),
                    );
                    _toolboxOrientation = orientation;
                  });
                }

                void handleDragStart() {
                  _dragPosition = clampedOffset;
                }

                void handleDragEnd() {
                  _dragPosition = null;
                }

                if (_toolboxOffset == null) {
                  return Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: FloatingToolbox(
                        orientation: ToolboxOrientation.horizontal,
                        currentTool: drawState.currentTool,
                        onToolSelected: (tool) {
                          context.read<DrawBloc>().add(SelectToolEvent(tool));
                        },
                        onDragStart: handleDragStart,
                        onDragUpdate: handleDragUpdate,
                        onDragEnd: handleDragEnd,
                        onSelectFolder: () => EditorScreen.requestDirectoryWithNotice(context),
                        onSaveProject: () => _showSaveDialog(context),
                        onOpenProject: () => _openProject(context),
                        onPickBackground: () => _pickBackgroundImage(context),
                        onDeleteBackground: () {
                          context.read<DrawBloc>().add(SetBackgroundEvent(null));
                        },
                        hasBackground: drawState.backgroundPath != null,
                      ),
                    ),
                  );
                } else {
                  return Positioned(
                    left: clampedOffset.dx,
                    top: clampedOffset.dy,
                    child: FloatingToolbox(
                      orientation: _toolboxOrientation,
                      currentTool: drawState.currentTool,
                      onToolSelected: (tool) {
                        context.read<DrawBloc>().add(SelectToolEvent(tool));
                      },
                      onDragStart: handleDragStart,
                      onDragUpdate: handleDragUpdate,
                      onDragEnd: handleDragEnd,
                      onSelectFolder: () => EditorScreen.requestDirectoryWithNotice(context),
                      onSaveProject: () => _showSaveDialog(context),
                      onOpenProject: () => _openProject(context),
                      onPickBackground: () => _pickBackgroundImage(context),
                      onDeleteBackground: () {
                        context.read<DrawBloc>().add(SetBackgroundEvent(null));
                      },
                      hasBackground: drawState.backgroundPath != null,
                      maxHeight: verticalHeight,
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _exportCanvas(BuildContext context) {
    final drawState = context.read<DrawBloc>().state;
    if (drawState.history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('На холсте ничего не нарисовано для экспорта.')),
      );
      return;
    }

    final nameController = TextEditingController(text: 'экспорт_узи_${DateTime.now().millisecondsSinceEpoch}');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Экспортировать схему с разметкой'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Имя файла изображения'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ProjectBloc>().add(
                      ExportProjectEvent(
                        projectName: nameController.text,
                        actions: drawState.history,
                        backgroundPath: drawState.backgroundPath,
                      ),
                    );
              },
              child: const Text('Экспорт'),
            ),
          ],
        );
      },
    );
  }

  void _pickBackgroundImage(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        withData: kIsWeb,
      );
      if (result != null) {
        if (kIsWeb) {
          final bytes = result.files.single.bytes;
          if (bytes != null) {
            final blobUrl = createBlobUrl(bytes);
            if (context.mounted) {
              context.read<DrawBloc>().add(SetBackgroundEvent(blobUrl));
            }
          }
        } else {
          final path = result.files.single.path;
          if (path != null && context.mounted) {
            context.read<DrawBloc>().add(SetBackgroundEvent(path));
          }
        }
      }
    } catch (e) {
      debugPrint('Ошибка выбора фонового изображения: $e');
    }
  }

  String _getProjectNameFromPath(String path) {
    final fileName = path.split('/').last.split('\\').last;
    return fileName.replaceAll('.meddraw', '');
  }

  void _showSaveDialog(BuildContext context) {
    final projectBloc = context.read<ProjectBloc>();
    final currentFilePath = projectBloc.currentProjectFilePath;

    if (currentFilePath != null) {
      final projectName = _getProjectNameFromPath(currentFilePath);
      showDialog(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Сохранить проект'),
            content: Text('Перезаписать существующий файл проекта "$projectName" или сохранить его как новый?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  final actions = context.read<DrawBloc>().state.history;
                  final backgroundPath = context.read<DrawBloc>().state.backgroundPath;
                  projectBloc.add(
                    SaveProjectEvent(
                      projectName: projectName,
                      actions: actions,
                      backgroundPath: backgroundPath,
                    ),
                  );
                },
                child: const Text('Перезаписать'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _showSaveAsDialog(context);
                },
                child: const Text('Сохранить как новый'),
              ),
            ],
          );
        },
      );
    } else {
      _showSaveAsDialog(context);
    }
  }

  void _showSaveAsDialog(BuildContext context) {
    final nameController = TextEditingController(text: 'проект_узи_${DateTime.now().millisecondsSinceEpoch}');
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Сохранить новый проект'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Имя файла проекта'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () {
                final actions = context.read<DrawBloc>().state.history;
                final backgroundPath = context.read<DrawBloc>().state.backgroundPath;
                context.read<ProjectBloc>().add(
                      SaveProjectEvent(
                        projectName: nameController.text,
                        actions: actions,
                        backgroundPath: backgroundPath,
                      ),
                    );
                Navigator.pop(dialogContext);
              },
              child: const Text('Сохранить'),
            ),
          ],
        );
      },
    );
  }

  void _openProject(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: kIsWeb,
      );
      if (result != null) {
        ProjectFileSource? source;
        if (kIsWeb) {
          final file = result.files.single;
          if (file.bytes != null) {
            source = ProjectFileSource(
              bytes: file.bytes,
              name: file.name,
            );
          }
        } else {
          final path = result.files.single.path;
          if (path != null) {
            source = ProjectFileSource(
              path: path,
              name: result.files.single.name,
            );
          }
        }
        
        if (source != null && context.mounted) {
          context.read<ProjectBloc>().add(LoadProjectEvent(source));
        }
      }
    } catch (e) {
      debugPrint('Ошибка выбора файла проекта: $e');
    }
  }

}
