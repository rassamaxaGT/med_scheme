import '../../../../../core/utils/image_loader.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/draw_action.dart';
import '../../bloc/draw_bloc.dart';
import '../../bloc/draw_event.dart';
import '../../bloc/draw_state.dart';
import 'canvas_painter.dart';

class CanvasWidget extends StatefulWidget {
  final ui.Image? backgroundImage;
  final ValueNotifier<double>? scaleNotifier;
  final ValueNotifier<String?>? selectedActionIdNotifier;
  final ValueNotifier<int>? resetZoomNotifier;

  const CanvasWidget({
    super.key,
    this.backgroundImage,
    this.scaleNotifier,
    this.selectedActionIdNotifier,
    this.resetZoomNotifier,
  });

  @override
  State<CanvasWidget> createState() => _CanvasWidgetState();
}

class _CanvasWidgetState extends State<CanvasWidget> {
  // Локальное состояние активного рисования
  DrawAction? _activeAction;
  List<Offset> _currentPoints = [];

  // Состояние выделения и перемещения
  String? _selectedActionId;
  Offset? _dragStartPoint;
  DrawAction? _originalActionForDrag;
  double _dragStartRotation = 0.0;
  String?
  _draggedHandle; // 'topLeft', 'topRight', 'bottomLeft', 'bottomRight' или null
  // Для Paint-like resize: пред-scale позиции захваченного/anchor углов + canvas-позиция anchor
  Offset? _rotatedDraggedCorner; // A = rotate(draggedLocal, rotCenter, angle)
  Offset? _rotatedAnchorCorner; // B = rotate(anchorLocal,  rotCenter, angle)
  Offset?
  _anchorCanvas; // canvas-позиция anchor при старте drag (без cell offset)

  // Последняя выбранная кисть для рисования
  ToolType _lastSelectedBrush = ToolType.pencil;
  bool _isAutoSwitchedToMove = false;

  // Динамически загруженное фоновое изображение из BLoC
  ui.Image? _loadedBackgroundImage;
  String? _loadedBackgroundPath;

  // Кэш фоновых изображений (в т.ч. пользовательских)
  final Map<String, ui.Image?> _bgImages = {};

  // Кэш пользовательских PNG-штампов
  final Map<String, ui.Image?> _stampImages = {};

  // ── Оптимизация: кэш non-null карт ─────────────────────────────────────────
  // Вместо создания Map.fromEntries(...) на каждый build — поддерживаем
  // готовые карты, обновляемые только при изменении карт исходных.
  Map<String, ui.Image> _bgImagesNonNull = {};
  Map<String, ui.Image> _stampImagesNonNull = {};

