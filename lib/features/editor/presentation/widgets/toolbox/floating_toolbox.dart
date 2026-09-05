import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../../data/services/custom_stamps_service.dart';
import '../../../domain/entities/draw_action.dart';
import '../../bloc/draw_bloc.dart';
import '../../bloc/draw_event.dart';
import '../../bloc/draw_state.dart';
import '../dialogs/add_custom_stamp_dialog.dart';

enum ToolboxOrientation { horizontal, verticalLeft, verticalRight }

class FloatingToolbox extends StatefulWidget {
  final ToolboxOrientation orientation;
  final ToolType currentTool;
  final ValueChanged<ToolType> onToolSelected;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final double? width;
  final double? maxHeight;

  const FloatingToolbox({
    super.key,
    required this.orientation,
    required this.currentTool,
    required this.onToolSelected,
    required this.onDragUpdate,
    this.onDragStart,
    this.onDragEnd,
    this.width,
    this.maxHeight,
  });

  @override
  State<FloatingToolbox> createState() => _FloatingToolboxState();
}

class _ToolItemDefinition {
  final String id;
  final ToolType tool;
  final String label;
  final String? verticalLabel;
  final String tooltip;
  final IconData icon;
  final Color? color;
  final bool? isDashed;
  final bool? isSelectedOverride;
  final VoidCallback? onTapOverride;
  final VoidCallback? onLongPress;
  final String? customStampPath;
  final CustomStampItem? customStampItem;
  final bool isCustomStamp;

  _ToolItemDefinition({
    required this.id,
    required this.tool,
    required this.label,
    this.verticalLabel,
    required this.tooltip,
    required this.icon,
    this.color,
    this.isDashed,
    this.isSelectedOverride,
    this.onTapOverride,
    this.onLongPress,
    this.customStampPath,
    this.customStampItem,
    this.isCustomStamp = false,
  });

  String getDisplayLabel(bool isVertical) {
    if (isVertical && verticalLabel != null) {
      return verticalLabel!;
    }
    return label;
  }
}

class _ToolGroupDefinition {
  final String id;
  final String name;
  final IconData icon;
  final Color? color;
  final List<_ToolItemDefinition> items;
  final bool isCustomGroup;

  _ToolGroupDefinition({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
    required this.items,
    this.isCustomGroup = false,
  });
}

class _FloatingToolboxState extends State<FloatingToolbox> {
  String? _expandedGroupId;

  static final Map<String, Uint8List> _thumbnailBytesCache = {};

