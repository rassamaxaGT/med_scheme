import 'package:shared_preferences/shared_preferences.dart';

/// Сервис хранения пресетов клиник, врачей, УЗ-аппаратов и датчиков в SharedPreferences
class ReportPresetsService {
  static const String _keyClinics = 'report_clinics_list';
  static const String _keyDefaultClinic = 'report_default_clinic';

  static const String _keyDoctors = 'report_doctors_list';
  static const String _keyDefaultDoctor = 'report_default_doctor';

  static const String _keyDevices = 'report_devices_list';
  static const String _keyDefaultDevice = 'report_default_device';

  static const String _keyProbes = 'report_probes_list';
  static const String _keySelectedProbe1 = 'report_selected_probe1';
  static const String _keySelectedProbe2 = 'report_selected_probe2';

  // Начальные списки оборудования и датчиков по умолчанию
  static const List<String> initialClinics = [
    'Кабинет ультразвуковой диагностики',
  ];

  static const List<String> initialDevices = [
    'GE Voluson E8',
    'GE Voluson E10',
    'Samsung WS80A',
    'Mindray Resona 7',
    'Canon Aplio i800',
  ];

  static const List<String> initialProbes = [
    'Конвексный C1-5 (трансабдоминальный)',
    'Полостной RIC5-9 (трансвагинальный)',
    'Линейный 9L',
    'Секторный M5S',
  ];

  final SharedPreferences _prefs;

  ReportPresetsService(this._prefs);

