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
  String? _draggedHandle; // 'topLeft', 'topRight', 'bottomLeft', 'bottomRight' или null
  // Для Paint-like resize: пред-scale позиции захваченного/anchor углов + canvas-позиция anchor
  Offset? _rotatedDraggedCorner; // A = rotate(draggedLocal, rotCenter, angle)
  Offset? _rotatedAnchorCorner;  // B = rotate(anchorLocal,  rotCenter, angle)
  Offset? _anchorCanvas;         // canvas-позиция anchor при старте drag (без cell offset)

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

  // Переменные для зума и панорамирования (Zoom & Pan)
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _normalizedFocalPoint = Offset.zero;

  // Курсор ластика в экранных координатах
  Offset? _eraserCursorPosition;
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
        if (state.currentTool != ToolType.move && state.currentTool != ToolType.eraser) {
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
        final String? targetBgPath = state.backgroundPaths.contains('assets/schemes/standart_endo.jpg')
            ? 'assets/schemes/standart_endo.jpg'
            : state.backgroundPath;
        if (targetBgPath != _loadedBackgroundPath) {
          _loadedBackgroundPath = targetBgPath;
          Future.microtask(() => _loadBackground(targetBgPath));
        }

        // Автоматическая подгрузка изображений для пользовательских фонов
        for (final path in state.backgroundPaths) {
          if (!_bgImages.containsKey(path)) {
            _bgImages[path] = null;
            Future.microtask(() => _loadBgImage(path));
          }
        }

        // Автоматическая подгрузка изображений для пользовательских штампов из истории
        for (final action in state.history) {
          if (action is StampAction && action.stampType == 'custom' && action.customStampPath != null) {
            final path = action.customStampPath!;
            if (!_stampImages.containsKey(path)) {
              _stampImages[path] = null as dynamic; // Временная заглушка, чтобы не запускать загрузку повторно
              Future.microtask(() => _loadCustomStampImage(path));
            }
          }
        }

        // Также грузим текущий выбранный кастомный штамп
        if (state.customStampPath != null && !_stampImages.containsKey(state.customStampPath!)) {
          _stampImages[state.customStampPath!] = null as dynamic;
          Future.microtask(() => _loadCustomStampImage(state.customStampPath!));
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
                setState(() {
                  _initialHistoryBeforeErase = [];
                  _hasErasedAnything = false;
                  _eraserCursorPosition = null;
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
                if (activeState.currentTool == ToolType.eraser && mounted) {
                  setState(() => _eraserCursorPosition = event.localPosition);
                }
              },
              onExit: (_) {
                if (mounted) setState(() => _eraserCursorPosition = null);
              },
              child: GestureDetector(
                // Scale gestures для масштабирования холста двумя пальцами
                onScaleStart: _onScaleStart,
                onScaleUpdate: _onScaleUpdate,
                onScaleEnd: _onScaleEnd,
                child: Stack(
                  children: [
                    Transform(
                      transform: Matrix4.translationValues(_offset.dx, _offset.dy, 0.0)
                        * Matrix4.diagonal3Values(_scale, _scale, 1.0),
                      child: CustomPaint(
                        size: Size.infinite,
                        painter: CanvasPainter(
                          history: state.history,
                          // Не отображаем _activeAction для ластика — только курсор-круг
                          activeAction: state.currentTool != ToolType.eraser ? _activeAction : null,
                          backgroundImage: widget.backgroundImage ?? _loadedBackgroundImage,
                          backgroundPaths: state.backgroundPaths,
                          backgroundPath: state.backgroundPath,
                          bgImages: Map<String, ui.Image>.fromEntries(
                            _bgImages.entries
                                .where((e) => e.value != null)
                                .map((e) => MapEntry(e.key, e.value!)),
                          ),
                          stampImages: Map<String, ui.Image>.fromEntries(
                            _stampImages.entries
                                .where((e) => e.value != null)
                                .map((e) => MapEntry(e.key, e.value!)),
                          ),
                          selectedActionId: _selectedActionId,
                          patientId: state.patientId,
                        ),
                      ),
                    ),
                    // Кнопка удаления выделенного объекта
                    if (state.currentTool == ToolType.move && _selectedActionId != null)
                      _buildDeleteButton(context, state),
                    // Курсор ластика — оверлей
                    if (state.currentTool == ToolType.eraser && _eraserCursorPosition != null)
                      _buildEraserCursor(state),
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
      final image = await loadUiImage(path);
      if (mounted) {
        setState(() {
          _bgImages[path] = image;
          if (_loadedBackgroundImage == null || path == _loadedBackgroundPath) {
            _loadedBackgroundImage = image;
            _loadedBackgroundPath = path;
          }
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки фонового изображения $path: $e');
      if (mounted) {
        setState(() {
          _bgImages.remove(path);
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
          _stampImages[path] = image;
        });
      }
    } catch (e) {
      debugPrint('Ошибка загрузки пользовательского штампа $path: $e');
      if (mounted) {
        setState(() {
          _stampImages.remove(path);
        });
      }
    }
  }

  Offset _getCellOffsetForPath(String? path) {
    if (path == null) return Offset.zero;
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final idx = activePaths.indexOf(path);
    if (idx == -1) return Offset.zero;

    final cols = activePaths.length <= 1 ? 1 : 2;
    final double col0W = 600.0 * CanvasPainter.getSchemeAspectRatio(activePaths.isEmpty ? '' : activePaths[0]);

    final col = idx % cols;
    final row = idx ~/ cols;
    return Offset(col == 0 ? 0.0 : col0W, row * 600.0);
  }

  Offset _getSchemeLocalPosition(Offset rawCanvasPt, String? targetPath) {
    if (targetPath == null) return rawCanvasPt;
    final cellOffset = _getCellOffsetForPath(targetPath);
    final pInCell = rawCanvasPt - cellOffset;
    final double origHeight = CanvasPainter.getOriginalSchemeSize(targetPath).height;
    final double scale = origHeight / 600.0;
    return pInCell * scale;
  }

  Offset _schemeToCanvasSpace(Offset point, String? path) {
    if (path == null) return point;
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final idx = activePaths.indexOf(path);
    if (idx == -1) return point;

    final cols = activePaths.length <= 1 ? 1 : 2;
    final double col0W = 600.0 * CanvasPainter.getSchemeAspectRatio(activePaths.isEmpty ? '' : activePaths[0]);

    final double origHeight = CanvasPainter.getOriginalSchemeSize(path).height;

    // Масштабируем точку в пространство высотой 600.0
    final double scale = 600.0 / origHeight;
    final scaledPoint = point * scale;

    final col = idx % cols;
    final row = idx ~/ cols;
    final cellOffset = Offset(col == 0 ? 0.0 : col0W, row * 600.0);

    return scaledPoint + cellOffset;
  }

  ({String? targetSchemePath, Offset localPoint}) _getSchemeInfo(
    Offset canvasPoint,
    List<String> backgroundPaths,
  ) {
    if (backgroundPaths.isEmpty) {
      return (targetSchemePath: null, localPoint: canvasPoint);
    }
    final count = backgroundPaths.length;
    final int cols = count <= 1 ? 1 : 2;

    final double col0W = 600.0 * CanvasPainter.getSchemeAspectRatio(backgroundPaths[0]);

    for (int i = 0; i < backgroundPaths.length; i++) {
      final int col = i % cols;
      final int row = i ~/ cols;
      final double cellW = col == 0 ? col0W : 800.0;
      final double cellH = 600.0;

      final cellRect = Rect.fromLTWH(col == 0 ? 0.0 : col0W, row * 600.0, cellW, cellH);
      if (cellRect.contains(canvasPoint)) {
        // Масштабируем localPoint обратно в оригинальное пространство схемы
        final double origHeight = CanvasPainter.getOriginalSchemeSize(backgroundPaths[i]).height;
        final double scale = origHeight / 600.0;
        return (
          targetSchemePath: backgroundPaths[i],
          localPoint: (canvasPoint - cellRect.topLeft) * scale,
        );
      }
    }
    return (
      targetSchemePath: backgroundPaths.first,
      localPoint: canvasPoint,
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

    final originalBounds = CanvasPainter.getOriginalActionBounds(selected);
    if (originalBounds == Rect.zero) return const SizedBox.shrink();

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);

    final scaleY = selected.scaleY.abs() == 0 ? 1.0 : selected.scaleY.abs();
    final localDeletePt = Offset(originalBounds.center.dx, originalBounds.bottom + (25.0 / scaleY));
    final deleteCanvasPt = CanvasPainter.getTransformedActionPoint(selected, localDeletePt);
    final deleteScreenPt = _canvasToScreen(_schemeToCanvasSpace(deleteCanvasPt, selected.targetSchemePath));

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
    double t = ((p.dx - a.dx) * (b.dx - a.dx) + (p.dy - a.dy) * (b.dy - a.dy)) / l2;
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
        final dist = _getDistanceToSegment(p, action.points[i], action.points[i + 1]);
        if (dist < minDistance) {
          minDistance = dist;
        }
      }
      return minDistance;
    } else if (action is ShapeAction) {
      final rect = Rect.fromPoints(action.startPoint, action.endPoint).inflate(8.0);
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
      );
    }
    return original;
  }


  // Метод перевода точки из canvas-координат в локальную систему координат объекта.
  // Обратная операция к: rendered_p = p * scale + offset
  // Поэтому: object_p = (canvas_p - offset) / scale
  Offset _canvasToObjectSpace(Offset p, DrawAction action) {
    final path = action.targetSchemePath;
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final idx = activePaths.indexOf(path ?? '');
    
    final double col0W = 600.0 * CanvasPainter.getSchemeAspectRatio(activePaths.isEmpty ? '' : activePaths[0]);
    final double origHeight = CanvasPainter.getOriginalSchemeSize(path ?? '').height;
        
    final col = idx == -1 ? 0 : (idx % (activePaths.length <= 1 ? 1 : 2));
    final row = idx == -1 ? 0 : (idx ~/ (activePaths.length <= 1 ? 1 : 2));
    
    final cellOffset = Offset(col == 0 ? 0.0 : col0W, row * 600.0);
    final pInCellUnified = p - cellOffset;
    
    // Переводим из пространства 600.0 в оригинальное пространство схемы
    final double scaleBack = origHeight / 600.0;
    final pInCellOriginal = pInCellUnified * scaleBack;

    final double scaleX = action.scaleX == 0 ? 1.0 : action.scaleX;
    final double scaleY = action.scaleY == 0 ? 1.0 : action.scaleY;

    final unscaled = Offset(
      (pInCellOriginal.dx - action.offsetX) / scaleX,
      (pInCellOriginal.dy - action.offsetY) / scaleY,
    );

    double rotation = 0.0;
    Offset rotationCenter = Offset.zero;

    if (action is ShapeAction) {
      rotation = action.rotation;
      rotationCenter = Rect.fromPoints(action.startPoint, action.endPoint).center;
    } else if (action is StampAction) {
      rotation = action.rotation;
      rotationCenter = action.position;
    }

    if (rotation != 0.0) {
      final dx = unscaled.dx - rotationCenter.dx;
      final dy = unscaled.dy - rotationCenter.dy;
      final cosA = math.cos(-rotation);
      final sinA = math.sin(-rotation);
      return Offset(
        rotationCenter.dx + dx * cosA - dy * sinA,
        rotationCenter.dy + dx * sinA + dy * cosA,
      );
    }

    return unscaled;
  }

  // Метод изменения размера объекта (обновляем scaleX/scaleY и offsetX/offsetY)
  DrawAction _resizeAction(DrawAction original, Rect oldRect, Rect newRect) {
    final originalBounds = CanvasPainter.getOriginalActionBounds(original);
    if (originalBounds.width == 0 || originalBounds.height == 0) return original;

    double newScaleX = newRect.width / originalBounds.width;
    double newScaleY = newRect.height / originalBounds.height;

    // Запрещаем отрицательный масштаб — объект не должен отражаться при сжатии
    const double minScale = 0.05;
    newScaleX = newScaleX.clamp(minScale, double.infinity);
    newScaleY = newScaleY.clamp(minScale, double.infinity);

    // Для кругов (эндометриома, миома) сохраняем пропорции 1:1 при изменении размера
    if (original is ShapeAction &&
        (original.shapeType == 'endometrioma' || original.shapeType == 'myoma')) {
      final double scale = (newScaleX + newScaleY) / 2;
      newScaleX = scale;
      newScaleY = scale;
    }

    final newOffsetX = newRect.left - originalBounds.left * newScaleX;
    final newOffsetY = newRect.top - originalBounds.top * newScaleY;

    if (original is StrokeAction) {
      return StrokeAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        points: original.points,
        isEraser: original.isEraser,
        brushType: original.brushType,
        isDashed: original.isDashed,
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
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
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
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
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
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
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
        targetSchemePath: original.targetSchemePath,
      );
    }
    return original;
  }

  /// Применяет новый scale и offset к объекту, сохраняя все остальные поля.
  /// Используется при resize в локальном пространстве объекта (корректно для повёрнутых).
  DrawAction _applyScaleAndOffset(DrawAction original, double scaleX, double scaleY, double offsetX, double offsetY) {
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
    final baseSize = CanvasPainter.getCanvasBaseSize(activePaths);

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);

    final drawRect = CanvasPainter.getDrawRect(containerSize, baseSize);

    final double dx = (unzoomed.dx - drawRect.left) * (baseSize.width / drawRect.width);
    final double dy = (unzoomed.dy - drawRect.top) * (baseSize.height / drawRect.height);
    return Offset(dx, dy);
  }

  // Преобразование координат холста в экранные координаты (для точного хит-тестирования маркеров)
  Offset _canvasToScreen(Offset canvasOffset) {
    final activePaths = context.read<DrawBloc>().state.backgroundPaths;
    final baseSize = CanvasPainter.getCanvasBaseSize(activePaths);

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    final containerSize = renderBox?.size ?? const Size(800.0, 600.0);

    final drawRect = CanvasPainter.getDrawRect(containerSize, baseSize);

    // 1. Преобразование из canvas-пространства в contain-бокс drawRect
    final double xInDraw = canvasOffset.dx * (drawRect.width / baseSize.width) + drawRect.left;
    final double yInDraw = canvasOffset.dy * (drawRect.height / baseSize.height) + drawRect.top;

    // 2. Применение масштаба и сдвига Zoom/Pan
    final double screenX = xInDraw * _scale + _offset.dx;
    final double screenY = yInDraw * _scale + _offset.dy;

    return Offset(screenX, screenY);
  }

  void _eraseAtPoint(Offset canvasPoint, double eraserRadius) {
    // Fix #6: throttle — не чаще одного раза за кадр (16 мс), иначе BLoC
    // получает сотни событий в секунду и провоцирует подтормаживания.
    final now = DateTime.now();
    if (_lastEraseTime != null &&
        now.difference(_lastEraseTime!).inMilliseconds < 16) {
      return;
    }
    _lastEraseTime = now;

    final state = context.read<DrawBloc>().state;
    final List<DrawAction> updatedHistory = List<DrawAction>.from(state.history);
    bool historyChanged = false;

    for (int i = updatedHistory.length - 1; i >= 0; i--) {
      final action = updatedHistory[i];
      final localObjPos = _canvasToObjectSpace(canvasPoint, action);
      
      final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
      final double effectiveRadius = eraserRadius / (avgScale <= 0 ? 1.0 : avgScale);

      if (action is StrokeAction) {
        // Быстрая проверка пересечения с bounding box штриха
        final bounds = CanvasPainter.getOriginalActionBounds(action);
        final threshold = effectiveRadius + (action.strokeWidth / 2);
        final expandedRect = bounds.inflate(threshold);
        if (!expandedRect.contains(localObjPos)) {
          continue;
        }

        // Проверяем, близко ли ластик к линии
        final dist = _getDistanceToAction(localObjPos, action);
        if (dist < threshold) {
          // Разбиваем линию на непрерывные сегменты, исключая стёртые точки
          final List<List<Offset>> segments = [];
          List<Offset> currentSegment = [];

          for (final pt in action.points) {
            final double d = (pt - localObjPos).distance;
            if (d < effectiveRadius) {
              if (currentSegment.isNotEmpty) {
                segments.add(currentSegment);
                currentSegment = [];
              }
            } else {
              currentSegment.add(pt);
            }
          }
          if (currentSegment.isNotEmpty) {
            segments.add(currentSegment);
          }

          // Удаляем старый штрих
          updatedHistory.removeAt(i);
          historyChanged = true;

          // Добавляем новые сегменты на то же место
          int insertIndex = i;
          for (final segmentPoints in segments) {
            if (segmentPoints.isNotEmpty) {
              updatedHistory.insert(
                insertIndex,
                StrokeAction(
                  id: _generateId(), // Fix #20: стабильный уникальный ID вместо хеша
                  color: action.color,
                  strokeWidth: action.strokeWidth,
                  points: segmentPoints,
                  isEraser: action.isEraser,
                  brushType: action.brushType,
                  scaleX: action.scaleX,
                  scaleY: action.scaleY,
                  offsetX: action.offsetX,
                  offsetY: action.offsetY,
                ),
              );
              insertIndex++;
            }
          }
        }
      } else {
        // Для не-линий (фигур, штампов, стрелок) удаляем объект целиком при касании ластика
        final dist = _getDistanceToAction(localObjPos, action);
        if (dist < effectiveRadius) {
          updatedHistory.removeAt(i);
          historyChanged = true;
        }
      }
    }

    if (historyChanged) {
      _hasErasedAnything = true;
      context.read<DrawBloc>().add(UpdateHistoryWithoutUndoEvent(updatedHistory));
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    final state = context.read<DrawBloc>().state;
    // Palm Rejection: Если рисуем стилусом, игнорируем любые касания пальцами (touch)
    if (event.kind == ui.PointerDeviceKind.stylus) {
      _isStylusActive = true;
      _lastStylusTime = DateTime.now();
    } else if (event.kind == ui.PointerDeviceKind.touch) {
      if (_isStylusActive || (_lastStylusTime != null && DateTime.now().difference(_lastStylusTime!).inMilliseconds < 300)) {
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
        selectedAction = state.history.firstWhere((a) => a.id == _selectedActionId);
      } catch (_) {}
      if (selectedAction != null) {
        final originalBounds = CanvasPainter.getOriginalActionBounds(selectedAction);
        if (originalBounds != Rect.zero) {
          final scaleY = selectedAction.scaleY.abs() == 0 ? 1.0 : selectedAction.scaleY.abs();
          final localDeletePt = Offset(originalBounds.center.dx, originalBounds.bottom + (25.0 / scaleY));
          final deleteCanvasPt = CanvasPainter.getTransformedActionPoint(selectedAction, localDeletePt);
          final deleteScreenPt = _canvasToScreen(_schemeToCanvasSpace(deleteCanvasPt, selectedAction.targetSchemePath));

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
        DrawAction? selectedAction;
        try {
          selectedAction = state.history.firstWhere((a) => a.id == _selectedActionId);
        } catch (_) {}

        if (selectedAction != null) {
          final originalBounds = CanvasPainter.getOriginalActionBounds(selectedAction);
          const double threshold = 32.0; // экранные пиксели — не зависит от зума

          final scaleY = selectedAction.scaleY.abs() == 0 ? 1.0 : selectedAction.scaleY.abs();
          final rotationLocalPt = Offset(originalBounds.center.dx, originalBounds.top - (30.0 / scaleY));
          final rotationCanvasPt = _schemeToCanvasSpace(CanvasPainter.getTransformedActionPoint(selectedAction, rotationLocalPt), selectedAction.targetSchemePath);
          final rotationScreenPt = _canvasToScreen(rotationCanvasPt);

          String? hitHandle;

          if ((event.localPosition - rotationScreenPt).distance < threshold) {
            hitHandle = 'rotation';
          } else {
            final cornersLocal = <String, Offset>{
              'topLeft': originalBounds.topLeft,
              'topRight': originalBounds.topRight,
              'bottomLeft': originalBounds.bottomLeft,
              'bottomRight': originalBounds.bottomRight,
            };
            for (final entry in cornersLocal.entries) {
              final canvasPt = _schemeToCanvasSpace(CanvasPainter.getTransformedActionPoint(selectedAction, entry.value), selectedAction.targetSchemePath);
              final screenPt = _canvasToScreen(canvasPt);
              if ((event.localPosition - screenPt).distance < threshold) {
                hitHandle = entry.key;
                break;
              }
            }
          }

          if (hitHandle != null) {
            setState(() {
              _draggedHandle = hitHandle;
              _dragStartPoint = localPosition;
              _originalActionForDrag = selectedAction;
              _activeAction = selectedAction;
            });

            // Инициализируем данные для Paint-like resize (не нужно для rotation-handle)
            if (hitHandle != 'rotation') {
              final action = selectedAction!;
              final origBounds = CanvasPainter.getOriginalActionBounds(action);

              // Определяем захваченный и anchor углы в LOCAL пространстве
              final Offset draggedLocal;
              final Offset anchorLocal;
              switch (hitHandle) {
                case 'topLeft':
                  draggedLocal = origBounds.topLeft;
                  anchorLocal = origBounds.bottomRight;
                case 'topRight':
                  draggedLocal = origBounds.topRight;
                  anchorLocal = origBounds.bottomLeft;
                case 'bottomLeft':
                  draggedLocal = origBounds.bottomLeft;
                  anchorLocal = origBounds.topRight;
                default: // bottomRight
                  draggedLocal = origBounds.bottomRight;
                  anchorLocal = origBounds.topLeft;
              }

              // Вычисляем угол вращения и центр вращения
              double rotation = 0.0;
              Offset rotCenter = origBounds.center;
              if (action is ShapeAction) {
                rotation = action.rotation;
                rotCenter = Rect.fromPoints(action.startPoint, action.endPoint).center;
              } else if (action is StampAction) {
                rotation = action.rotation;
                rotCenter = action.position;
              }

              // Вспомогательная функция вращения точки вокруг центра
              Offset rotatePoint(Offset p, Offset center, double angle) {
                if (angle == 0.0) return p;
                final dx = p.dx - center.dx;
                final dy = p.dy - center.dy;
                final c = math.cos(angle);
                final s = math.sin(angle);
                return Offset(center.dx + dx * c - dy * s, center.dy + dx * s + dy * c);
              }

              // A и B — "пред-scale" позиции (после вращения, до scale+offset)
              final a = rotatePoint(draggedLocal, rotCenter, rotation);
              final b = rotatePoint(anchorLocal, rotCenter, rotation);

              // Anchor в canvas-пространстве (без cellOffset)
              final sx = action.scaleX == 0 ? 1.0 : action.scaleX;
              final sy = action.scaleY == 0 ? 1.0 : action.scaleY;
              final anchorCv = Offset(b.dx * sx + action.offsetX, b.dy * sy + action.offsetY);

              setState(() {
                _rotatedDraggedCorner = a;
                _rotatedAnchorCorner = b;
                _anchorCanvas = anchorCv;
              });
            }
            return;
          }
        }
      }

      // 2. Иначе ищем новый объект для выделения/перемещения
      DrawAction? hitAction;
      double minHitDistance = double.infinity;
      for (final action in state.history.reversed) {
        if (action.targetSchemePath != null && !state.backgroundPaths.contains(action.targetSchemePath)) {
          continue; // Игнорируем действия от выключенных схем
        }
        final localObjPos = _canvasToObjectSpace(rawCanvasPt, action);
        final dist = _getDistanceToAction(localObjPos, action);
        final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
        final screenDist = dist * avgScale;
        final threshold = 20.0 + (action.strokeWidth / 2);
        if (screenDist < threshold && screenDist < minHitDistance) {
          hitAction = action;
          minHitDistance = screenDist;
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
          _dragStartPoint = _getSchemeLocalPosition(rawCanvasPt, hitAction.targetSchemePath);
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
      setState(() {
        _initialHistoryBeforeErase = List<DrawAction>.from(state.history);
        _hasErasedAnything = false;
        _eraserCursorPosition = event.localPosition;
        _currentPoints = [rawCanvasPt];
      });
      _eraseAtPoint(rawCanvasPt, state.currentStrokeWidth / 2);
      return;
    }

    final double pressure = event.pressure;
    _activeStrokeWidth =
        state.currentStrokeWidth * (pressure > 0.0 ? (0.5 + pressure) : 1.0);
    final double strokeWidth = _activeStrokeWidth!;

    setState(() {
      if (state.currentTool == ToolType.pencil ||
          state.currentTool == ToolType.adhesions ||
          state.currentTool == ToolType.fibrosis) {
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
                  : 'pencil',
          isDashed: state.currentTool == ToolType.pencil ? state.currentLineDashed : false,
          targetSchemePath: targetPath,
        );
      } else if (state.currentTool == ToolType.endometrioma ||
          state.currentTool == ToolType.myoma ||
          state.currentTool == ToolType.infiltrate ||
          state.currentTool == ToolType.bowelInfiltrate ||
          state.currentTool == ToolType.adenomyosis ||
          state.currentTool == ToolType.gui) {
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
                      : state.currentTool == ToolType.bowelInfiltrate
                          ? 'bowelInfiltrate'
                          : state.currentTool == ToolType.gui
                              ? 'gui'
                              : 'adenomyosis',
          figoType: state.currentTool == ToolType.myoma ? state.currentFigoType : null,
          targetSchemePath: targetPath,
        );
      } else if (state.currentTool == ToolType.iud ||
          state.currentTool == ToolType.foci ||
          state.currentTool == ToolType.customStamp ||
          state.currentTool == ToolType.follicle ||
          state.currentTool == ToolType.polyp) {
        // Штампы срабатывают мгновенно при нажатии
        if (state.currentTool == ToolType.customStamp && state.customStampPath == null) {
          return;
        }
        final stampAction = StampAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          position: localPosition,
          stampType: state.currentTool == ToolType.customStamp
              ? 'custom'
              : state.currentTool == ToolType.iud
                  ? 'iud'
                  : state.currentTool == ToolType.foci
                      ? 'foci'
                      : state.currentTool == ToolType.follicle
                          ? 'follicle'
                          : 'polyp',
          customStampPath: state.currentTool == ToolType.customStamp ? state.customStampPath : null,
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
      setState(() {
        _eraserCursorPosition = event.localPosition;
        _currentPoints.add(rawCanvasPt);
      });
      _eraseAtPoint(rawCanvasPt, state.currentStrokeWidth / 2);
      return;
    }

    if (_activeAction == null) return;

    if (state.currentTool == ToolType.move) {
      if (_selectedActionId != null && _originalActionForDrag != null && _dragStartPoint != null) {
        final offset = localPosition - _dragStartPoint!;
        setState(() {
          if (_draggedHandle != null) {
            // Текущие rendered-bounds (с учётом всех трансформаций) — нужны только для вращения
            final currentBounds = CanvasPainter.getActionBounds(_originalActionForDrag!);

            if (_draggedHandle == 'rotation') {
              final center = currentBounds.center;
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
                );
              }
            } else {
              // Paint-like resize: используем предвычисленные A, B, anchorCanvas из _onPointerDown.
              //
              // Прямое преобразование: canvas = rotate(local, rotCenter, angle) * scale + offset
              // Угол вращения фиксирован. Нужно найти новые scaleX, scaleY, offsetX, offsetY.
              //
              // Система уравнений (cursor следует захваченному углу, anchor неподвижен):
              //   cursor  = A * (newScaleX, newScaleY) + (newOffsetX, newOffsetY)
              //   anchor  = B * (newScaleX, newScaleY) + (newOffsetX, newOffsetY)
              // Откуда: newScaleX = (cursor.dx - anchor.dx) / (A.dx - B.dx)
              //         newScaleY = (cursor.dy - anchor.dy) / (A.dy - B.dy)
              //         newOffsetX = anchor.dx - B.dx * newScaleX
              //         newOffsetY = anchor.dy - B.dy * newScaleY
              if (_rotatedDraggedCorner != null && _rotatedAnchorCorner != null && _anchorCanvas != null) {
                final action = _originalActionForDrag!;
                final a = _rotatedDraggedCorner!;
                final b = _rotatedAnchorCorner!;
                final anchor = _anchorCanvas!;

                // cursorCanvas = localPosition (cell offset уже вычтен одинаково с anchorCanvas)
                final cursor = localPosition;

                const double minScale = 0.05;
                const double eps = 1e-6;

                // newScaleX
                final double denomX = a.dx - b.dx;
                double newScaleX = denomX.abs() < eps
                    ? (action.scaleX == 0 ? 1.0 : action.scaleX) // ось вырождена — сохраняем текущий scale
                    : (cursor.dx - anchor.dx) / denomX;
                newScaleX = newScaleX.clamp(minScale, double.infinity);

                // newScaleY
                final double denomY = a.dy - b.dy;
                double newScaleY = denomY.abs() < eps
                    ? (action.scaleY == 0 ? 1.0 : action.scaleY)
                    : (cursor.dy - anchor.dy) / denomY;
                newScaleY = newScaleY.clamp(minScale, double.infinity);

                // Для кругов (endometrioma, myoma) — пропорциональный scale
                if (action is ShapeAction &&
                    (action.shapeType == 'endometrioma' || action.shapeType == 'myoma')) {
                  final avg = (newScaleX + newScaleY) / 2;
                  newScaleX = avg;
                  newScaleY = avg;
                }

                // Offset так, чтобы anchor остался неподвижным
                final double newOffsetX = anchor.dx - b.dx * newScaleX;
                final double newOffsetY = anchor.dy - b.dy * newScaleY;

                _activeAction = _applyScaleAndOffset(action, newScaleX, newScaleY, newOffsetX, newOffsetY);
              }
            }
          } else {
            _activeAction = _offsetAction(_originalActionForDrag!, offset);
          }
        });
      }
      return;
    }

    setState(() {
      // Fix #15: используем толщину, зафиксированную в onPointerDown
      final double strokeWidth = _activeStrokeWidth ?? state.currentStrokeWidth;

      if (_activeAction is StrokeAction) {
        _currentPoints.add(localPosition);
        _activeAction = StrokeAction(
          id: _activeAction!.id,
          color: _activeAction!.color,
          strokeWidth: strokeWidth,
          points: List<Offset>.from(_currentPoints),
          isEraser: false,
          brushType: (_activeAction as StrokeAction).brushType,
          isDashed: (_activeAction as StrokeAction).isDashed,
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
    });
  }

  void _onPointerUp(PointerUpEvent event) {
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _isZooming = false;
    }

    if (event.kind == ui.PointerDeviceKind.touch) {
      if (_isStylusActive || (_lastStylusTime != null && DateTime.now().difference(_lastStylusTime!).inMilliseconds < 300)) {
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
      if (_hasErasedAnything) {
        context.read<DrawBloc>().add(SaveUndoStateEvent(_initialHistoryBeforeErase));
      }
      setState(() {
        _initialHistoryBeforeErase = [];
        _hasErasedAnything = false;
        _eraserCursorPosition = event.localPosition;
        _currentPoints = [];
      });
      return;
    }

    if (_activeAction == null) return;

    if (state.currentTool == ToolType.move) {
      if (_selectedActionId != null && _activeAction != null) {
        context.read<DrawBloc>().add(UpdateActionEvent(_activeAction!));
        setState(() {
          // Fix #7: сохраняем финальное состояние как новую «оригинальную» точку отсчёта,
          // чтобы следующий захват маркера не давал прыжка.
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
          final defaultW = shape.shapeType == 'gui'
              ? 60.0
              : (shape.shapeType == 'infiltrate' || shape.shapeType == 'bowelInfiltrate'
                  ? 80.0
                  : 40.0);
          final defaultH = shape.shapeType == 'gui'
              ? 36.0
              : (shape.shapeType == 'infiltrate' || shape.shapeType == 'bowelInfiltrate'
                  ? 50.0
                  : 40.0);
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
              hintText: 'Введите расстояние (например, 15 мм) или примечание...',
            ),
            onChanged: (value) => text = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null), // Нажата Отмена
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(text), // Нажато Добавить (может быть пустым)
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
    if (drawState.currentTool == ToolType.move && _selectedActionId != null && _activePointers.length >= 2) {
      try {
        final action = drawState.history.firstWhere((a) => a.id == _selectedActionId);
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
    if (_originalActionForDrag is ShapeAction && _activeAction != null && (_activeAction as ShapeAction).rotation != _dragStartRotation) {
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

    final bool isCtrl = HardwareKeyboard.instance.isControlPressed;
    final bool isShift = HardwareKeyboard.instance.isShiftPressed;

    setState(() {
      if (isCtrl) {
        // Зум в точку под курсором (аналог pinch-to-zoom для мыши)
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
        _offset = _offset + Offset(
          -event.scrollDelta.dx * 1.5,
          -event.scrollDelta.dy * 1.5,
        );
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
      case ToolType.arrow:
        return SystemMouseCursors.precise;
      case ToolType.endometrioma:
      case ToolType.myoma:
      case ToolType.infiltrate:
      case ToolType.bowelInfiltrate:
        return SystemMouseCursors.precise;
      case ToolType.iud:
      case ToolType.foci:
      case ToolType.customStamp:
      case ToolType.gui:
      case ToolType.follicle:
      case ToolType.adenomyosis:
      case ToolType.polyp:
        return SystemMouseCursors.click;
    }
  }

  // ──────────────────────────────────────────────
  // Оверлей курсора ластика (круг в экранных координатах)
  // ──────────────────────────────────────────────

  Widget _buildEraserCursor(DrawState state) {
    // Радиус круга масштабируется вместе с холстом, но ограничен разумными рамками
    final double radius = (state.currentStrokeWidth / 2 * _scale).clamp(4.0, 120.0);
    final center = _eraserCursorPosition!;
    return Positioned(
      left: center.dx - radius,
      top: center.dy - radius,
      child: IgnorePointer(
        child: Container(
          width: radius * 2,
          height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.black54,
              width: 1.5,
            ),
          ),
          foregroundDecoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white70,
              width: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}
