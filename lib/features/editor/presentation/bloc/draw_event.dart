import 'dart:typed_data';
import 'dart:ui';
import '../../data/services/custom_stamps_service.dart';
import '../../domain/entities/draw_action.dart';
import '../../domain/entities/page_data.dart';
import 'draw_state.dart';

abstract class DrawEvent {}

class AddActionEvent extends DrawEvent {
  final DrawAction action;
  AddActionEvent(this.action);
}

class UpdateActionEvent extends DrawEvent {
  final DrawAction action;
  UpdateActionEvent(this.action);
}

class SetBackgroundEvent extends DrawEvent {
  final String? path;
  SetBackgroundEvent(this.path);
}

class ToggleSchemeEvent extends DrawEvent {
  final String schemePath;
  ToggleSchemeEvent(this.schemePath);
}

class AddCustomSchemeEvent extends DrawEvent {
  final String path;
  final String? customTitle;
  AddCustomSchemeEvent(this.path, {this.customTitle});
}

class RemoveCustomSchemeEvent extends DrawEvent {
  final String path;
  RemoveCustomSchemeEvent(this.path);
}

class SetBackgroundPathsEvent extends DrawEvent {
  final List<String> paths;
  SetBackgroundPathsEvent(this.paths);
}

class UndoEvent extends DrawEvent {}

class RedoEvent extends DrawEvent {}

class ClearCanvasEvent extends DrawEvent {}

class SelectToolEvent extends DrawEvent {
  final ToolType tool;
  SelectToolEvent(this.tool);
}

class ChangeColorEvent extends DrawEvent {
  final Color color;
  ChangeColorEvent(this.color);
}

class ChangeStrokeWidthEvent extends DrawEvent {
  final double strokeWidth;
  ChangeStrokeWidthEvent(this.strokeWidth);
}

class DeleteActionEvent extends DrawEvent {
  final String actionId;
  DeleteActionEvent(this.actionId);
}

class SetHistoryEvent extends DrawEvent {
  final List<DrawAction> history;
  SetHistoryEvent(this.history);
}

class SetPatientIdEvent extends DrawEvent {
  final String patientId;
  SetPatientIdEvent(this.patientId);
}

@Deprecated('FIGO classification was removed in v2.0 specification')
class ChangeFigoTypeEvent extends DrawEvent {
  final String figoType;
  ChangeFigoTypeEvent(this.figoType);
}

class ToggleLineDashedEvent extends DrawEvent {
  final bool isDashed;
  ToggleLineDashedEvent(this.isDashed);
}

class ImportCustomStampEvent extends DrawEvent {
  final String path;
  ImportCustomStampEvent(this.path);
}

class SelectCustomStampEvent extends DrawEvent {
  final String path;
  SelectCustomStampEvent(this.path);
}

class LoadCustomStampsEvent extends DrawEvent {}

class AssignCustomStampSlotEvent extends DrawEvent {
  final int slotIndex;
  final String? sourceFilePath;
  final Uint8List? bytes;

  AssignCustomStampSlotEvent({
    required this.slotIndex,
    this.sourceFilePath,
    this.bytes,
  });
}

class SelectCustomStampSlotEvent extends DrawEvent {
  final int slotIndex;
  SelectCustomStampSlotEvent(this.slotIndex);
}

class ClearCustomStampSlotEvent extends DrawEvent {
  final int slotIndex;
  ClearCustomStampSlotEvent(this.slotIndex);
}

class UpdateHistoryWithoutUndoEvent extends DrawEvent {
  final List<DrawAction> history;
  UpdateHistoryWithoutUndoEvent(this.history);
}

class SaveUndoStateEvent extends DrawEvent {
  final List<DrawAction> undoState;
  SaveUndoStateEvent(this.undoState);
}

class SetFullStateEvent extends DrawEvent {
  final List<DrawAction>? history;
  final String patientId;
  final String? backgroundPath;
  final List<PageData>? pages;
  final int? currentPageIndex;
  final List<CustomSchemeItem>? customSchemes;

  SetFullStateEvent({
    this.history,
    required this.patientId,
    this.backgroundPath,
    this.pages,
    this.currentPageIndex,
    this.customSchemes,
  });
}

// ── События мультистраничности ──────────────────────────────────────────

class SwitchPageEvent extends DrawEvent {
  final int pageIndex;
  SwitchPageEvent(this.pageIndex);
}

class AddPageEvent extends DrawEvent {
  final String pageType; // 'pelvis', 'uterus', 'custom'
  final String? title;
  final String? backgroundPath;

  AddPageEvent({
    this.pageType = 'custom',
    this.title,
    this.backgroundPath,
  });
}

class RemovePageEvent extends DrawEvent {
  final int pageIndex;
  RemovePageEvent(this.pageIndex);
}

class SetEraserTargetEvent extends DrawEvent {
  final EraserTarget target;
  SetEraserTargetEvent(this.target);
}

class ResetProjectEvent extends DrawEvent {}

// ── События группировок кастомных штампов (v2) ───────────────────────────

class AddCustomStampItemEvent extends DrawEvent {
  final String name;
  final String groupId;
  final String? sourceFilePath;
  final Uint8List? bytes;

  AddCustomStampItemEvent({
    required this.name,
    required this.groupId,
    this.sourceFilePath,
    this.bytes,
  });
}

class DeleteCustomStampItemEvent extends DrawEvent {
  final String id;
  DeleteCustomStampItemEvent(this.id);
}

class SelectCustomStampItemEvent extends DrawEvent {
  final CustomStampItem item;
  SelectCustomStampItemEvent(this.item);
}

class UpdateCustomStampGroupEvent extends DrawEvent {
  final String id;
  final String newGroupId;
  UpdateCustomStampGroupEvent({required this.id, required this.newGroupId});
}

class CreateCustomGroupEvent extends DrawEvent {
  final String groupName;
  CreateCustomGroupEvent(this.groupName);
}
