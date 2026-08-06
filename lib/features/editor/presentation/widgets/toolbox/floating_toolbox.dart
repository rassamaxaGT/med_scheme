import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/entities/draw_action.dart';
import '../../bloc/draw_bloc.dart';
import '../../bloc/draw_event.dart';

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

class _FloatingToolboxState extends State<FloatingToolbox> {
  bool _isInfiltrateSubMenuOpen = false;

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
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24.0),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isVertical ? 6.0 : 8.0,
                vertical: isVertical ? 8.0 : 6.0,
              ),
              decoration: BoxDecoration(
                color: const Color(0xCC1A1A1A), // Темный матовый фон
                borderRadius: BorderRadius.circular(24.0),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.15),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 16.0,
                    offset: const Offset(0, 4),
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
                    onPanUpdate: (details) =>
                        widget.onDragUpdate(details.delta),
                    onPanEnd: (_) => widget.onDragEnd?.call(),
                    onPanCancel: () => widget.onDragEnd?.call(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        color: Colors
                            .transparent, // Делает всю область кликабельной
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
                      scrollDirection: isVertical
                          ? Axis.vertical
                          : Axis.horizontal,
                      child: Flex(
                        direction: isVertical ? Axis.vertical : Axis.horizontal,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Инфильтрат (с раскрывающимся подменю: Инфильтрат брюшины / Инфильтрат кишки / ГУИ)
                          _buildInfiltrateMenu(context, isVertical),

                          // 2. Эндометриома
                          _buildToolButton(
                            context,
                            tool: ToolType.endometrioma,
                            label: isVertical ? 'Эндомет.' : 'Эндометриома',
                            tooltip: 'Эндометриома (коричневый круг)',
                            icon: Icons.circle,
                            customColor: const Color(0xFF5C4033),
                            isVertical: isVertical,
                          ),

                          // 3. Спайки
                          _buildToolButton(
                            context,
                            tool: ToolType.adhesions,
                            label: 'Спайки',
                            tooltip: 'Спайки (паутина)',
                            icon: Icons.grain,
                            customColor: const Color(0xFF9E9E9E), // Grey
                            isVertical: isVertical,
                          ),

                          // 4. Фиброз
                          _buildToolButton(
                            context,
                            tool: ToolType.fibrosis,
                            label: 'Фиброз',
                            tooltip: 'Фиброз (кисть со штриховкой)',
                            icon: Icons.linear_scale,
                            isVertical: isVertical,
                          ),

                          // 5. Миома
                          _buildToolButton(
                            context,
                            tool: ToolType.myoma,
                            label: 'Миома',
                            tooltip: 'Миома (розовая/фуксия)',
                            icon: Icons.circle_outlined,
                            customColor: const Color(
                              0xFFFF69B4,
                            ), // Pink/Fuchsia
                            isVertical: isVertical,
                          ),

                          // 6. ВМС
                          _buildToolButton(
                            context,
                            tool: ToolType.iud,
                            label: 'ВМС',
                            tooltip: 'ВМС (спираль)',
                            icon: Icons.webhook,
                            customColor: const Color(0xFF000000), // Black
                            isVertical: isVertical,
                          ),

                          // 7. Очаг
                          _buildToolButton(
                            context,
                            tool: ToolType.foci,
                            label: 'Очаг',
                            tooltip: 'Очаг эндометриоза',
                            icon: Icons.bubble_chart,
                            customColor: const Color(
                              0xFF880E4F,
                            ), // Cherry / Вишневый
                            isVertical: isVertical,
                          ),

                          // 8. Фолликул (новый)
                          _buildToolButton(
                            context,
                            tool: ToolType.follicle,
                            label: 'Фоллик.',
                            tooltip: 'Фолликул (голубой контур без заливки)',
                            icon: Icons.radio_button_unchecked,
                            customColor: const Color(0xFF03A9F4), // Light Blue
                            isVertical: isVertical,
                          ),

                          // 9. Аденомиоз (новый)
                          _buildToolButton(
                            context,
                            tool: ToolType.adenomyosis,
                            label: 'Аденом.',
                            tooltip:
                                'Узловой аденомиоз (вишневый размытый круг)',
                            icon: Icons.blur_on,
                            customColor: const Color(0xFF880E4F), // Cherry
                            isVertical: isVertical,
                          ),

                          // 10. Полип (новый)
                          _buildToolButton(
                            context,
                            tool: ToolType.polyp,
                            label: 'Полип',
                            tooltip: 'Полип эндометрия',
                            icon: Icons.spa,
                            customColor: const Color(
                              0xFFFF7043,
                            ), // Peach/Orange
                            isVertical: isVertical,
                          ),

                          // 11. PNG Штамп
                          _buildToolButton(
                            context,
                            tool: ToolType.customStamp,
                            label: 'Штамп',
                            tooltip: 'Пользовательский штамп (PNG)',
                            icon: Icons.image_outlined,
                            isVertical: isVertical,
                          ),

                          // 12. Линия расстояния (dashed)
                          _buildToolButton(
                            context,
                            tool: ToolType.arrow,
                            label: isVertical ? 'Расст.' : 'Расстояние',
                            tooltip: 'Линия измерения расстояния (пунктир)',
                            icon: Icons.linear_scale,
                            isVertical: isVertical,
                            isDashedForce: true,
                            isSelectedOverride:
                                widget.currentTool == ToolType.arrow &&
                                context
                                    .read<DrawBloc>()
                                    .state
                                    .currentLineDashed,
                            onTapOverride: () {
                              context.read<DrawBloc>().add(
                                ToggleLineDashedEvent(true),
                              );
                              widget.onToolSelected(ToolType.arrow);
                            },
                          ),

                          // 13. Линия-указатель (solid arrow)
                          _buildToolButton(
                            context,
                            tool: ToolType.arrow,
                            label: isVertical ? 'Указат.' : 'Указатель',
                            tooltip: 'Линия-указатель (стрелка)',
                            icon: Icons.arrow_outward,
                            isVertical: isVertical,
                            isDashedForce: false,
                            isSelectedOverride:
                                widget.currentTool == ToolType.arrow &&
                                !context
                                    .read<DrawBloc>()
                                    .state
                                    .currentLineDashed,
                            onTapOverride: () {
                              context.read<DrawBloc>().add(
                                ToggleLineDashedEvent(false),
                              );
                              widget.onToolSelected(ToolType.arrow);
                            },
                          ),

                          // 14. Кисть (pencil)
                          _buildToolButton(
                            context,
                            tool: ToolType.pencil,
                            label: 'Кисть',
                            tooltip: 'Обычная кисть',
                            icon: Icons.brush,
                            isVertical: isVertical,
                          ),

                          // 15. Ластик
                          _buildToolButton(
                            context,
                            tool: ToolType.eraser,
                            label: 'Ластик',
                            tooltip: 'Ластик',
                            icon: Icons.cleaning_services,
                            isVertical: isVertical,
                          ),
                        ],
                      ),
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

  Widget _buildInfiltrateMenu(BuildContext context, bool isVertical) {
    final activeTool = widget.currentTool;
    final isAnySubToolActive =
        activeTool == ToolType.infiltrate ||
        activeTool == ToolType.bowelInfiltrate ||
        activeTool == ToolType.gui;

    final subTools = [
      _SubToolData(
        tool: ToolType.infiltrate,
        label: 'Инфильтрат',
        tooltip: 'Глубокий эндометриоидный инфильтрат (коричневый)',
        icon: Icons.blur_linear,
        color: const Color(0xFF5C4033),
      ),
      _SubToolData(
        tool: ToolType.bowelInfiltrate,
        label: 'Инф. кишки',
        tooltip: 'Инфильтрат кишки (коричневый)',
        icon: Icons.waves,
        color: const Color(0xFF5C4033),
      ),
      _SubToolData(
        tool: ToolType.gui,
        label: 'ГУИ',
        tooltip: 'Головной убор индейца (фиолетовый)',
        icon: Icons.style,
        color: const Color(0xFF8E24AA),
      ),
    ];

    if (_isInfiltrateSubMenuOpen) {
      final items = subTools.map((data) {
        return _buildToolButton(
          context,
          tool: data.tool,
          label: isVertical
              ? (data.tool == ToolType.bowelInfiltrate ? 'Инф.киш' : data.label)
              : data.label,
          tooltip: data.tooltip,
          icon: data.icon,
          customColor: data.color,
          isVertical: isVertical,
          onTapOverride: () {
            widget.onToolSelected(data.tool);
            setState(() {
              _isInfiltrateSubMenuOpen = false;
            });
          },
        );
      }).toList();

      final collapseBtn = GestureDetector(
        onTap: () => setState(() => _isInfiltrateSubMenuOpen = false),
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
              ? [...items, collapseBtn]
              : [collapseBtn, ...items],
        ),
      );
    } else {
      final defaultData = subTools.firstWhere(
        (t) => t.tool == activeTool,
        orElse: () => subTools.first,
      );

      final mainButton = _buildToolButton(
        context,
        tool: defaultData.tool,
        label: isVertical
            ? (defaultData.tool == ToolType.bowelInfiltrate
                  ? 'Инф.киш'
                  : defaultData.label)
            : defaultData.label,
        tooltip: defaultData.tooltip,
        icon: defaultData.icon,
        customColor: defaultData.color,
        isVertical: isVertical,
      );

      final expandTrigger = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => setState(() => _isInfiltrateSubMenuOpen = true),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isVertical ? 12.0 : 2.0,
              vertical: isVertical ? 2.0 : 12.0,
            ),
            child: Icon(
              isVertical ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
              size: 16,
              color: isAnySubToolActive ? Colors.white : Colors.white70,
            ),
          ),
        ),
      );

      return Container(
        decoration: BoxDecoration(
          color: isAnySubToolActive
              ? (defaultData.color).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isAnySubToolActive
                ? defaultData.color
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
  }) {
    final isSelected = isSelectedOverride ?? (widget.currentTool == tool);
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isVertical ? 0.0 : 2.0,
        vertical: isVertical ? 2.0 : 0.0,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: onTapOverride ?? () => widget.onToolSelected(tool),
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
                      color: customColor ?? (isSelected ? Colors.white : Colors.white.withValues(alpha: 0.8)),
                      isDashed: isDashedForce ?? (tool == ToolType.arrow && context.read<DrawBloc>().state.currentLineDashed),
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
    final stamps = state.customStamps;
    final activePath = state.customStampPath;

    Future<void> pickStamp() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['png'],
      );
      if (result != null && result.files.single.path != null) {
        drawBloc.add(ImportCustomStampEvent(result.files.single.path!));
      }
    }

    final children = <Widget>[
      isVertical
          ? Tooltip(
              message: 'Загрузить PNG штамп',
              child: InkWell(
                onTap: pickStamp,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 16),
                ),
              ),
            )
          : ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.add, size: 14),
              label: const Text(
                'Загрузить PNG',
                style: TextStyle(fontSize: 11),
              ),
              onPressed: pickStamp,
            ),
      if (stamps.isNotEmpty) ...[
        SizedBox(width: isVertical ? 0 : 8, height: isVertical ? 8 : 0),
        ...stamps.map((path) {
          final isSelected = activePath == path;
          final filename = path.split(RegExp(r'[/\\]')).last;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            child: isVertical
                ? Tooltip(
                    message: filename,
                    child: GestureDetector(
                      onTap: () => drawBloc.add(SelectCustomStampEvent(path)),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Theme.of(context).colorScheme.primary
                              : Colors.white.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.white24,
                          ),
                        ),
                        child: const Icon(
                          Icons.image,
                          size: 16,
                          color: Colors.white70,
                        ),
                      ),
                    ),
                  )
                : GestureDetector(
                    onTap: () => drawBloc.add(SelectCustomStampEvent(path)),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? Colors.white : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.image,
                            size: 12,
                            color: Colors.white70,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            filename.length > 10
                                ? '${filename.substring(0, 8)}..'
                                : filename,
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
          );
        }),
      ] else ...[
        SizedBox(width: isVertical ? 0 : 8, height: isVertical ? 8 : 0),
        Text(
          isVertical ? 'Нет' : 'Загрузите PNG штампы',
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white38,
            fontStyle: FontStyle.italic,
          ),
        ),
      ],
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
        const Color(0xFFFF00FF), // Fuchsia
        const Color(0xFFFF69B4), // Pink
        const Color(0xFF1976D2), // Blue
        const Color(0xFF388E3C), // Green
        const Color(0xFF757575), // Grey
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

    final showAdvanced = currentTool != ToolType.myoma;
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

    final label = Text(
      '${currentStrokeWidth.round()} px',
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

    final maxStrokeWidth = currentTool == ToolType.eraser ? 80.0 : 20.0;
    final slider = Slider(
      min: 1.0,
      max: maxStrokeWidth,
      value: currentStrokeWidth.clamp(1.0, maxStrokeWidth),
      onChanged: onThicknessChanged,
    );

    if (isVertical) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          preview,
          const SizedBox(height: 8),
          RotatedBox(
            quarterTurns: 3,
            child: SizedBox(
              width: 100,
              height: 24,
              child: SliderTheme(data: sliderThemeData, child: slider),
            ),
          ),
          const SizedBox(height: 8),
          label,
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          preview,
          const SizedBox(width: 8),
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

  @override
  Widget build(BuildContext context) {
    final bool showColor =
        currentTool == ToolType.pencil ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.fibrosis ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.myoma;

    final bool showThickness =
        currentTool == ToolType.pencil ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.fibrosis ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.eraser ||
        currentTool == ToolType.foci ||
        currentTool == ToolType.iud ||
        currentTool == ToolType.customStamp ||
        currentTool == ToolType.gui ||
        currentTool == ToolType.follicle ||
        currentTool == ToolType.adenomyosis ||
        currentTool == ToolType.polyp;

    final bool showCustomStamps = currentTool == ToolType.customStamp;
    final bool isVertical = orientation != ToolboxOrientation.horizontal;

    // Fix #13: строим единый список дочерних виджетов,
    // независимый от ориентации — затем оборачиваем в Flex с нужным Axis.
    final children = <Widget>[
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
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: isVertical
                ? const EdgeInsets.symmetric(horizontal: 8.0, vertical: 16.0)
                : const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            decoration: BoxDecoration(
              color: const Color(0xCC2A2A2A),
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
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
        ),
      ),
    );
  }
}

