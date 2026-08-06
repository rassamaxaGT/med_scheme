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
      bgPaths =
          (json['backgroundPaths'] as List).map((e) => e.toString()).toList();
    }

    return PageData(
      id: json['id'] as String? ??
          'page_${DateTime.now().millisecondsSinceEpoch}',
      pageType: json['pageType'] as String? ?? 'custom',
      title: json['title'] as String? ?? 'Лист',
      backgroundPaths: bgPaths,
      backgroundPath: json['backgroundPath'] as String?,
      history: historyList,
    );
  }
}