  static Widget buildStampThumbnail(
    String path, {
    double? width,
    double? height,
    BoxFit fit = BoxFit.contain,
    double iconSize = 20,
  }) {
    if (path.startsWith('data:image')) {
      try {
        Uint8List? bytes = _thumbnailBytesCache[path];
        if (bytes == null) {
          final commaIndex = path.indexOf(',');
          final base64Data = commaIndex != -1 ? path.substring(commaIndex + 1) : path;
          bytes = base64Decode(base64Data);
          if (_thumbnailBytesCache.length > 50) {
            _thumbnailBytesCache.remove(_thumbnailBytesCache.keys.first);
          }
          _thumbnailBytesCache[path] = bytes;
        }
        return Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (_, _, _) => Icon(Icons.broken_image, size: iconSize, color: Colors.white54),
        );
      } catch (_) {
        return Icon(Icons.broken_image, size: iconSize, color: Colors.white54);
      }
    } else if (kIsWeb) {
      return Image.network(
        path,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => Icon(Icons.broken_image, size: iconSize, color: Colors.white54),
      );
    } else {
      return Image.file(
        File(path),
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (_, _, _) => Icon(Icons.broken_image, size: iconSize, color: Colors.white54),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bool isVertical = widget.orientation != ToolboxOrientation.horizontal;
    final double targetWidth = isVertical
        ? 76.0
        : (widget.width ?? (screenWidth > 700 ? 700.0 : screenWidth - 32));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        width: targetWidth,
        constraints: BoxConstraints(
          maxWidth: targetWidth,
          maxHeight: isVertical
              ? (widget.maxHeight ??
                    (screenHeight -
                        kToolbarHeight -
                        MediaQuery.paddingOf(context).top -
                        32.0))
              : double.infinity,
        ),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isVertical ? 6.0 : 8.0,
            vertical: isVertical ? 8.0 : 6.0,
          ),
          decoration: BoxDecoration(
            color: const Color(
              0xF21C2128,
            ), // Быстрый непрозрачный/матовый фон без GPU-blur
            borderRadius: BorderRadius.circular(20.0),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 12.0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Flex(
            direction: isVertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Зона захвата для перетаскивания (Drag Handle) - СНАРУЖИ SingleChildScrollView
              GestureDetector(
                onPanStart: (_) => widget.onDragStart?.call(),
                onPanUpdate: (details) => widget.onDragUpdate(details.delta),
                onPanEnd: (_) => widget.onDragEnd?.call(),
                onPanCancel: () => widget.onDragEnd?.call(),
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Container(
                    color:
                        Colors.transparent, // Делает всю область кликабельной
                    padding: EdgeInsets.symmetric(
                      horizontal: isVertical ? 16.0 : 16.0,
                      vertical: isVertical ? 16.0 : 12.0,
                    ),
                    child: Icon(
                      Icons.drag_indicator,
                      color: Colors.white.withValues(alpha: 0.6),
                      size: 24,
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: isVertical ? 0.0 : 4.0,
                height: isVertical ? 4.0 : 0.0,
              ),
              Container(
                height: isVertical ? 1.0 : 24.0,
                width: isVertical ? 24.0 : 1.0,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              SizedBox(
                width: isVertical ? 0.0 : 4.0,
                height: isVertical ? 4.0 : 0.0,
              ),
              // Список инструментов внутри пролистываемой области
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
                  child: Flex(
                    direction: isVertical ? Axis.vertical : Axis.horizontal,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ..._getToolGroups(context, context.watch<DrawBloc>().state).map(
                        (group) => _buildToolGroup(context, group, isVertical),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<_ToolGroupDefinition> _getToolGroups(
    BuildContext context,
    DrawState drawState,
  ) {
    final groups = <_ToolGroupDefinition>[
      // 1. Инфильтрат
      _ToolGroupDefinition(
        id: 'infiltrate',
        name: 'Инфильтрат',
        icon: Icons.blur_linear,
        color: const Color(0xFF5C4033),
        items: [
          _ToolItemDefinition(
            id: 'infiltrate',
            tool: ToolType.infiltrate,
            label: 'Инфильтрат',
            tooltip: 'Глубокий эндометриоидный инфильтрат (коричневый)',
            icon: Icons.blur_linear,
            color: const Color(0xFF5C4033),
          ),
          _ToolItemDefinition(
            id: 'bowelInfiltrate',
            tool: ToolType.bowelInfiltrate,
            label: 'Инф. кишки',
            verticalLabel: 'Инф.киш',
            tooltip: 'Инфильтрат кишки (штамп)',
            icon: Icons.waves,
            color: const Color(0xFF5C4033),
          ),
          _ToolItemDefinition(
            id: 'infiltrateStamp2',
            tool: ToolType.infiltrateStamp2,
            label: 'Штамп 2',
            tooltip: 'Инфильтрат (штамп 2)',
            icon: Icons.waves,
            color: const Color(0xFF5C4033),
          ),
          _ToolItemDefinition(
            id: 'bowelInfiltrate2',
            tool: ToolType.bowelInfiltrate2,
            label: 'Инфильтрат 2',
            verticalLabel: 'Инф. 2',
            tooltip: 'Инфильтрат 2 (дуга с фестонами)',
            icon: Icons.waves,
            color: const Color(0xFF5C4033),
          ),
          _ToolItemDefinition(
            id: 'gui',
            tool: ToolType.gui,
            label: 'ГУИ',
            tooltip: 'Головной убор индейца (фиолетовый)',
            icon: Icons.style,
            color: const Color(0xFF8E24AA),
          ),
        ],
      ),

      // 2. Эндометриома
      _ToolGroupDefinition(
        id: 'endometrioma',
        name: 'Эндометриома',
        icon: Icons.circle,
        color: const Color(0xFF5C4033),
        items: [
          _ToolItemDefinition(
            id: 'endometrioma',
            tool: ToolType.endometrioma,
            label: 'Эндометриома',
            verticalLabel: 'Эндомет.',
            tooltip: 'Эндометриома (коричневый круг)',
            icon: Icons.circle,
            color: const Color(0xFF5C4033),
          ),
        ],
      ),

      // 3. Спайки
      _ToolGroupDefinition(
        id: 'adhesions',
        name: 'Спайки',
        icon: Icons.grain,
        color: const Color(0xFF9E9E9E),
        items: [
          _ToolItemDefinition(
            id: 'adhesions',
            tool: ToolType.adhesions,
            label: 'Спайки',
            tooltip: 'Спайки (паутина)',
            icon: Icons.grain,
            color: const Color(0xFF9E9E9E),
          ),
        ],
      ),

      // 4. Фиброз
      _ToolGroupDefinition(
        id: 'fibrosis',
        name: 'Фиброз',
        icon: Icons.linear_scale,
        items: [
          _ToolItemDefinition(
            id: 'fibrosis',
            tool: ToolType.fibrosis,
            label: 'Фиброз',
            tooltip: 'Фиброз (кисть со штриховкой)',
            icon: Icons.linear_scale,
          ),
        ],
      ),

      // 5. Миома
      _ToolGroupDefinition(
        id: 'myoma',
        name: 'Миома',
        icon: Icons.circle_outlined,
        color: const Color(0xFFFF69B4),
        items: [
          _ToolItemDefinition(
            id: 'myoma',
            tool: ToolType.myoma,
            label: 'Миома',
            tooltip: 'Миома (условное обозначение)',
            icon: Icons.circle_outlined,
            color: const Color(0xFFFF69B4),
          ),
          _ToolItemDefinition(
            id: 'myomaStamp',
            tool: ToolType.myomaStamp,
            label: 'Штамп',
            tooltip: 'Миома (штамп PNG)',
            icon: Icons.circle,
            color: const Color(0xFFFF69B4),
          ),
        ],
      ),

      // 6. ВМС
      _ToolGroupDefinition(
        id: 'iud',
        name: 'ВМС',
        icon: Icons.webhook,
        color: const Color(0xFF000000),
        items: [
          _ToolItemDefinition(
            id: 'iud',
            tool: ToolType.iud,
            label: 'ВМС',
            tooltip: 'ВМС (условное обозначение)',
            icon: Icons.webhook,
            color: const Color(0xFF000000),
          ),
          _ToolItemDefinition(
            id: 'iudStamp',
            tool: ToolType.iudStamp,
            label: 'Мирена',
            tooltip: 'Мирена (штамп PNG)',
            icon: Icons.straighten,
            color: const Color(0xFF000000),
          ),
        ],
      ),

      // 7. Очаг
      _ToolGroupDefinition(
        id: 'foci',
        name: 'Очаг',
        icon: Icons.bubble_chart,
        color: const Color(0xFF880E4F),
        items: [
          _ToolItemDefinition(
            id: 'foci',
            tool: ToolType.foci,
            label: 'Очаг',
            tooltip: 'Очаг эндометриоза',
            icon: Icons.bubble_chart,
            color: const Color(0xFF880E4F),
          ),
        ],
      ),

      // 8. Фолликул
      _ToolGroupDefinition(
        id: 'follicle',
        name: 'Фолликул',
        icon: Icons.radio_button_unchecked,
        color: const Color(0xFF03A9F4),
        items: [
          _ToolItemDefinition(
            id: 'follicle',
            tool: ToolType.follicle,
            label: 'Фолликул',
            verticalLabel: 'Фоллик.',
            tooltip: 'Фолликул (фиксированный круг 8px)',
            icon: Icons.radio_button_unchecked,
            color: const Color(0xFF03A9F4),
          ),
        ],
      ),

      // 9. Киста
      _ToolGroupDefinition(
        id: 'cyst',
        name: 'Киста',
        icon: Icons.panorama_fish_eye,
        color: const Color(0xFFFFD600),
        items: [
          _ToolItemDefinition(
            id: 'cyst',
            tool: ToolType.cyst,
            label: 'Киста',
            tooltip: 'Киста (измеряемая по размеру, без заливки)',
            icon: Icons.panorama_fish_eye,
            color: const Color(0xFFFFD600),
          ),
        ],
      ),

      // 10. Аденомиоз
      _ToolGroupDefinition(
        id: 'adenomyosis',
        name: 'Аденомиоз',
        icon: Icons.blur_on,
        color: const Color(0xFF880E4F),
        items: [
          _ToolItemDefinition(
            id: 'adenomyosis',
            tool: ToolType.adenomyosis,
            label: 'Аденомиоз',
            verticalLabel: 'Аденом.',
            tooltip: 'Узловой аденомиоз (вишневый размытый круг)',
            icon: Icons.blur_on,
            color: const Color(0xFF880E4F),
          ),
        ],
      ),

      // 11. Полип
      _ToolGroupDefinition(
        id: 'polyp',
        name: 'Полип',
        icon: Icons.spa,
        color: const Color(0xFFFF7043),
        items: [
          _ToolItemDefinition(
            id: 'polyp',
            tool: ToolType.polyp,
            label: 'Полип',
            tooltip: 'Полип эндометрия',
            icon: Icons.spa,
            color: const Color(0xFFFF7043),
          ),
        ],
      ),

      // 12. Штампы (пользовательские штампы)
      _ToolGroupDefinition(
        id: 'custom_stamps',
        name: 'Штампы',
        icon: Icons.image_outlined,
        items: [
          _ToolItemDefinition(
            id: 'add_stamp_placeholder',
            tool: ToolType.customStamp,
            label: 'Штамп',
            tooltip: 'Загрузить пользовательский PNG-штамп',
            icon: Icons.add_photo_alternate_outlined,
            onTapOverride: () => _pickAndAddStamp(context, defaultGroupId: 'custom_stamps'),
          ),
        ],
      ),

      // 13. Линия расстояния
      _ToolGroupDefinition(
        id: 'arrow_distance',
        name: 'Расстояние',
        icon: Icons.linear_scale,
        items: [
          _ToolItemDefinition(
            id: 'arrow_distance',
            tool: ToolType.arrow,
            label: 'Расстояние',
            verticalLabel: 'Расст.',
            tooltip: 'Линия измерения расстояния (пунктир)',
            icon: Icons.linear_scale,
            isDashed: true,
            isSelectedOverride: widget.currentTool == ToolType.arrow &&
                drawState.currentLineDashed,
            onTapOverride: () {
              context.read<DrawBloc>().add(ToggleLineDashedEvent(true));
              widget.onToolSelected(ToolType.arrow);
            },
          ),
        ],
      ),

      // 14. Линия-указатель
      _ToolGroupDefinition(
        id: 'arrow_pointer',
        name: 'Указатель',
        icon: Icons.arrow_outward,
        items: [
          _ToolItemDefinition(
            id: 'arrow_pointer',
            tool: ToolType.arrow,
            label: 'Указатель',
            verticalLabel: 'Указат.',
            tooltip: 'Линия-указатель (стрелка)',
            icon: Icons.arrow_outward,
            isDashed: false,
            isSelectedOverride: widget.currentTool == ToolType.arrow &&
                !drawState.currentLineDashed,
            onTapOverride: () {
              context.read<DrawBloc>().add(ToggleLineDashedEvent(false));
              widget.onToolSelected(ToolType.arrow);
            },
          ),
        ],
      ),

      // 15. Кисть
      _ToolGroupDefinition(
        id: 'pencil',
        name: 'Кисть',
        icon: Icons.brush,
        items: [
          _ToolItemDefinition(
            id: 'pencil',
            tool: ToolType.pencil,
            label: 'Кисть',
            tooltip: 'Обычная кисть',
            icon: Icons.brush,
          ),
        ],
      ),

      // 16. Спрей
      _ToolGroupDefinition(
        id: 'spray',
        name: 'Спрей',
        icon: Icons.blur_on,
        items: [
          _ToolItemDefinition(
            id: 'spray',
            tool: ToolType.spray,
            label: 'Спрей',
            tooltip: 'Спрей / Баллончик',
            icon: Icons.blur_on,
          ),
        ],
      ),

      // 17. Ластик
      _ToolGroupDefinition(
        id: 'eraser',
        name: 'Ластик',
        icon: Icons.cleaning_services,
        items: [
          _ToolItemDefinition(
            id: 'eraser',
            tool: ToolType.eraser,
            label: 'Ластик',
            tooltip: 'Ластик',
            icon: Icons.cleaning_services,
          ),
        ],
      ),
    ];

    // Добавляем созданные пользователем группы
    for (final customGroupName in drawState.customGroups) {
      final trimmed = customGroupName.trim();
      if (trimmed.isEmpty) continue;
      if (!groups.any((g) => g.id == trimmed || g.name == trimmed)) {
        groups.add(_ToolGroupDefinition(
          id: trimmed,
          name: trimmed,
          icon: Icons.bookmark_border,
          isCustomGroup: true,
          items: [],
        ));
      }
    }

    // Распределяем кастомные штампы по группам
    for (final stamp in drawState.customStampItems) {
      _ToolGroupDefinition? targetGroup;
      for (final g in groups) {
        if (g.id == stamp.groupId || g.name == stamp.groupId) {
          targetGroup = g;
          break;
        }
      }
      if (targetGroup == null) {
        if (drawState.customGroups.isNotEmpty) {
          final firstCustom = drawState.customGroups.first.trim();
          targetGroup = groups.firstWhere(
            (g) => g.id == firstCustom || g.name == firstCustom,
            orElse: () => groups.firstWhere((g) => g.id == 'custom_stamps'),
          );
        } else {
          targetGroup = groups.firstWhere((g) => g.id == 'custom_stamps');
        }
      }

      // Если в группе штампов был плейсхолдер — удаляем его при наличии реальных штампов
      targetGroup.items.removeWhere((it) => it.id.startsWith('add_stamp_placeholder'));

      final bool isStampSelected = widget.currentTool == ToolType.customStamp &&
          (drawState.activeStampItem?.id == stamp.id ||
              (drawState.customStampPath != null &&
                  drawState.customStampPath == stamp.imagePath));

      targetGroup.items.add(_ToolItemDefinition(
        id: stamp.id,
        tool: ToolType.customStamp,
        label: stamp.name,
        tooltip: '${targetGroup.name}: ${stamp.name} (долгий клик — настройки)',
        icon: Icons.image,
        customStampPath: stamp.imagePath,
        customStampItem: stamp,
        isCustomStamp: true,
        isSelectedOverride: isStampSelected,
        onTapOverride: () {
          context.read<DrawBloc>().add(SelectCustomStampItemEvent(stamp));
          widget.onToolSelected(ToolType.customStamp);
          setState(() => _expandedGroupId = null);
        },
        onLongPress: () => _showCustomStampOptions(context, stamp),
      ));
    }

    // Для пустых пользовательских групп добавляем интерактивный плейсхолдер
    for (final g in groups) {
      if (g.isCustomGroup && g.items.isEmpty) {
        g.items.add(_ToolItemDefinition(
          id: 'add_stamp_placeholder_${g.id}',
          tool: ToolType.customStamp,
          label: g.name,
          tooltip: 'Группа "${g.name}": нажмите, чтобы добавить штамп (долгий клик — удалить группу)',
          icon: Icons.add_photo_alternate_outlined,
          onTapOverride: () => _pickAndAddStamp(context, defaultGroupId: g.id),
          onLongPress: () => _showEmptyGroupOptions(context, g),
        ));
      }
    }

    return groups;
  }

  Widget _buildToolGroup(
    BuildContext context,
    _ToolGroupDefinition group,
    bool isVertical,
  ) {
    if (group.items.isEmpty) {
      return const SizedBox.shrink();
    }

    // Правило: если в группе ровно 1 инструмент — отображается сам по себе
    if (group.items.length == 1) {
      final item = group.items.first;
      final displayLabel = group.isCustomGroup
          ? (isVertical && group.name.length > 7
              ? '${group.name.substring(0, 6)}.'
              : group.name)
          : item.getDisplayLabel(isVertical);

      final displayTooltip = group.isCustomGroup && item.customStampItem != null
          ? '${group.name}: ${item.label} (долгий клик — настройки)'
          : item.tooltip;

      return _buildToolButton(
        context,
        tool: item.tool,
        label: displayLabel,
        tooltip: displayTooltip,
        icon: item.icon,
        customColor: item.color,
        isVertical: isVertical,
        isSelectedOverride: item.isSelectedOverride,
        isDashedForce: item.isDashed,
        onTapOverride: item.onTapOverride,
        onLongPress: item.onLongPress,
        customStampPath: item.customStampPath,
      );
    }

    // Правило: если в группе несколько инструментов — отображается как раскрывающаяся группа
    final bool isExpanded = _expandedGroupId == group.id;

    final isAnyItemActive = group.items.any((it) {
      if (it.isSelectedOverride != null) return it.isSelectedOverride!;
      return widget.currentTool == it.tool;
    });

    final activeItem = group.items.firstWhere(
      (it) {
        if (it.isSelectedOverride != null) return it.isSelectedOverride!;
        return widget.currentTool == it.tool;
      },
      orElse: () => group.items.first,
    );

    if (isExpanded) {
      final itemsWidgets = group.items.map((it) {
        return _buildToolButton(
          context,
          tool: it.tool,
          label: it.getDisplayLabel(isVertical),
          tooltip: it.tooltip,
          icon: it.icon,
          customColor: it.color,
          isVertical: isVertical,
          isSelectedOverride: it.isSelectedOverride,
          isDashedForce: it.isDashed,
          onTapOverride: it.onTapOverride ?? () {
            widget.onToolSelected(it.tool);
            setState(() => _expandedGroupId = null);
          },
          onLongPress: it.onLongPress,
          customStampPath: it.customStampPath,
        );
      }).toList();

      // Кнопка быстрого добавления штампа в эту группу
      final addStampBtn = _RightTooltip(
        message: 'Добавить штамп в "${group.name}"',
        child: GestureDetector(
          onTap: () => _pickAndAddStamp(context, defaultGroupId: group.id),
          child: Container(
            padding: const EdgeInsets.all(6),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              size: 14,
              color: Colors.white70,
            ),
          ),
        ),
      );

      final collapseBtn = GestureDetector(
        onTap: () => setState(() => _expandedGroupId = null),
        child: Container(
          padding: const EdgeInsets.all(4),
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: const BoxDecoration(
            color: Colors.white10,
            shape: BoxShape.circle,
          ),
          child: Icon(
            isVertical ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_left,
            size: 14,
            color: Colors.white70,
          ),
        ),
      );

      return Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Flex(
          direction: isVertical ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: isVertical
              ? [...itemsWidgets, addStampBtn, collapseBtn]
              : [collapseBtn, ...itemsWidgets, addStampBtn],
        ),
      );
    } else {
      final displayLabel = group.isCustomGroup
          ? (isVertical && group.name.length > 7
              ? '${group.name.substring(0, 6)}.'
              : group.name)
          : activeItem.getDisplayLabel(isVertical);

      final displayTooltip = group.isCustomGroup
          ? '${group.name}: ${activeItem.label} (раскройте группу для выбора)'
          : activeItem.tooltip;

      final mainButton = _buildToolButton(
        context,
        tool: activeItem.tool,
        label: displayLabel,
        tooltip: displayTooltip,
        icon: activeItem.icon,
        customColor: activeItem.color,
        isVertical: isVertical,
        isSelectedOverride: activeItem.isSelectedOverride,
        isDashedForce: activeItem.isDashed,
        onTapOverride: activeItem.onTapOverride,
        onLongPress: activeItem.onLongPress,
        customStampPath: activeItem.customStampPath,
      );

      final expandTrigger = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _expandedGroupId = group.id),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isVertical ? 12.0 : 2.0,
              vertical: isVertical ? 2.0 : 12.0,
            ),
            child: Icon(
              isVertical
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              size: 16,
              color: isAnyItemActive ? Colors.white : Colors.white70,
            ),
          ),
        ),
      );

      final highlightColor =
          activeItem.color ?? Theme.of(context).colorScheme.primary;

      return Container(
        decoration: BoxDecoration(
          color: isAnyItemActive
              ? highlightColor.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAnyItemActive
                ? highlightColor
                : Colors.white.withValues(alpha: 0.1),
            width: 1.0,
          ),
        ),
        child: Flex(
          direction: isVertical ? Axis.vertical : Axis.horizontal,
          mainAxisSize: MainAxisSize.min,
          children: [
            mainButton,
            Container(
              height: isVertical ? 1.0 : 28.0,
              width: isVertical ? 28.0 : 1.0,
              color: Colors.white.withValues(alpha: 0.15),
            ),
            expandTrigger,
          ],
        ),
      );
    }
  }

