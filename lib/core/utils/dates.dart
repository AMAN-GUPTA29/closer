import 'package:intl/intl.dart';

/// Date policy (documented in docs/database.md):
///   * Relationship start dates are calendar dates without a time zone.
///   * "Days together" counts calendar days in the device's local time zone
///     and includes the start date, so the start date itself is day 1.
///   * Future start dates are not allowed by the backend.
int daysTogether(DateTime startDate, DateTime now) {
  final start = DateTime.utc(startDate.year, startDate.month, startDate.day);
  final today = DateTime.utc(now.year, now.month, now.day);
  final diff = today.difference(start).inDays;
  return diff < 0 ? 0 : diff + 1;
}

String daysTogetherLabel(int days) => days == 1
    ? '1 day together'
    : '${NumberFormat.decimalPattern().format(days)} days together';

/// Locale-aware medium date, e.g. "Apr 12, 2024".
String formatMediumDate(DateTime date) => DateFormat.yMMMd().format(date);

/// Short relative description of a past instant ("just now", "2h ago",
/// "3 days ago", or a date for anything older than a week).
String relativeTime(DateTime instant, DateTime now) {
  final diff = now.difference(instant);
  if (diff.isNegative || diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return formatMediumDate(instant.toLocal());
}

/// "expires in 6 days", "expires in 3 hours", "expired".
String expiryLabel(DateTime? expiresAt, DateTime now) {
  if (expiresAt == null) return 'never expires';
  final diff = expiresAt.difference(now);
  if (diff.isNegative) return 'expired';
  if (diff.inDays >= 1) {
    return 'expires in ${diff.inDays} ${diff.inDays == 1 ? 'day' : 'days'}';
  }
  if (diff.inHours >= 1) {
    return 'expires in ${diff.inHours} ${diff.inHours == 1 ? 'hour' : 'hours'}';
  }
  return 'expires in under an hour';
}

/// "expires in 6 days" → "Expires in 6 days".
String sentenceCase(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

/// "Mon", "Tue", … in the device locale.
String weekdayShort(DateTime date) => DateFormat.E().format(date);