  void _rebuildNonNullBgImages() {
    _bgImagesNonNull = Map.fromEntries(
      _bgImages.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key, e.value!)),
    );
  }

  void _rebuildNonNullStampImages() {
    _stampImagesNonNull = Map.fromEntries(
      _stampImages.entries
          .where((e) => e.value != null)
          .map((e) => MapEntry(e.key, e.value!)),
    );
  }

  // ── ValueNotifier-driven repaint ────────────────────────────────────────────────
  // Активный штрих: не вызывает setState — painter сам перерисовывается через repaint
  // listenable. Убирает 60+ rebuildа widget-дерева в секунду во время рисования.
  final ValueNotifier<DrawAction?> _activeStrokeNotifier = ValueNotifier(null);

  // Курсор ластика и превью штампов: только обновляет overlay-виджет, не перестраивает весь виджет
  final ValueNotifier<Offset?> _hoverCursorNotifier = ValueNotifier(null);

  // Переменные для зума и панорамирования (Zoom & Pan)
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _normalizedFocalPoint = Offset.zero;

  List<DrawAction> _initialHistoryBeforeErase = [];
  bool _hasErasedAnything = false;
  DateTime? _lastEraseTime; // Fix #6: throttle ластика

  // Флаги управления режимами ввода
  bool _isStylusActive = false;
  DateTime? _lastStylusTime;
  bool _isZooming = false;

  // Активные указатели для отслеживания мультитача
  final Set<int> _activePointers = {};
  ToolType? _lastTool;

  // Fix #15: толщина линии фиксируется при onPointerDown и не меняется в ходе штриха
  double? _activeStrokeWidth;

  // Fix #5: монотонный счётчик ID — исключает коллизии при быстром рисовании
  int _idCounter = 0;
  String _generateId() =>
      '${DateTime.now().millisecondsSinceEpoch}_${_idCounter++}';

  @override
  void initState() {
    super.initState();
    widget.resetZoomNotifier?.addListener(_onResetZoom);
  }

  @override
  void dispose() {
    widget.resetZoomNotifier?.removeListener(_onResetZoom);
    _activeStrokeNotifier.dispose();
    _hoverCursorNotifier.dispose();
    super.dispose();
  }

  void _onResetZoom() {
    setState(() {
      _scale = 1.0;
      _offset = Offset.zero;
      widget.scaleNotifier?.value = 1.0;
    });
  }

  @override
  void didUpdateWidget(covariant CanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.resetZoomNotifier != widget.resetZoomNotifier) {
      oldWidget.resetZoomNotifier?.removeListener(_onResetZoom);
      widget.resetZoomNotifier?.addListener(_onResetZoom);
    }
    _activePointers.clear();
    _isZooming = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawBloc, DrawState>(
      builder: (context, state) {
        if (state.currentTool != _lastTool) {
          _lastTool = state.currentTool;
          _activePointers.clear();
          _isZooming = false;
        }

        // Запоминаем последнюю выбранную кисть
        if (state.currentTool != ToolType.move &&
            state.currentTool != ToolType.eraser) {
          _lastSelectedBrush = state.currentTool;
        }

        // Сбрасываем выделение, если активен не инструмент перемещения
        if (state.currentTool != ToolType.move && _selectedActionId != null) {
          _selectedActionId = null;
        }

        // Сбрасываем флаг автопереключения, если вышли из режима перемещения
        if (state.currentTool != ToolType.move) {
          _isAutoSwitchedToMove = false;
        }

        // Загрузка фонового изображения, если список изменился
        final String? targetBgPath = state.backgroundPaths.isNotEmpty
            ? state.backgroundPaths.first
            : state.backgroundPath;
        if (targetBgPath != _loadedBackgroundPath) {
          _loadedBackgroundPath = targetBgPath;
          Future.microtask(() => _loadBackground(targetBgPath));
        }

        // Автоматическая подгрузка изображений для фонов
        for (final path in state.backgroundPaths) {
          // Перезагружаем если: ключ отсутствует, или значение null (прошлая загрузка неудалась)
          if (!_bgImages.containsKey(path) || _bgImages[path] == null) {
            _bgImages[path] = null; // маркируем как «загружается»
            Future.microtask(() => _loadBgImage(path));
          }
        }

        // Автоматическая подгрузка изображений для пользовательских штампов из истории
        for (final action in state.history) {
          if (action is StampAction && action.customStampPath != null) {
            final path = action.customStampPath!;
            if (!_stampImages.containsKey(path)) {
              _stampImages[path] =
                  null
                      as dynamic; // Временная заглушка, чтобы не запускать загрузку повторно
              Future.microtask(() => _loadCustomStampImage(path));
            }
          }
        }

        // Также грузим 'assets/images/infiltrat.png' для штампа инфильтрата кишки
        if (!_stampImages.containsKey('assets/images/infiltrat.png')) {
          _stampImages['assets/images/infiltrat.png'] = null as dynamic;
          Future.microtask(
            () => _loadCustomStampImage('assets/images/infiltrat.png'),
          );
        }

        // Также грузим 'assets/images/myoma.png' для штампа миомы
        if (!_stampImages.containsKey('assets/images/myoma.png')) {
          _stampImages['assets/images/myoma.png'] = null as dynamic;
          Future.microtask(
            () => _loadCustomStampImage('assets/images/myoma.png'),
          );
        }

        // Также грузим 'assets/images/mirena.png' для штампа Мирена (ВМС)
        if (!_stampImages.containsKey('assets/images/mirena.png')) {
          _stampImages['assets/images/mirena.png'] = null as dynamic;
          Future.microtask(
            () => _loadCustomStampImage('assets/images/mirena.png'),
          );
        }

        // Также грузим 'assets/images/infiltrat2.png' для второго штампа инфильтрата
        if (!_stampImages.containsKey('assets/images/infiltrat2.png')) {
          _stampImages['assets/images/infiltrat2.png'] = null as dynamic;
          Future.microtask(
            () => _loadCustomStampImage('assets/images/infiltrat2.png'),
          );
        }

        // Также грузим 'assets/images/polyp.png' для штампа полипа
        if (!_stampImages.containsKey('assets/images/polyp.png')) {
          _stampImages['assets/images/polyp.png'] = null as dynamic;
          Future.microtask(
            () => _loadCustomStampImage('assets/images/polyp.png'),
          );
        }

        // Также грузим все кастомные штампы из слотов
        for (final slotPath in state.customStampSlots) {
          if (slotPath != null && (!_stampImages.containsKey(slotPath) || _stampImages[slotPath] == null)) {
            _stampImages[slotPath] = null as dynamic;
            Future.microtask(() => _loadCustomStampImage(slotPath));
          }
        }

        // Также грузим все кастомные штампы из списка customStampItems
        for (final item in state.customStampItems) {
          if (item.imagePath.isNotEmpty &&
              (!_stampImages.containsKey(item.imagePath) || _stampImages[item.imagePath] == null)) {
            _stampImages[item.imagePath] = null as dynamic;
            Future.microtask(() => _loadCustomStampImage(item.imagePath));
          }
        }

        // Также грузим текущий выбранный кастомный штамп
        final activeCustomPath = state.customStampPath ?? state.activeStampItem?.imagePath;
        if (activeCustomPath != null && activeCustomPath.isNotEmpty &&
            (!_stampImages.containsKey(activeCustomPath) || _stampImages[activeCustomPath] == null)) {
          _stampImages[activeCustomPath] = null as dynamic;
          Future.microtask(() => _loadCustomStampImage(activeCustomPath));
        }

        return ClipRect(
          child: Listener(
            // Listener для низкоуровневой обработки касаний, стилуса и колеса мыши
            onPointerDown: _onPointerDown,
            onPointerMove: _onPointerMove,
            onPointerUp: _onPointerUp,
            onPointerCancel: (event) {
              final activeState = context.read<DrawBloc>().state;
              _activePointers.remove(event.pointer);
              if (_activePointers.length < 2) {
                _isZooming = false;
              }
              if (activeState.currentTool == ToolType.eraser) {
                _hoverCursorNotifier.value = null;
                _activeStrokeNotifier.value = null;
                setState(() {
                  _activeAction = null;
                  _initialHistoryBeforeErase = [];
                  _hasErasedAnything = false;
                  _currentPoints = [];
                });
              } else if (activeState.currentTool == ToolType.move) {
                setState(() {
                  _draggedHandle = null;
                  _activeAction = null;
                  _originalActionForDrag = null;
                  _rotatedDraggedCorner = null;
                  _rotatedAnchorCorner = null;
                  _anchorCanvas = null;
                });
              }
            },
            onPointerSignal: _onPointerSignal,
            child: MouseRegion(
              cursor: _getCursorForTool(state),
              onHover: (event) {
                final activeState = context.read<DrawBloc>().state;
                final bool needsHover =
                    activeState.currentTool == ToolType.eraser ||
                    activeState.currentTool == ToolType.iud ||
                    activeState.currentTool == ToolType.iudStamp ||
                    activeState.currentTool == ToolType.follicle ||
                    activeState.currentTool == ToolType.polyp ||
                    activeState.currentTool == ToolType.foci ||
                    activeState.currentTool == ToolType.bowelInfiltrate ||
                    activeState.currentTool == ToolType.infiltrateStamp2 ||
                    activeState.currentTool == ToolType.myomaStamp ||
                    (activeState.currentTool == ToolType.customStamp &&
                        (activeState.customStampPath != null ||
                            activeState.activeStampItem != null));
                if (needsHover) {
                  _hoverCursorNotifier.value = event.localPosition;
                } else {
                  _hoverCursorNotifier.value = null;
                }
              },
              onExit: (_) {
                _hoverCursorNotifier.value = null;
              },
              child: GestureDetector(
                // Scale gestures для масштабирования холста двумя пальцами
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Stack(
                  children: [
                    Transform(
                      transform:
                          Matrix4.translationValues(
                            _offset.dx,
                            _offset.dy,
                            0.0,
                          ) *
                          Matrix4.diagonal3Values(_scale, _scale, 1.0),
                      child: RepaintBoundary(
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: CanvasPainter(
                            history: state.history,
                            // Используем notifier — painter сам перерисовывается без setState
                            activeActionNotifier: _activeStrokeNotifier,
                            backgroundImage:
                                widget.backgroundImage ??
                                _loadedBackgroundImage,
                            backgroundPaths: state.backgroundPaths,
                            backgroundPath: state.backgroundPath,
                            bgImages: _bgImagesNonNull,
                            stampImages: _stampImagesNonNull,
                            selectedActionId: _selectedActionId,
                            patientId: state.patientId,
                          ),
                        ),
                      ),
                    ),
                    // Кнопка удаления выделенного объекта
                    if (state.currentTool == ToolType.move &&
                        _selectedActionId != null)
                      _buildDeleteButton(context, state),
                    // Курсор ластика или призрачный превью-штамп — оверлей, не требует перестройки всего виджета
                    ValueListenableBuilder<Offset?>(
                      valueListenable: _hoverCursorNotifier,
                      builder: (context, hoverPos, _) {
                        if (hoverPos == null) return const SizedBox.shrink();

                        if (state.currentTool == ToolType.eraser) {
                          return _buildEraserCursor(state, hoverPos);
                        }

                        final bool isGhostTool =
                            state.currentTool == ToolType.iud ||
                            state.currentTool == ToolType.iudStamp ||
                            state.currentTool == ToolType.follicle ||
                            state.currentTool == ToolType.polyp ||
                            state.currentTool == ToolType.foci ||
                            state.currentTool == ToolType.bowelInfiltrate ||
                            state.currentTool == ToolType.infiltrateStamp2 ||
                            state.currentTool == ToolType.myomaStamp ||
                            (state.currentTool == ToolType.customStamp &&
                                (state.customStampPath != null ||
                                    state.activeStampItem != null));

                        if (isGhostTool) {
                          return _buildGhostCursor(state, hoverPos);
                        }

                        return const SizedBox.shrink();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // Загрузка изображения из файла
  void _loadBackground(String? path) async {
    if (path == null) {
      if (mounted) {
        setState(() {
          _loadedBackgroundImage = null;
        });
      }
      return;
    }
    try {
      final image = await loadUiImage(path);
      if (mounted) {
        setState(() {
          _loadedBackgroundImage = image;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки фонового изображения: $e');
      if (mounted) {
        setState(() {
          _loadedBackgroundImage = null;
        });
      }
    }
  }

  // Загрузка любого фонового изображения (в т.ч. пользовательского)
  void _loadBgImage(String path) async {
    try {
      debugPrint('[ImageLoader] Loading: $path');
      final image = await loadUiImage(path);
      debugPrint(
        '[ImageLoader] Result for $path: ${image != null ? "OK (${image.width}x${image.height})" : "NULL"}',
      );
      if (mounted) {
        setState(() {
          if (image != null) {
            _bgImages[path] = image;
            _rebuildNonNullBgImages();
            if (_loadedBackgroundImage == null ||
                path == _loadedBackgroundPath) {
              _loadedBackgroundImage = image;
              _loadedBackgroundPath = path;
            }
          } else {
            // Удаляем ключ чтобы следующий build повторил загрузку
            _bgImages.remove(path);
            _rebuildNonNullBgImages();
          }
        });
      }
    } catch (e) {
      debugPrint('[ImageLoader] Error loading $path: $e');
      if (mounted) {
        setState(() {
          _bgImages.remove(path);
          _rebuildNonNullBgImages();
        });
      }
    }
  }

  // Загрузка изображения пользовательского штампа
  void _loadCustomStampImage(String path) async {
    try {
      final image = await loadUiImage(path);
      if (mounted) {
        setState(() {
          if (image != null) {
            _stampImages[path] = image;
            _rebuildNonNullStampImages(); // синхронизируем кэш non-null карты
          } else {
            _stampImages.remove(path);
            _rebuildNonNullStampImages();
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки пользовательского штампа $path: $e');
      if (mounted) {
        setState(() {
          _stampImages.remove(path);
          _rebuildNonNullStampImages();
        });
      }
    }
  }

  Offset _getSchemeLocalPosition(Offset rawCanvasPt, String? targetPath) {
    if (targetPath == null) return rawCanvasPt;
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final imgRect = CanvasPainter.getSchemeImageRect(
      path: targetPath,
      activePaths: activePaths,
      bgImages: _bgImagesNonNull,
    );
    if (imgRect == Rect.zero) return rawCanvasPt;

    final origSize = CanvasPainter.getOriginalSchemeSize(
      targetPath,
      _bgImagesNonNull[targetPath],
    );
    final double s = imgRect.width / origSize.width;

    return (rawCanvasPt - imgRect.topLeft) / (s > 0 ? s : 1.0);
  }

  Offset _schemeToCanvasSpace(Offset point, String? path) {
    if (path == null) return point;
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final imgRect = CanvasPainter.getSchemeImageRect(
      path: path,
      activePaths: activePaths,
      bgImages: _bgImagesNonNull,
    );
    if (imgRect == Rect.zero) return point;

    final origSize = CanvasPainter.getOriginalSchemeSize(
      path,
      _bgImagesNonNull[path],
    );
    final double s = imgRect.width / origSize.width;

    return imgRect.topLeft + point * s;
  }

  ({String? targetSchemePath, Offset localPoint}) _getSchemeInfo(
    Offset canvasPoint,
    List<String> backgroundPaths,
  ) {
    if (backgroundPaths.isEmpty) {
      return (targetSchemePath: null, localPoint: canvasPoint);
    }

    // 1. Проверяем попадание в точный Rect изображения схемы
    for (final path in backgroundPaths) {
      final imgRect = CanvasPainter.getSchemeImageRect(
        path: path,
        activePaths: backgroundPaths,
        bgImages: _bgImagesNonNull,
      );
      if (imgRect.contains(canvasPoint)) {
        final origSize = CanvasPainter.getOriginalSchemeSize(
          path,
          _bgImagesNonNull[path],
        );
        final double s = imgRect.width / origSize.width;
        return (
          targetSchemePath: path,
          localPoint: (canvasPoint - imgRect.topLeft) / (s > 0 ? s : 1.0),
        );
      }
    }

    // 2. Если клик на поле рядом, находим ближайшую схему
    String closestPath = backgroundPaths.first;
    double minDistance = double.infinity;

    for (final path in backgroundPaths) {
      final imgRect = CanvasPainter.getSchemeImageRect(
        path: path,
        activePaths: backgroundPaths,
        bgImages: _bgImagesNonNull,
      );
      final dist = (canvasPoint - imgRect.center).distance;
      if (dist < minDistance) {
        minDistance = dist;
        closestPath = path;
      }
    }

    final imgRect = CanvasPainter.getSchemeImageRect(
      path: closestPath,
      activePaths: backgroundPaths,
      bgImages: _bgImagesNonNull,
    );
    final origSize = CanvasPainter.getOriginalSchemeSize(
      closestPath,
      _bgImagesNonNull[closestPath],
    );
    final double s = imgRect != Rect.zero
        ? (imgRect.width / origSize.width)
        : 1.0;

    return (
      targetSchemePath: closestPath,
      localPoint: (canvasPoint - imgRect.topLeft) / (s > 0 ? s : 1.0),
    );
  }

  // Плавающая кнопка удаления выделенного объекта
  Widget _buildDeleteButton(BuildContext context, DrawState state) {
    DrawAction? selected;
    if (_activeAction != null && _activeAction!.id == _selectedActionId) {
      selected = _activeAction;
    } else {
      try {
        selected = state.history.firstWhere((a) => a.id == _selectedActionId);
      } catch (_) {
        return const SizedBox.shrink();
      }
    }

    if (selected == null) return const SizedBox.shrink();
    if (selected.targetSchemePath != null &&
        !state.backgroundPaths.contains(selected.targetSchemePath)) {
      return const SizedBox.shrink();
    }

    final originalBounds = CanvasPainter.getActionSelectionBounds(selected);
    if (originalBounds == Rect.zero) return const SizedBox.shrink();

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);

    final scaleY = selected.scaleY.abs() == 0 ? 1.0 : selected.scaleY.abs();
    final localDeletePt = Offset(
      originalBounds.center.dx,
      originalBounds.bottom + (25.0 / scaleY),
    );
    final deleteCanvasPt = CanvasPainter.getTransformedActionPoint(
      selected,
      localDeletePt,
    );
    final deleteScreenPt = _canvasToScreen(
      _schemeToCanvasSpace(deleteCanvasPt, selected.targetSchemePath),
    );

    final buttonX = deleteScreenPt.dx - 20;
    final buttonY = deleteScreenPt.dy - 20;

    return Positioned(
      left: buttonX.clamp(4.0, containerSize.width - 48.0),
      top: buttonY.clamp(4.0, containerSize.height - 48.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            final id = _selectedActionId!;
            setState(() {
              _selectedActionId = null;
              _activeAction = null;
              _originalActionForDrag = null;
              _draggedHandle = null;
            });
            widget.selectedActionIdNotifier?.value = null;
            context.read<DrawBloc>().add(DeleteActionEvent(id));
          },
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFD32F2F),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.delete, color: Colors.white, size: 20),
          ),
        ),
      ),
    );
  }

  // Вспомогательные методы хит-тестинга
  double _getDistanceToSegment(Offset p, Offset a, Offset b) {
    final l2 = (a - b).distanceSquared;
    if (l2 == 0) return (p - a).distance;
    double t =
        ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
    t = t.clamp(0.0, 1.0);
    final projection = a + (b - a) * t;
    return (p - projection).distance;
  }

  double _getDistanceToAction(Offset p, DrawAction action) {
    if (action is StrokeAction) {
      if (action.points.isEmpty) return double.infinity;
      if (action.points.length == 1) return (p - action.points.first).distance;
      double minDistance = double.infinity;
      for (int i = 0; i < action.points.length - 1; i++) {
        final dist = _getDistanceToSegment(
          p,
          action.points[i],
          action.points[i + 1],
        );
        if (dist < minDistance) {
          minDistance = dist;
        }
      }
      return minDistance;
    } else if (action is ShapeAction) {
      final rect = Rect.fromPoints(
        action.startPoint,
        action.endPoint,
      ).inflate(8.0);
      if (rect.contains(p)) return 0.0;
      final corners = [
        rect.topLeft,
        rect.topRight,
        rect.bottomRight,
        rect.bottomLeft,
      ];
      double minDistance = double.infinity;
      for (int i = 0; i < 4; i++) {
        final d = _getDistanceToSegment(p, corners[i], corners[(i + 1) % 4]);
        if (d < minDistance) {
          minDistance = d;
        }
      }
      return minDistance;
    } else if (action is TextAction) {
      return _getDistanceToSegment(p, action.startPoint, action.endPoint);
    } else if (action is StampAction) {
      final bounds = CanvasPainter.getOriginalActionBounds(action);
      if (bounds.contains(p)) return 0.0;
      return (p - action.position).distance;
    }
    return double.infinity;
  }

  // Метод создания смещенного объекта при перемещении (обновляем offsetX/offsetY)
  DrawAction _offsetAction(DrawAction original, Offset offset) {
    final double newOffsetX = original.offsetX + offset.dx;
    final double newOffsetY = original.offsetY + offset.dy;

    if (original is StrokeAction) {
      return StrokeAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        points: original.points,
        isEraser: original.isEraser,
        brushType: original.brushType,
        isDashed: original.isDashed,
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    } else if (original is ShapeAction) {
      return ShapeAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        startPoint: original.startPoint,
        endPoint: original.endPoint,
        shapeType: original.shapeType,
        figoType: original.figoType,
        rotation: original.rotation,
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    } else if (original is StampAction) {
      return StampAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        position: original.position,
        stampType: original.stampType,
        customStampPath: original.customStampPath,
        rotation: original.rotation,
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    } else if (original is TextAction) {
      return TextAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        startPoint: original.startPoint,
        endPoint: original.endPoint,
        text: original.text,
        isDashed: original.isDashed,
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    }
    return original;
  }

  // Метод перевода точки из canvas-координат в локальную систему координат объекта.
  // Обратная операция к: rendered_p = p * scale + offset
  // Поэтому: object_p = (canvas_p - offset) / scale
  Offset _canvasToObjectSpace(Offset p, DrawAction action) {
    final path = action.targetSchemePath;
    final pInCellOriginal = _getSchemeLocalPosition(p, path);

    final originalBounds = CanvasPainter.getOriginalActionBounds(action);
    double rotation = 0.0;
    Offset rotationCenter = originalBounds.center;

    if (action is ShapeAction) {
      rotation = action.rotation;
      rotationCenter = Rect.fromPoints(
        action.startPoint,
        action.endPoint,
      ).center;
    } else if (action is StampAction) {
      rotation = action.rotation;
      rotationCenter = action.position;
    }

    // 1. Снимаем глобальный offset и смещение к центру вращения
    final dx = pInCellOriginal.dx - action.offsetX - rotationCenter.dx;
    final dy = pInCellOriginal.dy - action.offsetY - rotationCenter.dy;

    // 2. Снимаем вращение
    double unrotX = dx;
    double unrotY = dy;
    if (rotation != 0.0) {
      final cosA = math.cos(-rotation);
      final sinA = math.sin(-rotation);
      unrotX = dx * cosA - dy * sinA;
      unrotY = dx * sinA + dy * cosA;
    }

    // 3. Снимаем локальное масштабирование
    final double scaleX = action.scaleX == 0 ? 1.0 : action.scaleX;
    final double scaleY = action.scaleY == 0 ? 1.0 : action.scaleY;

    // 4. Возвращаем к центру объекта
    return Offset(
      rotationCenter.dx + unrotX / scaleX,
      rotationCenter.dy + unrotY / scaleY,
    );
  }

  /// Применяет новый scale и offset к объекту, сохраняя все остальные поля.
  /// Используется при resize в локальном пространстве объекта (корректно для повёрнутых).
  DrawAction _applyScaleAndOffset(
    DrawAction original,
    double scaleX,
    double scaleY,
    double offsetX,
    double offsetY,
  ) {
    if (original is StrokeAction) {
      return StrokeAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        points: original.points,
        isEraser: original.isEraser,
        brushType: original.brushType,
        isDashed: original.isDashed,
        scaleX: scaleX,
        scaleY: scaleY,
        offsetX: offsetX,
        offsetY: offsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    } else if (original is ShapeAction) {
      return ShapeAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        startPoint: original.startPoint,
        endPoint: original.endPoint,
        shapeType: original.shapeType,
        figoType: original.figoType,
        rotation: original.rotation,
        scaleX: scaleX,
        scaleY: scaleY,
        offsetX: offsetX,
        offsetY: offsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    } else if (original is StampAction) {
      return StampAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        position: original.position,
        stampType: original.stampType,
        customStampPath: original.customStampPath,
        rotation: original.rotation,
        scaleX: scaleX,
        scaleY: scaleY,
        offsetX: offsetX,
        offsetY: offsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    } else if (original is TextAction) {
      return TextAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        startPoint: original.startPoint,
        endPoint: original.endPoint,
        text: original.text,
        isDashed: original.isDashed,
        scaleX: scaleX,
        scaleY: scaleY,
        offsetX: offsetX,
        offsetY: offsetY,
        targetSchemePath: original.targetSchemePath,
        eraserMasks: original.eraserMasks,
      );
    }
    return original;
  }

  // Преобразование глобальных экранных координат в координаты холста с учетом Zoom/Pan и центрирования
  Offset _screenToCanvas(Offset screenOffset) {
    // 1. Снимаем Zoom и Pan
    final unzoomed = (screenOffset - _offset) / _scale;

    // 2. Обратное преобразование центрирования и вписывания contain-бокса
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final baseSize = CanvasPainter.getCanvasBaseSize(
      activePaths,
      _bgImagesNonNull,
    );

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);

    final drawRect = CanvasPainter.getDrawRect(containerSize, baseSize);

    final double dx =
        (unzoomed.dx - drawRect.left) * (baseSize.width / drawRect.width);
    final double dy =
        (unzoomed.dy - drawRect.top) * (baseSize.height / drawRect.height);
    return Offset(dx, dy);
  }

  // Преобразование координат холста в экранные координаты (для точного хит-тестирования маркеров)
  Offset _canvasToScreen(Offset canvasOffset) {
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final baseSize = CanvasPainter.getCanvasBaseSize(
      activePaths,
      _bgImagesNonNull,
    );

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);

    final drawRect = CanvasPainter.getDrawRect(containerSize, baseSize);

    // 1. Преобразование из canvas-пространства в contain-бокс drawRect
    final double xInDraw =
        canvasOffset.dx * (drawRect.width / baseSize.width) + drawRect.left;
    final double yInDraw =
        canvasOffset.dy * (drawRect.height / baseSize.height) + drawRect.top;

    // 2. Применение масштаба и сдвига Zoom/Pan
    final double screenX = xInDraw * _scale + _offset.dx;
    final double screenY = yInDraw * _scale + _offset.dy;

    return Offset(screenX, screenY);
  }

  void _applyLocalEraserStroke(
    List<Offset> rawCanvasPoints,
    double eraserWidth,
    EraserTarget target,
  ) {
    if (target == EraserTarget.backgroundOnly) {
      return;
    }

    final now = DateTime.now();
    if (_lastEraseTime != null &&
        now.difference(_lastEraseTime!).inMilliseconds < 16) {
      return;
    }
    _lastEraseTime = now;

    if (rawCanvasPoints.isEmpty) return;

    final state = context.read<DrawBloc>().state;
    final List<DrawAction> updatedHistory = List<DrawAction>.from(
      state.history,
    );
    bool historyChanged = false;

    for (int i = 0; i < updatedHistory.length; i++) {
      final action = updatedHistory[i];
      if (action is EraserStrokeAction) continue;

      final rawPt = rawCanvasPoints.first;
      final schemeInfo = _getSchemeInfo(rawPt, state.backgroundPaths);
      if (action.targetSchemePath != null &&
          action.targetSchemePath != schemeInfo.targetSchemePath) {
        continue;
      }

      final List<Offset> localPoints = [];
      final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
      final double effectiveWidth =
          eraserWidth / (avgScale <= 0 ? 1.0 : avgScale);

      final bounds = CanvasPainter.getOriginalActionBounds(
        action,
      ).inflate(effectiveWidth * 4);

      for (final pt in rawCanvasPoints) {
        final localPt = _canvasToObjectSpace(pt, action);
        if (bounds == Rect.zero || bounds.contains(localPt)) {
          localPoints.add(localPt);
        }
      }

      if (localPoints.isNotEmpty) {
        final newMask = EraserMaskData(
          localPoints: localPoints,
          strokeWidth: effectiveWidth,
          target: target,
        );
        final existingMasks = List<EraserMaskData>.from(
          action.eraserMasks ?? [],
        );
        existingMasks.add(newMask);

        updatedHistory[i] = action.copyWithEraserMasks(existingMasks);
        historyChanged = true;
      }
    }

    if (historyChanged) {
      _hasErasedAnything = true;
      context.read<DrawBloc>().add(
        UpdateHistoryWithoutUndoEvent(updatedHistory),
      );
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final state = context.read<DrawBloc>().state;
    // Palm Rejection: Если рисуем стилусом, игнорируем любые касания пальцами (touch)
    if (event.kind == ui.PointerDeviceKind.stylus) {
      _isStylusActive = true;
      _lastStylusTime = DateTime.now();
    } else if (event.kind == ui.PointerDeviceKind.touch) {
      if (_isStylusActive ||
          (_lastStylusTime != null &&
              DateTime.now().difference(_lastStylusTime!).inMilliseconds <
                  300)) {
        return;
      }
    }

    _activePointers.add(event.pointer);

    // Если коснулись двумя или более пальцами, сбрасываем рисование и активируем зум/пан
    if (_activePointers.length >= 2) {
      setState(() {
        _activeAction = null;
        _currentPoints = [];
        _isZooming = true;
      });
      return;
    } else {
      _isZooming = false;
    }

    if (_isZooming) return; // Во время масштабирования не рисуем

    final rawCanvasPt = _screenToCanvas(event.localPosition);
    final schemeInfo = _getSchemeInfo(rawCanvasPt, state.backgroundPaths);
    final targetPath = schemeInfo.targetSchemePath;
    final localPosition = schemeInfo.localPoint;
    final id = _generateId();

    // Проверяем, не кликнули ли мы по кнопке удаления выделенного объекта
    if (state.currentTool == ToolType.move && _selectedActionId != null) {
      DrawAction? selectedAction;
      try {
        selectedAction = state.history.firstWhere(
          (a) => a.id == _selectedActionId,
        );
      } catch (_) {}
      if (selectedAction != null) {
        final selectionBounds =
            CanvasPainter.getActionSelectionBounds(selectedAction);
        if (selectionBounds != Rect.zero) {
          final scaleY = selectedAction.scaleY.abs() == 0
              ? 1.0
              : selectedAction.scaleY.abs();
          final localDeletePt = Offset(
            selectionBounds.center.dx,
            selectionBounds.bottom + (25.0 / scaleY),
          );
          final deleteCanvasPt = CanvasPainter.getTransformedActionPoint(
            selectedAction,
            localDeletePt,
          );
          final deleteScreenPt = _canvasToScreen(
            _schemeToCanvasSpace(
              deleteCanvasPt,
              selectedAction.targetSchemePath,
            ),
          );

          if ((event.localPosition - deleteScreenPt).distance < 25.0) {
            // Клик по кнопке удаления — игнорируем здесь, чтобы сработал InkWell кнопки
            return;
          }
        }
      }
    }

    if (state.currentTool == ToolType.move) {
      // 1. Сначала проверяем, попал ли клик на угловой маркер уже выбранного объекта
      if (_selectedActionId != null) {
        DrawAction? foundAction;
        try {
          foundAction = state.history.firstWhere(
            (a) => a.id == _selectedActionId,
          );
        } catch (_) {}

        if (foundAction != null) {
          final selectedAction = foundAction;
          final selectionBounds =
              CanvasPainter.getActionSelectionBounds(selectedAction);
          final localObjPos = _canvasToObjectSpace(rawCanvasPt, selectedAction);
          final double avgScale = ((selectedAction.scaleX.abs() + selectedAction.scaleY.abs()) / 2)
              .clamp(0.1, 10.0);

          // 1.1. Область захвата вращения: строго в размерах иконки вращения
          final rotationLocalPt = Offset(
            selectionBounds.center.dx,
            selectionBounds.top - (36.0 / avgScale),
          );
          final double rotRadius = 14.0 / avgScale;

          final rotationCanvasPt = _schemeToCanvasSpace(
            CanvasPainter.getTransformedActionPoint(
              selectedAction,
              rotationLocalPt,
            ),
            selectedAction.targetSchemePath,
          );
          final rotationScreenPt = _canvasToScreen(rotationCanvasPt);

          final rotEdgeCanvasPt = _schemeToCanvasSpace(
            CanvasPainter.getTransformedActionPoint(
              selectedAction,
              rotationLocalPt + Offset(rotRadius, 0),
            ),
            selectedAction.targetSchemePath,
          );
          final rotEdgeScreenPt = _canvasToScreen(rotEdgeCanvasPt);
          final double screenRotRadius = (rotEdgeScreenPt - rotationScreenPt).distance;

          String? hitHandle;

          // Захват вращения исключительно в пределах визуальной иконки вращения (с допуском 1.5 px на сглаживание)
          if ((event.localPosition - rotationScreenPt).distance <= screenRotRadius + 1.5) {
            hitHandle = 'rotation';
          } else {
            // Область захвата изменения размера: исключительно через углы (не захватывая грани и тело координатного квадрата)
            const double cornerThreshold = 32.0;
            final double handleSize = 10.0 / avgScale;

            // Допустимое проникновение угла вдоль сторон внутрь рамки (не больше четверти стороны рамки и не дальше визуального маркера)
            final double maxInwardX = math.min(handleSize * 1.5, selectionBounds.width * 0.25);
            final double maxInwardY = math.min(handleSize * 1.5, selectionBounds.height * 0.25);

            final cornersLocal = <String, Offset>{
              'topLeft': selectionBounds.topLeft,
              'topRight': selectionBounds.topRight,
              'bottomLeft': selectionBounds.bottomLeft,
              'bottomRight': selectionBounds.bottomRight,
            };

            for (final entry in cornersLocal.entries) {
              final cornerPt = entry.value;

              // Проверяем проникновение вдоль осей внутрь координатного квадрата:
              // Если клик глубоко на грани или внутри квадрата, это НЕ угол (это грань/тело для перемещения)
              final double inwardX;
              final double inwardY;
              switch (entry.key) {
                case 'topLeft':
                  inwardX = localObjPos.dx - cornerPt.dx;
                  inwardY = localObjPos.dy - cornerPt.dy;
                case 'topRight':
                  inwardX = cornerPt.dx - localObjPos.dx;
                  inwardY = localObjPos.dy - cornerPt.dy;
                case 'bottomLeft':
                  inwardX = localObjPos.dx - cornerPt.dx;
                  inwardY = cornerPt.dy - localObjPos.dy;
                default: // bottomRight
                  inwardX = cornerPt.dx - localObjPos.dx;
                  inwardY = cornerPt.dy - localObjPos.dy;
              }

              // Если клик уходит дальше допустимой угловой зоны внутрь или вдоль граней — отсекаем
              if (inwardX > maxInwardX || inwardY > maxInwardY) {
                continue;
              }

              final canvasPt = _schemeToCanvasSpace(
                CanvasPainter.getTransformedActionPoint(
                  selectedAction,
                  cornerPt,
                ),
                selectedAction.targetSchemePath,
              );
              final screenPt = _canvasToScreen(canvasPt);
              if ((event.localPosition - screenPt).distance < cornerThreshold) {
                hitHandle = entry.key;
                break;
              }
            }
          }

          if (hitHandle != null) {
            setState(() {
              _draggedHandle = hitHandle;
              _dragStartPoint = _getSchemeLocalPosition(
                rawCanvasPt,
                selectedAction.targetSchemePath,
              );
              _originalActionForDrag = selectedAction;
              _activeAction = selectedAction;
            });

            // Инициализируем данные для локального resize (не нужно для rotation-handle)
            if (hitHandle != 'rotation') {
              final action = selectedAction;
              final origBounds = CanvasPainter.getOriginalActionBounds(action);

              // draggedLocal берётся из selectionBounds (где расположен кликнутый маркер)
              final Offset draggedLocal;
              // origAnchorLocal берётся из исходного контура САМОГО ОБЪЕКТА (чтобы закреплялся угол объекта)
              final Offset origAnchorLocal;
              switch (hitHandle) {
                case 'topLeft':
                  draggedLocal = selectionBounds.topLeft;
                  origAnchorLocal = origBounds.bottomRight;
                case 'topRight':
                  draggedLocal = selectionBounds.topRight;
                  origAnchorLocal = origBounds.bottomLeft;
                case 'bottomLeft':
                  draggedLocal = selectionBounds.bottomLeft;
                  origAnchorLocal = origBounds.topRight;
                default: // bottomRight
                  draggedLocal = selectionBounds.bottomRight;
                  origAnchorLocal = origBounds.topLeft;
              }

              // Фиксированная позиция anchor-угла САМОГО ОБЪЕКТА в мировом пространстве схемы
              final anchorWorld = CanvasPainter.getTransformedActionPoint(
                action,
                origAnchorLocal,
              );

              setState(() {
                _rotatedDraggedCorner = draggedLocal;
                _rotatedAnchorCorner = origAnchorLocal;
                _anchorCanvas = anchorWorld;
              });
            }
            return;
          }

          // 1.3. Перетаскивание за любой участок внутри координатного квадрата и его границы
          final double borderTolerance = 8.0 / avgScale;
          if (selectionBounds.inflate(borderTolerance).contains(localObjPos)) {
            setState(() {
              _draggedHandle = null;
              _rotatedDraggedCorner = null;
              _rotatedAnchorCorner = null;
              _anchorCanvas = null;
              _dragStartPoint = _getSchemeLocalPosition(
                rawCanvasPt,
                selectedAction.targetSchemePath,
              );
              _originalActionForDrag = selectedAction;
              _activeAction = selectedAction;
            });
            return;
          }
        }
      }

      // 2. Иначе ищем новый объект для выделения/перемещения
      DrawAction? hitAction;
      double minHitDistance = double.infinity;
      for (final action in state.history.reversed) {
        if (action.targetSchemePath != null &&
            !state.backgroundPaths.contains(action.targetSchemePath)) {
          continue; // Игнорируем действия от выключенных схем
        }
        final localObjPos = _canvasToObjectSpace(rawCanvasPt, action);
        final selectionBounds = CanvasPainter.getActionSelectionBounds(action);
        final isInsideBox = selectionBounds.contains(localObjPos);

        final dist = _getDistanceToAction(localObjPos, action);
        final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
        final screenDist = dist * avgScale;
        final threshold = 20.0 + (action.strokeWidth / 2);
        if (isInsideBox || screenDist < threshold) {
          final effectiveDist = isInsideBox ? 0.0 : screenDist;
          if (effectiveDist < minHitDistance) {
            hitAction = action;
            minHitDistance = effectiveDist;
            if (isInsideBox) {
              break;
            }
          }
        }
      }

      setState(() {
        _draggedHandle = null;
        _rotatedDraggedCorner = null;
        _rotatedAnchorCorner = null;
        _anchorCanvas = null;
        if (hitAction != null) {
          _selectedActionId = hitAction.id;
          widget.selectedActionIdNotifier?.value = hitAction.id;
          _dragStartPoint = _getSchemeLocalPosition(
            rawCanvasPt,
            hitAction.targetSchemePath,
          );
          _originalActionForDrag = hitAction;
          _activeAction = hitAction;
        } else {
          // Кликнули в стороне! Снимаем выделение
          _selectedActionId = null;
          widget.selectedActionIdNotifier?.value = null;
          _dragStartPoint = null;
          _originalActionForDrag = null;
          _activeAction = null;
          if (_isAutoSwitchedToMove) {
            _isAutoSwitchedToMove = false;
            context.read<DrawBloc>().add(SelectToolEvent(_lastSelectedBrush));
          }
        }
      });
      return;
    }

    if (state.currentTool == ToolType.eraser) {
      _hoverCursorNotifier.value = event.localPosition;
      final erasePoint = targetPath != null ? localPosition : rawCanvasPt;
      setState(() {
        _initialHistoryBeforeErase = List<DrawAction>.from(state.history);
        _hasErasedAnything = false;
        _currentPoints = [erasePoint];
        if (state.eraserTarget == EraserTarget.everything ||
            state.eraserTarget == EraserTarget.backgroundOnly) {
          _activeAction = EraserStrokeAction(
            id: id,
            strokeWidth: state.currentStrokeWidth,
            points: List<Offset>.from(_currentPoints),
            target: state.eraserTarget,
            targetSchemePath: targetPath,
          );
        } else {
          _activeAction = null;
        }
      });
      _activeStrokeNotifier.value = _activeAction;
      _applyLocalEraserStroke(
        [rawCanvasPt],
        state.currentStrokeWidth,
        state.eraserTarget,
      );
      return;
    }

    final double pressure = event.pressure;
    _activeStrokeWidth =
        state.currentStrokeWidth * (pressure > 0.0 ? (0.5 + pressure) : 1.0);
    final double strokeWidth = _activeStrokeWidth!;

    setState(() {
      if (state.currentTool == ToolType.pencil ||
          state.currentTool == ToolType.adhesions ||
          state.currentTool == ToolType.fibrosis ||
          state.currentTool == ToolType.spray) {
        // Инициализируем линию (штрих)
        _currentPoints = [localPosition];
        _activeAction = StrokeAction(
          id: id,
          color: state.currentColor,
          strokeWidth: strokeWidth,
          points: _currentPoints,
          isEraser: false,
          brushType: state.currentTool == ToolType.adhesions
              ? 'adhesions'
              : state.currentTool == ToolType.fibrosis
              ? 'fibrosis'
              : state.currentTool == ToolType.spray
              ? 'spray'
              : 'pencil',
          isDashed: state.currentTool == ToolType.pencil
              ? state.currentLineDashed
              : false,
          targetSchemePath: targetPath,
        );
      } else if (state.currentTool == ToolType.endometrioma ||
          state.currentTool == ToolType.myoma ||
          state.currentTool == ToolType.infiltrate ||
          state.currentTool == ToolType.bowelInfiltrate2 ||
          state.currentTool == ToolType.adenomyosis ||
          state.currentTool == ToolType.gui ||
          state.currentTool == ToolType.cyst) {
        // Овал (фигуры)
        _activeAction = ShapeAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          startPoint: localPosition,
          endPoint: localPosition,
          shapeType: state.currentTool == ToolType.endometrioma
              ? 'endometrioma'
              : state.currentTool == ToolType.myoma
              ? 'myoma'
              : state.currentTool == ToolType.infiltrate
              ? 'infiltrate'
              : state.currentTool == ToolType.bowelInfiltrate2
              ? 'bowelInfiltrate2'
              : state.currentTool == ToolType.gui
              ? 'gui'
              : state.currentTool == ToolType.cyst
              ? 'cyst'
              : 'adenomyosis',
          figoType: state.currentTool == ToolType.myoma
              ? state.currentFigoType
              : null,
          targetSchemePath: targetPath,
        );
      } else if (state.currentTool == ToolType.iud ||
          state.currentTool == ToolType.iudStamp ||
          state.currentTool == ToolType.foci ||
          state.currentTool == ToolType.customStamp ||
          state.currentTool == ToolType.follicle ||
          state.currentTool == ToolType.polyp ||
          state.currentTool == ToolType.bowelInfiltrate ||
          state.currentTool == ToolType.infiltrateStamp2 ||
          state.currentTool == ToolType.myomaStamp) {
        // Штампы срабатывают мгновенно при нажатии
        final effectiveCustomStampPath = state.customStampPath ?? state.activeStampItem?.imagePath;
        if (state.currentTool == ToolType.customStamp &&
            effectiveCustomStampPath == null) {
          return;
        }
        final stampAction = StampAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          position: localPosition,
          stampType: state.currentTool == ToolType.iudStamp
              ? 'iudStamp'
              : (state.currentTool == ToolType.myomaStamp
                  ? 'myomaStamp'
                  : (state.currentTool == ToolType.bowelInfiltrate
                      ? 'bowelInfiltrate'
                      : (state.currentTool == ToolType.infiltrateStamp2
                          ? 'infiltrateStamp2'
                          : (state.currentTool == ToolType.customStamp
                              ? 'custom'
                              : state.currentTool == ToolType.iud
                              ? 'iud'
                              : state.currentTool == ToolType.foci
                              ? 'foci'
                              : state.currentTool == ToolType.follicle
                              ? 'follicle'
                              : 'polyp')))),
          customStampPath: state.currentTool == ToolType.iudStamp
              ? 'assets/images/mirena.png'
              : (state.currentTool == ToolType.myomaStamp
                  ? 'assets/images/myoma.png'
                  : (state.currentTool == ToolType.bowelInfiltrate
                      ? 'assets/images/infiltrat.png'
                      : (state.currentTool == ToolType.infiltrateStamp2
                          ? 'assets/images/infiltrat2.png'
                          : (state.currentTool == ToolType.polyp
                              ? 'assets/images/polyp.png'
                              : (state.currentTool == ToolType.customStamp
                                    ? effectiveCustomStampPath
                                    : null))))),
          targetSchemePath: targetPath,
        );
        context.read<DrawBloc>().add(AddActionEvent(stampAction));

        setState(() {
          _activeAction = null;
        });
      } else if (state.currentTool == ToolType.arrow) {
        // Инициализируем стрелку
        _activeAction = TextAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          startPoint: localPosition,
          endPoint: localPosition,
          text: '',
          isDashed: state.currentLineDashed,
          targetSchemePath: targetPath,
        );
      }
    });
    // Синхронизируем notifier после setState, чтобы painter знал о начальном состоянии
    _activeStrokeNotifier.value = _activeAction;
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.kind == ui.PointerDeviceKind.touch && _isStylusActive) {
      return; // Игнорируем касание ладонью при активном стилусе
    }
    if (_isZooming) return;

    final state = context.read<DrawBloc>().state;
    final rawCanvasPt = _screenToCanvas(event.localPosition);
    final targetPath = _activeAction?.targetSchemePath;
    final localPosition = _getSchemeLocalPosition(rawCanvasPt, targetPath);

    // Ластик: отслеживаем точки и позицию курсора
    if (state.currentTool == ToolType.eraser) {
      // Обновляем курсор через notifier — нет setState
      _hoverCursorNotifier.value = event.localPosition;
      final erasePoint = _activeAction?.targetSchemePath != null
          ? localPosition
          : rawCanvasPt;
      _currentPoints.add(erasePoint);
      if (_activeAction is EraserStrokeAction) {
        final updated = EraserStrokeAction(
          id: _activeAction!.id,
          strokeWidth: state.currentStrokeWidth,
          points: List<Offset>.from(_currentPoints),
          target: state.eraserTarget,
          targetSchemePath: _activeAction!.targetSchemePath,
        );
        _activeAction = updated;
        _activeStrokeNotifier.value = updated;
      }
      _applyLocalEraserStroke(
        [rawCanvasPt],
        state.currentStrokeWidth,
        state.eraserTarget,
      );
      return;
    }

    if (_activeAction == null) return;

    if (state.currentTool == ToolType.move) {
      if (_selectedActionId != null &&
          _originalActionForDrag != null &&
          _dragStartPoint != null) {
        final offset = localPosition - _dragStartPoint!;
        // Обновляем _activeAction напрямую, затем сигнализируем repaint — без setState
        if (_draggedHandle != null) {
          if (_draggedHandle == 'rotation') {
            final origBounds = CanvasPainter.getOriginalActionBounds(
              _originalActionForDrag!,
            );
            Offset rotCenter = origBounds.center;
            if (_originalActionForDrag is ShapeAction) {
              rotCenter = Rect.fromPoints(
                (_originalActionForDrag as ShapeAction).startPoint,
                (_originalActionForDrag as ShapeAction).endPoint,
              ).center;
            } else if (_originalActionForDrag is StampAction) {
              rotCenter = (_originalActionForDrag as StampAction).position;
            }
            final center =
                rotCenter +
                Offset(
                  _originalActionForDrag!.offsetX,
                  _originalActionForDrag!.offsetY,
                );

            final double currentAngle = math.atan2(
              localPosition.dy - center.dy,
              localPosition.dx - center.dx,
            );
            final double newRotation = currentAngle + math.pi / 2;

            if (_originalActionForDrag is ShapeAction) {
              final shape = _originalActionForDrag as ShapeAction;
              _activeAction = ShapeAction(
                id: shape.id,
                color: shape.color,
                strokeWidth: shape.strokeWidth,
                startPoint: shape.startPoint,
                endPoint: shape.endPoint,
                shapeType: shape.shapeType,
                figoType: shape.figoType,
                rotation: newRotation,
                scaleX: shape.scaleX,
                scaleY: shape.scaleY,
                offsetX: shape.offsetX,
                offsetY: shape.offsetY,
                targetSchemePath: shape.targetSchemePath,
                eraserMasks: shape.eraserMasks,
              );
            } else if (_originalActionForDrag is StampAction) {
              final stamp = _originalActionForDrag as StampAction;
              _activeAction = StampAction(
                id: stamp.id,
                color: stamp.color,
                strokeWidth: stamp.strokeWidth,
                position: stamp.position,
                stampType: stamp.stampType,
                customStampPath: stamp.customStampPath,
                rotation: newRotation,
                scaleX: stamp.scaleX,
                scaleY: stamp.scaleY,
                offsetX: stamp.offsetX,
                offsetY: stamp.offsetY,
                targetSchemePath: stamp.targetSchemePath,
                eraserMasks: stamp.eraserMasks,
              );
            }
          } else {
            if (_rotatedDraggedCorner != null &&
                _rotatedAnchorCorner != null &&
                _anchorCanvas != null) {
              final action = _originalActionForDrag!;
              final draggedLocal = _rotatedDraggedCorner!;
              final origAnchorLocal = _rotatedAnchorCorner!;
              final anchorWorld = _anchorCanvas!;
              final cursorWorld = localPosition;

              final origBounds = CanvasPainter.getOriginalActionBounds(action);
              double rotation = 0.0;
              Offset rotCenter = origBounds.center;
              if (action is ShapeAction) {
                rotation = action.rotation;
                rotCenter = Rect.fromPoints(
                  action.startPoint,
                  action.endPoint,
                ).center;
              } else if (action is StampAction) {
                rotation = action.rotation;
                rotCenter = action.position;
              }

              final double initScaleX =
                  action.scaleX.abs() == 0 ? 1.0 : action.scaleX.abs();
              final double initScaleY =
                  action.scaleY.abs() == 0 ? 1.0 : action.scaleY.abs();
              final double s0 = (initScaleX + initScaleY) / 2;

              final cosA = math.cos(rotation);
              final sinA = math.sin(rotation);

              // 1. Исходная позиция захваченного маркера в мировых координатах схемы
              final draggedWorld0 = CanvasPainter.getTransformedActionPoint(
                action,
                draggedLocal,
              );

              // 2. Исходный вектор от зафиксированного угла объекта (anchorWorld) до маркера
              final diffWorld0 = draggedWorld0 - anchorWorld;
              final u0X = diffWorld0.dx * cosA + diffWorld0.dy * sinA;
              final u0Y = -diffWorld0.dx * sinA + diffWorld0.dy * cosA;
              final double lenSq0 = u0X * u0X + u0Y * u0Y;

              // 3. Текущий вектор от anchorWorld до курсора в локальной ориентации
              final diffWorld = cursorWorld - anchorWorld;
              final uX = diffWorld.dx * cosA + diffWorld.dy * sinA;
              final uY = -diffWorld.dx * sinA + diffWorld.dy * cosA;

              // 4. Проекция перемещения курсора на исходную диагональ растяжения
              const double eps = 1e-6;
              const double minScale = 0.02;

              final double dot = uX * u0X + uY * u0Y;
              final double scaleFactor = lenSq0 > eps ? (dot / lenSq0) : 1.0;

              final double newUniformScale =
                  (s0 * scaleFactor).clamp(minScale, 100.0);

              // 5. Вычисляем новый Offset так, чтобы угол САМОГО ОБЪЕКТА (origAnchorLocal) оставался СТРОГО в anchorWorld
              // anchorWorld = rotCenter + R(rotation) * ((origAnchorLocal - rotCenter) * newUniformScale) + newOffset
              final anchorDx =
                  (origAnchorLocal.dx - rotCenter.dx) * newUniformScale;
              final anchorDy =
                  (origAnchorLocal.dy - rotCenter.dy) * newUniformScale;
              final rotatedAnchor = Offset(
                anchorDx * cosA - anchorDy * sinA,
                anchorDx * sinA + anchorDy * cosA,
              );

              final newOffsetX =
                  anchorWorld.dx - rotCenter.dx - rotatedAnchor.dx;
              final newOffsetY =
                  anchorWorld.dy - rotCenter.dy - rotatedAnchor.dy;

              _activeAction = _applyScaleAndOffset(
                action,
                newUniformScale,
                newUniformScale,
                newOffsetX,
                newOffsetY,
              );
            }
          }
        } else {
          _activeAction = _offsetAction(_originalActionForDrag!, offset);
        }
        // Сигнализируем repaint через notifier — без setState
        _activeStrokeNotifier.value = _activeAction;
      }
      return;
    }

    // Обновляем _activeAction напрямую (без setState), сигнализируем repaint через notifier.
    // Это устраняет 60+ rebuilds/сек в виджет-дереве во время рисования.
    final double strokeWidth = _activeStrokeWidth ?? state.currentStrokeWidth;

    if (_activeAction is StrokeAction) {
      final stroke = _activeAction as StrokeAction;
      if (stroke.brushType == 'spray') {
        if (_currentPoints.isEmpty ||
            (localPosition - _currentPoints.last).distance >= 4.0) {
          _currentPoints.add(localPosition);
        }
      } else {
        _currentPoints.add(localPosition);
      }
      _activeAction = StrokeAction(
        id: _activeAction!.id,
        color: _activeAction!.color,
        strokeWidth: strokeWidth,
        points: List<Offset>.from(_currentPoints),
        isEraser: false,
        brushType: stroke.brushType,
        isDashed: stroke.isDashed,
        targetSchemePath: _activeAction!.targetSchemePath,
      );
    } else if (_activeAction is ShapeAction) {
      final shape = _activeAction as ShapeAction;
      _activeAction = ShapeAction(
        id: shape.id,
        color: shape.color,
        strokeWidth: shape.strokeWidth,
        startPoint: shape.startPoint,
        endPoint: localPosition,
        shapeType: shape.shapeType,
        figoType: shape.figoType,
        rotation: shape.rotation,
        targetSchemePath: shape.targetSchemePath,
      );
    } else if (_activeAction is TextAction) {
      final text = _activeAction as TextAction;
      _activeAction = TextAction(
        id: text.id,
        color: text.color,
        strokeWidth: text.strokeWidth,
        startPoint: text.startPoint,
        endPoint: localPosition,
        text: text.text,
        isDashed: text.isDashed,
        targetSchemePath: text.targetSchemePath,
      );
    }
    _activeStrokeNotifier.value = _activeAction;
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _isZooming = false;
    }

    if (event.kind == ui.PointerDeviceKind.touch) {
      if (_isStylusActive ||
          (_lastStylusTime != null &&
              DateTime.now().difference(_lastStylusTime!).inMilliseconds <
                  300)) {
        return; // Игнорируем ладонь
      }
    }
    if (event.kind == ui.PointerDeviceKind.stylus) {
      _isStylusActive = false; // Отпустили стилус
      _lastStylusTime = DateTime.now();
    }

    if (_isZooming) return;

    final state = context.read<DrawBloc>().state;

    // Ластик: обрабатываем отдельно
    if (state.currentTool == ToolType.eraser) {
      if (_activeAction is EraserStrokeAction &&
          (_activeAction as EraserStrokeAction).points.isNotEmpty) {
        context.read<DrawBloc>().add(AddActionEvent(_activeAction!));
      } else if (_hasErasedAnything) {
        context.read<DrawBloc>().add(
          SaveUndoStateEvent(_initialHistoryBeforeErase),
        );
      }
      _activeStrokeNotifier.value = null;
      _hoverCursorNotifier.value = event.localPosition;
      setState(() {
        _activeAction = null;
        _initialHistoryBeforeErase = [];
        _hasErasedAnything = false;
        _currentPoints = [];
      });
      return;
    }

    if (_activeAction == null) return;

    if (state.currentTool == ToolType.move) {
      if (_selectedActionId != null && _activeAction != null) {
        context.read<DrawBloc>().add(UpdateActionEvent(_activeAction!));
        _activeStrokeNotifier.value = null;
        setState(() {
          _originalActionForDrag = _activeAction;
          _activeAction = null;
          _draggedHandle = null;
          _rotatedDraggedCorner = null;
          _rotatedAnchorCorner = null;
          _anchorCanvas = null;
        });
      }
      return;
    }

    if (_activeAction is TextAction) {
      final drawBloc = context.read<DrawBloc>();
      _showTextDialog(context).then((text) {
        if (text != null) {
          final oldTextAction = _activeAction as TextAction;
          final finalAction = TextAction(
            id: oldTextAction.id,
            color: oldTextAction.color,
            strokeWidth: oldTextAction.strokeWidth,
            startPoint: oldTextAction.startPoint,
            endPoint: oldTextAction.endPoint,
            text: text,
            isDashed: oldTextAction.isDashed,
            targetSchemePath: oldTextAction.targetSchemePath,
          );
          drawBloc.add(AddActionEvent(finalAction));

          setState(() {
            _activeAction = null;
          });
        } else {
          setState(() {
            _activeAction = null;
          });
        }
      });
    } else {
      var finalAction = _activeAction!;
      if (finalAction is ShapeAction) {
        final shape = finalAction;
        if ((shape.endPoint - shape.startPoint).distance < 5.0) {
          final double sf = CanvasPainter.getSchemeScaleFactor(
            shape.targetSchemePath,
            context.read<DrawBloc>().state.backgroundPaths,
            _bgImagesNonNull,
          );
          final defaultW =
              (shape.shapeType == 'gui'
                  ? 60.0
                  : (shape.shapeType == 'infiltrate' ||
                            shape.shapeType == 'bowelInfiltrate' ||
                            shape.shapeType == 'bowelInfiltrate2'
                        ? 80.0
                        : 40.0)) *
              sf;
          final defaultH =
              (shape.shapeType == 'gui'
                  ? 36.0
                  : (shape.shapeType == 'infiltrate' ||
                            shape.shapeType == 'bowelInfiltrate' ||
                            shape.shapeType == 'bowelInfiltrate2'
                        ? 50.0
                        : 40.0)) *
              sf;
          finalAction = ShapeAction(
            id: shape.id,
            color: shape.color,
            strokeWidth: shape.strokeWidth,
            startPoint: shape.startPoint - Offset(defaultW / 2, defaultH / 2),
            endPoint: shape.startPoint + Offset(defaultW / 2, defaultH / 2),
            shapeType: shape.shapeType,
            figoType: shape.figoType,
            rotation: shape.rotation,
            targetSchemePath: shape.targetSchemePath,
          );
        }
      }
      context.read<DrawBloc>().add(AddActionEvent(finalAction));

      setState(() {
        _activeAction = null;
        _currentPoints = [];
        _activeStrokeWidth = null; // Fix #15: сбросить зафиксированную толщину
      });
      _activeStrokeNotifier.value = null;
    }
  }

  // Диалог ввода текста для стрелки / измерения расстояния
  Future<String?> _showTextDialog(BuildContext context) async {
    String text = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Измерение расстояния'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText:
                  'Введите расстояние (например, 15 мм) или примечание...',
            ),
            onChanged: (value) => text = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null), // Нажата Отмена
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(text), // Нажато Добавить (может быть пустым)
              child: const Text('Добавить'),
            ),
          ],
        );
      },
    );
  }

  // ──────────────────────────────────────────────
  // Масштабирование (пинч-жест, два пальца)
  // ──────────────────────────────────────────────

  void _onScaleStart(ScaleStartDetails details) {
    final drawState = context.read<DrawBloc>().state;
    if (drawState.currentTool == ToolType.eraser) return;

    // Поворот фигуры доступен только при жесте двумя пальцами (pinch/rotate)
    if (drawState.currentTool == ToolType.move &&
        _selectedActionId != null &&
        _activePointers.length >= 2) {
      try {
        final action = drawState.history.firstWhere(
          (a) => a.id == _selectedActionId,
        );
        if (action is ShapeAction) {
          setState(() {
            _originalActionForDrag = action;
            _dragStartRotation = action.rotation;
            _isZooming = false;
            _activeAction = action;
          });
          return;
        }
      } catch (_) {}
    }

    if (_activeAction != null) return;
    setState(() {
      _isZooming = true;
      _previousScale = _scale;
      _normalizedFocalPoint = (details.localFocalPoint - _offset) / _scale;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final drawState = context.read<DrawBloc>().state;
    if (drawState.currentTool == ToolType.move &&
        _selectedActionId != null &&
        _originalActionForDrag is ShapeAction &&
        _activePointers.length >= 2) {
      final original = _originalActionForDrag as ShapeAction;
      setState(() {
        final newRotation = _dragStartRotation + details.rotation;
        _activeAction = ShapeAction(
          id: original.id,
          color: original.color,
          strokeWidth: original.strokeWidth,
          startPoint: original.startPoint,
          endPoint: original.endPoint,
          shapeType: original.shapeType,
          figoType: original.figoType,
          rotation: newRotation,
          scaleX: original.scaleX,
          scaleY: original.scaleY,
          offsetX: original.offsetX,
          offsetY: original.offsetY,
        );
      });
      return;
    }

    if (!_isZooming) return;
    setState(() {
      _scale = (_previousScale * details.scale).clamp(0.2, 8.0);
      _offset = details.localFocalPoint - _normalizedFocalPoint * _scale;
      widget.scaleNotifier?.value = _scale;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    // Завершаем поворот, только если мы были в режиме поворота фигуры (было 2+ пальца)
    if (_originalActionForDrag is ShapeAction &&
        _activeAction != null &&
        (_activeAction as ShapeAction).rotation != _dragStartRotation) {
      context.read<DrawBloc>().add(UpdateActionEvent(_activeAction!));
      setState(() {
        _originalActionForDrag = _activeAction;
        _activeAction = null;
      });
    }
    setState(() {
      _isZooming = false;
    });
  }

  // ──────────────────────────────────────────────
  // Колесо мыши: Ctrl+scroll = zoom, scroll = pan
  // ──────────────────────────────────────────────

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;

    final bool isCtrl = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.controlRight) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.metaRight);
    final bool isShift = HardwareKeyboard.instance.isShiftPressed ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftLeft) ||
        HardwareKeyboard.instance.logicalKeysPressed.contains(LogicalKeyboardKey.shiftRight);

    setState(() {
      if (isCtrl) {
        if (event.scrollDelta.dy == 0) return;
        // Зум в точку под курсором (аналог pinch-to-zoom для мыши / Ctrl+Wheel в веб и десктоп)
        final double zoomFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
        final double newScale = (_scale * zoomFactor).clamp(0.1, 10.0);
        final focalPoint = event.localPosition;
        _offset = focalPoint - (focalPoint - _offset) * (newScale / _scale);
        _scale = newScale;
        widget.scaleNotifier?.value = _scale;
      } else if (isShift) {
        // Горизонтальный пан (Shift+колесо)
        _offset = _offset + Offset(-event.scrollDelta.dy * 1.5, 0);
      } else {
        // Вертикальный и горизонтальный пан (трекпад / обычная мышь)
        _offset =
            _offset +
            Offset(-event.scrollDelta.dx * 1.5, -event.scrollDelta.dy * 1.5);
      }
    });
  }

  // ──────────────────────────────────────────────
  // Курсор мыши — зависит от активного инструмента
  // ──────────────────────────────────────────────

  MouseCursor _getCursorForTool(DrawState state) {
    switch (state.currentTool) {
      case ToolType.eraser:
        // Скрываем системный курсор — вместо него рисуем круг через _buildEraserCursor
        return SystemMouseCursors.none;
      case ToolType.move:
        return _selectedActionId != null
            ? SystemMouseCursors.grab
            : SystemMouseCursors.move;
      case ToolType.pencil:
      case ToolType.adhesions:
      case ToolType.fibrosis:
      case ToolType.spray:
      case ToolType.arrow:
        return SystemMouseCursors.precise;
      case ToolType.endometrioma:
      case ToolType.myoma:
      case ToolType.myomaStamp:
      case ToolType.infiltrate:
      case ToolType.bowelInfiltrate:
      case ToolType.infiltrateStamp2:
      case ToolType.bowelInfiltrate2:
      case ToolType.cyst:
        return SystemMouseCursors.precise;
      case ToolType.iud:
      case ToolType.iudStamp:
      case ToolType.foci:
      case ToolType.follicle:
      case ToolType.polyp:
        return SystemMouseCursors.precise;
      case ToolType.customStamp:
        return SystemMouseCursors.precise;
      case ToolType.gui:
      case ToolType.adenomyosis:
        return SystemMouseCursors.click;
    }
  }

  // ──────────────────────────────────────────────
  // Точный расчет масштаба схемы в экранные пиксели
  // ──────────────────────────────────────────────

  double _getSchemeToScreenScale(
    Offset screenPoint,
    List<String> backgroundPaths,
  ) {
    final rawCanvasPt = _screenToCanvas(screenPoint);
    final schemeInfo = _getSchemeInfo(rawCanvasPt, backgroundPaths);
    final targetPath =
        schemeInfo.targetSchemePath ??
        (backgroundPaths.isNotEmpty ? backgroundPaths.first : null);

    final baseSize = CanvasPainter.getCanvasBaseSize(
      backgroundPaths,
      _bgImagesNonNull,
    );
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);
    final drawRect = CanvasPainter.getDrawRect(containerSize, baseSize);

    final double gridScale = (baseSize.height > 0)
        ? (drawRect.height / baseSize.height)
        : 1.0;

    double s = 1.0;
    if (targetPath != null) {
      final imgRect = CanvasPainter.getSchemeImageRect(
        path: targetPath,
        activePaths: backgroundPaths,
        bgImages: _bgImagesNonNull,
      );
      if (imgRect != Rect.zero) {
        final origSize = CanvasPainter.getOriginalSchemeSize(
          targetPath,
          _bgImagesNonNull[targetPath],
        );
        s = imgRect.width / origSize.width;
      }
    }

    return _scale * gridScale * s;
  }

  // ──────────────────────────────────────────────
  // Оверлей курсора ластика (круг в экранных координатах)
  // ──────────────────────────────────────────────

  Widget _buildEraserCursor(DrawState state, Offset center) {
    final double effectiveScale = _getSchemeToScreenScale(
      center,
      state.backgroundPaths,
    );
    // Точный радиус в экранных пикселях 1-в-1 с областью стирания на схеме
    final double radius = (state.currentStrokeWidth / 2) * effectiveScale;
    final bool isErasingBackground =
        state.eraserTarget == EraserTarget.everything ||
        state.eraserTarget == EraserTarget.backgroundOnly;

    final Color cursorColor = switch (state.eraserTarget) {
      EraserTarget.annotationsOnly => const Color(0xFF0F4C81),
      EraserTarget.backgroundOnly => const Color(0xFF00897B),
      EraserTarget.everything => Colors.orangeAccent,
    };

    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isErasingBackground
                ? cursorColor.withValues(alpha: 0.08)
                : Colors.transparent,
            border: Border.all(
              color: cursorColor,
              width: 1.5,
            ),
          ),
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white70, width: 0.5),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────
  // Призрачный (ghost) превью-курсор для штампов
  // ──────────────────────────────────────────────

  Widget _buildGhostCursor(DrawState state, Offset position) {
    final double effectiveScale = _getSchemeToScreenScale(
      position,
      state.backgroundPaths,
    );

    final String? effectiveCustomPath = state.customStampPath ?? state.activeStampItem?.imagePath;

    final ui.Image? stampImage = state.currentTool == ToolType.bowelInfiltrate
        ? (_stampImagesNonNull['assets/images/infiltrat.png'] ??
            _stampImages['assets/images/infiltrat.png'])
        : (state.currentTool == ToolType.infiltrateStamp2
            ? (_stampImagesNonNull['assets/images/infiltrat2.png'] ??
                _stampImages['assets/images/infiltrat2.png'])
            : (state.currentTool == ToolType.polyp
                ? (_stampImagesNonNull['assets/images/polyp.png'] ??
                    _stampImages['assets/images/polyp.png'])
                : (state.currentTool == ToolType.myomaStamp
                    ? (_stampImagesNonNull['assets/images/myoma.png'] ??
                        _stampImages['assets/images/myoma.png'])
                    : (state.currentTool == ToolType.iudStamp
                        ? (_stampImagesNonNull['assets/images/mirena.png'] ??
                            _stampImages['assets/images/mirena.png'])
                        : (state.currentTool == ToolType.customStamp && effectiveCustomPath != null
                            ? (_stampImagesNonNull[effectiveCustomPath] ??
                                _stampImages[effectiveCustomPath])
                            : null)))));

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _GhostStampPainter(
            tool: state.currentTool,
            color: state.currentColor,
            strokeWidth: state.currentStrokeWidth,
            effectiveScale: effectiveScale,
            stampImage: stampImage,
          ),
        ),
      ),
    );
  }
}