  static Future<ReportPresetsService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ReportPresetsService(prefs);
  }

  // ==================== КЛИНИКИ ====================

  List<String> getClinics() {
    final list = _prefs.getStringList(_keyClinics);
    if (list == null || list.isEmpty) {
      return List<String>.from(initialClinics);
    }
    return List<String>.from(list);
  }

  String getDefaultClinic() {
    final def = _prefs.getString(_keyDefaultClinic);
    if (def != null && def.isNotEmpty) {
      return def;
    }
    final all = getClinics();
    return all.isNotEmpty ? all.first : '';
  }

  Future<void> addClinic(String clinic, {bool makeDefault = false}) async {
    final trimmed = clinic.trim();
    if (trimmed.isEmpty) return;

    final list = getClinics();
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      await _prefs.setStringList(_keyClinics, list);
    }
    if (makeDefault || _prefs.getString(_keyDefaultClinic) == null) {
      await _prefs.setString(_keyDefaultClinic, trimmed);
    }
  }

  Future<void> setDefaultClinic(String clinic) async {
    await _prefs.setString(_keyDefaultClinic, clinic.trim());
  }

  Future<void> editClinic(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    final list = getClinics();
    final idx = list.indexOf(oldTrimmed);
    if (idx != -1) {
      list[idx] = newTrimmed;
      await _prefs.setStringList(_keyClinics, list);
    }
    if (getDefaultClinic() == oldTrimmed) {
      await _prefs.setString(_keyDefaultClinic, newTrimmed);
    }
  }

  Future<void> removeClinic(String clinic) async {
    final list = getClinics();
    list.remove(clinic.trim());
    await _prefs.setStringList(_keyClinics, list);
    if (getDefaultClinic() == clinic.trim()) {
      await _prefs.setString(_keyDefaultClinic, list.isNotEmpty ? list.first : '');
    }
  }

  // ==================== ВРАЧИ ====================

  List<String> getDoctors() {
    final list = _prefs.getStringList(_keyDoctors);
    return list != null ? List<String>.from(list) : <String>[];
  }

  String getDefaultDoctor() {
    return _prefs.getString(_keyDefaultDoctor) ?? '';
  }

  Future<void> addDoctor(String doctor, {bool makeDefault = false}) async {
    final trimmed = doctor.trim();
    if (trimmed.isEmpty) return;

    final list = getDoctors();
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      await _prefs.setStringList(_keyDoctors, list);
    }
    if (makeDefault || _prefs.getString(_keyDefaultDoctor) == null) {
      await _prefs.setString(_keyDefaultDoctor, trimmed);
    }
  }

  Future<void> setDefaultDoctor(String doctor) async {
    await _prefs.setString(_keyDefaultDoctor, doctor.trim());
  }

  Future<void> editDoctor(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    final list = getDoctors();
    final idx = list.indexOf(oldTrimmed);
    if (idx != -1) {
      list[idx] = newTrimmed;
      await _prefs.setStringList(_keyDoctors, list);
    }
    if (getDefaultDoctor() == oldTrimmed) {
      await _prefs.setString(_keyDefaultDoctor, newTrimmed);
    }
  }

  Future<void> removeDoctor(String doctor) async {
    final list = getDoctors();
    list.remove(doctor.trim());
    await _prefs.setStringList(_keyDoctors, list);
    if (getDefaultDoctor() == doctor.trim()) {
      await _prefs.setString(_keyDefaultDoctor, list.isNotEmpty ? list.first : '');
    }
  }

  // ==================== УЗ-АППАРАТЫ ====================

  List<String> getDevices() {
    final list = _prefs.getStringList(_keyDevices);
    if (list == null || list.isEmpty) {
      return List<String>.from(initialDevices);
    }
    return List<String>.from(list);
  }

  String getDefaultDevice() {
    final def = _prefs.getString(_keyDefaultDevice);
    if (def != null && def.isNotEmpty) {
      return def;
    }
    final all = getDevices();
    return all.isNotEmpty ? all.first : '';
  }

  Future<void> addDevice(String device, {bool makeDefault = false}) async {
    final trimmed = device.trim();
    if (trimmed.isEmpty) return;

    final list = getDevices();
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      await _prefs.setStringList(_keyDevices, list);
    }
    if (makeDefault || _prefs.getString(_keyDefaultDevice) == null) {
      await _prefs.setString(_keyDefaultDevice, trimmed);
    }
  }

  Future<void> setDefaultDevice(String device) async {
    await _prefs.setString(_keyDefaultDevice, device.trim());
  }

  Future<void> editDevice(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    final list = getDevices();
    final idx = list.indexOf(oldTrimmed);
    if (idx != -1) {
      list[idx] = newTrimmed;
      await _prefs.setStringList(_keyDevices, list);
    }
    if (getDefaultDevice() == oldTrimmed) {
      await _prefs.setString(_keyDefaultDevice, newTrimmed);
    }
  }

  Future<void> removeDevice(String device) async {
    final list = getDevices();
    list.remove(device.trim());
    await _prefs.setStringList(_keyDevices, list);
    if (getDefaultDevice() == device.trim()) {
      await _prefs.setString(_keyDefaultDevice, list.isNotEmpty ? list.first : '');
    }
  }

  // ==================== УЗ-ДАТЧИКИ ====================

  List<String> getProbes() {
    final list = _prefs.getStringList(_keyProbes);
    if (list == null || list.isEmpty) {
      return List<String>.from(initialProbes);
    }
    return List<String>.from(list);
  }

  String getSelectedProbe1() {
    final p = _prefs.getString(_keySelectedProbe1);
    if (p != null && p.isNotEmpty) return p;
    final probes = getProbes();
    return probes.isNotEmpty ? probes.first : '';
  }

  String getSelectedProbe2() {
    final p = _prefs.getString(_keySelectedProbe2);
    if (p != null) return p;
    final probes = getProbes();
    return probes.length > 1 ? probes[1] : '';
  }

  String getDefaultProbe() {
    return getSelectedProbe1();
  }

  Future<void> addProbe(String probe, {bool makeDefault = false}) async {
    final trimmed = probe.trim();
    if (trimmed.isEmpty) return;

    final list = getProbes();
    if (!list.contains(trimmed)) {
      list.add(trimmed);
      await _prefs.setStringList(_keyProbes, list);
    }
    if (makeDefault || _prefs.getString(_keySelectedProbe1) == null) {
      await _prefs.setString(_keySelectedProbe1, trimmed);
    }
  }

  Future<void> setDefaultProbe(String probe) async {
    await _prefs.setString(_keySelectedProbe1, probe.trim());
  }

  Future<void> editProbe(String oldName, String newName) async {
    final oldTrimmed = oldName.trim();
    final newTrimmed = newName.trim();
    if (oldTrimmed.isEmpty || newTrimmed.isEmpty || oldTrimmed == newTrimmed) return;

    final list = getProbes();
    final idx = list.indexOf(oldTrimmed);
    if (idx != -1) {
      list[idx] = newTrimmed;
      await _prefs.setStringList(_keyProbes, list);
    }
    if (getSelectedProbe1() == oldTrimmed) {
      await _prefs.setString(_keySelectedProbe1, newTrimmed);
    }
    if (getSelectedProbe2() == oldTrimmed) {
      await _prefs.setString(_keySelectedProbe2, newTrimmed);
    }
  }

  Future<void> setSelectedProbes(String probe1, String probe2) async {
    await _prefs.setString(_keySelectedProbe1, probe1.trim());
    await _prefs.setString(_keySelectedProbe2, probe2.trim());
  }

  Future<void> removeProbe(String probe) async {
    final list = getProbes();
    list.remove(probe.trim());
    await _prefs.setStringList(_keyProbes, list);
    if (getSelectedProbe1() == probe.trim()) {
      await _prefs.setString(_keySelectedProbe1, list.isNotEmpty ? list.first : '');
    }
    if (getSelectedProbe2() == probe.trim()) {
      await _prefs.setString(_keySelectedProbe2, '');
    }
  }
}
