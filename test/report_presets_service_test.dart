import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:med_scheme/features/editor/data/services/report_presets_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ReportPresetsService Tests', () {
    late ReportPresetsService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      service = await ReportPresetsService.create();
    });

    test('Initial clinics should contain default clinic', () {
      final clinics = service.getClinics();
      expect(clinics, isNotEmpty);
      expect(service.getDefaultClinic(), 'Кабинет ультразвуковой диагностики');
    });

    test('Adding clinic and setting default clinic works', () async {
      await service.addClinic('Клиника Эксперт', makeDefault: true);
      expect(service.getClinics(), contains('Клиника Эксперт'));
      expect(service.getDefaultClinic(), 'Клиника Эксперт');

      await service.addClinic('Госпиталь №1', makeDefault: false);
      expect(service.getClinics(), contains('Госпиталь №1'));
      expect(service.getDefaultClinic(), 'Клиника Эксперт');

      await service.setDefaultClinic('Госпиталь №1');
      expect(service.getDefaultClinic(), 'Госпиталь №1');

      await service.removeClinic('Госпиталь №1');
      expect(service.getClinics(), isNot(contains('Госпиталь №1')));
    });

    test('Doctors management works as expected', () async {
      expect(service.getDoctors(), isEmpty);
      expect(service.getDefaultDoctor(), '');

      await service.addDoctor('Иванова А.А.', makeDefault: true);
      expect(service.getDoctors(), contains('Иванова А.А.'));
      expect(service.getDefaultDoctor(), 'Иванова А.А.');

      await service.addDoctor('Петров Б.Б.', makeDefault: false);
      expect(service.getDoctors().length, 2);

      await service.removeDoctor('Иванова А.А.');
      expect(service.getDoctors(), isNot(contains('Иванова А.А.')));
      expect(service.getDefaultDoctor(), 'Петров Б.Б.');
    });

    test('Devices and Probes management works as expected', () async {
      final devices = service.getDevices();
      expect(devices, contains('GE Voluson E8'));
      expect(service.getDefaultDevice(), 'GE Voluson E8');

      await service.addDevice('Mindray Nuewa I9', makeDefault: true);
      expect(service.getDefaultDevice(), 'Mindray Nuewa I9');

      final probes = service.getProbes();
      expect(probes, isNotEmpty);
      expect(service.getSelectedProbe1(), contains('Конвексный'));
      expect(service.getSelectedProbe2(), contains('Полостной'));

      await service.addProbe('Матричный 3D/4D');
      expect(service.getProbes(), contains('Матричный 3D/4D'));

      await service.setSelectedProbes('Матричный 3D/4D', '');
      expect(service.getSelectedProbe1(), 'Матричный 3D/4D');
      expect(service.getSelectedProbe2(), '');

      await service.setDefaultProbe('Линейный 9L');
      expect(service.getDefaultProbe(), 'Линейный 9L');
    });

    test('Editing clinics, doctors, devices, and probes works correctly', () async {
      // Clinic editing
      await service.addClinic('Клиника 1', makeDefault: true);
      await service.editClinic('Клиника 1', 'Клиника 1 Обновленная');
      expect(service.getClinics(), contains('Клиника 1 Обновленная'));
      expect(service.getDefaultClinic(), 'Клиника 1 Обновленная');

      // Doctor editing
      await service.addDoctor('Врач Старый', makeDefault: true);
      await service.editDoctor('Врач Старый', 'Врач Новый');
      expect(service.getDoctors(), contains('Врач Новый'));
      expect(service.getDefaultDoctor(), 'Врач Новый');

      // Device editing
      await service.addDevice('Аппарат Старый', makeDefault: true);
      await service.editDevice('Аппарат Старый', 'Аппарат Новый');
      expect(service.getDevices(), contains('Аппарат Новый'));
      expect(service.getDefaultDevice(), 'Аппарат Новый');

      // Probe editing
      await service.addProbe('Датчик Старый', makeDefault: true);
      await service.editProbe('Датчик Старый', 'Датчик Новый');
      expect(service.getProbes(), contains('Датчик Новый'));
      expect(service.getSelectedProbe1(), 'Датчик Новый');
    });
  });
}
