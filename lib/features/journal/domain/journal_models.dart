import 'package:flutter/foundation.dart';

import '../../../core/models/group_type.dart';
import '../../../core/widgets/milestone_card.dart' show MilestoneTheme;
import '../../groups/domain/group_models.dart';
import '../../photos/domain/photo_models.dart';

enum MilestoneType {
  daysTogether('days_together'),
  anniversary('anniversary'),
  firstDate('first_date'),
  firstTrip('first_trip'),
  birthday('birthday'),
  holiday('holiday'),
  graduation('graduation'),
  reunion('reunion'),
  custom('custom');

  const MilestoneType(this.dbValue);
  final String dbValue;

  static MilestoneType parse(String? v) => MilestoneType.values.firstWhere(
    (t) => t.dbValue == v,
    orElse: () => MilestoneType.custom,
  );
}

MilestoneTheme parseTheme(String? v) => switch (v) {
  'heart' => MilestoneTheme.heart,
  'celebration' => MilestoneTheme.celebration,
  _ => MilestoneTheme.neutral,
};

@immutable
class Milestone {
  const Milestone({
    required this.id,
    required this.groupId,
    required this.title,
    required this.type,
    required this.eventDate,
    required this.theme,
    this.description,
    this.coverPhotoId,
    this.coverThumbPath,
    this.createdBy,
    this.isPinned = false,
  });

  factory Milestone.fromJson(Map<String, dynamic> json) => Milestone(
    id: json['id'] as String,
    groupId: json['group_id'] as String,
    title: json['title'] as String,
    type: MilestoneType.parse(json['type'] as String?),
    eventDate: parseDate(json['event_date'] as String),
    description: json['description'] as String?,
    coverPhotoId: json['cover_photo_id'] as String?,
    coverThumbPath:
        json['cover_thumb_path'] as String? ??
        (json['cover'] as Map<String, dynamic>?)?['thumb_path'] as String?,
    createdBy: json['created_by'] as String?,
    theme: parseTheme(json['theme'] as String?),
    isPinned: json['is_pinned'] as bool? ?? false,
  );

  final String id;
  final String groupId;
  final String title;
  final MilestoneType type;
  final DateTime eventDate;
  final String? description;
  final String? coverPhotoId;

  /// Thumbnail of the cover photo when it is still active.
  final String? coverThumbPath;
  final String? createdBy;
  final MilestoneTheme theme;
  final bool isPinned;

  /// "100" for "100 days together" style titles, shown as the big number.
  String? get highlightNumber =>
      RegExp(r'^(\d{1,5})(?!\d)').firstMatch(title.trim())?.group(1);

  bool isUpcoming(DateTime now) =>
      eventDate.isAfter(DateTime(now.year, now.month, now.day));
}

/// What the Special Moment form saves.
@immutable
class MilestoneDraft {
  const MilestoneDraft({
    required this.title,
    required this.type,
    required this.eventDate,
    required this.theme,
    this.description,
    this.coverPhotoId,
    this.isPinned = false,
  });

  final String title;
  final MilestoneType type;
  final DateTime eventDate;
  final MilestoneTheme theme;
  final String? description;
  final String? coverPhotoId;
  final bool isPinned;

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'type': type.dbValue,
    'event_date': formatDate(eventDate),
    'theme': theme.name,
    'description': (description?.trim().isEmpty ?? true)
        ? null
        : description!.trim(),
    'cover_photo_id': coverPhotoId,
    'is_pinned': isPinned,
  };
}

/// One row of a journal: a photo memory or a milestone.
sealed class JournalEntry {
  const JournalEntry();

  String get id;
  String get groupId;
  DateTime get occurredAt;
  bool get isPinned;

  static JournalEntry? fromJson(Map<String, dynamic> json) {
    final occurred = DateTime.parse(json['occurred_at'] as String);
    return switch (json['kind']) {
      'photo' => PhotoEntry(
        Photo.fromJson(json['photo'] as Map<String, dynamic>),
        occurred,
      ),
      'milestone' => MilestoneEntry(
        Milestone.fromJson(json['milestone'] as Map<String, dynamic>),
        occurred,
      ),
      _ => null, // Unknown kinds from a newer server are skipped.
    };
  }
}

class PhotoEntry extends JournalEntry {
  const PhotoEntry(this.photo, this.occurredAt);

  final Photo photo;
  @override
  final DateTime occurredAt;
  @override
  String get id => photo.id;
  @override
  String get groupId => photo.groupId;
  @override
  bool get isPinned => photo.isPinned;
}

class MilestoneEntry extends JournalEntry {
  const MilestoneEntry(this.milestone, this.occurredAt);