class _GhostStampPainter extends CustomPainter {
  final ToolType tool;
  final Color color;
  final double strokeWidth;
  final double effectiveScale;
  final ui.Image? stampImage;

  _GhostStampPainter({
    required this.tool,
    required this.color,
    required this.strokeWidth,
    required this.effectiveScale,
    this.stampImage,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    // Точный масштаб с учётом зума холста, сетки мультисхем и разрешения шаблона
    canvas.scale(effectiveScale, effectiveScale);

    switch (tool) {
      case ToolType.iud:
        // ВМС: Т-образная форма
        final double scale = CanvasPainter.getIudScale(strokeWidth);
        final double width = 29.0 * scale;
        final double height = 36.0 * scale;

        final ghostPaint = Paint()
          ..color = color.withValues(alpha: 0.55)
          ..strokeWidth = (1.5 * scale).clamp(2.0, 8.0)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        // Горизонтальная планка
        canvas.drawLine(
          Offset(-width / 2, 0),
          Offset(width / 2, 0),
          ghostPaint,
        );
        // Вертикальная ножка вниз
        canvas.drawLine(Offset.zero, Offset(0, height), ghostPaint);

        // Точка прицела в центре верхней планки
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaint,
        );
        break;

      case ToolType.iudStamp:
        // Штамп Мирена (ВМС)
        final double scale = CanvasPainter.getIudScale(strokeWidth);
        final double height = 36.0 * scale;
        final double width = height *
            (stampImage != null
                ? (stampImage!.width / stampImage!.height)
                : (1216.0 / 1293.0));
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        );

        if (stampImage != null) {
          canvas.saveLayer(
            rect.inflate(4.0),
            Paint()..color = const Color(0x99FFFFFF), // 60% прозрачность
          );
          canvas.drawImageRect(
            stampImage!,
            Rect.fromLTWH(
              0,
              0,
              stampImage!.width.toDouble(),
              stampImage!.height.toDouble(),
            ),
            rect,
            Paint(),
          );
          canvas.restore();
        } else {
          final ghostPaint = Paint()
            ..color = const Color(0xFF000000).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, ghostPaint);
        }

