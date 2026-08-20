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
  late TextEditingController _doctorController;
  late TextEditingController _clinicController;
  late TextEditingController _notesController;
  late TextEditingController _filenameController;
  Timer? _debounceTimer;
  bool _isPrinting = false;

  final ProjectRepository _repository = getIt<ProjectRepository>();

  @override
  void initState() {
    super.initState();
    _config = ReportConfig(
      patientId: widget.projectData.patientId ?? '',
      orientation: PageOrientation.landscape,
      layoutMode: SchemeLayoutMode.allOnSinglePage,
      includeHeader: true,
      includeLegend: true,
      includeOnlyActiveMarkersInLegend: true,
      includeDoctorNotes: true,
      dpiScale: 2.0,
      pngExportType: PngExportType.fullMedicalCard,
    );

    _patientController = TextEditingController(text: _config.patientId);
    _doctorController = TextEditingController(text: _config.doctorName);
    _clinicController = TextEditingController(text: _config.clinicName);
    _notesController = TextEditingController(text: _config.doctorNotes);

    final defaultFilename = (_config.patientId.isNotEmpty)
        ? 'УЗИ_${_config.patientId}_${DateTime.now().millisecondsSinceEpoch}'
        : 'УЗИ_отчет_${DateTime.now().millisecondsSinceEpoch}';
    _filenameController = TextEditingController(text: defaultFilename);
  }

  void _onFieldChanged() {
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
    _doctorController.dispose();
    _clinicController.dispose();
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
      doctorName: _doctorController.text.trim(),
      clinicName: _clinicController.text.trim(),
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
                  TextField(
                    controller: _doctorController,
                    decoration: const InputDecoration(
                      labelText: 'ФИО врача УЗД',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => _onFieldChanged(),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _clinicController,
                    decoration: const InputDecoration(
                      labelText: 'Клиника / Отделение',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    onChanged: (val) => _onFieldChanged(),
                  ),

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
              child: PdfPreview(
                maxPageWidth: 700,
                canChangeOrientation: false,
                canChangePageFormat: false,
                canDebug: false,
                useActions: false,
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
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

      final patient = _patientController.text.trim().isNotEmpty
          ? _patientController.text.trim()
          : 'report';
      final docName = 'УЗИ_${patient}_${DateTime.now().millisecondsSinceEpoch}';

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
    final filename = _filenameController.text.trim();
    context.read<ProjectBloc>().add(
      ExportReportPdfEvent(
        projectName: filename.isNotEmpty ? filename : 'УЗИ_отчет',
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
      final filename = '${_filenameController.text.trim()}.pdf';
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
