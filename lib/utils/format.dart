import 'package:intl/intl.dart';

/// Pakistani (lakh/crore) digit grouping: Rs 1,25,000 / Rs 2,50,00,000
String formatMoney(double value, {bool withDecimals = true}) {
  final negative = value < 0;
  final abs = value.abs();
  var intPart = abs.truncate();
  var frac = ((abs - intPart) * 100).round();
  if (frac == 100) {
    intPart += 1;
    frac = 0;
  }
  final grouped = _groupPakistani(intPart.toString());
  final sign = negative ? '-' : '';
  if (!withDecimals || frac == 0) return 'Rs $sign$grouped';
  return 'Rs $sign$grouped.${frac.toString().padLeft(2, '0')}';
}

String _groupPakistani(String digits) {
  if (digits.length <= 3) return digits;
  final last3 = digits.substring(digits.length - 3);
  var rest = digits.substring(0, digits.length - 3);
  final parts = <String>[];
  while (rest.length > 2) {
    parts.insert(0, rest.substring(rest.length - 2));
    rest = rest.substring(0, rest.length - 2);
  }
  if (rest.isNotEmpty) parts.insert(0, rest);
  parts.add(last3);
  return parts.join(',');
}

/// Compact form for chart labels: 1.25 L, 2.5 Cr, 950
String formatCompact(double value) {
  final abs = value.abs();
  final sign = value < 0 ? '-' : '';
  if (abs >= 10000000) return '$sign${_trim(abs / 10000000)} Cr';
  if (abs >= 100000) return '$sign${_trim(abs / 100000)} L';
  if (abs >= 1000) return '$sign${_trim(abs / 1000)} K';
  return formatMoney(value);
}

String _trim(double v) {
  return v.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');
}

/// "2026-09"
String monthKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}';

DateTime monthDate(String key) {
  final parts = key.split('-');
  return DateTime(int.parse(parts[0]), int.parse(parts[1]));
}

String prevMonthKey(String key) {
  final d = monthDate(key);
  return monthKey(DateTime(d.year, d.month - 1));
}

String nextMonthKey(String key) {
  final d = monthDate(key);
  return monthKey(DateTime(d.year, d.month + 1));
}

String monthLabel(String key) => DateFormat('MMM yyyy').format(monthDate(key));

String fullMonthLabel(String key) =>
    DateFormat('MMMM yyyy').format(monthDate(key));

String dayLabel(DateTime d) => DateFormat('d MMM yyyy').format(d);

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;
