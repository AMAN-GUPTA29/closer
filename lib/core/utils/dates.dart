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

/// Medium date, e.g. "12 Apr 2024".
String formatMediumDate(DateTime date) => DateFormat('d MMM y').format(date);

/// Long date, e.g. "22 April 2026".
String formatLongDate(DateTime date) => DateFormat('d MMMM y').format(date);

/// "8 September" this year, "8 September 2025" otherwise.
String formatDayMonth(DateTime date, [DateTime? now]) =>
    date.year == (now ?? DateTime.now()).year
    ? DateFormat('d MMMM').format(date)
    : formatLongDate(date);

/// "7 Nov" this year, "7 Nov 2027" otherwise.
String formatShortDayMonth(DateTime date, [DateTime? now]) =>
    date.year == (now ?? DateTime.now()).year
    ? DateFormat('d MMM').format(date)
    : formatMediumDate(date);

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
