import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../../../../core/di/injection.dart';
import '../../../domain/entities/project_data.dart';
import '../../../domain/entities/report_config.dart';
import '../../../domain/repositories/project_repository.dart';
import '../../bloc/draw_bloc.dart';
import '../../bloc/project_bloc.dart';
import '../../../data/services/report_presets_service.dart';
import 'preset_management_dialog.dart';

/// Диалог настройки медицинского отчета с интерактивным предпросмотром и печатью
class PrintExportDialog extends StatefulWidget {
  final ProjectData projectData;

  const PrintExportDialog({
    super.key,
    required this.projectData,
  });

  static Future<void> show(BuildContext context) async {
    final drawState = context.read<DrawBloc>().state;
    final activePage = drawState.currentPage;
    final project = ProjectData(
      patientId: drawState.patientId,
      pages: [activePage],
    );

    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => Dialog.fullscreen(
        child: BlocProvider.value(
          value: context.read<ProjectBloc>(),
          child: PrintExportDialog(projectData: project),
        ),
      ),
    );
  }

  @override
  State<PrintExportDialog> createState() => _PrintExportDialogState();
}

class _PrintExportDialogState extends State<PrintExportDialog> {
  late ReportConfig _config;
  late TextEditingController _patientController;
  late TextEditingController _notesController;
  late TextEditingController _filenameController;
  Timer? _debounceTimer;
  bool _isPrinting = false;

  ReportPresetsService? _presetsService;
  List<String> _clinics = [];
  String _selectedClinic = '';
  List<String> _doctors = [];
  String _selectedDoctor = '';
  List<String> _devices = [];
  String _selectedDevice = '';
  List<String> _probes = [];
  String _selectedProbe1 = '';
  String _selectedProbe2 = '';
  DateTime _createdAt = DateTime.now();
  bool _isPresetsLoaded = false;

  final ProjectRepository _repository = getIt<ProjectRepository>();

  @override
  void initState() {
    super.initState();
    _config = ReportConfig(
      patientId: widget.projectData.patientId ?? '',
      orientation: PageOrientation.landscape,
      layoutMode: SchemeLayoutMode.allOnSinglePage,
      includeHeader: true,
      includeLegend: false,
      includeOnlyActiveMarkersInLegend: true,
      includeDoctorNotes: false,
      dpiScale: 2.0,
      pngExportType: PngExportType.fullMedicalCard,
    );

    _patientController = TextEditingController(text: _config.patientId);
    _notesController = TextEditingController(text: _config.doctorNotes);

    final defaultFilename = formatReportPdfFilename(
      patientId: _config.patientId,
      date: _createdAt,
    );
    _filenameController = TextEditingController(text: defaultFilename);

    _loadPresets();
  }

  Future<void> _loadPresets() async {
    try {
      final service = await ReportPresetsService.create();
      if (!mounted) return;
      setState(() {
        _presetsService = service;
        _clinics = service.getClinics();
        _selectedClinic = service.getDefaultClinic();

        _doctors = service.getDoctors();
        _selectedDoctor = service.getDefaultDoctor();

        _devices = service.getDevices();
        _selectedDevice = service.getDefaultDevice();

        _probes = service.getProbes();
        _selectedProbe1 = service.getSelectedProbe1();
        _selectedProbe2 = service.getSelectedProbe2();

        _config = _config.copyWith(
          clinicName: _selectedClinic,
          doctorName: _selectedDoctor,
          deviceModel: _selectedDevice,
          probes: _formattedProbesString(_selectedProbe1, _selectedProbe2),
          createdAt: _createdAt,
        );
        _isPresetsLoaded = true;
      });
    } catch (e) {
      debugPrint('Ошибка загрузки пресетов печати: $e');
      if (mounted) {
        setState(() => _isPresetsLoaded = true);
      }
    }
  }

