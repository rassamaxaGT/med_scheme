import 'draw_action.dart';

class ProjectData {
  final List<DrawAction> actions;
  final String? backgroundPath;
  final String? patientId;

  ProjectData({
    required this.actions,
    this.backgroundPath,
    this.patientId,
  });
}

