import '../../domain/entities/page_data.dart';
import 'draw_action_model.dart';

class PageDataModel {
  /// [pathRemapping] maps original file paths → archive names (for save)
  /// or archive names → extracted local paths (for load).
  static Map<String, dynamic> toJson(PageData page,
      {Map<String, String>? pathRemapping}) {
    return {
      'id': page.id,
      'pageType': page.pageType,
      'title': page.title,
      'backgroundPath': page.backgroundPath,
      'backgroundPaths': page.backgroundPaths,
      'history': page.history
          .map((a) => DrawActionModel.toJson(a, pathRemapping: pathRemapping))
          .toList(),
    };
  }

  static PageData fromJson(Map<String, dynamic> json,
      {Map<String, String>? pathRemapping}) {
    final historyList = (json['history'] as List? ?? [])
        .map((a) => DrawActionModel.fromJson(a as Map<String, dynamic>,
            pathRemapping: pathRemapping))
        .toList();

    List<String>? bgPaths;
    if (json['backgroundPaths'] is List) {
      bgPaths = (json['backgroundPaths'] as List).map((e) {
        final path = e.toString();
        return path == 'assets/schemes/standart_endo.jpg'
            ? 'assets/schemes/ls_view.png'
            : path;
      }).toList();
    }

    final bgPath = json['backgroundPath'] as String?;
    final resolvedBgPath = bgPath == 'assets/schemes/standart_endo.jpg'
        ? 'assets/schemes/ls_view.png'
        : bgPath;

    return PageData(
      id: json['id'] as String? ??
          'page_${DateTime.now().millisecondsSinceEpoch}',
      pageType: json['pageType'] as String? ?? 'custom',
      title: json['title'] as String? ?? 'Лист',
      backgroundPaths: bgPaths,
      backgroundPath: resolvedBgPath,
      history: historyList,
    );
  }
}