  Future<void> _pickAndAddStamp(
    BuildContext context, {
    String? defaultGroupId,
  }) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
        withData: true,
      );
      if (result != null && result.files.isNotEmpty && context.mounted) {
        final file = result.files.single;
        final bytes = file.bytes;
        final p = kIsWeb ? null : file.path;

        String defaultName = file.name;
        if (defaultName.toLowerCase().endsWith('.png')) {
          defaultName = defaultName.substring(0, defaultName.length - 4);
        }

        final drawBloc = context.read<DrawBloc>();
        final drawState = drawBloc.state;
        final groups = _getToolGroups(context, drawState);

        final groupOptions = groups.map((g) {
          return StampGroupOption(
            id: g.id,
            name: g.name,
            icon: g.icon,
            color: g.color,
          );
        }).toList();

        final dialogResult = await AddCustomStampDialog.show(
          context,
          imagePath: p,
          bytes: bytes,
          defaultName: defaultName,
          availableGroups: groupOptions,
          initialGroupId: defaultGroupId ?? 'custom_stamps',
        );

        if (dialogResult != null && context.mounted) {
          final targetGroupId = dialogResult.groupId.trim();
          final targetGroupName = dialogResult.groupName.trim();
          if (dialogResult.isNewGroup) {
            drawBloc.add(CreateCustomGroupEvent(targetGroupName));
          }
          drawBloc.add(AddCustomStampItemEvent(
            name: dialogResult.name,
            groupId: targetGroupId,
            sourceFilePath: p,
            bytes: bytes,
          ));
          widget.onToolSelected(ToolType.customStamp);
        }
      }
    } catch (e) {
      debugPrint('Ошибка выбора PNG-штампа: $e');
    }
  }

  void _showCustomStampOptions(BuildContext context, CustomStampItem stamp) {
    final drawBloc = context.read<DrawBloc>();
    final drawState = drawBloc.state;
    final groups = _getToolGroups(context, drawState);

    showDialog(
      context: context,
      builder: (ctx) {
        String currentGroupId = stamp.groupId;
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF22272E),
              title: Row(
                children: [
                  const Icon(Icons.tune, color: Colors.cyanAccent, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Штамп: ${stamp.name}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black38,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: buildStampThumbnail(stamp.imagePath, iconSize: 40),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Сменить группу:',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: groups.any((g) => g.id == currentGroupId)
                        ? currentGroupId
                        : (groups.isNotEmpty ? groups.first.id : null),
                    dropdownColor: const Color(0xFF1C2128),
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      filled: true,
                      fillColor: Colors.white10,
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    items: groups.map((g) {
                      return DropdownMenuItem(
                        value: g.id,
                        child: Text(g.name,
                            style: const TextStyle(color: Colors.white)),
                      );
                    }).toList(),
                    onChanged: (newVal) {
                      if (newVal != null) {
                        setDialogState(() => currentGroupId = newVal);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    drawBloc.add(DeleteCustomStampItemEvent(stamp.id));
                  },
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent, size: 16),
                  label: const Text('Удалить',
                      style: TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    if (currentGroupId != stamp.groupId) {
                      drawBloc.add(UpdateCustomStampGroupEvent(
                        id: stamp.id,
                        newGroupId: currentGroupId,
                      ));
                    }
                  },
                  child: const Text('Сохранить'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showEmptyGroupOptions(BuildContext context, _ToolGroupDefinition group) {
    final drawBloc = context.read<DrawBloc>();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF22272E),
          title: Row(
            children: [
              const Icon(Icons.bookmark_border, color: Colors.cyanAccent, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Группа: ${group.name}',
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
          ),
          content: const Text(
            'В этой группе пока нет штампов. Вы можете загрузить штамп или удалить группу.',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          actions: [
            TextButton.icon(
              onPressed: () {
                Navigator.of(ctx).pop();
                drawBloc.add(DeleteCustomGroupEvent(group.name));
              },
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 16),
              label: const Text('Удалить группу', style: TextStyle(color: Colors.redAccent)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.primary,
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                Navigator.of(ctx).pop();
                _pickAndAddStamp(context, defaultGroupId: group.id);
              },
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 16),
              label: const Text('Добавить штамп'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildToolButton(
    BuildContext context, {
    required ToolType tool,
    required String label,
    required String tooltip,
    required IconData icon,
    Color? customColor,
    required bool isVertical,
    bool? isSelectedOverride,
    bool? isDashedForce,
    VoidCallback? onTapOverride,
    VoidCallback? onLongPress,
    String? customStampPath,
  }) {
    final isSelected = isSelectedOverride ?? (widget.currentTool == tool);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isVertical ? 0.0 : 2.0,
        vertical: isVertical ? 2.0 : 0.0,
      ),
      child: _RightTooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(12.0),
            onTap: onTapOverride ?? () => widget.onToolSelected(tool),
            onLongPress: onLongPress,
            child: Container(
              width: 58,
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? (customColor ?? primaryColor).withValues(alpha: 0.2)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: customColor ?? primaryColor,
                              width: 2.0,
                            )
                          : null,
                    ),
                    child: Center(
                      child: _ToolIconPreview(
                        tool: tool,
                        color: customColor ??
                            (isSelected
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.8)),
                        isDashed: isDashedForce ??
                            (tool == ToolType.arrow &&
                                context.read<DrawBloc>().state.currentLineDashed),
                        customStampPath: customStampPath,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.0,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsBubble extends StatelessWidget {
  final Color currentColor;
  final double currentStrokeWidth;
  final ToolType currentTool;
  final ValueChanged<Color> onColorChanged;
  final ValueChanged<double> onThicknessChanged;
  final ToolboxOrientation orientation;
  final String currentFigoType;
  final ValueChanged<String> onFigoTypeChanged;
  final bool currentLineDashed;
  final ValueChanged<bool> onLineDashedChanged;

  const SettingsBubble({
    super.key,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentTool,
    required this.onColorChanged,
    required this.onThicknessChanged,
    required this.orientation,
    required this.currentFigoType,
    required this.onFigoTypeChanged,
    required this.currentLineDashed,
    required this.onLineDashedChanged,
  });

  Widget _buildDashedToggle(BuildContext context, bool isVertical) {
    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Пунктир',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
          const SizedBox(height: 2),
          SizedBox(
            height: 28,
            width: 28,
            child: Checkbox(
              value: currentLineDashed,
              activeColor: Theme.of(context).colorScheme.primary,
              onChanged: (val) {
                if (val != null) onLineDashedChanged(val);
              },
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Пунктир',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          Checkbox(
            value: currentLineDashed,
            activeColor: Theme.of(context).colorScheme.primary,
            onChanged: (val) {
              if (val != null) onLineDashedChanged(val);
            },
          ),
        ],
      );
    }
  }

  Widget _buildFociTypeToggle(BuildContext context, bool isVertical) {
    final isCherry =
        currentColor.toARGB32() == const Color(0xFF880E4F).toARGB32();
    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Очаг',
            style: TextStyle(fontSize: 10, color: Colors.white70),
          ),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => onColorChanged(
              isCherry ? const Color(0xFFFFF9C4) : const Color(0xFF880E4F),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                isCherry ? 'Свежий' : 'Старый',
                style: const TextStyle(
                  fontSize: 9,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Очаг:',
            style: TextStyle(fontSize: 11, color: Colors.white70),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => onColorChanged(
              isCherry ? const Color(0xFFFFF9C4) : const Color(0xFF880E4F),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white24),
              ),
              child: Text(
                isCherry ? 'Свежий (вишневый)' : 'Старый (желтый)',
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildCustomStampsSelector(BuildContext context, bool isVertical) {
    final drawBloc = context.read<DrawBloc>();
    final state = drawBloc.state;
    final activeSlot = state.activeStampSlotIndex;
    final path = (activeSlot >= 0 && activeSlot < state.customStampSlots.length)
        ? state.customStampSlots[activeSlot]
        : null;

    Future<void> pickStamp() async {
      try {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['png'],
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final file = result.files.single;
          final bytes = file.bytes;
          final p = kIsWeb ? null : file.path;
          if (kIsWeb) {
            if (bytes != null) {
              drawBloc.add(AssignCustomStampSlotEvent(
                slotIndex: activeSlot,
                bytes: bytes,
              ));
            }
          } else {
            if (p != null || bytes != null) {
              drawBloc.add(AssignCustomStampSlotEvent(
                slotIndex: activeSlot,
                sourceFilePath: p,
                bytes: bytes,
              ));
            }
          }
        }
      } catch (e) {
        debugPrint('Ошибка выбора PNG-штампа: $e');
      }
    }

    if (path == null || path.isEmpty) {
      return const SizedBox.shrink();
    }

    final children = <Widget>[
      Text(
        'Слот ${activeSlot + 1}',
        style: TextStyle(
          fontSize: isVertical ? 10 : 11,
          color: Colors.white70,
          fontWeight: FontWeight.bold,
        ),
      ),
      const SizedBox(width: 8, height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: _FloatingToolboxState.buildStampThumbnail(
          path,
          width: 28,
          height: 28,
          iconSize: 20,
        ),
      ),
      const SizedBox(width: 8, height: 6),
      _RightTooltip(
        message: 'Заменить файл в слоте ${activeSlot + 1}',
        child: IconButton(
          icon: const Icon(Icons.refresh, size: 16, color: Colors.white70),
          onPressed: pickStamp,
          tooltip: 'Заменить PNG',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
      const SizedBox(width: 8, height: 6),
      _RightTooltip(
        message: 'Очистить слот ${activeSlot + 1}',
        child: IconButton(
          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.redAccent),
          onPressed: () => drawBloc.add(ClearCustomStampSlotEvent(activeSlot)),
          tooltip: 'Очистить',
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ),
    ];

    return isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          )
        : Row(mainAxisSize: MainAxisSize.min, children: children);
  }

  Future<void> _openAdvancedColorPicker(BuildContext context) async {
    final gridColors = [
      Colors.black,
      Colors.white,
      Colors.grey,
      Colors.red,
      Colors.pink,
      Colors.purple,
      Colors.deepPurple,
      Colors.indigo,
      Colors.blue,
      Colors.lightBlue,
      Colors.cyan,
      Colors.teal,
      Colors.green,
      Colors.lightGreen,
      Colors.lime,
      Colors.yellow,
      Colors.amber,
      Colors.orange,
      Colors.deepOrange,
      Colors.brown,
      Colors.blueGrey,
    ];
    Color selectedColor = currentColor;
    final hexController = TextEditingController(
      text:
          '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
    );

    final color = await showDialog<Color>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Выбор цвета'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Сетка стандартных цветов
                  SizedBox(
                    width: 280,
                    height: 120,
                    child: GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 7,
                            crossAxisSpacing: 6,
                            mainAxisSpacing: 6,
                          ),
                      itemCount: gridColors.length,
                      itemBuilder: (context, index) {
                        final color = gridColors[index];
                        final isSelected =
                            selectedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                              hexController.text =
                                  '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white24,
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Поле для ручного HEX-кода
                  Row(
                    children: [
                      const Text(
                        'HEX: ',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: hexController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: '#FF0000',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 8,
                            ),
                          ),
                          onChanged: (val) {
                            final cleanHex = val.replaceAll('#', '');
                            if (cleanHex.length == 6) {
                              final intValue = int.tryParse(
                                cleanHex,
                                radix: 16,
                              );
                              if (intValue != null) {
                                setDialogState(() {
                                  selectedColor = Color(0xFF000000 | intValue);
                                });
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: selectedColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white24),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Отмена'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, selectedColor),
                  child: const Text('Выбрать'),
                ),
              ],
            );
          },
        );
      },
    );

    if (color != null) {
      onColorChanged(color);
    }
  }

  // ── Helpers для сборки секций — используются в обоих режимах ─────────────

  /// Fix #13: общий виджет выбора цвета, работает в любой ориентации.
  Widget _buildColorPicker(BuildContext context, bool isVertical) {
    final List<Color> colors;
    if (currentTool == ToolType.myoma) {
      colors = [
        const Color(0xFFFF69B4), // Розовый
        const Color(0xFFFF00FF), // Фуксия
        const Color(0xFF757575), // Серый
        const Color(0xFF000000), // Черный
      ];
    } else if (currentTool == ToolType.cyst) {
      colors = [
        const Color(0xFFFFD600), // Насыщенно-желтый
        const Color(0xFF757575), // Серый
        const Color(0xFF000000), // Черный
        const Color(0xFFD32F2F), // Красный
      ];
    } else {
      colors = [
        const Color(0xFF000000),
        const Color(0xFFD32F2F),
        const Color(0xFF388E3C),
        const Color(0xFF1976D2),
        const Color(0xFF5C4033),
        const Color(0xFFFFC0CB),
      ];
    }

    final swatches = colors.map((color) {
      final isSelected = currentColor.toARGB32() == color.toARGB32();
      return GestureDetector(
        onTap: () => onColorChanged(color),
        child: Padding(
          padding: isVertical
              ? const EdgeInsets.symmetric(vertical: 4.0)
              : const EdgeInsets.symmetric(horizontal: 4.0),
          child: Container(
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? Colors.white : Colors.white24,
                width: isSelected ? 2.0 : 1.0,
              ),
            ),
          ),
        ),
      );
    }).toList();

    final showAdvanced =
        currentTool != ToolType.myoma && currentTool != ToolType.cyst;
    final advancedBtn = showAdvanced
        ? GestureDetector(
            onTap: () => _openAdvancedColorPicker(context),
            child: Padding(
              padding: isVertical
                  ? const EdgeInsets.symmetric(vertical: 4.0)
                  : const EdgeInsets.symmetric(horizontal: 4.0),
              child: const Icon(
                Icons.add_circle_outline,
                size: 22,
                color: Colors.white70,
              ),
            ),
          )
        : const SizedBox.shrink();

    return isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [...swatches, if (showAdvanced) advancedBtn],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [...swatches, if (showAdvanced) advancedBtn],
          );
  }

  /// Fix #13: общий виджет слайдера толщины, работает в любой ориентации.
  Widget _buildThicknessSlider(
    BuildContext context,
    bool isVertical,
    bool showColor,
  ) {
    final bool showSliderPreview = currentTool != ToolType.bowelInfiltrate &&
        currentTool != ToolType.infiltrateStamp2 &&
        currentTool != ToolType.polyp &&
        currentTool != ToolType.customStamp &&
        currentTool != ToolType.myomaStamp &&
        currentTool != ToolType.iud &&
        currentTool != ToolType.iudStamp;

    final preview = Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      child: Container(
        width: currentStrokeWidth.clamp(2.0, 20.0),
        height: currentStrokeWidth.clamp(2.0, 20.0),
        decoration: BoxDecoration(
          color: showColor ? currentColor : Colors.white70,
          shape: BoxShape.circle,
        ),
      ),
    );

    final labelText = currentTool == ToolType.spray
        ? 'Конус: ${currentStrokeWidth.round()} px'
        : (currentTool == ToolType.iud ||
              currentTool == ToolType.iudStamp ||
              currentTool == ToolType.foci ||
              currentTool == ToolType.follicle ||
              currentTool == ToolType.polyp ||
              currentTool == ToolType.gui ||
              currentTool == ToolType.customStamp ||
              currentTool == ToolType.bowelInfiltrate ||
              currentTool == ToolType.infiltrateStamp2 ||
              currentTool == ToolType.myomaStamp)
        ? 'Размер: ${currentStrokeWidth.round()}'
        : '${currentStrokeWidth.round()} px';

    final label = Text(
      labelText,
      style: TextStyle(fontSize: isVertical ? 10 : 11, color: Colors.white70),
    );

    final sliderThemeData = SliderTheme.of(context).copyWith(
      trackHeight: 2.0,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
      overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
      activeTrackColor: Theme.of(context).colorScheme.primary,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
    );

    final maxStrokeWidth = currentTool == ToolType.eraser
        ? 80.0
        : (currentTool == ToolType.spray
            ? 60.0
            : ((currentTool == ToolType.bowelInfiltrate ||
                    currentTool == ToolType.infiltrateStamp2 ||
                    currentTool == ToolType.polyp ||
                    currentTool == ToolType.customStamp ||
                    currentTool == ToolType.myomaStamp ||
                    currentTool == ToolType.iud ||
                    currentTool == ToolType.iudStamp ||
                    currentTool == ToolType.fibrosis)
                ? 6.0
                : 20.0));
    final minStrokeWidth = currentTool == ToolType.spray ? 4.0 : 1.0;
    final int? divisions = (currentTool == ToolType.bowelInfiltrate ||
            currentTool == ToolType.infiltrateStamp2 ||
            currentTool == ToolType.polyp ||
            currentTool == ToolType.customStamp ||
            currentTool == ToolType.myomaStamp ||
            currentTool == ToolType.iud ||
            currentTool == ToolType.iudStamp ||
            currentTool == ToolType.fibrosis)
        ? 5
        : null;

    final slider = Slider(
      min: minStrokeWidth,
      max: maxStrokeWidth,
      divisions: divisions,
      value: currentStrokeWidth.clamp(minStrokeWidth, maxStrokeWidth),
      onChanged: onThicknessChanged,
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSliderPreview) ...[preview, const SizedBox(height: 4)],
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 75,
              height: 20,
              child: SliderTheme(data: sliderThemeData, child: slider),
            ),
          ),
          const SizedBox(height: 4),
          label,
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSliderPreview) ...[preview, const SizedBox(width: 8)],
          SizedBox(
            width: 120,
            height: 24,
            child: SliderTheme(data: sliderThemeData, child: slider),
          ),
          const SizedBox(width: 8),
          label,
        ],
      );
    }
  }

  /// Разделитель между секциями (вертикальный или горизонтальный).
  Widget _buildDivider(bool isVertical) => Container(
    height: isVertical ? 1.0 : 16.0,
    width: isVertical ? 16.0 : 1.0,
    color: Colors.white24,
    margin: isVertical
        ? const EdgeInsets.symmetric(vertical: 12.0)
        : const EdgeInsets.symmetric(horizontal: 12.0),
  );

  Widget _buildEraserModeSelector(BuildContext context, bool isVertical) {
    final state = context.watch<DrawBloc>().state;
    final currentTarget = state.eraserTarget;

    final options = [
      (
        target: EraserTarget.annotationsOnly,
        label: 'Стирать объекты',
        icon: Icons.layers_clear_outlined,
        tooltip: 'Стирать только объекты (не трогая фон)',
        color: const Color(0xFF0F4C81),
        borderColor: const Color(0xFF64B5F6),
      ),
      (
        target: EraserTarget.backgroundOnly,
        label: 'Стирать фон',
        icon: Icons.image_not_supported_outlined,
        tooltip: 'Стирать только фон (не трогая объекты)',
        color: const Color(0xFF00695C),
        borderColor: const Color(0xFF4DB6AC),
      ),
      (
        target: EraserTarget.everything,
        label: 'Стирать всё',
        icon: Icons.delete,
        tooltip: 'Стирать всё (и объекты, и фон)',
        color: const Color(0xFFE65100),
        borderColor: Colors.orangeAccent,
      ),
    ];

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final isSelected = currentTarget == opt.target;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3.0),
            child: _RightTooltip(
              message: opt.tooltip,
              child: GestureDetector(
                onTap: () {
                  context.read<DrawBloc>().add(
                    SetEraserTargetEvent(opt.target),
                  );
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? opt.color.withValues(alpha: 0.6)
                        : Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(
                      color: isSelected ? opt.borderColor : Colors.white12,
                      width: isSelected ? 1.5 : 1.0,
                    ),
                  ),
                  child: Icon(
                    opt.icon,
                    size: 17,
                    color: isSelected ? opt.borderColor : Colors.white70,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: options.map((opt) {
        final isSelected = currentTarget == opt.target;
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: _RightTooltip(
            message: opt.tooltip,
            child: GestureDetector(
              onTap: () {
                context.read<DrawBloc>().add(SetEraserTargetEvent(opt.target));
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10.0,
                  vertical: 5.0,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? opt.color.withValues(alpha: 0.55)
                      : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8.0),
                  border: Border.all(
                    color: isSelected ? opt.borderColor : Colors.white12,
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      opt.icon,
                      size: 14,
                      color: isSelected ? opt.borderColor : Colors.white70,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: isSelected
                            ? FontWeight.w600
                            : FontWeight.normal,
                        color: isSelected ? Colors.white : Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customStampPath = context.watch<DrawBloc>().state.customStampPath;
    if (currentTool == ToolType.customStamp &&
        (customStampPath == null || customStampPath.isEmpty)) {
      return const SizedBox.shrink();
    }

    final bool showColor =
        currentTool == ToolType.pencil ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.fibrosis ||
        currentTool == ToolType.spray ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.myoma ||
        currentTool == ToolType.cyst;

    final bool showThickness =
        currentTool == ToolType.pencil ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.fibrosis ||
        currentTool == ToolType.spray ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.eraser ||
        currentTool == ToolType.foci ||
        currentTool == ToolType.iud ||
        (currentTool == ToolType.customStamp &&
            customStampPath != null &&
            customStampPath.isNotEmpty) ||
        currentTool == ToolType.gui ||
        currentTool == ToolType.follicle ||
        currentTool == ToolType.cyst ||
        currentTool == ToolType.adenomyosis ||
        currentTool == ToolType.polyp ||
        currentTool == ToolType.bowelInfiltrate ||
        currentTool == ToolType.infiltrateStamp2 ||
        currentTool == ToolType.myomaStamp ||
        currentTool == ToolType.iudStamp;

    final bool showCustomStamps = currentTool == ToolType.customStamp &&
        customStampPath != null &&
        customStampPath.isNotEmpty;
    final bool isVertical = orientation != ToolboxOrientation.horizontal;

    // Fix #13: строим единый список дочерних виджетов,
    // независимый от ориентации — затем оборачиваем в Flex с нужным Axis.
    final children = <Widget>[
      if (currentTool == ToolType.eraser) ...[
        _buildEraserModeSelector(context, isVertical),
        _buildDivider(isVertical),
      ],
      if (currentTool == ToolType.arrow || currentTool == ToolType.pencil) ...[
        _buildDashedToggle(context, isVertical),
        _buildDivider(isVertical),
      ],
      if (currentTool == ToolType.foci) ...[
        _buildFociTypeToggle(context, isVertical),
        _buildDivider(isVertical),
      ],
      if (showCustomStamps) _buildCustomStampsSelector(context, isVertical),
      if (showColor) ...[
        _buildColorPicker(context, isVertical),
        if (showThickness) _buildDivider(isVertical),
      ],
      if (showThickness) _buildThicknessSlider(context, isVertical, showColor),
    ];

    return GestureDetector(
      child: Container(
        padding: isVertical
            ? const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0)
            : const EdgeInsets.symmetric(horizontal: 14.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: const Color(0xF222272E),
          borderRadius: BorderRadius.circular(16.0),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 10.0,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: SingleChildScrollView(
          scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
          child: Flex(
            direction: isVertical ? Axis.vertical : Axis.horizontal,
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: children,
          ),
        ),
      ),
    );
  }
}

class _ToolIconPreview extends StatelessWidget {
  final ToolType tool;
  final Color color;
  final bool isDashed;
  final String? customStampPath;

  const _ToolIconPreview({
    required this.tool,
    required this.color,
    this.isDashed = false,
    this.customStampPath,
  });

  @override
  Widget build(BuildContext context) {
    if (tool == ToolType.bowelInfiltrate) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/infiltrat.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ToolIconPainter(
                tool: tool,
                color: color,
                isDashed: isDashed,
              ),
            ),
          ),
        ),
      );
    }
    if (tool == ToolType.myomaStamp) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/myoma.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ToolIconPainter(
                tool: tool,
                color: color,
                isDashed: isDashed,
              ),
            ),
          ),
        ),
      );
    }
    if (tool == ToolType.iudStamp) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/mirena.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ToolIconPainter(
                tool: tool,
                color: color,
                isDashed: isDashed,
              ),
            ),
          ),
        ),
      );
    }
    if (tool == ToolType.infiltrateStamp2) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/infiltrat2.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ToolIconPainter(
                tool: tool,
                color: color,
                isDashed: isDashed,
              ),
            ),
          ),
        ),
      );
    }
    if (tool == ToolType.polyp) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: Image.asset(
          'assets/images/polyp.png',
          width: 22,
          height: 22,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => SizedBox(
            width: 22,
            height: 22,
            child: CustomPaint(
              painter: _ToolIconPainter(
                tool: tool,
                color: color,
                isDashed: isDashed,
              ),
            ),
          ),
        ),
      );
    }
    if (customStampPath != null && customStampPath!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: _FloatingToolboxState.buildStampThumbnail(
          customStampPath!,
          width: 22,
          height: 22,
          iconSize: 18,
        ),
      );
    }
    if (tool == ToolType.customStamp) {
      final state = context.read<DrawBloc>().state;
      if (state.customStampPath != null && state.customStampPath!.isNotEmpty) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: _FloatingToolboxState.buildStampThumbnail(
            state.customStampPath!,
            width: 22,
            height: 22,
            iconSize: 18,
          ),
        );
      }
    }
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _ToolIconPainter(tool: tool, color: color, isDashed: isDashed),
      ),
    );
  }
}

