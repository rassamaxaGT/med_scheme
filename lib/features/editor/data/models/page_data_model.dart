import '../../domain/entities/page_data.dart';
import 'draw_action_model.dart';

class PageDataModel {
  static Map<String, dynamic> toJson(PageData page) {
    return {
      'id': page.id,
      'pageType': page.pageType,
      'title': page.title,
      'backgroundPath': page.backgroundPath,
      'backgroundPaths': page.backgroundPaths,
      'history': page.history.map((a) => DrawActionModel.toJson(a)).toList(),
    };
  }

  static PageData fromJson(Map<String, dynamic> json) {
    final historyList = (json['history'] as List? ?? [])
        .map((a) => DrawActionModel.fromJson(a as Map<String, dynamic>))
        .toList();

    List<String>? bgPaths;
    if (json['backgroundPaths'] is List) {
      bgPaths = (json['backgroundPaths'] as List).map((e) => e.toString()).toList();
    }

    return PageData(
      id: json['id'] as String? ?? 'page_${DateTime.now().millisecondsSinceEpoch}',
      pageType: json['pageType'] as String? ?? 'custom',
      title: json['title'] as String? ?? 'Лист',
      backgroundPaths: bgPaths,
      backgroundPath: json['backgroundPath'] as String?,
      history: historyList,
    );
  }
}
