import '../data/events_catalog.dart'; // pour EventType

class HelloAssoEvent {
  final String id;
  final String slug;
  final String title;
  final EventType type;
  final DateTime dateStart;
  final DateTime? dateEnd;
  final String? horaire;
  final double prix; // 0 = gratuit

  HelloAssoEvent({
    required this.id,
    required this.slug,
    required this.title,
    required this.type,
    required this.dateStart,
    this.dateEnd,
    this.horaire,
    this.prix = 0,
  });

  bool get isGratuit => prix == 0;
  bool get isMultiDay =>
      dateEnd != null && dateEnd!.isAfter(dateStart);

  factory HelloAssoEvent.fromJson(Map<String, dynamic> json) {
    // Mapper le type HelloAsso vers EventType
    final formType = (json['formType'] as String?)?.toLowerCase() ?? '';
    EventType type;
    if (formType.contains('event')) {
      type = EventType.regateHabitable; // adapter selon vos types
    } else if (formType.contains('membership')) {
      type = EventType.mobilisation;
    } else {
      type = EventType.regateVoileLegere;
    }

    // Dates
    final startStr = json['startDate'] as String?;
    final endStr   = json['endDate']   as String?;
    final dateStart = startStr != null
        ? DateTime.parse(startStr)
        : DateTime.now();
    final dateEnd = endStr != null ? DateTime.parse(endStr) : null;

    // Prix : prendre le premier tier ou 0
    double prix = 0;
    final tiers = json['tiers'] as List<dynamic>?;
    if (tiers != null && tiers.isNotEmpty) {
      prix = ((tiers.first['price'] as num?)?.toDouble() ?? 0) / 100;
    }

    return HelloAssoEvent(
      id:        json['id']?.toString() ?? '',
      slug:      json['formSlug'] as String? ?? '',
      title:     json['title']    as String? ?? '',
      type:      type,
      dateStart: dateStart,
      dateEnd:   dateEnd,
      prix:      prix,
    );
  }
}