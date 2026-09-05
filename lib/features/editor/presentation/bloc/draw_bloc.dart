import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import '../../data/services/custom_stamps_service.dart';
import 'draw_event.dart';
import 'draw_state.dart';

/// Максимальная глубина стека Undo/Redo. Ограничивает потребление памяти.
const int _maxUndoSteps = 50;

/// Обрезает стек до последних [_maxUndoSteps] записей.
List<List<DrawAction>> _limited(List<List<DrawAction>> stack) {
  if (stack.length <= _maxUndoSteps) return stack;
  return stack.sublist(stack.length - _maxUndoSteps);
}

class DrawBloc extends Bloc<DrawEvent, DrawState> {
  CustomStampsService? _customStampsService;

  DrawBloc([CustomStampsService? customStampsService]) : super(DrawState.initial()) {
    _customStampsService = customStampsService;

    // ── Добавить действие ──────────────────────────────────────────────────
    on<AddActionEvent>((event, emit) {
      final updatedHistory = List<DrawAction>.from(state.history)..add(event.action);
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Обновить существующее действие (перемещение/ресайз) ───────────────
    on<UpdateActionEvent>((event, emit) {
      final updatedHistory = state.history.map((action) {
        return action.id == event.action.id ? event.action : action;
      }).toList();
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Установить фоновое изображение ────────────────────────────────────
    on<SetBackgroundEvent>((event, emit) {
      if (event.path == null) {
        emit(state.copyWith(clearBackground: true));
      } else {
        emit(state.copyWith(backgroundPaths: [event.path!]));
      }
    });

    on<ToggleSchemeEvent>((event, emit) {
      final currentPaths = List<String>.from(state.backgroundPaths);
      if (currentPaths.contains(event.schemePath)) {
        currentPaths.remove(event.schemePath);
      } else {
        currentPaths.add(event.schemePath);
      }
      emit(state.copyWith(backgroundPaths: currentPaths));
    });

    on<AddCustomSchemeEvent>((event, emit) {
      final updatedCustom = List<CustomSchemeItem>.from(state.customSchemes);
      final nextNumber = updatedCustom.length + 1;
      final title = event.customTitle ?? 'Своё изображение $nextNumber';
      final item = CustomSchemeItem(title: title, path: event.path);
      updatedCustom.add(item);

      final currentBgPaths = List<String>.from(state.backgroundPaths);
      if (!currentBgPaths.contains(event.path)) {
        currentBgPaths.add(event.path);
      }

      emit(state.copyWith(
        customSchemes: updatedCustom,
        backgroundPaths: currentBgPaths,
      ));
    });

    on<RemoveCustomSchemeEvent>((event, emit) {
      final updatedCustom = List<CustomSchemeItem>.from(state.customSchemes)
        ..removeWhere((item) => item.path == event.path);

      final currentBgPaths = List<String>.from(state.backgroundPaths)
        ..remove(event.path);

      emit(state.copyWith(
        customSchemes: updatedCustom,
        backgroundPaths: currentBgPaths,
      ));
    });

    on<SetBackgroundPathsEvent>((event, emit) {
      emit(state.copyWith(backgroundPaths: event.paths));
    });

    // ── Undo ──────────────────────────────────────────────────────────────
    on<UndoEvent>((event, emit) {
      if (state.undoStack.isEmpty) return;
      final updatedUndo = List<List<DrawAction>>.from(state.undoStack);
      final previousHistory = updatedUndo.removeLast();
      final updatedRedo = _limited(
        List<List<DrawAction>>.from(state.redoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: previousHistory,
        undoStack: updatedUndo,
        redoStack: updatedRedo,
      ));
    });

    // ── Redo ──────────────────────────────────────────────────────────────
    on<RedoEvent>((event, emit) {
      if (state.redoStack.isEmpty) return;
      final updatedRedo = List<List<DrawAction>>.from(state.redoStack);
      final nextHistory = updatedRedo.removeLast();
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: nextHistory,
        undoStack: updatedUndo,
        redoStack: updatedRedo,
      ));
    });

    // ── Очистить холст ────────────────────────────────────────────────────
    on<ClearCanvasEvent>((event, emit) {
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: [],
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    on<SelectToolEvent>((event, emit) {
      final defaultColor = _getColorForTool(event.tool, state.currentFigoType);
      double strokeWidth = state.currentStrokeWidth;
      if (event.tool == ToolType.eraser) {
        strokeWidth = 15.0;
      } else if (event.tool == ToolType.fibrosis) {
        strokeWidth = 3.0;
      } else if (event.tool == ToolType.adhesions) {
        strokeWidth = 2.0;
      } else if (event.tool == ToolType.arrow) {
        strokeWidth = 1.5;
      } else if (event.tool == ToolType.spray) {
        strokeWidth = 16.0;
      } else if (event.tool == ToolType.bowelInfiltrate ||
          event.tool == ToolType.infiltrateStamp2 ||
          event.tool == ToolType.myomaStamp ||
          event.tool == ToolType.iud ||
          event.tool == ToolType.iudStamp ||
          event.tool == ToolType.polyp ||
          event.tool == ToolType.customStamp) {
        strokeWidth = 3.0;
      } else if (event.tool == ToolType.foci ||
          event.tool == ToolType.follicle ||
          event.tool == ToolType.gui) {
        strokeWidth = 8.0;
      }
      emit(state.copyWith(
        currentTool: event.tool,
        currentColor: defaultColor ?? state.currentColor,
        currentStrokeWidth: strokeWidth,
      ));
    });

    on<ChangeColorEvent>((event, emit) {
      emit(state.copyWith(currentColor: event.color));
    });

    on<ChangeStrokeWidthEvent>((event, emit) {
      emit(state.copyWith(currentStrokeWidth: event.strokeWidth));
    });

    on<SetEraserTargetEvent>((event, emit) {
      emit(state.copyWith(eraserTarget: event.target));
    });

    // ── Удалить конкретное действие ───────────────────────────────────────
    on<DeleteActionEvent>((event, emit) {
      final updatedHistory =
          state.history.where((a) => a.id != event.actionId).toList();
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(state.history),
      );
      emit(state.copyWith(
        history: updatedHistory,
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Загрузить историю из проекта (Fix #2) ─────────────────────────────
    on<SetHistoryEvent>((event, emit) {
      emit(state.copyWith(
        history: event.history,
        undoStack: [],
        redoStack: [],
      ));
    });

    on<SetPatientIdEvent>((event, emit) {
      emit(state.copyWith(patientId: event.patientId));
    });

    on<ChangeFigoTypeEvent>((event, emit) {
      final defaultColor = _getColorForTool(state.currentTool, event.figoType);
      emit(state.copyWith(
        currentFigoType: event.figoType,
        currentColor: defaultColor ?? state.currentColor,
      ));
    });

    on<ToggleLineDashedEvent>((event, emit) {
      emit(state.copyWith(currentLineDashed: event.isDashed));
    });

    on<LoadCustomStampsEvent>((event, emit) async {
      try {
        final service = _customStampsService ?? await CustomStampsService.create();
        _customStampsService = service;
        final slots = await service.loadSlots();
        final activeIndex = service.getActiveSlotIndex();
        final activePath = (activeIndex >= 0 && activeIndex < slots.length) ? slots[activeIndex] : null;
        emit(state.copyWith(
          customStampSlots: slots,
          activeStampSlotIndex: activeIndex,
          customStampPath: activePath,
          customStamps: slots.whereType<String>().toList(),
        ));
      } catch (e) {
        debugPrint('DrawBloc: Error loading custom stamps: $e');
      }
    });

    on<AssignCustomStampSlotEvent>((event, emit) async {
      try {
        final service = _customStampsService ?? await CustomStampsService.create();
        _customStampsService = service;
        final savedPath = await service.saveStampToSlot(
          event.slotIndex,
          sourceFilePath: event.sourceFilePath,
          bytes: event.bytes,
        );
        if (savedPath != null) {
          final updatedSlots = List<String?>.from(state.customStampSlots);
          if (event.slotIndex >= 0 && event.slotIndex < updatedSlots.length) {
            updatedSlots[event.slotIndex] = savedPath;
          }
          emit(state.copyWith(
            customStampSlots: updatedSlots,
            activeStampSlotIndex: event.slotIndex,
            customStampPath: savedPath,
            customStamps: updatedSlots.whereType<String>().toList(),
            currentTool: ToolType.customStamp,
            currentStrokeWidth: 3.0,
          ));
        }
      } catch (e) {
        debugPrint('DrawBloc: Error assigning custom stamp slot: $e');
      }
    });

    on<SelectCustomStampSlotEvent>((event, emit) async {
      final slots = state.customStampSlots;
      if (event.slotIndex >= 0 && event.slotIndex < slots.length) {
        final path = slots[event.slotIndex];
        try {
          final service = _customStampsService ?? await CustomStampsService.create();
          _customStampsService = service;
          await service.setActiveSlotIndex(event.slotIndex);
        } catch (_) {}
        emit(state.copyWith(
          activeStampSlotIndex: event.slotIndex,
          customStampPath: path,
          currentTool: ToolType.customStamp,
          currentStrokeWidth: 3.0,
        ));
      }
    });

    on<ClearCustomStampSlotEvent>((event, emit) async {
      try {
        final service = _customStampsService ?? await CustomStampsService.create();
        _customStampsService = service;
        await service.clearSlot(event.slotIndex);
        final updatedSlots = List<String?>.from(state.customStampSlots);
        if (event.slotIndex >= 0 && event.slotIndex < updatedSlots.length) {
          updatedSlots[event.slotIndex] = null;
        }
        final currentActive = state.activeStampSlotIndex;
        final newActivePath = (currentActive >= 0 && currentActive < updatedSlots.length)
            ? updatedSlots[currentActive]
            : null;
        emit(state.copyWith(
          customStampSlots: updatedSlots,
          customStampPath: newActivePath,
          customStamps: updatedSlots.whereType<String>().toList(),
        ));
      } catch (e) {
        debugPrint('DrawBloc: Error clearing custom stamp slot: $e');
      }
    });

    on<ImportCustomStampEvent>((event, emit) async {
      // Ищем первый пустой слот или используем активный
      int targetSlot = state.activeStampSlotIndex;
      final slots = state.customStampSlots;
      final emptyIndex = slots.indexOf(null);
      if (emptyIndex != -1) {
        targetSlot = emptyIndex;
      }
      add(AssignCustomStampSlotEvent(slotIndex: targetSlot, sourceFilePath: event.path));
    });

    on<SelectCustomStampEvent>((event, emit) {
      final index = state.customStampSlots.indexOf(event.path);
      if (index != -1) {
        add(SelectCustomStampSlotEvent(index));
      } else {
        emit(state.copyWith(
          customStampPath: event.path,
          currentTool: ToolType.customStamp,
          currentStrokeWidth: 3.0,
        ));
      }
    });

    // ── Тихое обновление истории (используется ластиком, без undoStack) ───
    on<UpdateHistoryWithoutUndoEvent>((event, emit) {
      emit(state.copyWith(history: event.history));
    });

    // ── Сохранить точку Undo (ластик фиксирует состояние перед стиранием) ─
    on<SaveUndoStateEvent>((event, emit) {
      final updatedUndo = _limited(
        List<List<DrawAction>>.from(state.undoStack)..add(event.undoState),
      );
      emit(state.copyWith(
        undoStack: updatedUndo,
        redoStack: [],
      ));
    });

    // ── Установка полного состояния (автосохранение / загрузка) ─────────
    on<SetFullStateEvent>((event, emit) {
      if (event.pages != null && event.pages!.isNotEmpty) {
        emit(state.copyWith(
          pages: event.pages,
          currentPageIndex: event.currentPageIndex ?? 0,
          patientId: event.patientId,
          customSchemes: event.customSchemes ?? [],
        ));
      } else {
        final singlePage = PageData(
          id: 'page_1',
          pageType: 'custom',
          title: 'Схема',
          backgroundPath: event.backgroundPath,
          history: event.history ?? [],
        );
        emit(state.copyWith(
          pages: [singlePage],
          currentPageIndex: 0,
          patientId: event.patientId,
          customSchemes: event.customSchemes ?? [],
        ));
      }
    });

    // ── Сброс к чистому новому проекту ──────────────────────────────────
    on<ResetProjectEvent>((event, emit) {
      emit(DrawState.initial());
    });

    // ── События мультистраничности ──────────────────────────────────────────

    on<SwitchPageEvent>((event, emit) {
      if (event.pageIndex >= 0 && event.pageIndex < state.pages.length) {
        emit(state.copyWith(currentPageIndex: event.pageIndex));
      }
    });

    on<AddPageEvent>((event, emit) {
      final newIndex = state.pages.length;
      final pageTitle = event.title ??
          (event.pageType == 'pelvis'
              ? 'Таз'
              : event.pageType == 'uterus'
                  ? 'Матка'
                  : event.pageType == 'abdominal_wall'
                      ? 'Брюшная стенка'
                      : 'Лист ${newIndex + 1}');

      final defaultBgPaths = event.backgroundPath != null
          ? [event.backgroundPath!]
          : (event.pageType == 'pelvis'
              ? ['assets/schemes/ls_view.png']
              : (event.pageType == 'uterus'
                  ? ['assets/schemes/uretus.png']
                  : (event.pageType == 'abdominal_wall'
                      ? ['assets/schemes/abdominal_wall_cross_section.png']
                      : const <String>[])));

      final newPage = PageData(
        id: 'page_${DateTime.now().millisecondsSinceEpoch}',
        pageType: event.pageType,
        title: pageTitle,
        backgroundPaths: defaultBgPaths,
      );

      final updatedPages = List<PageData>.from(state.pages)..add(newPage);
      emit(state.copyWith(
        pages: updatedPages,
        currentPageIndex: newIndex,
      ));
    });

    on<RemovePageEvent>((event, emit) {
      if (state.pages.length <= 1) return; // Не удаляем последнюю страницу
      if (event.pageIndex < 0 || event.pageIndex >= state.pages.length) return;

      final updatedPages = List<PageData>.from(state.pages)..removeAt(event.pageIndex);
      int newIndex = state.currentPageIndex;
      if (newIndex >= updatedPages.length) {
        newIndex = updatedPages.length - 1;
      }
      emit(state.copyWith(
        pages: updatedPages,
        currentPageIndex: newIndex,
      ));
    });

    add(LoadCustomStampsEvent());
  }

  Color? _getColorForTool(ToolType tool, String figoType) {
    switch (tool) {
      case ToolType.infiltrate:
        return const Color(0xFF5C4033); // Brown
      case ToolType.adhesions:
        return const Color(0xFF9E9E9E); // Grey
      case ToolType.endometrioma:
        return const Color(0xFF8B5A2B); // Brown / Ochre
      case ToolType.myoma:
        return const Color(0xFFFF69B4); // Fuchsia / Pink
      case ToolType.foci:
        return const Color(0xFF880E4F); // Cherry / Вишневый
      case ToolType.fibrosis:
      case ToolType.iud:
      case ToolType.iudStamp:
      case ToolType.arrow:
        return const Color(0xFF000000); // Black
      case ToolType.bowelInfiltrate:
      case ToolType.infiltrateStamp2:
      case ToolType.bowelInfiltrate2:
        return const Color(0xFF5C4033); // Brown
      case ToolType.gui:
        return const Color(0xFF8E24AA); // Purple
      case ToolType.follicle:
        return const Color(0xFF03A9F4); // Light Blue / Cyan
      case ToolType.cyst:
        return const Color(0xFFFFD600); // Насыщенно-желтый
      case ToolType.adenomyosis:
        return const Color(0xFF880E4F); // Cherry
      case ToolType.polyp:
        return const Color(0xFFFF7043); // Orange/Peach
      default:
        return null;
    }
  }
}
