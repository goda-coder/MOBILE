import 'package:intl/intl.dart';

/// Format a minor-unit integer (e.g. 12345 piastres) into "123.45 EGP".
String formatMoney(int minor, {String currency = 'EGP', String locale = 'en_EG'}) {
  final f = NumberFormat.currency(
    locale: locale, name: currency, decimalDigits: 2, symbol: '',
  );
  return '${f.format(minor / 100).trim()} $currency';
}

/// Number-only formatting, no currency suffix.
String formatAmount(int minor, {String locale = 'en_EG'}) {
  final f = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = 2
    ..maximumFractionDigits = 2;
  return f.format(minor / 100);
}

/// Parse "12.34" -> 1234 (minor units). Returns null on bad input.
int? parseMinor(String input) {
  final t = input.trim().replaceAll(',', '');
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(t)) return null;
  final f = double.tryParse(t);
  if (f == null) return null;
  return (f * 100).round();
}

String formatRelative(DateTime d) {
  final diff = DateTime.now().difference(d);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours   < 24) return '${diff.inHours}h ago';
  if (diff.inDays    < 7)  return '${diff.inDays}d ago';
  return DateFormat.yMMMd().format(d);
}

String formatDateTime(DateTime d) => DateFormat.yMMMd().add_jm().format(d);
