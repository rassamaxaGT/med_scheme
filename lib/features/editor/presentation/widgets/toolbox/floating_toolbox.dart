import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../domain/entities/draw_action.dart';

enum ToolboxOrientation { horizontal, verticalLeft, verticalRight }

class FloatingToolbox extends StatelessWidget {
  final ToolboxOrientation orientation;
  final ToolType currentTool;
  final ValueChanged<ToolType> onToolSelected;
  final ValueChanged<Offset> onDragUpdate;
  final VoidCallback? onDragStart;
  final VoidCallback? onDragEnd;
  final VoidCallback onSelectFolder;
  final VoidCallback onSaveProject;
  final VoidCallback onOpenProject;
  final VoidCallback onPickBackground;
  final VoidCallback onDeleteBackground;
  final bool hasBackground;
  final double? maxHeight;

  const FloatingToolbox({
    super.key,
    required this.orientation,
    required this.currentTool,
    required this.onToolSelected,
    required this.onDragUpdate,
    this.onDragStart,
    this.onDragEnd,
    required this.onSelectFolder,
    required this.onSaveProject,
    required this.onOpenProject,
    required this.onPickBackground,
    required this.onDeleteBackground,
    required this.hasBackground,
    this.maxHeight,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final screenHeight = MediaQuery.sizeOf(context).height;
    final bool isVertical = orientation != ToolboxOrientation.horizontal;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {},
      child: Container(
        constraints: BoxConstraints(
          maxWidth: isVertical ? 76.0 : (screenWidth - 32),
          maxHeight: isVertical ? (maxHeight ?? (screenHeight - kToolbarHeight - MediaQuery.paddingOf(context).top - 32.0)) : double.infinity,
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
                    onPanStart: (_) => onDragStart?.call(),
                    onPanUpdate: (details) => onDragUpdate(details.delta),
                    onPanEnd: (_) => onDragEnd?.call(),
                    onPanCancel: () => onDragEnd?.call(),
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Container(
                        color: Colors.transparent, // Делает всю область кликабельной
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
                    // Список инструментов
                    _buildToolButton(
                      context,
                      tool: ToolType.move,
                      label: isVertical ? 'Движ.' : 'Движение',
                      tooltip: 'Выбор/Перемещение',
                      icon: Icons.open_with,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.pencil,
                      label: 'Кисть',
                      tooltip: 'Обычная кисть',
                      icon: Icons.brush,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.eraser,
                      label: 'Ластик',
                      tooltip: 'Ластик',
                      icon: Icons.cleaning_services,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.infiltrate,
                      label: 'Колючки',
                      tooltip: 'Инфильтрат (колючки)',
                      icon: Icons.blur_linear,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.adhesions,
                      label: 'Паутина',
                      tooltip: 'Спайки (паутина)',
                      icon: Icons.grain,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.endometrioma,
                      label: 'Коричн.',
                      tooltip: 'Эндометриома (коричневая)',
                      icon: Icons.circle,
                      customColor: const Color(0xFF5C4033),
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.myoma,
                      label: 'Розовый',
                      tooltip: 'Миома (розовая)',
                      icon: Icons.circle_outlined,
                      customColor: const Color(0xFFFF69B4),
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.iud,
                      label: 'Спираль',
                      tooltip: 'ВМС (спираль)',
                      icon: Icons.webhook,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.foci,
                      label: 'Очаг',
                      tooltip: 'Очаги (штамп-пятно)',
                      icon: Icons.bubble_chart,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.arrow,
                      label: 'Стрелка',
                      tooltip: 'Стрелка с текстом',
                      icon: Icons.arrow_outward,
                      isVertical: isVertical,
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
                    // Кнопка меню
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert, color: Colors.white),
                      tooltip: 'Меню опций',
                      onSelected: (value) {
                        switch (value) {
                          case 'load_bg':
                            onPickBackground();
                            break;
                          case 'delete_bg':
                            onDeleteBackground();
                            break;
                          case 'select_folder':
                            onSelectFolder();
                            break;
                          case 'open_project':
                            onOpenProject();
                            break;
                          case 'save_project':
                            onSaveProject();
                            break;
                        }
                      },
                      itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                        PopupMenuItem<String>(
                          value: 'load_bg',
                          child: ListTile(
                            leading: const Icon(Icons.image),
                            title: Text(hasBackground ? 'Сменить фон' : 'Загрузить фон'),
                            dense: true,
                          ),
                        ),
                        if (hasBackground)
                          const PopupMenuItem<String>(
                            value: 'delete_bg',
                            child: ListTile(
                              leading: Icon(Icons.no_photography, color: Colors.redAccent),
                              title: Text('Удалить фон', style: TextStyle(color: Colors.redAccent)),
                              dense: true,
                            ),
                          ),
                        const PopupMenuDivider(),
                        const PopupMenuItem<String>(
                          value: 'select_folder',
                          child: ListTile(
                            leading: Icon(Icons.folder_open),
                            title: Text('Выбрать папку проектов'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'open_project',
                          child: ListTile(
                            leading: Icon(Icons.upload_file),
                            title: Text('Открыть проект'),
                            dense: true,
                          ),
                        ),
                        const PopupMenuItem<String>(
                          value: 'save_project',
                          child: ListTile(
                            leading: Icon(Icons.save),
                            title: Text('Сохранить проект'),
                            dense: true,
                          ),
                        ),
                      ],
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

  Widget _buildToolButton(
    BuildContext context, {
    required ToolType tool,
    required String label,
    required String tooltip,
    required IconData icon,
    Color? customColor,
    required bool isVertical,
  }) {
    final isSelected = currentTool == tool;
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
          onTap: () => onToolSelected(tool),
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
                    color: isSelected ? primaryColor : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: isSelected
                        ? Colors.white
                        : (customColor ?? Colors.white.withValues(alpha: 0.8)),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9.0,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.7),
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

  const SettingsBubble({
    super.key,
    required this.currentColor,
    required this.currentStrokeWidth,
    required this.currentTool,
    required this.onColorChanged,
    required this.onThicknessChanged,
    required this.orientation,
  });

  @override
  Widget build(BuildContext context) {
    final bool showColor = currentTool == ToolType.pencil ||
        currentTool == ToolType.infiltrate ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.foci;

    final bool showThickness = currentTool == ToolType.pencil ||
        currentTool == ToolType.infiltrate ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.eraser ||
        currentTool == ToolType.endometrioma ||
        currentTool == ToolType.myoma ||
        currentTool == ToolType.iud;

    final colors = [
      const Color(0xFF000000), // Черный
      const Color(0xFFD32F2F), // Красный
      const Color(0xFF388E3C), // Зеленый
      const Color(0xFF1976D2), // Синий
      const Color(0xFF5C4033), // Коричневый (шоколад)
      const Color(0xFFFFC0CB), // Розовый
    ];

    final bool isVertical = orientation != ToolboxOrientation.horizontal;

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
              color: const Color(0xCC2A2A2A), // Чуть светлее тулбара для контраста
              borderRadius: BorderRadius.circular(16.0),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.15),
                width: 1.0,
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
              child: isVertical
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showColor) ...[
                          // Выбор цвета (вертикальный)
                          ...colors.map((color) {
                            final isSelected = currentColor.toARGB32() == color.toARGB32();
                            return GestureDetector(
                              onTap: () => onColorChanged(color),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0),
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
                          }),
                          if (showThickness)
                            Container(
                              width: 16,
                              height: 1,
                              color: Colors.white24,
                              margin: const EdgeInsets.symmetric(vertical: 12.0),
                            ),
                        ],
                        if (showThickness) ...[
                          // Превью толщины (закрашенный кружок)
                          Container(
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
                          ),
                          const SizedBox(height: 8),
                          // Слайдер толщины (вертикальный, повернут на 270 град)
                          RotatedBox(
                            quarterTurns: 3,
                            child: SizedBox(
                              width: 100,
                              height: 24,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  trackHeight: 2.0,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                  activeTrackColor: Theme.of(context).colorScheme.primary,
                                  inactiveTrackColor: Colors.white24,
                                  thumbColor: Colors.white,
                                ),
                                child: Slider(
                                  min: 1.0,
                                  max: 20.0,
                                  value: currentStrokeWidth,
                                  onChanged: onThicknessChanged,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${currentStrokeWidth.round()} px',
                            style: const TextStyle(fontSize: 10, color: Colors.white70),
                          ),
                        ],
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (showColor) ...[
                          // Выбор цвета (горизонтальный)
                          ...colors.map((color) {
                            final isSelected = currentColor.toARGB32() == color.toARGB32();
                            return GestureDetector(
                              onTap: () => onColorChanged(color),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
                          }),
                          if (showThickness)
                            Container(
                              height: 16,
                              width: 1,
                              color: Colors.white24,
                              margin: const EdgeInsets.symmetric(horizontal: 12.0),
                            ),
                        ],
                        if (showThickness) ...[
                          // Превью толщины (закрашенный кружок)
                          Container(
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
                          ),
                          const SizedBox(width: 8),
                          // Слайдер толщины
                          SizedBox(
                            width: 120,
                            height: 24,
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 2.0,
                                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
                                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12.0),
                                activeTrackColor: Theme.of(context).colorScheme.primary,
                                inactiveTrackColor: Colors.white24,
                                thumbColor: Colors.white,
                              ),
                              child: Slider(
                                min: 1.0,
                                max: 20.0,
                                value: currentStrokeWidth,
                                onChanged: onThicknessChanged,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${currentStrokeWidth.round()} px',
                            style: const TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
