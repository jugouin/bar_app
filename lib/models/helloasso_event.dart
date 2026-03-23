enum EventType { regateHabitable, regateVoileLegere, mobilisation }

class HelloAssoEvent {
  final String id;
  final String slug;
  final String title;
  final EventType type;
  final DateTime dateStart;
  final DateTime? dateEnd;
  final String? horaire;

  HelloAssoEvent({
    required this.id,
    required this.slug,
    required this.title,
    required this.type,
    required this.dateStart,
    this.dateEnd,
    this.horaire,
  });

  bool get isMultiDay =>
      dateEnd != null && dateEnd!.isAfter(dateStart);

  factory HelloAssoEvent.fromJson(Map<String, dynamic> json) {
    final startDate = DateTime.parse(json['startDate'] as String);
    final endDate   = json['endDate'] != null
        ? DateTime.parse(json['endDate'] as String)
        : null;

    // Horaire si même jour
    String? horaire;
    if (endDate != null &&
        startDate.day == endDate.day &&
        startDate.month == endDate.month) {
      horaire =
          '${_pad(startDate.hour)}:${_pad(startDate.minute)} - '
          '${_pad(endDate.hour)}:${_pad(endDate.minute)}';
    }

    return HelloAssoEvent(
      id:        json['formSlug'] as String? ?? '',
      slug:      json['formSlug'] as String? ?? '',
      title:     json['title']    as String? ?? '',
      type:      _mapType(json['description'] as String? ?? ''),
      dateStart: DateTime(startDate.year, startDate.month, startDate.day),
      dateEnd:   endDate != null
          ? DateTime(endDate.year, endDate.month, endDate.day)
          : null,
      horaire:   horaire,
    );
  }

  static EventType _mapType(String description) {
    final d = description.toLowerCase();
    if (d.contains('habitable') || d.contains('vh') || d.contains('suprise')) {
      return EventType.regateHabitable;
    }
    if (d.contains('l\u00e9gere') || d.contains('legere') || d.contains('vl') ||
        d.contains('optimist') || d.contains('laser') ||
        d.contains('d\u00e9riveur') || d.contains('deriveur')) {
      return EventType.regateVoileLegere;
    }
    return EventType.mobilisation;
  }

  static String _pad(int n) => n.toString().padLeft(2, '0');
}