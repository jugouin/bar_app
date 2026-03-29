const List<String> trigramMonths = [
  '', 'JAN', 'FÉV', 'MAR', 'AVR', 'MAI', 'JUN',
  'JUL', 'AOÛ', 'SEP', 'OCT', 'NOV', 'DÉC',
];

const List<String> fullMonths = [
  '',
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre',
];

/// 01/03/2026
String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}/'
    '${d.month.toString().padLeft(2, '0')}/'
    '${d.year}';

/// "mars 2026"
String formatMonthYear(int month, int year) =>
    '${fullMonths[month]} $year';

/// "mars 2026" depuis un monthKey "2026-03"
String formatMonthKey(String monthKey) {
  final parts = monthKey.split('-');
  return formatMonthYear(int.parse(parts[1]), int.parse(parts[0]));
}

/// "01/03/2026 → 05/03/2026" ou "01/03/2026" si même jour
String formatDateRange(DateTime start, DateTime? end) {
  if (end == null || _sameDay(start, end)) return formatDate(start);
  return '${formatDate(start)} → ${formatDate(end)}';
}

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;