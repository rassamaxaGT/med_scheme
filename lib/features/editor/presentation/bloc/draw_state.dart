import 'dart:ui';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';

class CustomSchemeItem {
  final String title;
  final String path;

  const CustomSchemeItem({required this.title, required this.path});
}

class DrawState {
  final List<PageData> pages;
  final int currentPageIndex;

  final ToolType currentTool;
  final Color currentColor;
  final double currentStrokeWidth;
  final String patientId;
  @Deprecated('FIGO classification was removed in v2.0 specification')
  final String currentFigoType;
  final bool currentLineDashed;
  final List<String?> customStampSlots;
  final int activeStampSlotIndex;
  final String? customStampPath;
  final List<String> customStamps;
  final List<CustomSchemeItem> customSchemes;
  final EraserTarget eraserTarget;

  DrawState({
    required this.pages,
    required this.currentPageIndex,
    required this.currentTool,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.patientId,
    required this.currentFigoType,
    required this.currentLineDashed,
    this.customStampSlots = const [null, null, null, null],
    this.activeStampSlotIndex = 0,
    this.customStampPath,
    required this.customStamps,
    this.customSchemes = const [],
    this.eraserTarget = EraserTarget.annotationsOnly,
  });

  /// Текущая активная страница
  PageData get currentPage =>
      pages.isNotEmpty && currentPageIndex >= 0 && currentPageIndex < pages.length
          ? pages[currentPageIndex]
          : (pages.isNotEmpty ? pages.first : PageData(id: 'page_def', pageType: 'custom', title: 'Схема'));

  /// Геттеры обратной совместимости для UI и логики
  List<DrawAction> get history => currentPage.history;
  List<List<DrawAction>> get undoStack => currentPage.undoStack;
  List<List<DrawAction>> get redoStack => currentPage.redoStack;
  List<String> get backgroundPaths => currentPage.backgroundPaths;
  String? get backgroundPath => currentPage.backgroundPath;

  factory DrawState.initial() {
    final defaultPages = [
      PageData(
        id: 'page_pelvis',
        pageType: 'pelvis',
        title: 'Таз',
        backgroundPaths: const ['assets/schemes/ls_view.png'],
      ),
      PageData(
        id: 'page_uterus',
        pageType: 'uterus',
        title: 'Матка',
        backgroundPaths: const ['assets/schemes/uretus.png'],
      ),
    ];

    return DrawState(
      pages: defaultPages,
      currentPageIndex: 0,
      currentTool: ToolType.pencil,
      currentColor: const Color(0xFF000000),
      currentStrokeWidth: 4.0,
      patientId: '',
      currentFigoType: '0',
      currentLineDashed: false,
      customStampSlots: const [null, null, null, null],
      activeStampSlotIndex: 0,
      customStampPath: null,
      customStamps: const [],
      eraserTarget: EraserTarget.annotationsOnly,
    );
  }

  DrawState copyWith({
    List<PageData>? pages,
    int? currentPageIndex,
    List<DrawAction>? history,
    List<List<DrawAction>>? undoStack,
    List<List<DrawAction>>? redoStack,
    ToolType? currentTool,
    Color? currentColor,
    double? currentStrokeWidth,
    List<String>? backgroundPaths,
    String? backgroundPath,
    bool clearBackground = false,
    String? patientId,
    String? currentFigoType,
    bool? currentLineDashed,
    List<String?>? customStampSlots,
    int? activeStampSlotIndex,
    String? customStampPath,
    List<String>? customStamps,
    List<CustomSchemeItem>? customSchemes,
    EraserTarget? eraserTarget,
  }) {
    List<PageData> newPages = pages != null ? List<PageData>.from(pages) : List<PageData>.from(this.pages);
    int newPageIndex = currentPageIndex ?? this.currentPageIndex;

    if (newPages.isEmpty) {
      newPages = [
        PageData(id: 'page_def', pageType: 'custom', title: 'Схема'),
      ];
      newPageIndex = 0;
    } else if (newPageIndex >= newPages.length) {
      newPageIndex = newPages.length - 1;
    } else if (newPageIndex < 0) {
      newPageIndex = 0;
    }

    // Если обновляется история, undo/redo или фон текущей страницы — обновляем активную страницу
    if (history != null ||
        undoStack != null ||
        redoStack != null ||
        backgroundPaths != null ||
        backgroundPath != null ||
        clearBackground) {
      final targetPage = newPages[newPageIndex];
      newPages[newPageIndex] = targetPage.copyWith(
        history: history,
        undoStack: undoStack,
        redoStack: redoStack,
        backgroundPaths: backgroundPaths,
        backgroundPath: backgroundPath,
        clearBackground: clearBackground,
      );
    }

    final effectiveSlots = customStampSlots ?? this.customStampSlots;
    final effectiveSlotIndex = activeStampSlotIndex ?? this.activeStampSlotIndex;
    final effectiveCustomStampPath = customStampPath ??
        ((effectiveSlotIndex >= 0 && effectiveSlotIndex < effectiveSlots.length)
            ? effectiveSlots[effectiveSlotIndex]
            : this.customStampPath);
    final effectiveCustomStamps = customStamps ?? effectiveSlots.whereType<String>().toList();

    return DrawState(
      pages: newPages,
      currentPageIndex: newPageIndex,
      currentTool: currentTool ?? this.currentTool,
      currentColor: currentColor ?? this.currentColor,
      currentStrokeWidth: currentStrokeWidth ?? this.currentStrokeWidth,
      patientId: patientId ?? this.patientId,
      currentFigoType: currentFigoType ?? this.currentFigoType,
      currentLineDashed: currentLineDashed ?? this.currentLineDashed,
      customStampSlots: effectiveSlots,
      activeStampSlotIndex: effectiveSlotIndex,
      customStampPath: effectiveCustomStampPath,
      customStamps: effectiveCustomStamps,
      customSchemes: customSchemes ?? this.customSchemes,
      eraserTarget: eraserTarget ?? this.eraserTarget,
    );
  }
}
