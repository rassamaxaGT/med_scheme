enum PageOrientation {
  portrait,
  landscape,
}

enum PngExportType {
  cleanScheme,
  fullMedicalCard,
}

enum SchemeLayoutMode {
  allOnSinglePage, // Все схемы размещаются на одной странице А4
  separatePages,   // Каждая схема на отдельной странице А4
}

/// Конфигурация параметров генерации медицинского отчета (PDF/PNG/Печать)
class ReportConfig {
  /// Ориентация листа в PDF
  final PageOrientation orientation;

  /// Режим размещения схем: все на 1 листе или на отдельных листах
  final SchemeLayoutMode layoutMode;

  /// Включать ли официальную шапку отчета (клиника, пациент, врач, дата)
  final bool includeHeader;

  /// Включать ли блок клинической легенды
  final bool includeLegend;

  /// Включать ли в легенду только реально нарисованные на схемах маркеры
  final bool includeOnlyActiveMarkersInLegend;

  /// Включать ли блок врачебных заметок / заключения
  final bool includeDoctorNotes;

  /// Название клиники или отделения
  final String clinicName;

  /// ФИО врача / УЗИ-специалиста
  final String doctorName;

  /// Идентификатор или ФИО пациента
  final String patientId;

  /// Модель или название УЗ-аппарата
  final String deviceModel;

  /// Используемые УЗ-датчики
  final String probes;

  /// Дата создания исследования
  final DateTime? createdAt;

  /// Текст заключения / описания исследования
  final String doctorNotes;

  /// Идентификаторы страниц для вывода в отчет (если пустой список — все страницы)
  final List<String> selectedPageIds;

  /// Множитель разрешения (1.0 = 72 dpi, 2.0 = 150 dpi, 3.0 = 300 dpi)
  final double dpiScale;

  /// Тип экспорта для PNG (только схема или готовый бланк)
  final PngExportType pngExportType;

  const ReportConfig({
    this.orientation = PageOrientation.landscape,
    this.layoutMode = SchemeLayoutMode.allOnSinglePage,
    this.includeHeader = true,
    this.includeLegend = false,
    this.includeOnlyActiveMarkersInLegend = true,
    this.includeDoctorNotes = false,
    this.clinicName = 'Кабинет ультразвуковой диагностики',
    this.doctorName = '',
    this.patientId = '',
    this.deviceModel = '',
    this.probes = '',
    this.createdAt,
    this.doctorNotes = '',
    this.selectedPageIds = const [],
    this.dpiScale = 2.0,
    this.pngExportType = PngExportType.fullMedicalCard,
  });

  ReportConfig copyWith({
    PageOrientation? orientation,
    SchemeLayoutMode? layoutMode,
    bool? includeHeader,
    bool? includeLegend,
    bool? includeOnlyActiveMarkersInLegend,
    bool? includeDoctorNotes,
    String? clinicName,
    String? doctorName,
    String? patientId,
    String? deviceModel,
    String? probes,
    DateTime? createdAt,
    String? doctorNotes,
    List<String>? selectedPageIds,
    double? dpiScale,
    PngExportType? pngExportType,
  }) {
    return ReportConfig(
      orientation: orientation ?? this.orientation,
      layoutMode: layoutMode ?? this.layoutMode,
      includeHeader: includeHeader ?? this.includeHeader,
      includeLegend: includeLegend ?? this.includeLegend,
      includeOnlyActiveMarkersInLegend:
          includeOnlyActiveMarkersInLegend ??
          this.includeOnlyActiveMarkersInLegend,
      includeDoctorNotes: includeDoctorNotes ?? this.includeDoctorNotes,
      clinicName: clinicName ?? this.clinicName,
      doctorName: doctorName ?? this.doctorName,
      patientId: patientId ?? this.patientId,
      deviceModel: deviceModel ?? this.deviceModel,
      probes: probes ?? this.probes,
      createdAt: createdAt ?? this.createdAt,
      doctorNotes: doctorNotes ?? this.doctorNotes,
      selectedPageIds: selectedPageIds ?? this.selectedPageIds,
      dpiScale: dpiScale ?? this.dpiScale,
      pngExportType: pngExportType ?? this.pngExportType,
    );
  }
}
