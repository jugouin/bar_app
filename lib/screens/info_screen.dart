// lib/screens/info_screen.dart

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/events_catalog.dart';
import '../models/helloasso_event.dart';
import '../services/helloasso_service.dart';

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
        _eventsFuture = _service.fetchEvents();
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
      builder: (_) => _RegistrationSheet(
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
            _FilterBar(
              selected: _selectedFilter,
              onSelected: (type) =>
                  setState(() => _selectedFilter = type),
              typeConfig: _typeConfig,
            ),
            const SizedBox(height: 4),

            // ── Contenu ─────────────────────────────────────────────
            Expanded(
              child: FutureBuilder<List<HelloAssoEvent>>(
                future: _eventsFuture,
                builder: (context, snapshot) {
                  // Chargement
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: _blue),
                    );
                  }

                  // Erreur
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

                  // Filtrer + trier
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
                  final past =
                      allEvents.where(_isPast).toList();

                  return ListView(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    children: [
                      if (upcoming.isNotEmpty) ...[
                        _SectionHeader(label: "À venir"),
                        ...upcoming.map((e) => _EventCard(
                              event: e,
                              typeConfig: _typeConfig,
                              onTap: () => _openRegistration(e),
                            )),
                      ],
                      if (past.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        _SectionHeader(label: "Passés", muted: true),
                        ...past.map((e) => _EventCard(
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

// ── Bottom sheet inscription ─────────────────────────────────────────
class _RegistrationSheet extends StatefulWidget {
  final HelloAssoEvent event;
  final HelloAssoService service;
  final Map<EventType, ({String label, IconData icon, Color color})>
      typeConfig;

  const _RegistrationSheet({
    required this.event,
    required this.service,
    required this.typeConfig,
  });

  @override
  State<_RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<_RegistrationSheet> {
  bool _loading = false;
  static const _blue = Color(0xFF2D5478);

  Future<void> _inscrire() async {
    setState(() => _loading = true);
    try {
      final url = await widget.service.createCheckout(widget.event);
      if (!mounted) return;
      Navigator.pop(context);
      await launchUrl(Uri.parse(url),
          mode: LaunchMode.externalApplication);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erreur : $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cfg = widget.typeConfig[widget.event.type]!;
    final event = widget.event;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFEAF4FB),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(
          24, 16, 24, MediaQuery.of(context).viewInsets.bottom + 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _blue.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Type badge
          Row(
            children: [
              Icon(cfg.icon, size: 14, color: cfg.color),
              const SizedBox(width: 6),
              Text(
                cfg.label,
                style: TextStyle(
                  color: cfg.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Titre
          Text(
            event.title,
            style: const TextStyle(
              color: _blue,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          // Date
          _InfoRow(
            icon: Icons.calendar_today,
            label: _formatDateRange(event),
          ),
          // Horaire (optionnel)
          if (event.horaire != null) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.access_time,
              label: event.horaire!,
            ),
          ],
          const SizedBox(height: 8),
          // Prix
          _InfoRow(
            icon: Icons.euro,
            label: event.isGratuit
                ? 'Gratuit'
                : '${event.prix.toStringAsFixed(0)} €',
            labelColor:
                event.isGratuit ? Colors.green.shade700 : _blue,
          ),

          const SizedBox(height: 28),

          // Bouton S'inscrire
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _loading ? null : _inscrire,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.how_to_reg_outlined, size: 18),
              label: Text(
                _loading ? "Création du lien..." : "S'inscrire",
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                disabledBackgroundColor: _blue.withOpacity(0.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateRange(HelloAssoEvent e) {
    final start = _formatDate(e.dateStart);
    if (!e.isMultiDay) return start;
    return '$start → ${_formatDate(e.dateEnd!)}';
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}

// ── Info row ─────────────────────────────────────────────────────────
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;

  const _InfoRow({required this.icon, required this.label, this.labelColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 15, color: const Color(0xFF2D5478)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: labelColor ?? const Color(0xFF2D5478),
            fontSize: 14,
            fontWeight:
                labelColor != null ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ],
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
          _FilterChip(
            label: "Tous",
            icon: Icons.calendar_month,
            isSelected: selected == null,
            color: const Color(0xFF2D5478),
            onTap: () => onSelected(null),
          ),
          const SizedBox(width: 8),
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
            Icon(icon,
                size: 14, color: isSelected ? Colors.white : color),
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
  final HelloAssoEvent event;
  final Map<EventType, ({String label, IconData icon, Color color})>
      typeConfig;
  final bool muted;
  final VoidCallback onTap;

  const _EventCard({
    required this.event,
    required this.typeConfig,
    required this.onTap,
    this.muted = false,
  });

  static const _blue = Color(0xFF2D5478);

  @override
  Widget build(BuildContext context) {
    final cfg = typeConfig[event.type]!;

    return Opacity(
      opacity: muted ? 0.5 : 1.0,
      child: GestureDetector(
        onTap: onTap,
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
                // ── Bloc date ──────────────────────────────────────
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
                        event.dateStart.day.toString().padLeft(2, '0'),
                        style: TextStyle(
                          color: cfg.color,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _monthAbbr(event.dateStart.month),
                        style: TextStyle(
                          color: cfg.color,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                      // Multi-jours
                      if (event.isMultiDay) ...[
                        Padding(
                          padding:
                              const EdgeInsets.symmetric(vertical: 2),
                          child: Text('·',
                              style: TextStyle(
                                  color: cfg.color, fontSize: 10)),
                        ),
                        Text(
                          event.dateEnd!.day.toString().padLeft(2, '0'),
                          style: TextStyle(
                            color: cfg.color,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            height: 1,
                          ),
                        ),
                        Text(
                          _monthAbbr(event.dateEnd!.month),
                          style: TextStyle(
                            color: cfg.color,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 14),

                // ── Infos ──────────────────────────────────────────
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        event.title,
                        style: const TextStyle(
                          color: _blue,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
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
                          if (event.horaire != null)
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.access_time,
                                    size: 13, color: _blue),
                                const SizedBox(width: 4),
                                Text(
                                  event.horaire!,
                                  style: const TextStyle(
                                      color: _blue, fontSize: 12),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // ── Prix + flèche ──────────────────────────────────
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: event.isGratuit
                            ? Colors.green.shade50
                            : _blue.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: event.isGratuit
                              ? Colors.green.shade300
                              : _blue.withOpacity(0.25),
                        ),
                      ),
                      child: Text(
                        event.isGratuit
                            ? "Gratuit"
                            : "${event.prix.toStringAsFixed(0)} €",
                        style: TextStyle(
                          color: event.isGratuit
                              ? Colors.green.shade700
                              : _blue,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (!muted) ...[
                      const SizedBox(height: 8),
                      Icon(Icons.arrow_forward_ios,
                          size: 12, color: _blue.withOpacity(0.4)),
                    ],
                  ],
                ),
              ],
            ),
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