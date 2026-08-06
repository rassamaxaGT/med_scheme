import 'page_data.dart';
import 'draw_action.dart';
import '../../presentation/bloc/draw_state.dart';

class ProjectData {
  final List<PageData> pages;
  final String? patientId;
  final List<CustomSchemeItem> customSchemes;

  ProjectData({
    required this.pages,
    this.patientId,
    this.customSchemes = const [],
  });

  /// Устаревший геттер истории первой страницы для обратной совместимости
  List<DrawAction> get actions => pages.isNotEmpty ? pages.first.history : const [];

  /// Устаревший геттер фона первой страницы для обратной совместимости
  String? get backgroundPath => pages.isNotEmpty ? pages.first.backgroundPath : null;
}