  String _formattedProbesString(String p1, String p2) {
    final trimmed1 = p1.trim();
    final trimmed2 = p2.trim();
    if (trimmed1.isNotEmpty && trimmed2.isNotEmpty && trimmed1 != trimmed2) {
      return '$trimmed1, $trimmed2';
    } else if (trimmed1.isNotEmpty) {
      return trimmed1;
    } else if (trimmed2.isNotEmpty) {
      return trimmed2;
    }
    return '';
  }

  void _onFieldChanged() {
    _filenameController.text = formatReportPdfFilename(
      patientId: _patientController.text.trim(),
      date: _createdAt,
    );
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _patientController.dispose();
    _notesController.dispose();
    _filenameController.dispose();
    super.dispose();
  }

  ProjectData get _currentProjectData {
    return widget.projectData.copyWith(
      patientId: _patientController.text.trim(),
    );
  }

  ReportConfig get _currentConfig {
    return _config.copyWith(
      patientId: _patientController.text.trim(),
      doctorName: _selectedDoctor.trim(),
      clinicName: _selectedClinic.trim(),
      deviceModel: _selectedDevice.trim(),
      probes: _formattedProbesString(_selectedProbe1, _selectedProbe2),
      createdAt: _createdAt,
      doctorNotes: _notesController.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Печать и экспорт медицинского отчета', style: TextStyle(fontSize: 16)),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          OutlinedButton.icon(
            icon: const Icon(Icons.share, color: Colors.white, size: 16),
            label: const Text('Поделиться', style: TextStyle(color: Colors.white, fontSize: 13)),
            style: OutlinedButton.styleFrom(
              fixedSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              side: const BorderSide(color: Colors.white24),
            ),
            onPressed: _sharePdf,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.image, size: 16),
            label: const Text('Экспорт PNG', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              fixedSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: const Color(0xFF238636),
              foregroundColor: Colors.white,
            ),
            onPressed: _exportPng,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: const Icon(Icons.picture_as_pdf, size: 16),
            label: const Text('Сохранить PDF', style: TextStyle(fontSize: 13)),
            style: ElevatedButton.styleFrom(
              fixedSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            onPressed: _savePdf,
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(
            icon: _isPrinting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.print, size: 16),
            label: const Text('Печать', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              fixedSize: const Size.fromHeight(36),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              backgroundColor: const Color(0xFF0F4C81),
              foregroundColor: Colors.white,
            ),
            onPressed: _isPrinting ? null : _directPrint,
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Row(
        children: [
          // Левая панель: настройки параметров
          SizedBox(
            width: 340,
            child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161B22) : const Color(0xFFF6F8FA),
                border: Border(
                  right: BorderSide(
                    color: isDark ? const Color(0xFF30363D) : const Color(0xFFD0D7DE),
                  ),
                ),
              ),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildSectionTitle('Данные исследования'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _patientController,
                    decoration: const InputDecoration(
                      labelText: 'Пациент (ID / ФИО)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => _onFieldChanged(),
                  ),
                  const SizedBox(height: 10),
                  _buildClinicSelector(),
                  const SizedBox(height: 10),
                  _buildDoctorSelector(),
                  const SizedBox(height: 10),
                  _buildDeviceSelector(),
                  const SizedBox(height: 10),
                  _buildProbe1Selector(),
                  const SizedBox(height: 10),
                  _buildProbe2Selector(),
                  const SizedBox(height: 10),
                  _buildCreatedAtPicker(),

                  const SizedBox(height: 16),
                  _buildSectionTitle('Вёрстка и страницы'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<SchemeLayoutMode>(
                    initialValue: _config.layoutMode,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Размещение схем',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: SchemeLayoutMode.allOnSinglePage,
                        child: Text(
                          'Все схемы на 1 листе А4',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: SchemeLayoutMode.separatePages,
                        child: Text(
                          'Каждая схема на отдельном листе',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _config = _config.copyWith(layoutMode: val));
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<PageOrientation>(
                    initialValue: _config.orientation,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Ориентация страницы',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PageOrientation.landscape,
                        child: Text(
                          'Альбомная (Landscape)',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: PageOrientation.portrait,
                        child: Text(
                          'Книжная (Portrait)',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _config = _config.copyWith(orientation: val));
                      }
                    },
                  ),

                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Шапка отчета', style: TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _config.includeHeader,
                    onChanged: (val) => setState(() => _config = _config.copyWith(includeHeader: val)),
                  ),
                  SwitchListTile(
                    title: const Text('Клиническая легенда', style: TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _config.includeLegend,
                    onChanged: (val) => setState(() => _config = _config.copyWith(includeLegend: val)),
                  ),
                  if (_config.includeLegend)
                    SwitchListTile(
                      title: const Text('Только активные маркеры', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      dense: true,
                      contentPadding: const EdgeInsets.only(left: 12),
                      value: _config.includeOnlyActiveMarkersInLegend,
                      onChanged: (val) => setState(() => _config = _config.copyWith(includeOnlyActiveMarkersInLegend: val)),
                    ),
                  SwitchListTile(
                    title: const Text('Блок заключения врача', style: TextStyle(fontSize: 13)),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _config.includeDoctorNotes,
                    onChanged: (val) => setState(() => _config = _config.copyWith(includeDoctorNotes: val)),
                  ),
                  if (_config.includeDoctorNotes) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _notesController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Текст заключения / Заметки',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      onChanged: (val) => _onFieldChanged(),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _buildSectionTitle('Параметры PNG'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<PngExportType>(
                    initialValue: _config.pngExportType,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Формат экспорта PNG',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: PngExportType.fullMedicalCard,
                        child: Text(
                          'Медицинский бланк',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      DropdownMenuItem(
                        value: PngExportType.cleanScheme,
                        child: Text(
                          'Чистая схема',
                          style: TextStyle(fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _config = _config.copyWith(pngExportType: val));
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          // Правая панель: интерактивный предпросмотр
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF0D1117) : const Color(0xFFEAEEF2),
              child: !_isPresetsLoaded
                  ? const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(strokeWidth: 2.5),
                          SizedBox(height: 12),
                          Text('Подготовка отчета...', style: TextStyle(fontSize: 13)),
                        ],
                      ),
                    )
                  : PdfPreview(
                      maxPageWidth: 700,
                      canChangeOrientation: false,
                      canChangePageFormat: false,
                      canDebug: false,
                      useActions: false,
                      dynamicLayout: false,
                      dpi: 120.0,
                      loadingWidget: const Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(strokeWidth: 2.5),
                            SizedBox(height: 12),
                            Text('Формирование бланка...', style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                      build: (PdfPageFormat format) => _repository.generateReportPdf(
                        project: _currentProjectData,
                        config: _currentConfig,
                        isForPreview: true,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClinicSelector() {
    final clinics = List<String>.from(_clinics);
    if (_selectedClinic.isNotEmpty && !clinics.contains(_selectedClinic)) {
      clinics.insert(0, _selectedClinic);
    }
    final value = clinics.contains(_selectedClinic)
        ? _selectedClinic
        : (clinics.isNotEmpty ? clinics.first : null);

    return DropdownButtonFormField<String>(
      key: ValueKey('clinic_${value ?? ""}'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Клиника / Отделение',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        ...clinics.map((c) {
          final isDefault = _presetsService?.getDefaultClinic() == c;
          return DropdownMenuItem<String>(
            value: c,
            child: Row(
              children: [
                if (isDefault) ...[
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    c,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const DropdownMenuItem<String>(
          value: '__manage_clinics__',
          child: Row(
            children: [
              Icon(Icons.tune, size: 14, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'Настроить список...',
                style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == '__manage_clinics__') {
          _showManageClinicsDialog();
          return;
        }
        if (val != null) {
          setState(() => _selectedClinic = val);
          _onFieldChanged();
        }
      },
    );
  }

  Future<void> _showManageClinicsDialog() async {
    if (_presetsService == null) return;
    await PresetManagementDialog.show(
      context: context,
      title: 'Управление списком клиник',
      itemLabel: 'Клиника / Отделение',
      initialItems: _presetsService!.getClinics(),
      initialDefault: _presetsService!.getDefaultClinic(),
      onAdd: (name, makeDefault) => _presetsService!.addClinic(name, makeDefault: makeDefault),
      onRemove: (name) => _presetsService!.removeClinic(name),
      onSetDefault: (name) => _presetsService!.setDefaultClinic(name),
    );

    if (mounted) {
      setState(() {
        _clinics = _presetsService!.getClinics();
        final def = _presetsService!.getDefaultClinic();
        if (!_clinics.contains(_selectedClinic)) {
          _selectedClinic = def;
        }
      });
      _onFieldChanged();
    }
  }

  Widget _buildDoctorSelector() {
    final doctors = List<String>.from(_doctors);
    if (_selectedDoctor.isNotEmpty && !doctors.contains(_selectedDoctor)) {
      doctors.insert(0, _selectedDoctor);
    }
    final value = doctors.contains(_selectedDoctor) ? _selectedDoctor : '';

    return DropdownButtonFormField<String>(
      key: ValueKey('doc_$value'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'ФИО врача УЗД',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('(Не указан)', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        ...doctors.map((d) {
          final isDefault = _presetsService?.getDefaultDoctor() == d;
          return DropdownMenuItem<String>(
            value: d,
            child: Row(
              children: [
                if (isDefault) ...[
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    d,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const DropdownMenuItem<String>(
          value: '__manage_doctors__',
          child: Row(
            children: [
              Icon(Icons.tune, size: 14, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'Настроить список...',
                style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == '__manage_doctors__') {
          _showManageDoctorsDialog();
          return;
        }
        if (val != null) {
          setState(() => _selectedDoctor = val);
          _onFieldChanged();
        }
      },
    );
  }

  Future<void> _showManageDoctorsDialog() async {
    if (_presetsService == null) return;
    await PresetManagementDialog.show(
      context: context,
      title: 'Управление списком врачей УЗД',
      itemLabel: 'ФИО врача',
      initialItems: _presetsService!.getDoctors(),
      initialDefault: _presetsService!.getDefaultDoctor(),
      onAdd: (name, makeDefault) => _presetsService!.addDoctor(name, makeDefault: makeDefault),
      onRemove: (name) => _presetsService!.removeDoctor(name),
      onSetDefault: (name) => _presetsService!.setDefaultDoctor(name),
    );

    if (mounted) {
      setState(() {
        _doctors = _presetsService!.getDoctors();
        final def = _presetsService!.getDefaultDoctor();
        if (!_doctors.contains(_selectedDoctor)) {
          _selectedDoctor = def;
        }
      });
      _onFieldChanged();
    }
  }

  Widget _buildDeviceSelector() {
    final devices = List<String>.from(_devices);
    if (_selectedDevice.isNotEmpty && !devices.contains(_selectedDevice)) {
      devices.insert(0, _selectedDevice);
    }
    final value = devices.contains(_selectedDevice)
        ? _selectedDevice
        : (devices.isNotEmpty ? devices.first : null);

    return DropdownButtonFormField<String>(
      key: ValueKey('dev_${value ?? ""}'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'УЗ-аппарат',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        ...devices.map((dev) {
          final isDefault = _presetsService?.getDefaultDevice() == dev;
          return DropdownMenuItem<String>(
            value: dev,
            child: Row(
              children: [
                if (isDefault) ...[
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    dev,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const DropdownMenuItem<String>(
          value: '__manage_devices__',
          child: Row(
            children: [
              Icon(Icons.tune, size: 14, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'Настроить список...',
                style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == '__manage_devices__') {
          _showManageDevicesDialog();
          return;
        }
        if (val != null) {
          setState(() => _selectedDevice = val);
          _onFieldChanged();
        }
      },
    );
  }

  Future<void> _showManageDevicesDialog() async {
    if (_presetsService == null) return;
    await PresetManagementDialog.show(
      context: context,
      title: 'Управление списком УЗ-аппаратов',
      itemLabel: 'Модель аппарата',
      initialItems: _presetsService!.getDevices(),
      initialDefault: _presetsService!.getDefaultDevice(),
      onAdd: (name, makeDefault) => _presetsService!.addDevice(name, makeDefault: makeDefault),
      onRemove: (name) => _presetsService!.removeDevice(name),
      onSetDefault: (name) => _presetsService!.setDefaultDevice(name),
    );

    if (mounted) {
      setState(() {
        _devices = _presetsService!.getDevices();
        final def = _presetsService!.getDefaultDevice();
        if (!_devices.contains(_selectedDevice)) {
          _selectedDevice = def;
        }
      });
      _onFieldChanged();
    }
  }

  Widget _buildProbe1Selector() {
    final probes = List<String>.from(_probes);
    if (_selectedProbe1.isNotEmpty && !probes.contains(_selectedProbe1)) {
      probes.insert(0, _selectedProbe1);
    }
    final value = probes.contains(_selectedProbe1)
        ? _selectedProbe1
        : (probes.isNotEmpty ? probes.first : null);

    return DropdownButtonFormField<String>(
      key: ValueKey('p1_${value ?? ""}'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'УЗ-датчик 1 (основной)',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        ...probes.map((p) {
          final isDefault = _presetsService?.getDefaultProbe() == p;
          return DropdownMenuItem<String>(
            value: p,
            child: Row(
              children: [
                if (isDefault) ...[
                  const Icon(Icons.star, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    p,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          );
        }),
        const DropdownMenuItem<String>(
          value: '__manage_probes__',
          child: Row(
            children: [
              Icon(Icons.tune, size: 14, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'Настроить список...',
                style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == '__manage_probes__') {
          _showManageProbesDialog();
          return;
        }
        if (val != null) {
          setState(() => _selectedProbe1 = val);
          _presetsService?.setSelectedProbes(_selectedProbe1, _selectedProbe2);
          _onFieldChanged();
        }
      },
    );
  }

  Future<void> _showManageProbesDialog() async {
    if (_presetsService == null) return;
    await PresetManagementDialog.show(
      context: context,
      title: 'Управление списком УЗ-датчиков',
      itemLabel: 'Тип / модель датчика',
      initialItems: _presetsService!.getProbes(),
      initialDefault: _presetsService!.getDefaultProbe(),
      onAdd: (name, makeDefault) => _presetsService!.addProbe(name, makeDefault: makeDefault),
      onRemove: (name) => _presetsService!.removeProbe(name),
      onSetDefault: (name) => _presetsService!.setDefaultProbe(name),
    );

    if (mounted) {
      setState(() {
        _probes = _presetsService!.getProbes();
        final def = _presetsService!.getDefaultProbe();
        if (!_probes.contains(_selectedProbe1)) {
          _selectedProbe1 = def;
        }
        if (_selectedProbe2.isNotEmpty && !_probes.contains(_selectedProbe2)) {
          _selectedProbe2 = '';
        }
      });
      _presetsService!.setSelectedProbes(_selectedProbe1, _selectedProbe2);
      _onFieldChanged();
    }
  }

  Widget _buildProbe2Selector() {
    final probes = List<String>.from(_probes);
    if (_selectedProbe2.isNotEmpty && !probes.contains(_selectedProbe2)) {
      probes.insert(0, _selectedProbe2);
    }
    final value = probes.contains(_selectedProbe2) ? _selectedProbe2 : '';

    return DropdownButtonFormField<String>(
      key: ValueKey('p2_$value'),
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'УЗ-датчик 2 (дополнительный)',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      items: [
        const DropdownMenuItem<String>(
          value: '',
          child: Text('(Не используется)', style: TextStyle(fontSize: 13, color: Colors.grey)),
        ),
        ...probes.map((p) {
          return DropdownMenuItem<String>(
            value: p,
            child: Text(
              p,
              style: const TextStyle(fontSize: 13),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
        const DropdownMenuItem<String>(
          value: '__manage_probes__',
          child: Row(
            children: [
              Icon(Icons.tune, size: 14, color: Color(0xFF58A6FF)),
              SizedBox(width: 6),
              Text(
                'Настроить список...',
                style: TextStyle(fontSize: 12, color: Color(0xFF58A6FF)),
              ),
            ],
          ),
        ),
      ],
      onChanged: (val) {
        if (val == '__manage_probes__') {
          _showManageProbesDialog();
          return;
        }
        if (val != null) {
          setState(() => _selectedProbe2 = val);
          _presetsService?.setSelectedProbes(_selectedProbe1, _selectedProbe2);
          _onFieldChanged();
        }
      },
    );
  }

  Widget _buildCreatedAtPicker() {
    return InkWell(
      onTap: _pickCreatedAtDate,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Дата создания',
          border: OutlineInputBorder(),
          isDense: true,
          suffixIcon: Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          _formatDateTime(_createdAt),
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  Future<void> _pickCreatedAtDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _createdAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (pickedDate != null && mounted) {
      final pickedTime = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(_createdAt),
      );
      if (mounted) {
        setState(() {
          _createdAt = DateTime(
            pickedDate.year,
            pickedDate.month,
            pickedDate.day,
            pickedTime?.hour ?? _createdAt.hour,
            pickedTime?.minute ?? _createdAt.minute,
          );
        });
        _onFieldChanged();
      }
    }
  }

  String _formatDateTime(DateTime dt) {
    final day = dt.day.toString().padLeft(2, '0');
    final month = dt.month.toString().padLeft(2, '0');
    final year = dt.year.toString();
    final hour = dt.hour.toString().padLeft(2, '0');
    final min = dt.minute.toString().padLeft(2, '0');
    return '$day.$month.$year $hour:$min';
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.bold,
        color: Color(0xFF58A6FF),
      ),
    );
  }

  Future<void> _directPrint() async {
    setState(() => _isPrinting = true);
    try {
      final pdfBytes = await _repository.generateReportPdf(
        project: _currentProjectData,
        config: _currentConfig,
      );

      final docName = _filenameController.text.trim().isNotEmpty
          ? _filenameController.text.trim()
          : formatReportPdfFilename(
              patientId: _patientController.text.trim(),
              date: _createdAt,
            );

      await Printing.layoutPdf(
        name: docName,
        onLayout: (PdfPageFormat format) async => pdfBytes,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки на печать: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isPrinting = false);
      }
    }
  }

  void _savePdf() {
    final filename = _filenameController.text.trim().isNotEmpty
        ? _filenameController.text.trim()
        : formatReportPdfFilename(
            patientId: _patientController.text.trim(),
            date: _createdAt,
          );
    context.read<ProjectBloc>().add(
      ExportReportPdfEvent(
        projectName: filename,
        project: _currentProjectData,
        config: _currentConfig,
      ),
    );
    Navigator.of(context).pop();
  }

  void _exportPng() {
    final filename = _filenameController.text.trim();
    context.read<ProjectBloc>().add(
      ExportReportPngEvent(
        projectName: filename.isNotEmpty ? filename : 'УЗИ_схема',
        project: _currentProjectData,
        config: _currentConfig,
      ),
    );
    Navigator.of(context).pop();
  }

  Future<void> _sharePdf() async {
    try {
      final bytes = await _repository.generateReportPdf(
        project: _currentProjectData,
        config: _currentConfig,
      );
      final baseName = _filenameController.text.trim().isNotEmpty
          ? _filenameController.text.trim()
          : formatReportPdfFilename(
              patientId: _patientController.text.trim(),
              date: _createdAt,
            );
      final filename = '$baseName.pdf';
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка отправки: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
