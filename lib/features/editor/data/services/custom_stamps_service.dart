import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Модель кастомного штампа с поддержкой названия и группы
class CustomStampItem {
  final String id;
  final String name;
  final String imagePath;
  final String groupId;
  final int createdAt;

  CustomStampItem({
    required this.id,
    required this.name,
    required this.imagePath,
    required this.groupId,
    int? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().millisecondsSinceEpoch;

  CustomStampItem copyWith({
    String? id,
    String? name,
    String? imagePath,
    String? groupId,
    int? createdAt,
  }) {
    return CustomStampItem(
      id: id ?? this.id,
      name: name ?? this.name,
      imagePath: imagePath ?? this.imagePath,
      groupId: groupId ?? this.groupId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'imagePath': imagePath,
        'groupId': groupId,
        'createdAt': createdAt,
      };

  factory CustomStampItem.fromJson(Map<String, dynamic> json) =>
      CustomStampItem(
        id: json['id'] as String,
        name: (json['name'] as String?)?.isNotEmpty == true
            ? json['name'] as String
            : 'Штамп',
        imagePath: json['imagePath'] as String,
        groupId: (json['groupId'] as String?)?.isNotEmpty == true
            ? json['groupId'] as String
            : 'custom_stamps',
        createdAt: json['createdAt'] as int?,
      );
}

/// Оптимизирует байты PNG-штампа для максимального быстродействия (0-15мс) и предотвращения переполнения квоты localStorage.
/// Использует аппаратный C++ декодер/масштабатор движка Flutter (ui.instantiateImageCodec)
/// и ультра-быстрый резервный режим без тяжелых проходов zlib level 6.
Future<Uint8List> optimizeStampBytes(Uint8List rawBytes, {int maxDimension = 300}) async {
  if (rawBytes.isEmpty) return rawBytes;

  // Если файл уже имеет небольшой размер (<45 КБ), пропускаем тяжелое перекодирование
  if (rawBytes.length < 45 * 1024) {
    return rawBytes;
  }

  // 1. Аппаратное быстрое декодирование и масштабирование через встроенный C++ движок Flutter
  try {
    int? origW;
    int? origH;
    if (rawBytes.length >= 24 &&
        rawBytes[0] == 0x89 && rawBytes[1] == 0x50 && rawBytes[2] == 0x4E && rawBytes[3] == 0x47) {
      origW = (rawBytes[16] << 24) | (rawBytes[17] << 16) | (rawBytes[18] << 8) | rawBytes[19];
      origH = (rawBytes[20] << 24) | (rawBytes[21] << 16) | (rawBytes[22] << 8) | rawBytes[23];
    }

    int? targetW;
    int? targetH;
    if (origW != null && origH != null && origW > 0 && origH > 0) {
      if (origW <= maxDimension && origH <= maxDimension) {
        targetW = origW;
        targetH = origH;
      } else if (origW >= origH) {
        targetW = maxDimension;
        targetH = math.max(1, (origH * maxDimension / origW).round());
      } else {
        targetH = maxDimension;
        targetW = math.max(1, (origW * maxDimension / origH).round());
      }
    } else {
      targetW = maxDimension;
    }

    final codec = await ui.instantiateImageCodec(
      rawBytes,
      targetWidth: targetW,
      targetHeight: targetH,
    );
    final frame = await codec.getNextFrame();
    final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData != null) {
      final res = byteData.buffer.asUint8List();
      if (res.isNotEmpty && res.length < rawBytes.length) {
        return res;
      }
    }
  } catch (e) {
    debugPrint('CustomStampsService: native fast resize fallback: $e');
  }

  // 2. Резервный быстрый метод (уровень сжатия 1 вместо 6 — в десятки раз быстрее!)
  try {
    final decoded = img.decodeImage(rawBytes);
    if (decoded == null) return rawBytes;

    if (decoded.width <= maxDimension && decoded.height <= maxDimension) {
      if (rawBytes.length < 80 * 1024) return rawBytes;
    }

    img.Image resized = decoded;
    if (decoded.width > maxDimension || decoded.height > maxDimension) {
      if (decoded.width >= decoded.height) {
        resized = img.copyResize(decoded, width: maxDimension, interpolation: img.Interpolation.linear);
      } else {
        resized = img.copyResize(decoded, height: maxDimension, interpolation: img.Interpolation.linear);
      }
    }

    return Uint8List.fromList(img.encodePng(resized, level: 1));
  } catch (e) {
    debugPrint('CustomStampsService: fallback optimize error: $e');
    return rawBytes;
  }
}

/// Сервис автономного хранения пользовательских PNG-штампов в локальной директории приложения (Native)
/// или в SharedPreferences в виде Base64 Data URI (Web).
class CustomStampsService {
  static const int slotCount = 4;
  static const String _keySlotPrefix = 'custom_stamp_slot_';
  static const String _keyActiveSlot = 'custom_stamp_active_slot';
  static const String _keyItems = 'custom_stamps_items_v2';
  static const String _keyGroups = 'custom_stamps_groups_v2';

  final SharedPreferences _prefs;
  List<CustomStampItem>? _cachedItems;
  List<String>? _cachedGroups;

  CustomStampsService(this._prefs);

  static Future<CustomStampsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    final service = CustomStampsService(prefs);
    if (!kIsWeb) {
      await service._ensureDirectory();
    }
    return service;
  }

  Future<Directory> _getStorageDirectory() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final dir = Directory('${docsDir.path}/custom_stamps');
    return dir;
  }