  final Milestone milestone;
  @override
  final DateTime occurredAt;
  @override
  String get id => milestone.id;
  @override
  String get groupId => milestone.groupId;
  @override
  bool get isPinned => milestone.isPinned;
}

/// Keyset cursor for the journal: (occurred_at, id).
@immutable
class JournalCursor {
  const JournalCursor(this.occurredAt, this.id);

  factory JournalCursor.after(JournalEntry e) =>
      JournalCursor(e.occurredAt, e.id);

  final DateTime occurredAt;
  final String id;
}

@immutable
class JournalPage {
  const JournalPage({required this.entries, required this.hasMore});

  final List<JournalEntry> entries;
  final bool hasMore;
}

/// Ready-made milestone starting points per group type.
@immutable
class MilestoneTemplate {
  const MilestoneTemplate(this.label, this.type, this.title, this.theme);

  final String label;
  final MilestoneType type;
  final String title;
  final MilestoneTheme theme;

  static List<MilestoneTemplate> forGroup(GroupType type) => switch (type) {
    GroupType.couple => const [
      MilestoneTemplate(
        'Anniversary',
        MilestoneType.anniversary,
        'Our anniversary',
        MilestoneTheme.heart,
      ),
      MilestoneTemplate(
        '100 days',
        MilestoneType.daysTogether,
        '100 days together',
        MilestoneTheme.heart,
      ),
      MilestoneTemplate(
        'First date',
        MilestoneType.firstDate,
        'Our first date',
        MilestoneTheme.heart,
      ),
      MilestoneTemplate(
        'First trip',
        MilestoneType.firstTrip,
        'Our first trip',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Birthday',
        MilestoneType.birthday,
        'Birthday',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Custom',
        MilestoneType.custom,
        '',
        MilestoneTheme.heart,
      ),
    ],
    GroupType.friends => const [
      MilestoneTemplate(
        'Trip',
        MilestoneType.firstTrip,
        'Our trip',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Birthday',
        MilestoneType.birthday,
        'Birthday',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Graduation',
        MilestoneType.graduation,
        'Graduation day',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Holiday',
        MilestoneType.holiday,
        'Holiday together',
        MilestoneTheme.neutral,
      ),
      MilestoneTemplate(
        'Custom',
        MilestoneType.custom,
        '',
        MilestoneTheme.neutral,
      ),
    ],
    GroupType.family => const [
      MilestoneTemplate(
        'Birthday',
        MilestoneType.birthday,
        'Birthday',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Reunion',
        MilestoneType.reunion,
        'Family reunion',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Holiday',
        MilestoneType.holiday,
        'Holidays together',
        MilestoneTheme.neutral,
      ),
      MilestoneTemplate(
        'Graduation',
        MilestoneType.graduation,
        'Graduation day',
        MilestoneTheme.celebration,
      ),
      MilestoneTemplate(
        'Custom',
        MilestoneType.custom,
        '',
        MilestoneTheme.neutral,
      ),
    ],
  };
}

/// An upcoming day worth counting down to.
@immutable
class Countdown {
  const Countdown(this.label, this.date, this.daysLeft);

  final String label;
  final DateTime date;
  final int daysLeft;
}

/// Next round-number day and next anniversary for a couple, both strictly
/// after today (local calendar dates; day 1 = start date).
List<Countdown> coupleCountdowns(DateTime start, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final s = DateTime(start.year, start.month, start.day);
  if (s.isAfter(today)) return const [];
  final out = <Countdown>[];

  final dayNumberToday =
      DateTime.utc(
        today.year,
        today.month,
        today.day,
      ).difference(DateTime.utc(s.year, s.month, s.day)).inDays +
      1;
  final nextHundred = (dayNumberToday ~/ 100 + 1) * 100;
  final hundredDate = DateTime(s.year, s.month, s.day + nextHundred - 1);
  out.add(
    Countdown(
      '$nextHundred days together',
      hundredDate,
      nextHundred - dayNumberToday,
    ),
  );

  var years = today.year - s.year;
  DateTime anniversary(int y) {
    // 29 Feb anniversaries fall on 28 Feb in non-leap years.
    final day = (s.month == 2 && s.day == 29 && !_isLeap(s.year + y))
        ? 28
        : s.day;
    return DateTime(s.year + y, s.month, day);
  }

  if (!anniversary(years).isAfter(today)) years++;
  if (years < 1) years = 1;
  final next = anniversary(years);
  out.add(
    Countdown(
      years == 1 ? '1st anniversary' : '${_ordinal(years)} anniversary',
      next,
      DateTime.utc(
        next.year,
        next.month,
        next.day,
      ).difference(DateTime.utc(today.year, today.month, today.day)).inDays,
    ),
  );
  out.sort((a, b) => a.daysLeft.compareTo(b.daysLeft));
  return out;
}

bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

String _ordinal(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}
