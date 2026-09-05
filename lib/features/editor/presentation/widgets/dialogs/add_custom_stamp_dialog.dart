import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

class StampGroupOption {
  final String id;
  final String name;
  final IconData icon;
  final Color? color;

  const StampGroupOption({
    required this.id,
    required this.name,
    required this.icon,
    this.color,
  });
}

class AddCustomStampResult {
  final String name;
  final String groupId;
  final String groupName;
  final bool isNewGroup;

  AddCustomStampResult({
    required this.name,
    required this.groupId,
    required this.groupName,
    required this.isNewGroup,
  });
}

class AddCustomStampDialog extends StatefulWidget {
  final String? imagePath;
  final Uint8List? bytes;
  final String defaultName;
  final List<StampGroupOption> availableGroups;
  final String? initialGroupId;

  const AddCustomStampDialog({
    super.key,
    this.imagePath,
    this.bytes,
    required this.defaultName,
    required this.availableGroups,
    this.initialGroupId,
  });

  static Future<AddCustomStampResult?> show(
    BuildContext context, {
    String? imagePath,
    Uint8List? bytes,
    required String defaultName,
    required List<StampGroupOption> availableGroups,
    String? initialGroupId,
  }) {
    return showDialog<AddCustomStampResult>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AddCustomStampDialog(
        imagePath: imagePath,
        bytes: bytes,
        defaultName: defaultName,
        availableGroups: availableGroups,
        initialGroupId: initialGroupId,
      ),
    );
  }

  @override
  State<AddCustomStampDialog> createState() => _AddCustomStampDialogState();
}

