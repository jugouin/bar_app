import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/helloasso_event.dart';
import '../services/helloasso_service.dart';


class RegistrationSheet extends StatefulWidget {
  final HelloAssoEvent event;
  final HelloAssoService service;
  final Map<EventType, ({String label, IconData icon, Color color})> typeConfig;

  const RegistrationSheet({
    super.key,
    required this.event,
    required this.service,
    required this.typeConfig,
  });

  @override
  State<RegistrationSheet> createState() => _RegistrationSheetState();
}

class _RegistrationSheetState extends State<RegistrationSheet> {
  bool _loading = false;
  static const _blue = Color(0xFF2D5478);

  Future<void> _inscrire() async {
    setState(() => _loading = true);
    try {
      final url = await widget.service.createCheckout(widget.event);
      if (!mounted) return;
      Navigator.pop(context);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
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
          EventInfoRow(
            icon: Icons.calendar_today,
            label: _formatDateRange(event),
          ),
          // Horaire (optionnel)
          if (event.horaire != null) ...[
            const SizedBox(height: 8),
            EventInfoRow(
              icon: Icons.access_time,
              label: event.horaire!,
            ),
          ],
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
                _loading ? "Redirection vers HelloAsso..." : "S'inscrire",
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

// ── Ligne d'info réutilisable ────────────────────────────────────────
class EventInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? labelColor;

  const EventInfoRow({
    super.key,
    required this.icon,
    required this.label,
    this.labelColor,
  });

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