class _ToolIconPainter extends CustomPainter {
  final ToolType tool;
  final Color color;
  final bool isDashed;

  _ToolIconPainter({
    required this.tool,
    required this.color,
    this.isDashed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 1.0;

    switch (tool) {
      case ToolType.endometrioma:
        // Эндометриома: красновато-коричневый диск + темное пятно + красный ободок + черная граница
        final fillPaint = Paint()
          ..color = const Color(0xDD7B3F35)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, fillPaint);

        final spotPaint = Paint()
          ..color = const Color(0xFF381210)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius * 0.55, spotPaint);

        final redRing = Paint()
          ..color = const Color(0xFFD32F2F)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, radius, redRing);

        final border = Paint()
          ..color = Colors.black
          ..strokeWidth = 0.8
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, radius, border);
        break;

      case ToolType.adhesions:
        // Спайки: паутина серых нитей
        final paint = Paint()
          ..color = const Color(0xFF9E9E9E)
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        final p1 = const Offset(2, 3);
        final p2 = Offset(size.width - 2, 4);
        final p3 = Offset(3, size.height - 3);
        final p4 = Offset(size.width - 3, size.height - 2);

        canvas.drawLine(p1, p4, paint);
        canvas.drawLine(p2, p3, paint);
        canvas.drawLine(p1, p2, paint);
        canvas.drawLine(p3, p4, paint);
        canvas.drawLine(
          Offset(p1.dx, size.height / 2),
          Offset(size.width - p1.dx, size.height / 2),
          paint,
        );
        break;

      case ToolType.fibrosis:
        // Фиброз: линия с хаотичными спикулами/тяжами
        final linePaint = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final start = const Offset(3, 19);
        final end = const Offset(19, 3);
        canvas.drawLine(start, end, linePaint);

        final spikePaint = Paint()
          ..color = color
          ..strokeWidth = 1.2
          ..style = PaintingStyle.stroke;

        canvas.drawLine(const Offset(8, 14), const Offset(4, 18), spikePaint);
        canvas.drawLine(const Offset(8, 14), const Offset(12, 18), spikePaint);
        canvas.drawLine(const Offset(14, 8), const Offset(18, 4), spikePaint);
        canvas.drawLine(const Offset(14, 8), const Offset(10, 4), spikePaint);
        canvas.drawLine(const Offset(11, 11), const Offset(7, 7), spikePaint);
        break;

      case ToolType.myoma:
        // Миома: розовая утолщенная окружность
        final fill = Paint()
          ..color = const Color(0xFFFF69B4).withValues(alpha: 0.3)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, fill);

        final ring = Paint()
          ..color = const Color(0xFFFF69B4)
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, radius - 1, ring);
        break;

      case ToolType.myomaStamp:
        final fillStamp = Paint()
          ..color = const Color(0xFFFF69B4).withValues(alpha: 0.5)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius, fillStamp);
        break;

      case ToolType.iud:
        // ВМС: Т-образная спираль
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(const Offset(4, 4), Offset(size.width - 4, 4), paint);
        canvas.drawLine(
          Offset(center.dx, 4),
          Offset(center.dx, size.height - 3),
          paint,
        );
        break;

      case ToolType.iudStamp:
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(const Offset(4, 4), Offset(size.width - 4, 4), paint);
        canvas.drawLine(
          Offset(center.dx, 4),
          Offset(center.dx, size.height - 3),
          paint,
        );
        break;

      case ToolType.foci:
        // Очаг: вишневая точка
        final fill = Paint()
          ..color = const Color(0xFF880E4F)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius * 0.7, fill);
        canvas.drawCircle(
          Offset(center.dx - 5, center.dy - 4),
          radius * 0.3,
          fill,
        );
        break;

      case ToolType.follicle:
        // Фолликул: голубой контур
        final ring = Paint()
          ..color = const Color(0xFF03A9F4)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, radius - 1, ring);
        break;

      case ToolType.cyst:
        // Киста: эллиптический контур без заливки (насыщенно-желтый / выбранный цвет)
        final ring = Paint()
          ..color = color
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawOval(
          Rect.fromCenter(
            center: center,
            width: (radius - 1) * 2.2,
            height: (radius - 1) * 1.6,
          ),
          ring,
        );
        break;

      case ToolType.spray:
        // Спрей: облако мелких цветных точек
        final sprayPaint = Paint()
          ..color = color
          ..style = PaintingStyle.fill;
        for (int i = 0; i < 16; i++) {
          final angle = (i * 2.3999);
          final r = radius * 0.7 * math.sqrt(i / 16.0);
          final px = center.dx + math.cos(angle) * r;
          final py = center.dy + math.sin(angle) * r;
          canvas.drawCircle(Offset(px, py), 1.2, sprayPaint);
        }
        break;

      case ToolType.adenomyosis:
        // Аденомиоз: размытый вишневый диск с рваными краями
        final blurPaint = Paint()
          ..color = const Color(0xFF880E4F).withValues(alpha: 0.8)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
        canvas.drawCircle(center, radius - 2, blurPaint);

        final outerPaint = Paint()
          ..color = const Color(0xCCB83B52)
          ..style = PaintingStyle.fill
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2);

        final path = Path();
        for (int i = 0; i < 12; i++) {
          final r = (radius - 1) * (0.8 + 0.25 * (i % 2 == 0 ? 1 : -1));
          final x = center.dx + 0.85 * r * (i % 3 == 0 ? 1.1 : 0.9);
          final y = center.dy + 0.85 * r * (i % 2 == 0 ? 0.9 : 1.1);
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        path.close();
        canvas.drawPath(path, outerPaint);
        break;

      case ToolType.polyp:
        // Полип: персиково-оранжевая капля / груша
        final fill = Paint()
          ..color = const Color(0xFFFF7043)
          ..style = PaintingStyle.fill;

        final p = Path();
        p.moveTo(center.dx, 3);
        p.cubicTo(
          size.width - 2,
          7,
          size.width - 2,
          size.height - 3,
          center.dx,
          size.height - 3,
        );
        p.cubicTo(2, size.height - 3, 2, 7, center.dx, 3);
        canvas.drawPath(p, fill);
        break;

      case ToolType.infiltrate:
        // Глубокий эндометриоидный инфильтрат: коричневый овал с черным фестончатым контуром
        final fillPaint = Paint()
          ..color = const Color(0xFF5C4033)
          ..style = PaintingStyle.fill;

        final rectInf = Rect.fromLTWH(2, 4, size.width - 4, size.height - 8);
        canvas.drawOval(rectInf, fillPaint);

        final borderPaint = Paint()
          ..color = Colors.black
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke;

        final pathInf = Path();
        final centerInf = rectInf.center;
        final rx = rectInf.width / 2;
        final ry = rectInf.height / 2;
        for (int i = 0; i < 16; i++) {
          final a = i * 2 * 3.14159 / 16;
          final wave = 1.0 + 0.15 * (i % 2 == 0 ? 1 : -1);
          final x = centerInf.dx + math.cos(a) * rx * wave;
          final y = centerInf.dy + math.sin(a) * ry * wave;
          if (i == 0) {
            pathInf.moveTo(x, y);
          } else {
            pathInf.lineTo(x, y);
          }
        }
        pathInf.close();
        canvas.drawPath(pathInf, borderPaint);
        break;

      case ToolType.bowelInfiltrate:
      case ToolType.infiltrateStamp2:
        // Инфильтрат кишки (штамп PNG)
        final fillBowel = Paint()
          ..color = const Color(0xFF5C4033)
          ..style = PaintingStyle.fill;
        final rectBowel = RRect.fromRectAndRadius(
          Rect.fromLTWH(2, 6, size.width - 4, size.height - 12),
          const Radius.circular(3),
        );
        canvas.drawRRect(rectBowel, fillBowel);
        break;

      case ToolType.bowelInfiltrate2:
        // Инфильтрат 2: коричневая дуга с фестонами
        final fill = Paint()
          ..color = const Color(0xFF5C4033)
          ..style = PaintingStyle.fill;

        final p = Path();
        p.addArc(
          Rect.fromLTWH(2, 4, size.width - 4, size.height - 6),
          0,
          3.14159,
        );
        p.close();
        canvas.drawPath(p, fill);
        break;

      case ToolType.gui:
        // ГУИ: точная миниатюра формы с закругленными язычками
        final strokePaint = Paint()
          ..color = const Color(0xFF4A148C)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round;

        final fillPaint = Paint()
          ..color = const Color(0xFF8E24AA).withValues(alpha: 0.65)
          ..style = PaintingStyle.fill;

        _drawGuiShapeForIcon(
          canvas,
          Rect.fromLTWH(1, 3, size.width - 2, size.height - 6),
          fillPaint,
          strokePaint,
        );
        break;

      case ToolType.arrow:
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        final start = const Offset(3, 19);
        final end = const Offset(19, 3);

        if (isDashed) {
          // Пунктирная линия расстояния
          canvas.drawLine(start, const Offset(9, 13), paint);
          canvas.drawLine(const Offset(13, 9), end, paint);
        } else {
          // Указатель со стрелкой
          canvas.drawLine(start, end, paint);
          canvas.drawLine(end, const Offset(13, 4), paint);
          canvas.drawLine(end, const Offset(18, 9), paint);
        }
        break;

      case ToolType.customStamp:
        final paint = Paint()
          ..color = Colors.white70
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(3, 3, size.width - 6, size.height - 6),
            const Radius.circular(4),
          ),
          paint,
        );
        canvas.drawCircle(const Offset(8, 8), 2.5, paint);
        break;

      case ToolType.pencil:
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;
        final path = Path();
        path.moveTo(3, size.height - 5);
        path.quadraticBezierTo(
          size.width / 2,
          2,
          size.width - 3,
          size.height - 3,
        );
        canvas.drawPath(path, paint);
        break;

      case ToolType.eraser:
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        final rrect = RRect.fromRectAndRadius(
          Rect.fromLTWH(4, 5, 14, 12),
          const Radius.circular(3),
        );
        canvas.drawRRect(rrect, paint);
        break;

      default:
        final paint = Paint()..color = Colors.white;
        canvas.drawCircle(center, 4, paint);
        break;
    }
  }

  void _drawGuiShapeForIcon(
    Canvas canvas,
    Rect bounds,
    Paint fillPaint,
    Paint strokePaint,
  ) {
    final double left = bounds.left;
    final double right = bounds.right;
    final double top = bounds.top;
    final double bottom = bounds.bottom;
    final double w = right - left;
    final double h = bottom - top;

    final path = Path();
    path.moveTo(left, top + h * 0.35);

    path.cubicTo(
      left + w * 0.25,
      top + h * 0.6,
      left + w * 0.6,
      top + h * 0.1,
      right - w * 0.1,
      top + h * 0.05,
    );

    path.quadraticBezierTo(right, top + h * 0.1, right, top + h * 0.3);
    path.quadraticBezierTo(
      right - w * 0.05,
      top + h * 0.6,
      right - w * 0.12,
      top + h * 0.62,
    );
    path.quadraticBezierTo(
      right - w * 0.2,
      top + h * 0.45,
      right - w * 0.25,
      top + h * 0.4,
    );
    path.quadraticBezierTo(
      right - w * 0.22,
      top + h * 0.85,
      right - w * 0.32,
      top + h * 0.88,
    );
    path.quadraticBezierTo(
      right - w * 0.42,
      top + h * 0.6,
      right - w * 0.48,
      top + h * 0.5,
    );
    path.quadraticBezierTo(
      left + w * 0.45,
      top + h * 0.98,
      left + w * 0.35,
      top + h * 1.0,
    );
    path.quadraticBezierTo(
      left + w * 0.28,
      top + h * 0.65,
      left + w * 0.25,
      top + h * 0.5,
    );
    path.quadraticBezierTo(
      left + w * 0.18,
      top + h * 0.75,
      left + w * 0.12,
      top + h * 0.72,
    );
    path.quadraticBezierTo(
      left + w * 0.08,
      top + h * 0.5,
      left + w * 0.05,
      top + h * 0.42,
    );
    path.quadraticBezierTo(
      left + w * 0.02,
      top + h * 0.38,
      left,
      top + h * 0.35,
    );
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ToolIconPainter oldDelegate) {
    return oldDelegate.tool != tool ||
        oldDelegate.color != color ||
        oldDelegate.isDashed != isDashed;
  }
}

