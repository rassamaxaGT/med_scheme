import '../../../../../core/utils/image_loader.dart';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/entities/draw_action.dart';
import '../../bloc/draw_bloc.dart';
import '../../bloc/draw_event.dart';
import '../../bloc/draw_state.dart';
import 'canvas_painter.dart';

class CanvasWidget extends StatefulWidget {
  final ui.Image? backgroundImage;

  const CanvasWidget({
    super.key,
    this.backgroundImage,
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

  // Переменные для зума и панорамирования (Zoom & Pan)
  double _scale = 1.0;
  double _previousScale = 1.0;
  Offset _offset = Offset.zero;
  Offset _normalizedFocalPoint = Offset.zero;

  // Флаги управления режимами ввода
  bool _isStylusActive = false;
  bool _isZooming = false;

  // Активные указатели для отслеживания мультитача
  final Set<int> _activePointers = {};
  ToolType? _lastTool;

  // Генератор уникальных ID для действий
  String _generateId() => DateTime.now().millisecondsSinceEpoch.toString();

  @override
  void didUpdateWidget(covariant CanvasWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    debugPrint('[CanvasLifecycle] didUpdateWidget called. Clearing pointers. Current scale=$_scale, offset=$_offset');
    _activePointers.clear();
    _isZooming = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DrawBloc, DrawState>(
      builder: (context, state) {
        if (state.currentTool != _lastTool) {
          debugPrint('[CanvasLifecycle] tool changed from $_lastTool to ${state.currentTool}. Clearing pointers. Current scale=$_scale, offset=$_offset');
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

        return ClipRect(
          child: Listener(
            // Listener используется для низкоуровневой обработки касаний и стилуса (силы нажатия)
            onPointerDown: (event) => _onPointerDown(event, state),
            onPointerMove: (event) => _onPointerMove(event, state),
            onPointerUp: (event) => _onPointerUp(event, state),
            onPointerCancel: (event) {
              _activePointers.remove(event.pointer);
              if (_activePointers.length < 2) {
                _isZooming = false;
              }
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
                        activeAction: _activeAction,
                        backgroundImage: widget.backgroundImage ?? _loadedBackgroundImage,
                        selectedActionId: _selectedActionId,
                      ),
                    ),
                  ),
                  // Кнопка удаления выделенного объекта
                  if (state.currentTool == ToolType.move && _selectedActionId != null)
                    _buildDeleteButton(context, state),
                ],
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
    } else if (action is StampAction) {
      return (p - action.position).distance;
    } else if (action is TextAction) {
      return _getDistanceToSegment(p, action.startPoint, action.endPoint);
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

  void _onPointerDown(PointerDownEvent event, DrawState state) {
    debugPrint('[CanvasPointer] _onPointerDown: id=${event.pointer}, position=${event.localPosition}, tool=${state.currentTool}');
    // Palm Rejection: Если рисуем стилусом, игнорируем любые касания пальцами (touch)
    if (event.kind == ui.PointerDeviceKind.stylus) {
      _isStylusActive = true;
    } else if (event.kind == ui.PointerDeviceKind.touch && _isStylusActive) {
      // Игнорируем касание ладонью
      debugPrint('[CanvasPointer] _onPointerDown Palm Rejection active - ignoring finger');
      return;
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
          _dragStartPoint = localPosition;
          _originalActionForDrag = hitAction;
          _activeAction = hitAction;
        } else {
          // Кликнули в стороне! Снимаем выделение
          _selectedActionId = null;
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

    // Вычисляем толщину линии с учетом давления стилуса (если оно доступно)
    final double pressure = event.pressure; // Значение от 0.0 до 1.0
    final double strokeWidth = state.currentStrokeWidth * (pressure > 0.0 ? (0.5 + pressure) : 1.0);

    setState(() {
      if (state.currentTool == ToolType.eraser) {
        // Ластик: рисуем визуальный след
        _currentPoints = [localPosition];
        _activeAction = StrokeAction(
          id: id,
          color: Colors.red.withValues(alpha: 0.3),
          strokeWidth: state.currentStrokeWidth,
          points: _currentPoints,
          isEraser: false,
          brushType: 'pencil',
        );
      } else if (state.currentTool == ToolType.pencil ||
          state.currentTool == ToolType.infiltrate ||
          state.currentTool == ToolType.adhesions) {
        // Инициализируем линию (штрих)
        _currentPoints = [localPosition];
        _activeAction = StrokeAction(
          id: id,
          color: state.currentColor,
          strokeWidth: strokeWidth,
          points: _currentPoints,
          isEraser: false,
          brushType: state.currentTool == ToolType.infiltrate
              ? 'infiltrate'
              : state.currentTool == ToolType.adhesions
                  ? 'adhesions'
                  : 'pencil',
        );
      } else if (state.currentTool == ToolType.endometrioma ||
          state.currentTool == ToolType.myoma) {
        // Овал (фигуры)
        _activeAction = ShapeAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          startPoint: localPosition,
          endPoint: localPosition,
          shapeType: state.currentTool == ToolType.endometrioma ? 'endometrioma' : 'myoma',
        );
      } else if (state.currentTool == ToolType.iud ||
          state.currentTool == ToolType.foci) {
        // Штампы срабатывают мгновенно при нажатии
        final stampAction = StampAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          position: localPosition,
          stampType: state.currentTool == ToolType.iud ? 'iud' : 'foci',
        );
        context.read<DrawBloc>().add(AddActionEvent(stampAction));

        // Сразу выделяем и переключаемся в режим перемещения
        setState(() {
          _selectedActionId = stampAction.id;
          _activeAction = null;
          _isAutoSwitchedToMove = true;
        });
        context.read<DrawBloc>().add(SelectToolEvent(ToolType.move));
      } else if (state.currentTool == ToolType.arrow) {
        // Инициализируем стрелку
        _activeAction = TextAction(
          id: id,
          color: state.currentColor,
          strokeWidth: state.currentStrokeWidth,
          startPoint: localPosition,
          endPoint: localPosition,
          text: '',
        );
      }
    });
  }

  void _onPointerMove(PointerMoveEvent event, DrawState state) {
    if (event.kind == ui.PointerDeviceKind.touch && _isStylusActive) {
      return; // Игнорируем касание ладонью при активном стилусе
    }
    if (_isZooming || _activeAction == null) return;

    final localPosition = _screenToCanvas(event.localPosition);

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
      final double pressure = event.pressure;
      final double strokeWidth = state.currentStrokeWidth * (pressure > 0.0 ? (0.5 + pressure) : 1.0);

      if (_activeAction is StrokeAction) {
        _currentPoints.add(localPosition);
        if (state.currentTool == ToolType.eraser) {
          _activeAction = StrokeAction(
            id: _activeAction!.id,
            color: Colors.red.withValues(alpha: 0.3),
            strokeWidth: state.currentStrokeWidth,
            points: List<Offset>.from(_currentPoints),
            isEraser: false,
            brushType: 'pencil',
          );
        } else {
          _activeAction = StrokeAction(
            id: _activeAction!.id,
            color: _activeAction!.color,
            strokeWidth: strokeWidth,
            points: List<Offset>.from(_currentPoints),
            isEraser: false,
            brushType: (_activeAction as StrokeAction).brushType,
          );
        }
      } else if (_activeAction is ShapeAction) {
        final shape = _activeAction as ShapeAction;
        _activeAction = ShapeAction(
          id: shape.id,
          color: shape.color,
          strokeWidth: shape.strokeWidth,
          startPoint: shape.startPoint,
          endPoint: localPosition,
          shapeType: shape.shapeType,
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
        );
      }
    });
  }

  void _onPointerUp(PointerUpEvent event, DrawState state) {
    debugPrint('[CanvasPointer] _onPointerUp: id=${event.pointer}, position=${event.localPosition}, activePointersCount=${_activePointers.length}');
    _activePointers.remove(event.pointer);
    if (_activePointers.length < 2) {
      _isZooming = false;
    }

    if (event.kind == ui.PointerDeviceKind.touch && _isStylusActive) {
      return; // Игнорируем ладонь
    }
    if (event.kind == ui.PointerDeviceKind.stylus) {
      _isStylusActive = false; // Отпустили стилус
    }
    if (_isZooming || _activeAction == null) {
      debugPrint('[CanvasPointer] _onPointerUp early return: _isZooming=$_isZooming, _activeActionIsNull=${_activeAction == null}');
      return;
    }

    if (state.currentTool == ToolType.move) {
      if (_selectedActionId != null && _activeAction != null) {
        context.read<DrawBloc>().add(UpdateActionEvent(_activeAction!));
        setState(() {
          _activeAction = null;
          _originalActionForDrag = null;
          _draggedHandle = null;
        });
      }
      return;
    }

    if (state.currentTool == ToolType.eraser) {
      _applyEraser(state);
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
          );
          drawBloc.add(AddActionEvent(finalAction));

          // Сразу выделяем и переключаемся в режим перемещения
          setState(() {
            _selectedActionId = finalAction.id;
            _activeAction = null;
            _isAutoSwitchedToMove = true;
          });
          drawBloc.add(SelectToolEvent(ToolType.move));
        } else {
          setState(() {
            _activeAction = null;
          });
        }
      });
    } else {
      final finalAction = _activeAction!;
      context.read<DrawBloc>().add(AddActionEvent(finalAction));

      // Сразу выделяем и переключаемся в режим перемещения
      setState(() {
        _selectedActionId = finalAction.id;
        _activeAction = null;
        _currentPoints = [];
        _isAutoSwitchedToMove = true;
      });
      context.read<DrawBloc>().add(SelectToolEvent(ToolType.move));
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

  void _applyEraser(DrawState state) {
    if (_currentPoints.isEmpty) {
      setState(() {
        _activeAction = null;
        _currentPoints = [];
      });
      return;
    }

    final double eraserWidth = state.currentStrokeWidth;
    final double eraserRadius = eraserWidth / 2;
    final List<DrawAction> newHistory = [];
    bool historyChanged = false;

    for (final action in state.history) {
      if (action is StrokeAction) {
        // Проверяем, стерта ли какая-то точка штриха
        final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
        final double localR = eraserRadius / (avgScale == 0 ? 1.0 : avgScale);

        final localEraserPoints = _currentPoints.map((p) => _canvasToObjectSpace(p, action)).toList();

        List<List<Offset>> newSegments = [];
        List<Offset> currentSegment = [];

        for (final p in action.points) {
          final isErased = _isPointErasedByPath(p, localEraserPoints, localR);
          if (isErased) {
            if (currentSegment.isNotEmpty) {
              newSegments.add(currentSegment);
              currentSegment = [];
            }
          } else {
            currentSegment.add(p);
          }
        }

        if (currentSegment.isNotEmpty) {
          newSegments.add(currentSegment);
        }

        if (newSegments.length == 1 && newSegments.first.length == action.points.length) {
          // Ничего не изменилось
          newHistory.add(action);
        } else {
          historyChanged = true;
          // Добавляем все нестертые сегменты как новые отдельные StrokeAction
          int index = 0;
          for (final segment in newSegments) {
            if (segment.isNotEmpty) {
              newHistory.add(StrokeAction(
                id: '${action.id}_erased_${index++}_${DateTime.now().microsecondsSinceEpoch}',
                color: action.color,
                strokeWidth: action.strokeWidth,
                points: segment,
                isEraser: action.isEraser,
                brushType: action.brushType,
                scaleX: action.scaleX,
                scaleY: action.scaleY,
                offsetX: action.offsetX,
                offsetY: action.offsetY,
              ));
            }
          }
        }
      } else {
        // Для ShapeAction, StampAction, TextAction проверяем пересечение с траекторией ластика
        bool intersects = false;
        for (final ep in _currentPoints) {
          final localEp = _canvasToObjectSpace(ep, action);
          final dist = _getDistanceToAction(localEp, action);
          final double avgScale = (action.scaleX.abs() + action.scaleY.abs()) / 2;
          final screenDist = dist * avgScale;
          // Увеличим порог для удобства попадания ластиком по векторным фигурам
          final threshold = eraserRadius + (action.strokeWidth / 2) + 5.0;
          if (screenDist < threshold) {
            intersects = true;
            break;
          }
        }

        if (intersects) {
          historyChanged = true; // Стираем (удаляем) полностью
        } else {
          newHistory.add(action);
        }
      }
    }

    if (historyChanged) {
      context.read<DrawBloc>().add(SetHistoryEvent(newHistory));
    }

    setState(() {
      _activeAction = null;
      _currentPoints = [];
    });
  }

  bool _isPointErasedByPath(Offset p, List<Offset> eraserPoints, double localR) {
    if (eraserPoints.isEmpty) return false;
    if (eraserPoints.length == 1) {
      return (p - eraserPoints.first).distance <= localR;
    }
    for (int i = 0; i < eraserPoints.length - 1; i++) {
      if (_getDistanceToSegment(p, eraserPoints[i], eraserPoints[i + 1]) <= localR) {
        return true;
      }
    }
    return false;
  }

  // Обработка масштабирования холста
  void _onScaleStart(ScaleStartDetails details) {
    if (_activeAction != null) {
      debugPrint('[CanvasGesture] _onScaleStart ignored: _activeAction is not null');
      return;
    }
    setState(() {
      _isZooming = true;
      _previousScale = _scale;
      _normalizedFocalPoint = (details.localFocalPoint - _offset) / _scale;
      debugPrint('[CanvasGesture] _onScaleStart: focal=${details.localFocalPoint}, scale=$_scale, offset=$_offset, normalized=$_normalizedFocalPoint');
    });
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (!_isZooming) {
      debugPrint('[CanvasGesture] _onScaleUpdate ignored: _isZooming is false');
      return;
    }
    setState(() {
      _scale = (_previousScale * details.scale).clamp(0.5, 4.0);
      _offset = details.localFocalPoint - _normalizedFocalPoint * _scale;
      debugPrint('[CanvasGesture] _onScaleUpdate: scaleDet=${details.scale}, focal=${details.localFocalPoint}, scale=$_scale, offset=$_offset');
    });
  }

  void _onScaleEnd(ScaleEndDetails details) {
    setState(() {
      _isZooming = false;
      debugPrint('[CanvasGesture] _onScaleEnd: _isZooming reset to false. scale=$_scale, offset=$_offset');
    });
  }
}
