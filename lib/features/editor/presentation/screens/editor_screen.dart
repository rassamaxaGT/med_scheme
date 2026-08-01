import 'dart:ui' as ui;
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../../core/utils/web_helper.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/project_file_source.dart';
import '../../data/models/draw_action_model.dart';
import '../bloc/draw_bloc.dart';
import '../bloc/draw_event.dart';
import '../bloc/draw_state.dart';
import '../bloc/project_bloc.dart';
import '../widgets/canvas/canvas_painter.dart';
import '../widgets/canvas/canvas_widget.dart';
import '../widgets/toolbox/floating_toolbox.dart';

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
  final _patientIdController = TextEditingController();
  Offset? _toolboxOffset;
  Offset? _dragPosition;

  List<String>? _savedHistoryIds;
  String? _lastSavedBackgroundPath;

  ToolboxOrientation _toolboxOrientation = ToolboxOrientation.horizontal;

  // PC-интерфейс: нотификаторы масштаба, выделения и сброса зума
  final _scaleNotifier = ValueNotifier<double>(1.0);
  final _selectedActionIdNotifier = ValueNotifier<String?>(null);
  final _resetZoomNotifier = ValueNotifier<int>(0);

  String _appVersion = '';
  Timer? _autoSaveTimer;

  double _safeClamp(double value, double min, double max) {
    if (min > max) return min;
    return value.clamp(min, max);
  }

  @override
  void initState() {
    super.initState();
    HardwareKeyboard.instance.addHandler(_handleKeyEvent);
    _loadVersion();
    _loadToolboxPosition();
    _startAutoSaveTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRestoreDraft();
    });
  }

  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _appVersion = '${packageInfo.version}+${packageInfo.buildNumber}';
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки версии: $e');
    }
  }

  Future<void> _loadToolboxPosition() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final dx = prefs.getDouble('toolbox_x');
      final dy = prefs.getDouble('toolbox_y');
      final orientationIndex = prefs.getInt('toolbox_orientation');
      if (dx != null && dy != null) {
        setState(() {
          _toolboxOffset = Offset(dx, dy);
        });
      }
      if (orientationIndex != null) {
        setState(() {
          _toolboxOrientation = ToolboxOrientation.values[orientationIndex];
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки позиции тулбара: $e');
    }
  }

  Future<void> _saveToolboxPosition() async {
    if (_toolboxOffset == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('toolbox_x', _toolboxOffset!.dx);
      await prefs.setDouble('toolbox_y', _toolboxOffset!.dy);
      await prefs.setInt('toolbox_orientation', _toolboxOrientation.index);
    } catch (e) {
      debugPrint('Ошибка сохранения позиции тулбара: $e');
    }
  }

  @override
  void dispose() {
    _patientIdController.dispose();
    _scaleNotifier.dispose();
    _selectedActionIdNotifier.dispose();
    _resetZoomNotifier.dispose();
    _autoSaveTimer?.cancel();
    HardwareKeyboard.instance.removeHandler(_handleKeyEvent);
    super.dispose();
  }

  bool _hasUnsavedChanges() {
    final drawState = context.read<DrawBloc>().state;
    if (drawState.backgroundPath != _lastSavedBackgroundPath) return true;
    final currentIds = drawState.history.map((a) => a.id).toList();
    if (_savedHistoryIds == null) return currentIds.isNotEmpty;
    if (currentIds.length != _savedHistoryIds!.length) return true;
    for (int i = 0; i < currentIds.length; i++) {
      if (currentIds[i] != _savedHistoryIds![i]) return true;
    }
    return false;
  }

  Future<bool?> _showExitWarningDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Несохраненные изменения'),
          content: const Text('У вас есть несохраненные изменения. Вы уверены, что хотите выйти? Все несохраненные изменения будут утеряны.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Остаться'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD32F2F),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Выйти без сохранения'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!_hasUnsavedChanges()) {
          Navigator.of(context).pop();
          return;
        }
        final bool? shouldPop = await _showExitWarningDialog(context);
        if (shouldPop == true && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
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
                  final isModified = _hasUnsavedChanges();

                  return Text(
                    isModified ? '$projectName • Изменено' : '$projectName • Сохранено',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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
            BlocBuilder<DrawBloc, DrawState>(
              builder: (context, drawState) {
                return GestureDetector(
                  onTap: () => _showPatientIdDialog(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    margin: const EdgeInsets.only(right: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: drawState.patientId.isNotEmpty ? const Color(0xFF0F4C81) : Colors.white24,
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.person,
                          size: 14,
                          color: drawState.patientId.isNotEmpty ? const Color(0xFF1976D2) : Colors.white54,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          drawState.patientId.isNotEmpty ? drawState.patientId : 'Указать пациента',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: drawState.patientId.isNotEmpty ? Colors.white : Colors.white54,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
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
                            : () async {
                                final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Очистить холст?'),
                                    content: const Text(
                                      'Все нарисованные маркеры будут удалены.\n'
                                      'Действие можно отменить через Undo (Ctrl+Z).',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(ctx, false),
                                        child: const Text('Отмена'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          foregroundColor: Colors.white,
                                        ),
                                        onPressed: () => Navigator.pop(ctx, true),
                                        child: const Text('Очистить'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirmed == true && context.mounted) {
                                  context.read<DrawBloc>().add(ClearCanvasEvent());
                                }
                              },
                      ),
                    ],
                  ),
                );
              },
            ),

            ValueListenableBuilder<double>(
              valueListenable: _scaleNotifier,
              builder: (context, scale, _) {
                return Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(scale * 100).round()}%',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white70,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Tooltip(
                        message: 'Сбросить масштаб (Ctrl+0)',
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _resetZoomNotifier.value++,
                          child: const Icon(
                            Icons.zoom_out_map,
                            size: 14,
                            color: Colors.white54,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            PopupMenuButton<int>(
              icon: const Icon(Icons.help_outline),
              tooltip: 'Справочные легенды',
              onSelected: (value) {
                if (value == 1) {
                  _showLegendDialog(
                    context,
                    'Легенда карты эндометриоза',
                    'assets/images/endo_legend.png',
                  );
                } else if (value == 2) {
                  _showLegendDialog(
                    context,
                    'Легенда классификации миом (FIGO)',
                    'assets/images/myoma_legend.png',
                  );
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 1,
                  child: Row(
                    children: [
                      Icon(Icons.map, size: 18),
                      SizedBox(width: 8),
                      Text('Легенда эндометриоза'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 2,
                  child: Row(
                    children: [
                      Icon(Icons.legend_toggle, size: 18),
                      SizedBox(width: 8),
                      Text('Легенда миом (FIGO)'),
                    ],
                  ),
                ),
              ],
            ),
            
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Сохранить проект',
              onPressed: () => _showSaveDialog(context),
            ),

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
            if (state is ProjectLoading) {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  const SnackBar(
                    content: Row(
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(width: 14),
                        Text('Выполняется операция…'),
                      ],
                    ),
                    duration: Duration(seconds: 30),
                  ),
                );
            } else if (state is ProjectSaved) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              final drawState = context.read<DrawBloc>().state;
              setState(() {
                _savedHistoryIds = drawState.history.map((a) => a.id).toList();
                _lastSavedBackgroundPath = drawState.backgroundPath;
              });
              _clearDraft(); // Очищаем черновик, так как проект успешно сохранен
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Проект успешно сохранён!')),
              );
            } else if (state is ProjectExported) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Схема экспортирована: ${state.outputPath}'),
                ),
              );
            } else if (state is ProjectLoaded) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              context.read<DrawBloc>().add(SetHistoryEvent(state.actions));
              context.read<DrawBloc>().add(SetBackgroundEvent(state.backgroundPath));
              final pId = state.patientId ?? '';
              _patientIdController.text = pId;
              context.read<DrawBloc>().add(SetPatientIdEvent(pId));
              setState(() {
                _savedHistoryIds = state.actions.map((a) => a.id).toList();
                _lastSavedBackgroundPath = state.backgroundPath;
              });
              _clearDraft(); // Очищаем черновик, так как загружен новый проект
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Проект успешно загружен!')),
              );
            } else if (state is ProjectError) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(state.message),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
          },
          child: Stack(
            children: [
              Positioned.fill(
                child: CanvasWidget(
                  scaleNotifier: _scaleNotifier,
                  selectedActionIdNotifier: _selectedActionIdNotifier,
                  resetZoomNotifier: _resetZoomNotifier,
                ),
              ),
              
              // Единый оптимизированный BlocBuilder для панели настроек и тулбара
              BlocBuilder<DrawBloc, DrawState>(
                builder: (context, drawState) {
                  final mediaQuery = MediaQuery.sizeOf(context);
                  final screenWidth = mediaQuery.width;
                  final screenHeight = mediaQuery.height;

                  final tool = drawState.currentTool;

                  // Размеры панели
                  final double statusBarHeight = MediaQuery.paddingOf(context).top;
                  final double horizontalWidth = screenWidth > 700 ? 700.0 : screenWidth - 32;
                  final double verticalWidth = 76.0;
                  final bool hasSettings = tool != ToolType.move;
                  final double horizontalHeight = hasSettings ? 110.0 : 60.0;
                  final double verticalHeight = (screenHeight - kToolbarHeight - statusBarHeight - 32.0).clamp(100.0, 520.0);

                  final double initialX = (screenWidth - horizontalWidth) / 2;
                  final double initialY = screenHeight - horizontalHeight - 32;

                  final currentOffset = _toolboxOffset ?? Offset(initialX, initialY);
                  final bubbleWidth = horizontalWidth.clamp(200.0, 340.0);

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
                    _saveToolboxPosition(); // Сохраняем позицию при завершении перетягивания
                  }

                  // Виджет настроек (Settings Bubble)
                  Widget? settingsBubble;
                  final bool showColor = tool == ToolType.pencil ||
                      tool == ToolType.adhesions ||
                      tool == ToolType.fibrosis ||
                      tool == ToolType.arrow ||
                      tool == ToolType.iud ||
                      tool == ToolType.foci;

                  final bool showThickness = tool == ToolType.pencil ||
                      tool == ToolType.adhesions ||
                      tool == ToolType.fibrosis ||
                      tool == ToolType.arrow ||
                      tool == ToolType.eraser;

                  final bool showCustomStamps = tool == ToolType.customStamp;
                  final bool showFigo = tool == ToolType.myoma;

                  if (tool != ToolType.move && (showColor || showThickness || showCustomStamps || showFigo)) {
                    settingsBubble = Container(
                      constraints: BoxConstraints(
                        maxWidth: (_toolboxOrientation == ToolboxOrientation.horizontal) ? bubbleWidth : verticalWidth,
                      ),
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
                        currentFigoType: drawState.currentFigoType,
                        onFigoTypeChanged: (type) {
                          context.read<DrawBloc>().add(ChangeFigoTypeEvent(type));
                        },
                        currentLineDashed: drawState.currentLineDashed,
                        onLineDashedChanged: (dashed) {
                          context.read<DrawBloc>().add(ToggleLineDashedEvent(dashed));
                        },
                      ),
                    );
                  }

                  // Позиционируем настройки и тулбар в одном Stack
                  Positioned? positionedSettings;
                  if (settingsBubble != null) {
                    if (_toolboxOrientation == ToolboxOrientation.horizontal) {
                      positionedSettings = Positioned(
                        left: clampedOffset.dx + (horizontalWidth - bubbleWidth) / 2,
                        top: clampedOffset.dy - 64.0, // Высота баббла настроек + отступ
                        child: settingsBubble,
                      );
                    } else if (_toolboxOrientation == ToolboxOrientation.verticalLeft) {
                      positionedSettings = Positioned(
                        left: clampedOffset.dx + verticalWidth + 8.0,
                        top: clampedOffset.dy,
                        child: settingsBubble,
                      );
                    } else {
                      positionedSettings = Positioned(
                        left: clampedOffset.dx - verticalWidth - 8.0,
                        top: clampedOffset.dy,
                        child: settingsBubble,
                      );
                    }
                  }

                  final positionedToolbox = Positioned(
                    left: clampedOffset.dx,
                    top: clampedOffset.dy,
                    child: FloatingToolbox(
                      orientation: _toolboxOrientation,
                      currentTool: drawState.currentTool,
                      onToolSelected: (tool) async {
                        if (tool == ToolType.customStamp && drawState.customStamps.isEmpty) {
                          final result = await FilePicker.platform.pickFiles(
                            type: FileType.custom,
                            allowedExtensions: ['png'],
                          );
                          if (result != null && result.files.single.path != null) {
                            if (context.mounted) {
                              context.read<DrawBloc>().add(ImportCustomStampEvent(result.files.single.path!));
                            }
                          } else {
                            if (context.mounted) {
                              context.read<DrawBloc>().add(SelectToolEvent(ToolType.pencil));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('PNG-штамп не выбран. Загрузите файл для использования инструмента.'),
                                ),
                              );
                            }
                          }
                        } else {
                          context.read<DrawBloc>().add(SelectToolEvent(tool));
                        }
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

                  return Stack(
                    children: [
                      if (positionedSettings != null) positionedSettings,
                      positionedToolbox,
                    ],
                  );
                },
              ),
              if (_appVersion.isNotEmpty)
                Positioned(
                  bottom: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.15),
                        width: 1.0,
                      ),
                    ),
                    child: Text(
                      'v$_appVersion',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPatientIdDialog(BuildContext context) {
    final drawBloc = context.read<DrawBloc>();
    final controller = TextEditingController(text: drawBloc.state.patientId);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Идентификация пациента'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Введите Фамилию или ID пациента...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () {
              final newId = controller.text;
              drawBloc.add(SetPatientIdEvent(newId));
              _patientIdController.text = newId; // Синхронизируем локальный контроллер
              Navigator.pop(ctx);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    ).then((_) => controller.dispose());
  }

  void _exportCanvas(BuildContext context) {
    final drawState = context.read<DrawBloc>().state;
    if (drawState.history.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('На холсте ничего не нарисовано для экспорта.')),
      );
      return;
    }

    final patientId = drawState.patientId;
    final defaultFilename = patientId.isNotEmpty 
        ? '${patientId}_${DateTime.now().millisecondsSinceEpoch}' 
        : 'экспорт_узи_${DateTime.now().millisecondsSinceEpoch}';
    final nameController = TextEditingController(text: defaultFilename);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Экспортировать схему с разметкой'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Имя файла'),
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
                        patientId: patientId,
                      ),
                    );
              },
              child: const Text('Экспорт в PNG'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F4C81),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.pop(dialogContext);
                context.read<ProjectBloc>().add(
                      ExportPdfEvent(
                        projectName: nameController.text,
                        actions: drawState.history,
                        backgroundPath: drawState.backgroundPath,
                        patientId: patientId,
                      ),
                    );
              },
              child: const Text('Экспорт в PDF'),
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
                  final drawState = context.read<DrawBloc>().state;
                  final actions = drawState.history;
                  final backgroundPath = drawState.backgroundPath;
                  final patientId = drawState.patientId;
                  projectBloc.add(
                    SaveProjectEvent(
                      projectName: projectName,
                      actions: actions,
                      backgroundPath: backgroundPath,
                      patientId: patientId,
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
    final drawState = context.read<DrawBloc>().state;
    final patientId = drawState.patientId;
    final String initialName = patientId.isNotEmpty
        ? '${patientId}_${DateTime.now().millisecondsSinceEpoch}'
        : 'проект_узи_${DateTime.now().millisecondsSinceEpoch}';
    final nameController = TextEditingController(text: initialName);
    
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
                final actions = drawState.history;
                final backgroundPath = drawState.backgroundPath;
                context.read<ProjectBloc>().add(
                      SaveProjectEvent(
                        projectName: nameController.text,
                        actions: actions,
                        backgroundPath: backgroundPath,
                        patientId: patientId,
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
      if (_hasUnsavedChanges()) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Открыть проект'),
            content: const Text('Несохранённые изменения будут потеряны. Продолжить?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Отмена'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Продолжить'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        if (confirm != true) return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: kIsWeb ? FileType.any : FileType.custom,
        allowedExtensions: kIsWeb ? null : ['meddraw'],
        withData: kIsWeb,
      );

      if (!mounted) return;

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

  void _showLegendDialog(BuildContext context, String title, String assetPath) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: Container(
            constraints: const BoxConstraints(maxWidth: 500, maxHeight: 500),
            child: InteractiveViewer(
              child: Image.asset(
                assetPath,
                fit: BoxFit.contain,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Закрыть'),
            ),
          ],
        );
      },
    );
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!mounted) return false;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) return false;

    final primaryFocus = FocusManager.instance.primaryFocus;
    if (primaryFocus?.context?.widget is EditableText) return false;

    final isCtrl = HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    final drawBloc = context.read<DrawBloc>();

    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      drawBloc.add(UndoEvent());
      return true;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.keyY) {
      drawBloc.add(RedoEvent());
      return true;
    }
    if (isCtrl && isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      drawBloc.add(RedoEvent());
      return true;
    }

    if (isCtrl && !isShift && event.logicalKey == LogicalKeyboardKey.keyS) {
      _showSaveDialog(context);
      return true;
    }

    if (isCtrl && event.logicalKey == LogicalKeyboardKey.digit0) {
      _resetZoomNotifier.value++;
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.delete) {
      final selectedId = _selectedActionIdNotifier.value;
      if (selectedId != null) {
        drawBloc.add(DeleteActionEvent(selectedId));
        _selectedActionIdNotifier.value = null;
        return true;
      }
      return false;
    }

    if (!isCtrl && !isShift) {
      final toolByNumber = <LogicalKeyboardKey, ToolType>{
        LogicalKeyboardKey.digit1: ToolType.pencil,
        LogicalKeyboardKey.digit2: ToolType.eraser,
        LogicalKeyboardKey.digit3: ToolType.move,
        LogicalKeyboardKey.digit4: ToolType.infiltrate,
        LogicalKeyboardKey.digit5: ToolType.adhesions,
        LogicalKeyboardKey.digit6: ToolType.fibrosis,
        LogicalKeyboardKey.digit7: ToolType.endometrioma,
        LogicalKeyboardKey.digit8: ToolType.myoma,
        LogicalKeyboardKey.digit9: ToolType.iud,
        LogicalKeyboardKey.digit0: ToolType.foci,
      };

      final tool = toolByNumber[event.logicalKey];
      if (tool != null) {
        drawBloc.add(SelectToolEvent(tool));
        return true;
      }

      if (event.logicalKey == LogicalKeyboardKey.keyE) {
        drawBloc.add(SelectToolEvent(ToolType.eraser));
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyM ||
          event.logicalKey == LogicalKeyboardKey.keyV) {
        drawBloc.add(SelectToolEvent(ToolType.move));
        return true;
      }
      if (event.logicalKey == LogicalKeyboardKey.keyP ||
          event.logicalKey == LogicalKeyboardKey.keyB) {
        drawBloc.add(SelectToolEvent(ToolType.pencil));
        return true;
      }
    }

    return false;
  }

  void _startAutoSaveTimer() {
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (!mounted) return;
      if (_hasUnsavedChanges()) {
        await _saveDraft();
      }
    });
  }

  Future<void> _saveDraft() async {
    try {
      final drawState = context.read<DrawBloc>().state;
      if (drawState.history.isEmpty) {
        await _clearDraft();
        return;
      }
      
      final Map<String, dynamic> draftMap = {
        'patientId': drawState.patientId,
        'backgroundPath': drawState.backgroundPath,
        'actions': drawState.history.map((a) => DrawActionModel.toJson(a)).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('autosave_draft', jsonEncode(draftMap));
      debugPrint('Автосохранение черновика успешно выполнено.');
    } catch (e) {
      debugPrint('Ошибка автосохранения: $e');
    }
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('autosave_draft');
      debugPrint('Черновик успешно удалён.');
    } catch (e) {
      debugPrint('Ошибка очистки черновика: $e');
    }
  }

  Future<void> _checkAndRestoreDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draftStr = prefs.getString('autosave_draft');
      if (draftStr == null || draftStr.isEmpty) return;
      
      final Map<String, dynamic> draftMap = jsonDecode(draftStr) as Map<String, dynamic>;
      final timestamp = draftMap['timestamp'] as int? ?? 0;
      final timeDiff = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(timestamp));
      
      // Игнорируем черновики старше 24 часов
      if (timeDiff.inHours > 24) {
        await _clearDraft();
        return;
      }
      
      if (!mounted) return;
      
      final confirm = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: const Text('Восстановление черновика'),
          content: const Text(
            'Приложение было закрыто некорректно или обнаружен несохраненный черновик исследования.\n\n'
            'Хотите восстановить последнее состояние рисования?'
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Удалить черновик'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Восстановить'),
            ),
          ],
        ),
      );
      
      if (confirm == true && mounted) {
        final actionsList = draftMap['actions'] as List;
        final patientId = draftMap['patientId'] as String? ?? '';
        final backgroundPath = draftMap['backgroundPath'] as String?;
        
        final actions = actionsList
            .map((json) => DrawActionModel.fromJson(json as Map<String, dynamic>))
            .toList();
            
        context.read<DrawBloc>().add(SetFullStateEvent(
          history: actions,
          patientId: patientId,
          backgroundPath: backgroundPath,
        ));
        
        _patientIdController.text = patientId;
        
        setState(() {
          _savedHistoryIds = null;
          _lastSavedBackgroundPath = null;
        });
      } else {
        await _clearDraft();
      }
    } catch (e) {
      debugPrint('Ошибка проверки/восстановления черновика: $e');
    }
  }
}