  Future<void> _ensureDirectory() async {
    if (kIsWeb) return;
    try {
      final dir = await _getStorageDirectory();
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
    } catch (e) {
      debugPrint('CustomStampsService: error creating directory: $e');
    }
  }

  Future<List<String?>> loadSlots() async {
    if (!kIsWeb) {
      await _ensureDirectory();
    }
    final List<String?> slots = List.filled(slotCount, null);

    for (int i = 0; i < slotCount; i++) {
      final path = _prefs.getString('$_keySlotPrefix$i');
      if (path != null && path.isNotEmpty) {
        if (kIsWeb || path.startsWith('data:image')) {
          slots[i] = path;
        } else {
          try {
            final file = File(path);
            if (await file.exists()) {
              slots[i] = path;
            } else {
              // Файл больше не существует на диске — очищаем запись
              await _prefs.remove('$_keySlotPrefix$i');
              slots[i] = null;
            }
          } catch (_) {
            slots[i] = path;
          }
        }
      }
    }
    return slots;
  }

  Future<String?> saveStampToSlot(
    int slotIndex, {
    String? sourceFilePath,
    Uint8List? bytes,
  }) async {
    if (slotIndex < 0 || slotIndex >= slotCount) return null;

    if (kIsWeb) {
      if (bytes != null) {
        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';
        await _prefs.setString('$_keySlotPrefix$slotIndex', base64String);
        await setActiveSlotIndex(slotIndex);
        return base64String;
      }
      if (sourceFilePath != null && sourceFilePath.startsWith('data:image')) {
        await _prefs.setString('$_keySlotPrefix$slotIndex', sourceFilePath);
        await setActiveSlotIndex(slotIndex);
        return sourceFilePath;
      }
      return null;
    }

    // Нативные платформы (Windows, Android, iOS, macOS, Linux)
    await _ensureDirectory();

    final dir = await _getStorageDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final destPath = '${dir.path}/stamp_slot_${slotIndex}_$timestamp.png';

    // Удаляем предыдущий файл слота, если он был
    final oldPath = _prefs.getString('$_keySlotPrefix$slotIndex');
    if (oldPath != null && oldPath.isNotEmpty && !oldPath.startsWith('data:image')) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        debugPrint('CustomStampsService: error deleting old file: $e');
      }
    }

    try {
      if (bytes != null) {
        final destFile = File(destPath);
        await destFile.writeAsBytes(bytes);
      } else if (sourceFilePath != null) {
        final sourceFile = File(sourceFilePath);
        if (!await sourceFile.exists()) return null;
        await sourceFile.copy(destPath);
      } else {
        return null;
      }
      await _prefs.setString('$_keySlotPrefix$slotIndex', destPath);
      await setActiveSlotIndex(slotIndex);
      return destPath;
    } catch (e) {
      debugPrint('CustomStampsService: error copying file: $e');
      return null;
    }
  }

  Future<void> clearSlot(int slotIndex) async {
    if (slotIndex < 0 || slotIndex >= slotCount) return;

    final oldPath = _prefs.getString('$_keySlotPrefix$slotIndex');
    if (oldPath != null && oldPath.isNotEmpty && !kIsWeb && !oldPath.startsWith('data:image')) {
      try {
        final oldFile = File(oldPath);
        if (await oldFile.exists()) {
          await oldFile.delete();
        }
      } catch (e) {
        debugPrint('CustomStampsService: error deleting file: $e');
      }
    }

    await _prefs.remove('$_keySlotPrefix$slotIndex');
  }

  int getActiveSlotIndex() {
    final val = _prefs.getInt(_keyActiveSlot);
    if (val != null && val >= 0 && val < slotCount) {
      return val;
    }
    return 0;
  }

  Future<void> setActiveSlotIndex(int index) async {
    if (index >= 0 && index < slotCount) {
      await _prefs.setInt(_keyActiveSlot, index);
    }
  }

  // ── Группировка и расширенный список штампов (v2) ──────────────────────────

  Future<List<CustomStampItem>> loadCustomStamps({bool forceReload = false}) async {
    if (!forceReload && _cachedItems != null) {
      return List<CustomStampItem>.from(_cachedItems!);
    }

    if (!kIsWeb) {
      await _ensureDirectory();
    }
    final rawJson = _prefs.getString(_keyItems);
    if (rawJson != null && rawJson.isNotEmpty) {
      try {
        final List<dynamic> list = jsonDecode(rawJson);
        final items = <CustomStampItem>[];
        bool needsResave = false;
        for (final item in list) {
          final stamp = CustomStampItem.fromJson(Map<String, dynamic>.from(item));
          if (kIsWeb || stamp.imagePath.startsWith('data:image')) {
            // Если в хранилище лежит старый гигантский base64 (>50KB), сжимаем его на лету через быстрый C++ движок
            if (stamp.imagePath.startsWith('data:image') && stamp.imagePath.length > 50000) {
              try {
                final comma = stamp.imagePath.indexOf(',');
                final data = comma != -1 ? stamp.imagePath.substring(comma + 1) : stamp.imagePath;
                final opt = await optimizeStampBytes(base64Decode(data));
                items.add(stamp.copyWith(imagePath: 'data:image/png;base64,${base64Encode(opt)}'));
                needsResave = true;
              } catch (_) {
                items.add(stamp);
              }
            } else {
              items.add(stamp);
            }
          } else {
            try {
              if (await File(stamp.imagePath).exists()) {
                items.add(stamp);
              }
            } catch (_) {
              items.add(stamp);
            }
          }
        }
        final groups = await loadCustomGroups();
        for (int idx = 0; idx < items.length; idx++) {
          final s = items[idx];
          if (s.groupId.startsWith('custom_group_')) {
            final newG = groups.isNotEmpty ? groups.last : 'custom_stamps';
            items[idx] = s.copyWith(groupId: newG);
            needsResave = true;
          }
        }
        _cachedItems = items;
        if (needsResave) {
          await _saveCustomStampsList(items);
        }
        return List<CustomStampItem>.from(items);
      } catch (e) {
        debugPrint('CustomStampsService: error parsing stamps json: $e');
      }
    }

    // Если список v2 пуст, выполним миграцию из старых слотов
    final legacySlots = await loadSlots();
    final migrated = <CustomStampItem>[];
    for (int i = 0; i < legacySlots.length; i++) {
      final p = legacySlots[i];
      if (p != null && p.isNotEmpty) {
        migrated.add(CustomStampItem(
          id: 'legacy_slot_$i',
          name: 'Штамп ${i + 1}',
          imagePath: p,
          groupId: 'custom_stamps',
        ));
      }
    }
    _cachedItems = migrated;
    if (migrated.isNotEmpty) {
      await _saveCustomStampsList(migrated);
    }
    return List<CustomStampItem>.from(migrated);
  }

  Future<void> _saveCustomStampsList(List<CustomStampItem> items) async {
    _cachedItems = List<CustomStampItem>.from(items);
    try {
      final raw = jsonEncode(items.map((e) => e.toJson()).toList());
      await _prefs.setString(_keyItems, raw);
    } catch (e) {
      debugPrint('CustomStampsService: error saving stamps list ($e). Cleaning up legacy keys...');
      // Очищаем старые раздутые слоты и черновик, чтобы освободить место
      for (int i = 0; i < slotCount; i++) {
        await _prefs.remove('$_keySlotPrefix$i');
      }
      await _prefs.remove('autosave_draft');

      // Сжимаем оставшиеся крупные элементы в списке
      for (int i = 0; i < items.length; i++) {
        final it = items[i];
        if (it.imagePath.startsWith('data:image') && it.imagePath.length > 50000) {
          try {
            final comma = it.imagePath.indexOf(',');
            final data = comma != -1 ? it.imagePath.substring(comma + 1) : it.imagePath;
            final opt = await optimizeStampBytes(base64Decode(data));
            items[i] = it.copyWith(imagePath: 'data:image/png;base64,${base64Encode(opt)}');
          } catch (_) {}
        }
      }

      try {
        final rawRetry = jsonEncode(items.map((e) => e.toJson()).toList());
        await _prefs.setString(_keyItems, rawRetry);
        debugPrint('CustomStampsService: successfully saved after compression.');
      } catch (retryError) {
        debugPrint('CustomStampsService: retry save failed: $retryError');
      }
    }
  }

  Future<CustomStampItem?> addCustomStamp({
    required String name,
    required String groupId,
    String? sourceFilePath,
    Uint8List? bytes,
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final stampId = 'stamp_${timestamp}_${math.Random().nextInt(10000)}';
    String? savedPath;

    // Быстрая оптимизация байтов перед сохранением
    Uint8List? optimizedBytes;
    if (bytes != null && bytes.isNotEmpty) {
      optimizedBytes = await optimizeStampBytes(bytes);
    } else if (sourceFilePath != null && sourceFilePath.startsWith('data:image')) {
      try {
        final comma = sourceFilePath.indexOf(',');
        final data = comma != -1 ? sourceFilePath.substring(comma + 1) : sourceFilePath;
        final raw = base64Decode(data);
        optimizedBytes = await optimizeStampBytes(raw);
      } catch (_) {}
    } else if (sourceFilePath != null && !kIsWeb) {
      try {
        final f = File(sourceFilePath);
        if (await f.exists()) {
          final raw = await f.readAsBytes();
          optimizedBytes = await optimizeStampBytes(raw);
        }
      } catch (_) {}
    }

    if (kIsWeb) {
      if (optimizedBytes != null) {
        savedPath = 'data:image/png;base64,${base64Encode(optimizedBytes)}';
      } else if (bytes != null) {
        savedPath = 'data:image/png;base64,${base64Encode(bytes)}';
      } else if (sourceFilePath != null && sourceFilePath.startsWith('data:image')) {
        savedPath = sourceFilePath;
      }
    } else {
      await _ensureDirectory();
      final dir = await _getStorageDirectory();
      final destPath = '${dir.path}/custom_stamp_$timestamp.png';
      try {
        final toWrite = optimizedBytes ?? bytes;
        if (toWrite != null) {
          final destFile = File(destPath);
          await destFile.writeAsBytes(toWrite);
          savedPath = destPath;
        } else if (sourceFilePath != null) {
          final sourceFile = File(sourceFilePath);
          if (await sourceFile.exists()) {
            await sourceFile.copy(destPath);
            savedPath = destPath;
          }
        }
      } catch (e) {
        debugPrint('CustomStampsService: error saving stamp file: $e');
        return null;
      }
    }

    if (savedPath == null) return null;

    final newStamp = CustomStampItem(
      id: stampId,
      name: name.trim().isNotEmpty ? name.trim() : 'Штамп',
      imagePath: savedPath,
      groupId: groupId.trim().isNotEmpty ? groupId.trim() : 'custom_stamps',
      createdAt: timestamp,
    );

    final currentList = await loadCustomStamps();
    currentList.add(newStamp);
    _cachedItems = currentList;
    await _saveCustomStampsList(currentList);

    return newStamp;
  }

  Future<void> deleteCustomStamp(String id) async {
    final currentList = await loadCustomStamps();
    final idx = currentList.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final item = currentList[idx];
      if (!kIsWeb && !item.imagePath.startsWith('data:image')) {
        try {
          final file = File(item.imagePath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (_) {}
      }
      currentList.removeAt(idx);
      _cachedItems = currentList;
      await _saveCustomStampsList(currentList);
    }
  }

  Future<void> updateCustomStampGroup(String id, String newGroupId) async {
    final currentList = await loadCustomStamps();
    final idx = currentList.indexWhere((s) => s.id == id);
    if (idx != -1) {
      currentList[idx] = currentList[idx].copyWith(groupId: newGroupId);
      _cachedItems = currentList;
      await _saveCustomStampsList(currentList);
    }
  }

  Future<List<String>> loadCustomGroups({bool forceReload = false}) async {
    if (!forceReload && _cachedGroups != null) {
      return List<String>.from(_cachedGroups!);
    }
    final raw = _prefs.getStringList(_keyGroups);
    if (raw != null) {
      _cachedGroups = List<String>.from(raw);
      return List<String>.from(raw);
    }
    _cachedGroups = [];
    return [];
  }

  Future<void> addCustomGroup(String groupName) async {
    final trimmed = groupName.trim();
    if (trimmed.isEmpty) return;
    final current = await loadCustomGroups();
    if (!current.contains(trimmed)) {
      current.add(trimmed);
      _cachedGroups = current;
      await _prefs.setStringList(_keyGroups, current);
    }
  }

  Future<void> deleteCustomGroup(String groupName) async {
    final current = await loadCustomGroups();
    if (current.contains(groupName)) {
      current.remove(groupName);
      _cachedGroups = current;
      await _prefs.setStringList(_keyGroups, current);
    }
  }
}
