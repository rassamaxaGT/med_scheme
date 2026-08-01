import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:file_picker/file_picker.dart';
import '../../../domain/entities/draw_action.dart';
import '../../bloc/draw_bloc.dart';
import '../../bloc/draw_event.dart';

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
                      label: 'Инфильтрат',
                      tooltip: 'Инфильтрат (волнистый эллипс)',
                      icon: Icons.blur_linear,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.adhesions,
                      label: 'Спайки',
                      tooltip: 'Спайки (паутина)',
                      icon: Icons.grain,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.fibrosis,
                      label: 'Фиброз',
                      tooltip: 'Фиброз (кисть со штриховкой)',
                      icon: Icons.linear_scale,
                      isVertical: isVertical,
                    ),

                    _buildToolButton(
                      context,
                      tool: ToolType.endometrioma,
                      label: 'Эндометриома',
                      tooltip: 'Эндометриома (коричневый круг)',
                      icon: Icons.circle,
                      customColor: const Color(0xFF5C4033),
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.myoma,
                      label: 'Миома FIGO',
                      tooltip: 'Миома по классификации FIGO',
                      icon: Icons.circle_outlined,
                      customColor: const Color(0xFFFF69B4),
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.iud,
                      label: 'ВМС',
                      tooltip: 'ВМС (спираль)',
                      icon: Icons.webhook,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.foci,
                      label: 'Очаг',
                      tooltip: 'Очаг эндометриоза',
                      icon: Icons.bubble_chart,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.customStamp,
                      label: 'PNG Штамп',
                      tooltip: 'Пользовательский штамп (PNG)',
                      icon: Icons.image_outlined,
                      isVertical: isVertical,
                    ),
                    _buildToolButton(
                      context,
                      tool: ToolType.arrow,
                      label: 'Расстояние',
                      tooltip: 'Линия измерения расстояния',
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

  Widget _buildFigoSelector(BuildContext context, bool isVertical) {
    final figoTypes = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '2-5'];
    
    Color getFigoColor(String type) {
      if (type == '0' || type == '1' || type == '2') return const Color(0xFFE91E63);
      if (type == '3' || type == '4') return const Color(0xFF1976D2);
      if (type == '5' || type == '6' || type == '7') return const Color(0xFF388E3C);
      if (type == '8') return const Color(0xFF757575);
      return const Color(0xFF9C27B0); // Hybrid
    }

    final children = figoTypes.map((type) {
      final isSelected = currentFigoType == type;
      final color = getFigoColor(type);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 1.0),
        child: GestureDetector(
          onTap: () => onFigoTypeChanged(type),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: isSelected ? color : color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: isSelected ? Colors.white : color.withValues(alpha: 0.4),
                width: 1.0,
              ),
            ),
            child: Text(
              type,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : Colors.white70,
              ),
            ),
          ),
        ),
      );
    }).toList();

    return isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('FIGO', style: TextStyle(fontSize: 10, color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Wrap(
                direction: Axis.vertical,
                spacing: 4,
                children: children,
              ),
            ],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('FIGO:', style: TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold)),
              const SizedBox(width: 6),
              ...children,
            ],
          );
  }

  Widget _buildDashedToggle(BuildContext context, bool isVertical) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Пунктир', style: TextStyle(fontSize: 11, color: Colors.white70)),
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
      ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white.withValues(alpha: 0.1),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.add, size: 14),
        label: const Text('Загрузить PNG', style: TextStyle(fontSize: 11)),
        onPressed: pickStamp,
      ),
      if (stamps.isNotEmpty) ...[
        const SizedBox(width: 8, height: 8),
        ...stamps.map((path) {
          final isSelected = activePath == path;
          final filename = path.split(RegExp(r'[/\\]')).last;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0, vertical: 2.0),
            child: GestureDetector(
              onTap: () => drawBloc.add(SelectCustomStampEvent(path)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
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
                    const Icon(Icons.image, size: 12, color: Colors.white70),
                    const SizedBox(width: 4),
                    Text(
                      filename.length > 10 ? '${filename.substring(0, 8)}..' : filename,
                      style: const TextStyle(fontSize: 10, color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ] else ...[
        const SizedBox(width: 8, height: 8),
        const Text(
          'Загрузите PNG штампы',
          style: TextStyle(fontSize: 10, color: Colors.white38, fontStyle: FontStyle.italic),
        ),
      ]
    ];

    return isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: children,
          );
  }

  Future<void> _openAdvancedColorPicker(BuildContext context) async {
    final gridColors = [
      Colors.black, Colors.white, Colors.grey, Colors.red, Colors.pink, Colors.purple,
      Colors.deepPurple, Colors.indigo, Colors.blue, Colors.lightBlue, Colors.cyan, Colors.teal,
      Colors.green, Colors.lightGreen, Colors.lime, Colors.yellow, Colors.amber, Colors.orange,
      Colors.deepOrange, Colors.brown, Colors.blueGrey
    ];
    Color selectedColor = currentColor;
    final hexController = TextEditingController(
      text: '#${currentColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
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
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                      ),
                      itemCount: gridColors.length,
                      itemBuilder: (context, index) {
                        final color = gridColors[index];
                        final isSelected = selectedColor.toARGB32() == color.toARGB32();
                        return GestureDetector(
                          onTap: () {
                            setDialogState(() {
                              selectedColor = color;
                              hexController.text = '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';
                            });
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected ? Colors.white : Colors.white24,
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
                      const Text('HEX: ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: TextField(
                          controller: hexController,
                          style: const TextStyle(fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: '#FF0000',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          ),
                          onChanged: (val) {
                            final cleanHex = val.replaceAll('#', '');
                            if (cleanHex.length == 6) {
                              final intValue = int.tryParse(cleanHex, radix: 16);
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
    final colors = [
      const Color(0xFF000000),
      const Color(0xFFD32F2F),
      const Color(0xFF388E3C),
      const Color(0xFF1976D2),
      const Color(0xFF5C4033),
      const Color(0xFFFFC0CB),
    ];

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

    final advancedBtn = GestureDetector(
      onTap: () => _openAdvancedColorPicker(context),
      child: Padding(
        padding: isVertical
            ? const EdgeInsets.symmetric(vertical: 4.0)
            : const EdgeInsets.symmetric(horizontal: 4.0),
        child: const Icon(Icons.add_circle_outline, size: 22, color: Colors.white70),
      ),
    );

    return isVertical
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [...swatches, advancedBtn],
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [...swatches, advancedBtn],
          );
  }

  /// Fix #13: общий виджет слайдера толщины, работает в любой ориентации.
  Widget _buildThicknessSlider(BuildContext context, bool isVertical, bool showColor) {
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

    final slider = Slider(
      min: 1.0,
      max: 20.0,
      value: currentStrokeWidth,
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
    final bool showColor = currentTool == ToolType.pencil ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.fibrosis ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.iud ||
        currentTool == ToolType.foci;

    final bool showThickness = currentTool == ToolType.pencil ||
        currentTool == ToolType.adhesions ||
        currentTool == ToolType.fibrosis ||
        currentTool == ToolType.arrow ||
        currentTool == ToolType.eraser;

    final bool showCustomStamps = currentTool == ToolType.customStamp;
    final bool isVertical = orientation != ToolboxOrientation.horizontal;

    // Fix #13: строим единый список дочерних виджетов,
    // независимый от ориентации — затем оборачиваем в Flex с нужным Axis.
    final children = <Widget>[
      if (currentTool == ToolType.myoma) ...[
        _buildFigoSelector(context, isVertical),
        _buildDivider(isVertical),
      ],
      if (currentTool == ToolType.arrow) ...[
        _buildDashedToggle(context, isVertical),
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