/// Всплывающая подсказка (тултип), отображаемая строго справа от целевого элемента.
/// Мгновенно скрывается при уходе курсора и не перекрывает соседние кнопки.
class _RightTooltip extends StatefulWidget {
  final String message;
  final Widget child;

  const _RightTooltip({
    required this.message,
    required this.child,
  });

  @override
  State<_RightTooltip> createState() => _RightTooltipState();
}

class _RightTooltipState extends State<_RightTooltip> {
  final _overlayController = OverlayPortalController();
  final _link = LayerLink();

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _link,
      child: MouseRegion(
        onEnter: (_) => _overlayController.show(),
        onExit: (_) => _overlayController.hide(),
        child: OverlayPortal(
          controller: _overlayController,
          overlayChildBuilder: (context) {
            return Positioned(
              width: 0,
              height: 0,
              child: CompositedTransformFollower(
                link: _link,
                targetAnchor: Alignment.centerRight,
                followerAnchor: Alignment.centerLeft,
                offset: const Offset(8, 0),
                child: IgnorePointer(
                  child: OverflowBox(
                    alignment: Alignment.centerLeft,
                    maxWidth: 320,
                    maxHeight: 120,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xF21C2128),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: Colors.white24,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
          child: widget.child,
        ),
      ),
    );
  }
}