class _SubToolData {
  final ToolType tool;
  final String label;
  final String tooltip;
  final IconData icon;
  final Color color;

  _SubToolData({
    required this.tool,
    required this.label,
    required this.tooltip,
    required this.icon,
    required this.color,
  });
}

class _ToolIconPreview extends StatelessWidget {
  final ToolType tool;
  final Color color;
  final bool isDashed;

  const _ToolIconPreview({
    required this.tool,
    required this.color,
    this.isDashed = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(
        painter: _ToolIconPainter(
          tool: tool,
          color: color,
          isDashed: isDashed,
        ),
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
        canvas.drawLine(Offset(p1.dx, size.height / 2), Offset(size.width - p1.dx, size.height / 2), paint);
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

      case ToolType.iud:
        // ВМС: Т-образная спираль
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(const Offset(4, 4), Offset(size.width - 4, 4), paint);
        canvas.drawLine(Offset(center.dx, 4), Offset(center.dx, size.height - 3), paint);
        break;

      case ToolType.foci:
        // Очаг: вишневая точка
        final fill = Paint()
          ..color = const Color(0xFF880E4F)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(center, radius * 0.7, fill);
        canvas.drawCircle(Offset(center.dx - 5, center.dy - 4), radius * 0.3, fill);
        break;

      case ToolType.follicle:
        // Фолликул: голубой контур
        final ring = Paint()
          ..color = const Color(0xFF03A9F4)
          ..strokeWidth = 2.0
          ..style = PaintingStyle.stroke;
        canvas.drawCircle(center, radius - 1, ring);
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
          final a = i * 3.14159 / 6;
          final r = (radius - 1) * (0.8 + 0.25 * (i % 2 == 0 ? 1 : -1));
          final x = center.dx + 0.85 * r * (i % 3 == 0 ? 1.1 : 0.9);
          final y = center.dy + 0.85 * r * (i % 2 == 0 ? 0.9 : 1.1);
          if (i == 0) path.moveTo(x, y); else path.lineTo(x, y);
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
        p.cubicTo(size.width - 2, 7, size.width - 2, size.height - 3, center.dx, size.height - 3);
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
          if (i == 0) pathInf.moveTo(x, y); else pathInf.lineTo(x, y);
        }
        pathInf.close();
        canvas.drawPath(pathInf, borderPaint);
        break;

      case ToolType.bowelInfiltrate:
        // Инфильтрат кишки: коричневая дуга с фестонами
        final fill = Paint()
          ..color = const Color(0xFF5C4033)
          ..style = PaintingStyle.fill;
        
        final p = Path();
        p.addArc(Rect.fromLTWH(2, 4, size.width - 4, size.height - 6), 0, 3.14159);
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

        _drawGuiShapeForIcon(canvas, Rect.fromLTWH(1, 3, size.width - 2, size.height - 6), fillPaint, strokePaint);
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
        canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(3, 3, size.width - 6, size.height - 6), const Radius.circular(4)), paint);
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
        path.quadraticBezierTo(size.width / 2, 2, size.width - 3, size.height - 3);
        canvas.drawPath(path, paint);
        break;

