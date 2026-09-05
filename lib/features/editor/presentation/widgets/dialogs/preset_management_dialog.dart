import 'package:flutter/material.dart';

/// Диалог полноценного управления пресетами (добавление, удаление, редактирование,
/// и назначение статуса «По умолчанию»).
class PresetManagementDialog extends StatefulWidget {
  final String title;
  final String itemLabel;
  final List<String> initialItems;
  final String? initialDefault;
  final Future<void> Function(String name, bool makeDefault) onAdd;
  final Future<void> Function(String name) onRemove;
  final Future<void> Function(String name) onSetDefault;

  const PresetManagementDialog({
    super.key,
    required this.title,
    required this.itemLabel,
    required this.initialItems,
    required this.initialDefault,
    required this.onAdd,
    required this.onRemove,
    required this.onSetDefault,
  });

  static Future<void> show({
    required BuildContext context,
    required String title,
    required String itemLabel,
    required List<String> initialItems,
    required String? initialDefault,
    required Future<void> Function(String name, bool makeDefault) onAdd,
    required Future<void> Function(String name) onRemove,
    required Future<void> Function(String name) onSetDefault,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => PresetManagementDialog(
        title: title,
        itemLabel: itemLabel,
        initialItems: initialItems,
        initialDefault: initialDefault,
        onAdd: onAdd,
        onRemove: onRemove,
        onSetDefault: onSetDefault,
      ),
    );
  }

  @override
  State<PresetManagementDialog> createState() => _PresetManagementDialogState();
}

class _PresetManagementDialogState extends State<PresetManagementDialog> {
  late List<String> _items;
  late String _defaultItem;
  final TextEditingController _newController = TextEditingController();
  bool _makeDefaultNew = false;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _items = List<String>.from(widget.initialItems);
    _defaultItem = widget.initialDefault ?? (_items.isNotEmpty ? _items.first : '');
  }

  @override
  void dispose() {
    _newController.dispose();
    super.dispose();
  }

  Future<void> _handleAddNew() async {
    final text = _newController.text.trim();
    if (text.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      await widget.onAdd(text, _makeDefaultNew);
      if (mounted) {
        setState(() {
          if (!_items.contains(text)) {
            _items.add(text);
          }
          if (_makeDefaultNew || _items.length == 1) {
            _defaultItem = text;
          }
          _newController.clear();
          _makeDefaultNew = false;
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleSetDefault(String item) async {
    if (_isProcessing || _defaultItem == item) return;
    setState(() => _isProcessing = true);
    try {
      await widget.onSetDefault(item);
      if (mounted) {
        setState(() {
          _defaultItem = item;
        });
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleRemove(String item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удаление варианта', style: TextStyle(fontSize: 16)),
        content: Text('Удалить «$item» из сохраненного списка?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        await widget.onRemove(item);
        if (mounted) {
          setState(() {
            _items.remove(item);
            if (_defaultItem == item) {
              _defaultItem = _items.isNotEmpty ? _items.first : '';
            }
          });
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Заголовок со строгой иконкой
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF21262D) : const Color(0xFFF6F8FA),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.tune, size: 20, color: isDark ? const Color(0xFF58A6FF) : const Color(0xFF0969DA)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    splashRadius: 18,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Верхний блок: Добавление нового элемента
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _newController,
                          decoration: InputDecoration(
                            labelText: 'Новая ${widget.itemLabel.toLowerCase()}',
                            hintText: 'Введите название...',
                            border: const OutlineInputBorder(),
                            isDense: true,
                          ),
                          onSubmitted: (_) => _handleAddNew(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 18),
                        label: const Text('Добавить', style: TextStyle(fontSize: 13)),
                        style: ElevatedButton.styleFrom(
                          fixedSize: const Size.fromHeight(40),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          backgroundColor: const Color(0xFF238636),
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _isProcessing ? null : _handleAddNew,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  CheckboxListTile(
                    title: const Text(
                      'Сделать основным по умолчанию для новых отчетов',
                      style: TextStyle(fontSize: 12),
                    ),
                    value: _makeDefaultNew,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (v) => setState(() => _makeDefaultNew = v ?? false),
                  ),
                ],
              ),
            ),

            const Divider(height: 1),

            // Подзаголовок списка
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Text(
                    'Сохраненные варианты (${_items.length})',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.grey[400] : Colors.grey[700],
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    '⭐ — статус по умолчанию',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // Список вариантов
            Expanded(
              child: _items.isEmpty
                  ? Center(
                      child: Text(
                        'Список пуст.\nДобавьте первый вариант выше.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      itemCount: _items.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (ctx, idx) {
                        final item = _items[idx];
                        final isDefault = item == _defaultItem;

                        return Container(
                          decoration: BoxDecoration(
                            color: isDefault
                                ? (isDark ? const Color(0xFF1F2A38) : const Color(0xFFEFF5FB))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: ListTile(
                            dense: true,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                            leading: IconButton(
                              icon: Icon(
                                isDefault ? Icons.star : Icons.star_border,
                                color: isDefault ? Colors.amber : (isDark ? Colors.white38 : Colors.grey),
                                size: 22,
                              ),
                              tooltip: isDefault
                                  ? 'Основное значение по умолчанию'
                                  : 'Сделать основным по умолчанию',
                              splashRadius: 18,
                              onPressed: _isProcessing ? null : () => _handleSetDefault(item),
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    item,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isDefault ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isDefault) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E88E5).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: const Color(0xFF1E88E5).withValues(alpha: 0.5), width: 0.8),
                                    ),
                                    child: const Text(
                                      'по умолчанию',
                                      style: TextStyle(fontSize: 10, color: Color(0xFF1E88E5), fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                              tooltip: 'Удалить',
                              splashRadius: 18,
                              onPressed: _isProcessing ? null : () => _handleRemove(item),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const Divider(height: 1),

            // Нижняя панель с кнопкой «Готово»
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      fixedSize: const Size.fromHeight(38),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Готово', style: TextStyle(fontSize: 13)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