        // Тонкий контур границы
        final borderPaint = Paint()
          ..color = const Color(0xFF000000).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rect, borderPaint);

        // Точка прицела в центре
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaint,
        );
        break;

      case ToolType.foci:
        // Эндометриоидный очаг (звездчатый лепестковый контур)
        final double rOuter = strokeWidth * 2;
        final double rInner = rOuter / 2;

        final fillPaint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.fill;

        final strokePaint = Paint()
          ..color = color.withValues(alpha: 0.8)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        final path = Path();
        for (int i = 0; i < 16; i++) {
          final angle = (i * math.pi) / 8;
          final r = (i % 2 == 0) ? rOuter : rInner;
          final x = math.cos(angle) * r;
          final y = math.sin(angle) * r;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, fillPaint);
        canvas.drawPath(path, strokePaint);

        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaint,
        );
        break;

      case ToolType.follicle:
        // Фолликул (голубой контур с мягкой заливкой)
        final double radius = strokeWidth * 1.5;

        final fillPaint = Paint()
          ..color = const Color(0xFF03A9F4).withValues(alpha: 0.15)
          ..style = PaintingStyle.fill;

        final ringPaint = Paint()
          ..color = const Color(0xFF03A9F4).withValues(alpha: 0.7)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;

        canvas.drawCircle(Offset.zero, radius, fillPaint);
        canvas.drawCircle(Offset.zero, radius, ringPaint);

        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaint,
        );
        break;

      case ToolType.polyp:
        // Штамп полипа
        final double scalePolyp = CanvasPainter.getBowelInfiltrateScale(strokeWidth);
        final double heightPolyp = 90.0 * scalePolyp;
        final double widthPolyp = heightPolyp *
            (stampImage != null
                ? (stampImage!.width / stampImage!.height)
                : (1001.0 / 1025.0));
        final rectPolyp = Rect.fromCenter(
          center: Offset.zero,
          width: widthPolyp,
          height: heightPolyp,
        );

        if (stampImage != null) {
          canvas.saveLayer(
            rectPolyp.inflate(4.0),
            Paint()..color = const Color(0x99FFFFFF), // 60% прозрачность
          );
          canvas.drawImageRect(
            stampImage!,
            Rect.fromLTWH(
              0,
              0,
              stampImage!.width.toDouble(),
              stampImage!.height.toDouble(),
            ),
            rectPolyp,
            Paint(),
          );
          canvas.restore();
        } else {
          final ghostPaint = Paint()
            ..color = const Color(0xFFFF7043).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawOval(rectPolyp, ghostPaint);
        }

        // Тонкий контур границы
        final borderPaintPolyp = Paint()
          ..color = const Color(0xFFFF7043).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawOval(rectPolyp, borderPaintPolyp);

        // Точка прицела в центре
        final dotPaintPolyp = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaintPolyp,
        );
        break;

      case ToolType.bowelInfiltrate:
        // Штамп инфильтрата кишки
        final double scale = CanvasPainter.getBowelInfiltrateScale(strokeWidth);
        final double height = 90.0 * scale;
        final double width = height *
            (stampImage != null
                ? (stampImage!.width / stampImage!.height)
                : 2.0);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        );

        if (stampImage != null) {
          canvas.saveLayer(
            rect.inflate(4.0),
            Paint()..color = const Color(0x99FFFFFF), // 60% прозрачность
          );
          canvas.drawImageRect(
            stampImage!,
            Rect.fromLTWH(
              0,
              0,
              stampImage!.width.toDouble(),
              stampImage!.height.toDouble(),
            ),
            rect,
            Paint(),
          );
          canvas.restore();
        } else {
          // Если картинка еще загружается - рисуем силуэт
          final ghostPaint = Paint()
            ..color = const Color(0xFF5C4033).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawOval(rect, ghostPaint);
        }

        // Тонкий контур границы
        final borderPaint = Paint()
          ..color = const Color(0xFF5C4033).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawOval(rect, borderPaint);

        // Точка прицела в центре
        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaint,
        );
        break;

      case ToolType.infiltrateStamp2:
        // Штамп инфильтрата 2
        final double scale = CanvasPainter.getInfiltrateStamp2Scale(strokeWidth);
        final double height = 90.0 * scale;
        final double width = height *
            (stampImage != null
                ? (stampImage!.width / stampImage!.height)
                : 1.0);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        );

        if (stampImage != null) {
          canvas.saveLayer(
            rect.inflate(4.0),
            Paint()..color = const Color(0x99FFFFFF), // 60% прозрачность
          );
          canvas.drawImageRect(
            stampImage!,
            Rect.fromLTWH(
              0,
              0,
              stampImage!.width.toDouble(),
              stampImage!.height.toDouble(),
            ),
            rect,
            Paint(),
          );
          canvas.restore();
        } else {
          final ghostPaint = Paint()
            ..color = const Color(0xFF5C4033).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawOval(rect, ghostPaint);
        }

        final borderPaint = Paint()
          ..color = const Color(0xFF5C4033).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawOval(rect, borderPaint);

        final dotPaintInf2 = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaintInf2,
        );
        break;

      case ToolType.myomaStamp:
        // Штамп миоматозного узла
        final double scale = CanvasPainter.getMyomaStampScale(strokeWidth);
        final double height = 90.0 * scale;
        final double width = height *
            (stampImage != null
                ? (stampImage!.width / stampImage!.height)
                : (1301.0 / 1209.0));
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        );

        if (stampImage != null) {
          canvas.saveLayer(
            rect.inflate(4.0),
            Paint()..color = const Color(0x99FFFFFF), // 60% прозрачность
          );
          canvas.drawImageRect(
            stampImage!,
            Rect.fromLTWH(
              0,
              0,
              stampImage!.width.toDouble(),
              stampImage!.height.toDouble(),
            ),
            rect,
            Paint(),
          );
          canvas.restore();
        } else {
          final ghostPaint = Paint()
            ..color = const Color(0xFFFF69B4).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawOval(rect, ghostPaint);
        }

        final borderPaint = Paint()
          ..color = const Color(0xFFFF69B4).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawOval(rect, borderPaint);

        final dotPaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaint,
        );
        break;

      case ToolType.customStamp:
        // Пользовательский PNG штамп
        final double scale = CanvasPainter.getBowelInfiltrateScale(strokeWidth);
        final double height = 90.0 * scale;
        final double width = height *
            (stampImage != null
                ? (stampImage!.width / stampImage!.height)
                : 1.0);
        final rect = Rect.fromCenter(
          center: Offset.zero,
          width: width,
          height: height,
        );

        if (stampImage != null) {
          canvas.saveLayer(
            rect.inflate(4.0),
            Paint()..color = const Color(0x99FFFFFF), // 60% прозрачность
          );
          canvas.drawImageRect(
            stampImage!,
            Rect.fromLTWH(
              0,
              0,
              stampImage!.width.toDouble(),
              stampImage!.height.toDouble(),
            ),
            rect,
            Paint(),
          );
          canvas.restore();
        } else {
          final ghostPaint = Paint()
            ..color = const Color(0xFF2196F3).withValues(alpha: 0.4)
            ..style = PaintingStyle.fill;
          canvas.drawRect(rect, ghostPaint);
        }

        final borderPaint = Paint()
          ..color = const Color(0xFF2196F3).withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;
        canvas.drawRect(rect, borderPaint);

        final dotPaintCustom = Paint()
          ..color = Colors.white.withValues(alpha: 0.9)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(
          Offset.zero,
          1.8 / (effectiveScale > 0 ? effectiveScale : 1.0),
          dotPaintCustom,
        );
        break;

      default:
        break;
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _GhostStampPainter oldDelegate) {
    return oldDelegate.tool != tool ||
        oldDelegate.color != color ||
        oldDelegate.strokeWidth != strokeWidth ||
        oldDelegate.effectiveScale != effectiveScale ||
        oldDelegate.stampImage != stampImage;
  }
}
