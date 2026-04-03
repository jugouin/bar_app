import 'package:bar_app/models/helloasso_event.dart';
import 'package:flutter/material.dart';

class EventFilterBar extends StatelessWidget {
  final EventType? selected;
  final void Function(EventType?) onSelected;
  final Map<EventType, ({String label, IconData icon, Color color})> typeConfig;

  const EventFilterBar({
    super.key,
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
                onTap: () => onSelected(selected == type ? null : type),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : color),
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