class _AddCustomStampDialogState extends State<AddCustomStampDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _newGroupController;
  late String _selectedGroupId;
  bool _isCreatingNewGroup = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.defaultName);
    _newGroupController = TextEditingController();

    if (widget.initialGroupId != null &&
        widget.availableGroups.any((g) => g.id == widget.initialGroupId)) {
      _selectedGroupId = widget.initialGroupId!;
    } else if (widget.availableGroups.any((g) => g.id == 'custom_stamps')) {
      _selectedGroupId = 'custom_stamps';
    } else if (widget.availableGroups.isNotEmpty) {
      _selectedGroupId = widget.availableGroups.first.id;
    } else {
      _selectedGroupId = 'custom_stamps';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _newGroupController.dispose();
    super.dispose();
  }

  Widget _buildPreview() {
    Widget imageWidget;
    if (widget.bytes != null && widget.bytes!.isNotEmpty) {
      imageWidget = Image.memory(widget.bytes!, fit: BoxFit.contain);
    } else if (widget.imagePath != null && widget.imagePath!.startsWith('data:image')) {
      try {
        final comma = widget.imagePath!.indexOf(',');
        final data = comma != -1 ? widget.imagePath!.substring(comma + 1) : widget.imagePath!;
        imageWidget = Image.memory(base64Decode(data), fit: BoxFit.contain);
      } catch (_) {
        imageWidget = const Icon(Icons.image, color: Colors.white54, size: 48);
      }
    } else if (widget.imagePath != null && !kIsWeb) {
      imageWidget = Image.file(File(widget.imagePath!), fit: BoxFit.contain);
    } else {
      imageWidget = const Icon(Icons.image, color: Colors.white54, size: 48);
    }

    return Container(
      width: 84,
      height: 84,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: imageWidget,
      ),
    );
  }

  void _onConfirm() {
    final stampName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : widget.defaultName;

    if (_isCreatingNewGroup) {
      final newGroupName = _newGroupController.text.trim();
      if (newGroupName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Пожалуйста, введите название новой группы'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      final newGroupId = 'custom_group_${DateTime.now().millisecondsSinceEpoch}';
      Navigator.of(context).pop(AddCustomStampResult(
        name: stampName,
        groupId: newGroupId,
        groupName: newGroupName,
        isNewGroup: true,
      ));
      return;
    }

    final selectedGroup = widget.availableGroups.firstWhere(
      (g) => g.id == _selectedGroupId,
      orElse: () => StampGroupOption(
        id: _selectedGroupId,
        name: 'Штампы',
        icon: Icons.bookmark,
      ),
    );

    Navigator.of(context).pop(AddCustomStampResult(
      name: stampName,
      groupId: selectedGroup.id,
      groupName: selectedGroup.name,
      isNewGroup: false,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF22272E),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Colors.white12, width: 1),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Заголовок
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.add_photo_alternate_outlined,
                      color: Theme.of(context).colorScheme.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Добавление штампа в панель',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Превью и поле названия
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPreview(),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Название штампа:',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 14),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            filled: true,
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            hintText: 'Введите название',
                            hintStyle: const TextStyle(color: Colors.white38),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: const BorderSide(color: Colors.white24),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Заголовок выбора группы
              const Text(
                'Выберите группу на 1-м уровне панели инструментов:',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),

              // Список групп
              Flexible(
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            ...widget.availableGroups.map((group) {
                              final isSelected =
                                  !_isCreatingNewGroup && _selectedGroupId == group.id;
                              return ChoiceChip(
                                label: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      group.icon,
                                      size: 14,
                                      color: group.color ??
                                          (isSelected ? Colors.white : Colors.white70),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      group.name,
                                      style: TextStyle(
                                        color: isSelected ? Colors.white : Colors.white70,
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.bold
                                            : FontWeight.normal,
                                      ),
                                    ),
                                  ],
                                ),
                                selected: isSelected,
                                selectedColor: Theme.of(context)
                                    .colorScheme
                                    .primary
                                    .withValues(alpha: 0.35),
                                backgroundColor: Colors.white.withValues(alpha: 0.05),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  side: BorderSide(
                                    color: isSelected
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.white12,
                                  ),
                                ),
                                onSelected: (sel) {
                                  if (sel) {
                                    setState(() {
                                      _selectedGroupId = group.id;
                                      _isCreatingNewGroup = false;
                                    });
                                  }
                                },
                              );
                            }),

                            // Кнопка "+ Создать новую группу"
                            ActionChip(
                              avatar: Icon(
                                _isCreatingNewGroup
                                    ? Icons.check_circle
                                    : Icons.add_circle_outline,
                                size: 16,
                                color: _isCreatingNewGroup
                                    ? Colors.lightGreenAccent
                                    : Colors.cyanAccent,
                              ),
                              label: Text(
                                '+ Новая группа',
                                style: TextStyle(
                                  color: _isCreatingNewGroup
                                      ? Colors.white
                                      : Colors.cyanAccent,
                                  fontSize: 12,
                                  fontWeight: _isCreatingNewGroup
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                              backgroundColor: _isCreatingNewGroup
                                  ? Colors.cyan.withValues(alpha: 0.25)
                                  : Colors.white.withValues(alpha: 0.05),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                                side: BorderSide(
                                  color: _isCreatingNewGroup
                                      ? Colors.cyanAccent
                                      : Colors.cyan.withValues(alpha: 0.4),
                                ),
                              ),
                              onPressed: () {
                                setState(() {
                                  _isCreatingNewGroup = true;
                                });
                              },
                            ),
                          ],
                        ),

                        // Если выбрано создание новой группы — поле ввода названия
                        if (_isCreatingNewGroup) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.cyan.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: Colors.cyan.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Название новой группы:',
                                  style: TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                TextField(
                                  controller: _newGroupController,
                                  autofocus: true,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 8,
                                    ),
                                    filled: true,
                                    fillColor: Colors.black26,
                                    hintText: 'Например: Сосуды, Лимфоузлы...',
                                    hintStyle: const TextStyle(
                                      color: Colors.white38,
                                      fontSize: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.cyanAccent,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(6),
                                      borderSide: const BorderSide(
                                        color: Colors.cyanAccent,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Кнопки действий
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Отмена',
                      style: TextStyle(color: Colors.white60),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _onConfirm,
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Сохранить'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
