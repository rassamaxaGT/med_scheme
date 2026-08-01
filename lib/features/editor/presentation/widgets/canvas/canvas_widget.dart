import '../../../../../core/utils/image_loader.dart';
import 'dart:ui' as ui;
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
  String? _draggedHandle; // 'topLeft', 'topRight', 'bottomLeft', 'bottomRight' или null

  // Последняя выбранная кисть для рисования
  ToolType _lastSelectedBrush = ToolType.pencil;
  bool _isAutoSwitchedToMove = false;

  // Динамически загруженное фоновое изображение из BLoC
  ui.Image? _loadedBackgroundImage;
  String? _loadedBackgroundPath;

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

        // Загрузка фонового изображения, если его путь изменился
        if (state.backgroundPath != _loadedBackgroundPath) {
          _loadedBackgroundPath = state.backgroundPath;
          Future.microtask(() => _loadBackground(state.backgroundPath));
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
            onPointerDown: (event) => _onPointerDown(event, state),
            onPointerMove: (event) => _onPointerMove(event, state),
            onPointerUp: (event) => _onPointerUp(event, state),
            onPointerCancel: (event) {
              _activePointers.remove(event.pointer);
              if (_activePointers.length < 2) {
                _isZooming = false;
              }
              if (state.currentTool == ToolType.eraser) {
                setState(() {
                  _initialHistoryBeforeErase = [];
                  _hasErasedAnything = false;
                  _eraserCursorPosition = null;
                  _currentPoints = [];
                });
              }
            },
            onPointerSignal: _onPointerSignal,
            child: MouseRegion(
              cursor: _getCursorForTool(state),
              onHover: (event) {
                if (state.currentTool == ToolType.eraser && mounted) {
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

    final bounds = CanvasPainter.getActionBounds(selected);
    if (bounds == Rect.zero) return const SizedBox.shrink();

    // Переводим bounds холста в экранные координаты с учётом Zoom/Pan
    final screenLeft = bounds.left * _scale + _offset.dx;
    final screenTop = bounds.top * _scale + _offset.dy;
    final screenRight = bounds.right * _scale + _offset.dx;
    final buttonX = (screenLeft + screenRight) / 2 - 20; // по центру по X
    final buttonY = screenTop - 44.0; // чуть выше рамки

    return Positioned(
      left: buttonX,
      top: buttonY.clamp(4.0, double.infinity),
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
      double minDistance = double.infinity;
      for (final strokePoint in action.points) {
        final dist = (p - strokePoint).distance;
        if (dist < minDistance) {
          minDistance = dist;
        }
      }
      return minDistance;
    } else if (action is ShapeAction) {
      final rect = Rect.fromPoints(action.startPoint, action.endPoint);
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
      final center = rect.center;
      final distToCenter = (p - center).distance;
      if (distToCenter < minDistance) {
        minDistance = distToCenter;
      }
      return minDistance;
    } else if (action is TextAction) {
      return _getDistanceToSegment(p, action.startPoint, action.endPoint);
    } else if (action is StampAction) {
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
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
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
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
      );
    } else if (original is StampAction) {
      return StampAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        position: original.position,
        stampType: original.stampType,
        customStampPath: original.customStampPath,
        scaleX: original.scaleX,
        scaleY: original.scaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
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
      );
    }
    return original;
  }


  // Метод перевода точки из canvas-координат в локальную систему координат объекта.
  // Обратная операция к: rendered_p = p * scale + offset
  // Поэтому: object_p = (canvas_p - offset) / scale
  Offset _canvasToObjectSpace(Offset p, DrawAction action) {
    final double scaleX = action.scaleX == 0 ? 1.0 : action.scaleX;
    final double scaleY = action.scaleY == 0 ? 1.0 : action.scaleY;

    return Offset(
      (p.dx - action.offsetX) / scaleX,
      (p.dy - action.offsetY) / scaleY,
    );
  }

  // Метод изменения размера объекта (обновляем scaleX/scaleY и offsetX/offsetY)
  DrawAction _resizeAction(DrawAction original, Rect oldRect, Rect newRect) {
    final originalBounds = CanvasPainter.getOriginalActionBounds(original);
    if (originalBounds.width == 0 || originalBounds.height == 0) return original;

    final newScaleX = newRect.width / originalBounds.width;
    final newScaleY = newRect.height / originalBounds.height;

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
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
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
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
      );
    } else if (original is StampAction) {
      return StampAction(
        id: original.id,
        color: original.color,
        strokeWidth: original.strokeWidth,
        position: original.position,
        stampType: original.stampType,
        customStampPath: original.customStampPath,
        scaleX: newScaleX,
        scaleY: newScaleY,
        offsetX: newOffsetX,
        offsetY: newOffsetY,
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
      );
    }
    return original;
  }

  // Преобразование глобальных экранных координат в координаты холста с учетом Zoom/Pan
  Offset _screenToCanvas(Offset screenOffset) {
    return (screenOffset - _offset) / _scale;
  }

  void _eraseAtPoint(Offset canvasPoint, double eraserRadius, DrawState state) {
    // Fix #6: throttle — не чаще одного раза за кадр (16 мс), иначе BLoC
    // получает сотни событий в секунду и провоцирует подтормаживания.
    final now = DateTime.now();
    if (_lastEraseTime != null &&
        now.difference(_lastEraseTime!).inMilliseconds < 16) {
      return;
    }
    _lastEraseTime = now;

    final List<DrawAction> updatedHistory = List<DrawAction>.from(state.history);
    bool historyChanged = false;

    for (int i = updatedHistory.length - 1; i >= 0; i--) {
      final action = updatedHistory[i];
      final localObjPos = _canvasToObjectSpace(canvasPoint, action);
      
      final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
      final double effectiveRadius = eraserRadius / (avgScale <= 0 ? 1.0 : avgScale);

      if (action is StrokeAction) {
        // Проверяем, близко ли ластик к линии
        final dist = _getDistanceToAction(localObjPos, action);
        if (dist < effectiveRadius + (action.strokeWidth / 2)) {
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
                  id: '${action.id}_${segmentPoints.hashCode}',
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

  void _onPointerDown(PointerDownEvent event, DrawState state) {
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

    final localPosition = _screenToCanvas(event.localPosition);
    final id = _generateId();

    // Проверяем, не кликнули ли мы по кнопке удаления выделенного объекта
    if (state.currentTool == ToolType.move && _selectedActionId != null) {
      DrawAction? selectedAction;
      try {
        selectedAction = state.history.firstWhere((a) => a.id == _selectedActionId);
      } catch (_) {}
      if (selectedAction != null) {
        final bounds = CanvasPainter.getActionBounds(selectedAction);
        if (bounds != Rect.zero) {
          final screenLeft = bounds.left * _scale + _offset.dx;
          final screenTop = bounds.top * _scale + _offset.dy;
          final screenRight = bounds.right * _scale + _offset.dx;
          final buttonY = (screenTop - 44.0).clamp(4.0, double.infinity);
          final buttonX = (screenLeft + screenRight) / 2 - 20;
          final buttonCenter = Offset(buttonX + 20, buttonY + 20);
          if ((event.localPosition - buttonCenter).distance < 25.0) {
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
          final bounds = CanvasPainter.getActionBounds(selectedAction);
          final threshold = 15.0; // зона чувствительности клика по маркеру

          final corners = {
            'topLeft': bounds.topLeft,
            'topRight': bounds.topRight,
            'bottomLeft': bounds.bottomLeft,
            'bottomRight': bounds.bottomRight,
          };

          String? hitHandle;
          for (final entry in corners.entries) {
            if ((localPosition - entry.value).distance < threshold) {
              hitHandle = entry.key;
              break;
            }
          }

          if (hitHandle != null) {
            setState(() {
              _draggedHandle = hitHandle;
              _dragStartPoint = localPosition;
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
        final localObjPos = _canvasToObjectSpace(localPosition, action);
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
        if (hitAction != null) {
          _selectedActionId = hitAction.id;
          widget.selectedActionIdNotifier?.value = hitAction.id;
          _dragStartPoint = localPosition;
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
        _currentPoints = [localPosition];
      });
      _eraseAtPoint(localPosition, state.currentStrokeWidth / 2, state);
      return;
    }

    // Fix #15: фиксируем толщину линии ОДИН РАЗ при нажатии.
    // Пересчёт в каждом onPointerMove приводил к прыжкам ширины
    // (финальная толщина штриха определялась последним событием Move).
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
        );
      } else if (state.currentTool == ToolType.endometrioma ||
          state.currentTool == ToolType.myoma ||
          state.currentTool == ToolType.infiltrate) {
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
                  : 'infiltrate',
          figoType: state.currentTool == ToolType.myoma ? state.currentFigoType : null,
        );
      } else if (state.currentTool == ToolType.iud ||
          state.currentTool == ToolType.foci ||
          state.currentTool == ToolType.customStamp) {
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
              : (state.currentTool == ToolType.iud ? 'iud' : 'foci'),
          customStampPath: state.currentTool == ToolType.customStamp ? state.customStampPath : null,
        );
        context.read<DrawBloc>().add(AddActionEvent(stampAction));

        // Просто завершаем рисование
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
        );
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event, DrawState state) {
    if (event.kind == ui.PointerDeviceKind.touch && _isStylusActive) {
      return; // Игнорируем касание ладонью при активном стилусе
    }
    if (_isZooming) return;

    final localPosition = _screenToCanvas(event.localPosition);

    // Ластик: отслеживаем точки и позицию курсора
    if (state.currentTool == ToolType.eraser) {
      setState(() {
        _eraserCursorPosition = event.localPosition;
        _currentPoints.add(localPosition);
      });
      _eraseAtPoint(localPosition, state.currentStrokeWidth / 2, state);
      return;
    }

    if (_activeAction == null) return;

    if (state.currentTool == ToolType.move) {
      if (_selectedActionId != null && _originalActionForDrag != null && _dragStartPoint != null) {
        final offset = localPosition - _dragStartPoint!;
        setState(() {
          if (_draggedHandle != null) {
            // Используем оригинальные bounds объекта (до начала изменения размера)
            final originalUnscaled = CanvasPainter.getOriginalActionBounds(_originalActionForDrag!);
            // Текущие rendered-bounds (с учётом всех трансформаций)
            final currentBounds = CanvasPainter.getActionBounds(_originalActionForDrag!);
            double left = currentBounds.left;
            double top = currentBounds.top;
            double right = currentBounds.right;
            double bottom = currentBounds.bottom;

            if (_draggedHandle == 'topLeft') {
              left = currentBounds.left + offset.dx;
              top = currentBounds.top + offset.dy;
            } else if (_draggedHandle == 'topRight') {
              right = currentBounds.right + offset.dx;
              top = currentBounds.top + offset.dy;
            } else if (_draggedHandle == 'bottomLeft') {
              left = currentBounds.left + offset.dx;
              bottom = currentBounds.bottom + offset.dy;
            } else if (_draggedHandle == 'bottomRight') {
              right = currentBounds.right + offset.dx;
              bottom = currentBounds.bottom + offset.dy;
            }
            final newRect = Rect.fromLTRB(left, top, right, bottom);
            _activeAction = _resizeAction(_originalActionForDrag!, originalUnscaled, newRect);
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
        );
      }
    });
  }

  void _onPointerUp(PointerUpEvent event, DrawState state) {
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
        });
      }
      return;
    }

    if (_activeAction is TextAction) {
      final drawBloc = context.read<DrawBloc>();
      _showTextDialog(context).then((text) {
        if (text != null && text.isNotEmpty) {
          final oldTextAction = _activeAction as TextAction;
          final finalAction = TextAction(
            id: oldTextAction.id,
            color: oldTextAction.color,
            strokeWidth: oldTextAction.strokeWidth,
            startPoint: oldTextAction.startPoint,
            endPoint: oldTextAction.endPoint,
            text: text,
            isDashed: oldTextAction.isDashed,
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
      final finalAction = _activeAction!;
      context.read<DrawBloc>().add(AddActionEvent(finalAction));

      setState(() {
        _activeAction = null;
        _currentPoints = [];
        _activeStrokeWidth = null; // Fix #15: сбросить зафиксированную толщину
      });
    }
  }

  // Диалог ввода текста для стрелки
  Future<String?> _showTextDialog(BuildContext context) async {
    String text = '';
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('Добавить примечание к стрелке'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Введите текст патологии...'),
            onChanged: (value) => text = value,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(''),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(text),
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
    if (_activeAction != null || drawState.currentTool == ToolType.eraser) return;
    setState(() {
      _isZooming = true;
      _previousScale = _scale;
      _normalizedFocalPoint = (details.localFocalPoint - _offset) / _scale;
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isZooming) return;
    setState(() {
      _scale = (_previousScale * details.scale).clamp(0.2, 8.0);
      _offset = details.localFocalPoint - _normalizedFocalPoint * _scale;
      widget.scaleNotifier?.value = _scale;
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
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
        return SystemMouseCursors.precise;
      case ToolType.iud:
      case ToolType.foci:
      case ToolType.customStamp:
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
