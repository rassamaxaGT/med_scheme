import 'draw_action.dart';

class ProjectData {
  final List<DrawAction> actions;
  final String? backgroundPath;

  ProjectData({
    required this.actions,
    this.backgroundPath,
  });
}
