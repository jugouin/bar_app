// lib/data/events_catalog.dart

enum EventType { regateHabitable, regateVoileLegere, mobilisation }

class ClubEvent {
  final String id;
  final String title;
  final EventType type;
  final DateTime dateStart;
  final DateTime? dateEnd;   // null = événement sur 1 jour
  final String? horaire;     // null = pas d'horaire affiché
  final double? prix;        // null = gratuit

  const ClubEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.dateStart,
    this.dateEnd,
    this.horaire,
    this.prix,
  });

  bool get isGratuit => prix == null;
  bool get isMultiDay =>
      dateEnd != null &&
      !dateEnd!.isAtSameMomentAs(dateStart) &&
      dateEnd!.isAfter(dateStart);
}

final List<ClubEvent> eventsCatalog = [
  ClubEvent(
    id: '1',
    title: 'Semaine du soir Voile légère',
    type: EventType.regateHabitable,
    dateStart: DateTime(2026, 7, 8),
    dateEnd: DateTime(2026, 7, 11),
    horaire: '18:00 - 20:30',
    prix: 15.0,
  ),
  ClubEvent(
    id: '2',
    title: 'Série du printemps — J/80',
    type: EventType.regateHabitable,
    dateStart: DateTime(2026, 4, 19),
    horaire: '10:00 - 17:00',
    prix: 20.0,
  ),
  ClubEvent(
    id: '3',
    title: 'Coupe Optimist jeunes',
    type: EventType.regateVoileLegere,
    dateStart: DateTime(2026, 5, 3),
    horaire: '09:30 - 16:30',
    prix: 10.0,
  ),
  ClubEvent(
    id: '4',
    title: 'Journée Laser & RS Aero',
    type: EventType.regateVoileLegere,
    dateStart: DateTime(2026, 5, 17),
    horaire: '10:00 - 17:00',
    prix: 15.0,
  ),
  ClubEvent(
    id: '5',
    title: 'Nettoyage du port',
    type: EventType.mobilisation,
    dateStart: DateTime(2026, 4, 12),
    horaire: '08:00 - 12:00',
    // gratuit, pas de prix
  ),
  ClubEvent(
    id: '6',
    title: "Mise à l'eau des bateaux école",
    type: EventType.mobilisation,
    dateStart: DateTime(2026, 3, 29),
    // pas d'horaire précis
  ),
  ClubEvent(
    id: '7',
    title: 'Grand Prix du lac — IRC/ORC',
    type: EventType.regateHabitable,
    dateStart: DateTime(2026, 6, 7),
    dateEnd: DateTime(2026, 6, 9),
    horaire: '08:00 - 19:00',
    prix: 45.0,
  ),
  ClubEvent(
    id: '8',
    title: 'Trophée Dériveurs seniors',
    type: EventType.regateVoileLegere,
    dateStart: DateTime(2026, 6, 21),
    dateEnd: DateTime(2026, 6, 22),
    horaire: '10:00 - 17:30',
    prix: 12.0,
  ),
];