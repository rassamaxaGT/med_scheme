import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
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
  DrawBloc() : super(DrawState.initial()) {
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
      if (event.tool == ToolType.fibrosis) {
        strokeWidth = 2.0;
      } else if (event.tool == ToolType.arrow) {
        strokeWidth = 1.5;
      } else if (event.tool == ToolType.spray) {
        strokeWidth = 16.0;
      } else if (event.tool == ToolType.foci ||
          event.tool == ToolType.follicle ||
          event.tool == ToolType.polyp ||
          event.tool == ToolType.gui ||
          event.tool == ToolType.customStamp ||
          event.tool == ToolType.iud) {
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

    on<ImportCustomStampEvent>((event, emit) {
      final updatedStamps = List<String>.from(state.customStamps);
      if (!updatedStamps.contains(event.path)) {
        updatedStamps.add(event.path);
      }
      emit(state.copyWith(
        customStamps: updatedStamps,
        customStampPath: event.path,
        currentTool: ToolType.customStamp,
      ));
    });

    on<SelectCustomStampEvent>((event, emit) {
      emit(state.copyWith(
        customStampPath: event.path,
        currentTool: ToolType.customStamp,
      ));
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
                  : 'Лист ${newIndex + 1}');

      final defaultBgPaths = event.backgroundPath != null
          ? [event.backgroundPath!]
          : (event.pageType == 'pelvis'
              ? ['assets/schemes/standart_endo.jpg']
              : (event.pageType == 'uterus'
                  ? ['assets/schemes/uterus.jpg']
                  : const <String>[]));

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
      case ToolType.iud:
      case ToolType.arrow:
        return const Color(0xFF000000); // Black
      case ToolType.bowelInfiltrate:
        return const Color(0xFF5C4033); // Brown
      case ToolType.gui:
        return const Color(0xFF8E24AA); // Purple
      case ToolType.follicle:
      case ToolType.cyst:
        return const Color(0xFF03A9F4); // Light Blue / Cyan
      case ToolType.adenomyosis:
        return const Color(0xFF880E4F); // Cherry
      case ToolType.polyp:
        return const Color(0xFFFF7043); // Orange/Peach
      default:
        return null;
    }
  }
}
