import 'draw_action.dart';

class PageData {
  final String id;
  final String pageType; // 'pelvis', 'uterus', 'custom'
  final String title; // 'Таз', 'Матка', etc.
  final List<String> backgroundPaths;
  final List<DrawAction> history;
  final List<List<DrawAction>> undoStack;
  final List<List<DrawAction>> redoStack;

  PageData({
    required this.id,
    required this.pageType,
    required this.title,
    List<String>? backgroundPaths,
    String? backgroundPath,
    List<DrawAction>? history,
    List<List<DrawAction>>? undoStack,
    List<List<DrawAction>>? redoStack,
  })  : backgroundPaths = backgroundPaths ?? (backgroundPath != null ? [backgroundPath] : const []),
        history = history ?? const [],
        undoStack = undoStack ?? const [],
        redoStack = redoStack ?? const [];

  String? get backgroundPath => backgroundPaths.isNotEmpty ? backgroundPaths.first : null;

  PageData copyWith({
    String? id,
    String? pageType,
    String? title,
    List<String>? backgroundPaths,
    String? backgroundPath,
    bool clearBackground = false,
    List<DrawAction>? history,
    List<List<DrawAction>>? undoStack,
    List<List<DrawAction>>? redoStack,
  }) {
    return PageData(
      id: id ?? this.id,
      pageType: pageType ?? this.pageType,
      title: title ?? this.title,
      backgroundPaths: clearBackground
          ? const []
          : (backgroundPaths ?? (backgroundPath != null ? [backgroundPath] : this.backgroundPaths)),
      history: history ?? this.history,
      undoStack: undoStack ?? this.undoStack,
      redoStack: redoStack ?? this.redoStack,
    );
  }
}
