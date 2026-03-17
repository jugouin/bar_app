enum EventType { regateHabitable, regateVoileLegere, mobilisation }

class ClubEvent {
  final String id;
  final String title;
  final EventType type;
  final DateTime date;
  final String horaire; // ex: "09:00 - 17:00"
  final double? prix;  // null = gratuit

  const ClubEvent({
    required this.id,
    required this.title,
    required this.type,
    required this.date,
    required this.horaire,
    this.prix,
  });

  bool get isGratuit => prix == null;
}

final List<ClubEvent> eventsCatalog = [
  ClubEvent(
    id: '1',
    title: 'Championnat régional IRC',
    type: EventType.regateHabitable,
    date: DateTime(2026, 4, 5),
    horaire: '09:00 - 18:00',
    prix: 35.0,
  ),
  ClubEvent(
    id: '2',
    title: 'Série du printemps — J/80',
    type: EventType.regateHabitable,
    date: DateTime(2026, 4, 19),
    horaire: '10:00 - 17:00',
    prix: 20.0,
  ),
  ClubEvent(
    id: '3',
    title: 'Coupe Optimist jeunes',
    type: EventType.regateVoileLegere,
    date: DateTime(2026, 5, 3),
    horaire: '09:30 - 16:30',
    prix: 10.0,
  ),
  ClubEvent(
    id: '4',
    title: 'Journée Laser & RS Aero',
    type: EventType.regateVoileLegere,
    date: DateTime(2026, 5, 17),
    horaire: '10:00 - 17:00',
    prix: 15.0,
  ),
  ClubEvent(
    id: '5',
    title: 'Nettoyage du port',
    type: EventType.mobilisation,
    date: DateTime(2026, 4, 12),
    horaire: '08:00 - 12:00',
    prix: null, // gratuit
  ),
  ClubEvent(
    id: '6',
    title: 'Mise à l\'eau des bateaux école',
    type: EventType.mobilisation,
    date: DateTime(2026, 3, 29),
    horaire: '08:30 - 13:00',
    prix: null,
  ),
  ClubEvent(
    id: '7',
    title: 'Grand Prix du lac — IRC/ORC',
    type: EventType.regateHabitable,
    date: DateTime(2026, 6, 7),
    horaire: '08:00 - 19:00',
    prix: 45.0,
  ),
  ClubEvent(
    id: '8',
    title: 'Trophée Dériveurs seniors',
    type: EventType.regateVoileLegere,
    date: DateTime(2026, 6, 21),
    horaire: '10:00 - 17:30',
    prix: 12.0,
  ),
];