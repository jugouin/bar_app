import 'package:flutter/material.dart';
import '../models/helloasso_event.dart';
import '../utils/date.dart';

class EventCard extends StatelessWidget {
  final HelloAssoEvent event;
  final Map<EventType, ({String label, IconData icon, Color color})> typeConfig;
  final bool muted;
  final VoidCallback onTap;

  const EventCard({
    super.key,
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
                  width: event.isMultiDay ? 110 : 52,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: cfg.color.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: event.isMultiDay
                      // Deux dates côte à côte avec une flèche
                      ? Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _DateBlock(
                              day: event.dateStart.day,
                              month: event.dateStart.month,
                              color: cfg.color,
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 4),
                              child: Text(
                                '→',
                                style: TextStyle(
                                  color: cfg.color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            _DateBlock(
                              day: event.dateEnd!.day,
                              month: event.dateEnd!.month,
                              color: cfg.color,
                            ),
                          ],
                        )
                      // Date unique
                      : _DateBlock(
                          day: event.dateStart.day,
                          month: event.dateStart.month,
                          color: cfg.color,
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

                // ── Flèche ─────────────────────────────────────────
                if (!muted)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Icon(
                      Icons.arrow_forward_ios,
                      size: 12,
                      color: _blue.withOpacity(0.4),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bloc jour + mois ─────────────────────────────────────────────────
class _DateBlock extends StatelessWidget {
  final int day;
  final int month;
  final Color color;

  const _DateBlock({
    required this.day,
    required this.month,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          day.toString().padLeft(2, '0'),
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            height: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          trigramMonths[month],
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }
}