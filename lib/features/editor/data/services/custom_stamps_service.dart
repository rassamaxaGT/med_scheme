import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Сервис автономного хранения пользовательских PNG-штампов в локальной директории приложения (Native)
/// или в SharedPreferences в виде Base64 Data URI (Web).
class CustomStampsService {
  static const int slotCount = 4;
  static const String _keySlotPrefix = 'custom_stamp_slot_';
  static const String _keyActiveSlot = 'custom_stamp_active_slot';

  final SharedPreferences _prefs;

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
}
