import 'package:flutter/material.dart';
import '../models/helloasso_event.dart';
import '../services/helloasso_service.dart';
import '../widgets/event_card.dart';
import '../widgets/event_filter_bar.dart';
import '../widgets/registration_sheet.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  final _service = HelloAssoService();
  late Future<List<HelloAssoEvent>> _eventsFuture;
  EventType? _selectedFilter;

  static const _blue = Color(0xFF2D5478);

  static const _typeConfig = {
    EventType.regateHabitable: (
      label: 'Régate habitable',
      icon: Icons.sailing,
      color: Color(0xFF1A6B8A),
    ),
    EventType.regateVoileLegere: (
      label: 'Voile légère',
      icon: Icons.wind_power,
      color: Color(0xFF2D5478),
    ),
    EventType.mobilisation: (
      label: 'Mobilisation',
      icon: Icons.groups_rounded,
      color: Color(0xFF3D7A6B),
    ),
  };

  @override
  void initState() {
    super.initState();
    _eventsFuture = _service.fetchEvents();
  }

  void _refresh() => setState(() {
    _eventsFuture = _service.refreshEvents();
  });

  bool _isPast(HelloAssoEvent e) {
    final today = DateTime(
        DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return (e.dateEnd ?? e.dateStart).isBefore(today);
  }

  void _openRegistration(HelloAssoEvent event) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => RegistrationSheet(
        event: event,
        service: _service,
        typeConfig: _typeConfig,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Agenda du club",
          style: TextStyle(color: _blue, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: _blue),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: _blue),
            onPressed: _refresh,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filtres ─────────────────────────────────────────────
            EventFilterBar(
              selected: _selectedFilter,
              onSelected: (type) => setState(() => _selectedFilter = type as EventType?),
              typeConfig: _typeConfig,
            ),
            const SizedBox(height: 4),

            // ── Contenu ─────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<HelloAssoEvent>>(
                future: _eventsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _blue),
                    );
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.wifi_off, color: _blue, size: 40),
                          const SizedBox(height: 12),
                          const Text(
                            'Impossible de charger les événements',
                            style: TextStyle(color: _blue),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _refresh,
                            icon: const Icon(Icons.refresh, size: 16),
                            label: const Text('Réessayer'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _blue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final allEvents = (snapshot.data ?? [])
                      .where((e) =>
                          _selectedFilter == null ||
                          e.type == _selectedFilter)
                      .toList()
                    ..sort((a, b) => a.dateStart.compareTo(b.dateStart));

                  if (allEvents.isEmpty) {
                    return const Center(
                      child: Text(
                        'Aucun événement',
                        style: TextStyle(color: _blue, fontSize: 14),
                      ),
                    );
                  }

                  final upcoming =
                      allEvents.where((e) => !_isPast(e)).toList();
                  final past = allEvents.where(_isPast).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _SectionHeader(label: "À venir"),
                        ...upcoming.map((e) => EventCard(
                              event: e,
                              typeConfig: _typeConfig,
                              onTap: () => _openRegistration(e),
                            )),
                      ],
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _SectionHeader(label: "Passés", muted: true),
                        ...past.map((e) => EventCard(
                              event: e,
                              typeConfig: _typeConfig,
                              muted: true,
                              onTap: () => _openRegistration(e),
                            )),
                      ],
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section header (privé à cet écran) ──────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  final bool muted;

  const _SectionHeader({required this.label, this.muted = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 4),
      child: Text(
        label,
        style: TextStyle(
          color: muted
              ? const Color(0xFF2D5478).withOpacity(0.45)
              : const Color(0xFF2D5478),
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}