      case ToolType.eraser:
        final paint = Paint()
          ..color = Colors.white
          ..strokeWidth = 1.8
          ..style = PaintingStyle.stroke;
        final rrect = RRect.fromRectAndRadius(Rect.fromLTWH(4, 5, 14, 12), const Radius.circular(3));
        canvas.drawRRect(rrect, paint);
        break;

      default:
        final paint = Paint()..color = Colors.white;
        canvas.drawCircle(center, 4, paint);
        break;
    }
  }

  void _drawGuiShapeForIcon(Canvas canvas, Rect bounds, Paint fillPaint, Paint strokePaint) {
    final double left = bounds.left;
    final double right = bounds.right;
    final double top = bounds.top;
    final double bottom = bounds.bottom;
    final double w = right - left;
    final double h = bottom - top;

    final path = Path();
    path.moveTo(left, top + h * 0.35);

    path.cubicTo(
      left + w * 0.25, top + h * 0.6,
      left + w * 0.6, top + h * 0.1,
      right - w * 0.1, top + h * 0.05,
    );

    path.quadraticBezierTo(right, top + h * 0.1, right, top + h * 0.3);
    path.quadraticBezierTo(right - w * 0.05, top + h * 0.6, right - w * 0.12, top + h * 0.62);
    path.quadraticBezierTo(right - w * 0.2, top + h * 0.45, right - w * 0.25, top + h * 0.4);
    path.quadraticBezierTo(right - w * 0.22, top + h * 0.85, right - w * 0.32, top + h * 0.88);
    path.quadraticBezierTo(right - w * 0.42, top + h * 0.6, right - w * 0.48, top + h * 0.5);
    path.quadraticBezierTo(left + w * 0.45, top + h * 0.98, left + w * 0.35, top + h * 1.0);
    path.quadraticBezierTo(left + w * 0.28, top + h * 0.65, left + w * 0.25, top + h * 0.5);
    path.quadraticBezierTo(left + w * 0.18, top + h * 0.75, left + w * 0.12, top + h * 0.72);
    path.quadraticBezierTo(left + w * 0.08, top + h * 0.5, left + w * 0.05, top + h * 0.42);
    path.quadraticBezierTo(left + w * 0.02, top + h * 0.38, left, top + h * 0.35);
    path.close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _ToolIconPainter oldDelegate) {
    return oldDelegate.tool != tool || oldDelegate.color != color || oldDelegate.isDashed != isDashed;
  }
}
