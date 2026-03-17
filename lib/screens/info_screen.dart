// lib/screens/info_screen.dart

import 'package:flutter/material.dart';
import '../data/events_catalog.dart';

class InfoScreen extends StatefulWidget {
  const InfoScreen({super.key});

  @override
  State<InfoScreen> createState() => _InfoScreenState();
}

class _InfoScreenState extends State<InfoScreen> {
  EventType? _selectedFilter; // null = tous

  static const _blue = Color(0xFF2D5478);
  static const _lightBlue = Color.fromARGB(255, 150, 201, 222);

  // Config par type
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

  List<ClubEvent> get _filteredEvents {
    final now = DateTime.now();
    final events = eventsCatalog
        .where((e) => _selectedFilter == null || e.type == _selectedFilter)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    // Séparer à venir / passés
    return events;
  }

  @override
  Widget build(BuildContext context) {
    final events = _filteredEvents;
    final now = DateTime.now();
    final upcoming = events.where((e) => !e.date.isBefore(
          DateTime(now.year, now.month, now.day),
        )).toList();
    final past = events.where((e) => e.date.isBefore(
          DateTime(now.year, now.month, now.day),
        )).toList();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primaryContainer,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        elevation: 0,
        title: const Text(
          "Agenda du club",
          style: TextStyle(
            color: _blue,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: _blue),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Filtres ───────────────────────────────────────────────
            _FilterBar(
              selected: _selectedFilter,
              onSelected: (type) =>
                  setState(() => _selectedFilter = type),
              typeConfig: _typeConfig,
            ),

            // ── Liste ─────────────────────────────────────────────────
            Expanded(
              child: events.isEmpty
                  ? const Center(
                      child: Text(
                        "Aucun événement",
                        style: TextStyle(color: _blue, fontSize: 14),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 12),
                      children: [
                        if (upcoming.isNotEmpty) ...[
                          _SectionHeader(label: "À venir"),
                          ...upcoming.map((e) => _EventCard(
                                event: e,
                                typeConfig: _typeConfig,
                              )),
                        ],
                        if (past.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _SectionHeader(label: "Passés", muted: true),
                          ...past.map((e) => _EventCard(
                                event: e,
                                typeConfig: _typeConfig,
                                muted: true,
                              )),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Barre de filtres ─────────────────────────────────────────────────
class _FilterBar extends StatelessWidget {
  final EventType? selected;
  final void Function(EventType?) onSelected;
  final Map<EventType, ({String label, IconData icon, Color color})>
      typeConfig;

  const _FilterBar({
    required this.selected,
    required this.onSelected,
    required this.typeConfig,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          // Chip "Tous"
          _FilterChip(
            label: "Tous",
            icon: Icons.calendar_month,
            isSelected: selected == null,
            color: const Color(0xFF2D5478),
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
          // Chips par type
          ...EventType.values.map((type) {
            final cfg = typeConfig[type]!;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _FilterChip(
                label: cfg.label,
                icon: cfg.icon,
                isSelected: selected == type,
                color: cfg.color,
                onTap: () =>
                    onSelected(selected == type ? null : type),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── En-tête de section ───────────────────────────────────────────────
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

// ── Carte événement ──────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final ClubEvent event;
  final Map<EventType, ({String label, IconData icon, Color color})>
      typeConfig;
  final bool muted;

  const _EventCard({
    required this.event,
    required this.typeConfig,
    this.muted = false,
  });

  @override
  Widget build(BuildContext context) {
    final cfg = typeConfig[event.type]!;
    final opacity = muted ? 0.5 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color.fromARGB(255, 150, 201, 222),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Bloc date ──────────────────────────────────────────
              Container(
                width: 52,
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: cfg.color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      event.date.day.toString().padLeft(2, '0'),
                      style: TextStyle(
                        color: cfg.color,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _monthAbbr(event.date.month),
                      style: TextStyle(
                        color: cfg.color,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 14),

              // ── Infos ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Titre
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Color(0xFF2D5478),
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Type + horaire
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(cfg.icon, size: 13, color: cfg.color),
                            const SizedBox(width: 4),
                            Text(
                              cfg.label,
                              style: TextStyle(
                                color: cfg.color,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time,
                                size: 13, color: Color(0xFF2D5478)),
                            const SizedBox(width: 4),
                            Text(
                              event.horaire,
                              style: const TextStyle(
                                color: Color(0xFF2D5478),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // ── Prix ───────────────────────────────────────────────
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: event.isGratuit
                      ? Colors.green.shade50
                      : const Color(0xFF2D5478).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: event.isGratuit
                        ? Colors.green.shade300
                        : const Color(0xFF2D5478).withOpacity(0.25),
                  ),
                ),
                child: Text(
                  event.isGratuit
                      ? "Gratuit"
                      : "${event.prix!.toStringAsFixed(0)} €",
                  style: TextStyle(
                    color: event.isGratuit
                        ? Colors.green.shade700
                        : const Color(0xFF2D5478),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _monthAbbr(int month) {
    const abbr = [
      '', 'JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUN',
      'JUL', 'AOÛ', 'SEP', 'OCT', 'NOV', 'DÉC',
    ];
    return abbr[month];
  }
}