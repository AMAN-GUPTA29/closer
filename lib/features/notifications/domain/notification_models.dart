import 'package:flutter/foundation.dart';

enum NotificationKind {
  photoAdded('photo_added'),
  memberJoined('member_joined'),
  milestoneAdded('milestone_added'),
  unknown('');

  const NotificationKind(this.dbValue);
  final String dbValue;

  static NotificationKind parse(String? v) =>
      NotificationKind.values.firstWhere(
        (k) => k.dbValue == v,
        orElse: () => NotificationKind.unknown,
      );
}

/// An in-app notification. Carries ids and names only, never captions.
@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.groupId,
    required this.kind,
    required this.createdAt,
    this.actorName,
    this.photoId,
    this.photoThumbPath,
    this.milestoneId,
    this.milestoneTitle,
    this.readAt,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final actor = json['actor'] as Map<String, dynamic>?;
    final photo = json['photo'] as Map<String, dynamic>?;
    final milestone = json['milestone'] as Map<String, dynamic>?;
    final read = json['read_at'] as String?;
    return AppNotification(
      id: (json['id'] as num).toInt(),
      groupId: json['group_id'] as String,
      kind: NotificationKind.parse(json['kind'] as String?),
      createdAt: DateTime.parse(json['created_at'] as String),
      actorName: actor?['display_name'] as String?,
      photoId: json['photo_id'] as String?,
      // Null when the photo was removed since: handled gracefully.
      photoThumbPath: photo?['thumb_path'] as String?,
      milestoneId: json['milestone_id'] as String?,
      milestoneTitle: milestone?['title'] as String?,
      readAt: read == null ? null : DateTime.parse(read),
    );
  }

  final int id;
  final String groupId;
  final NotificationKind kind;
  final DateTime createdAt;
  final String? actorName;
  final String? photoId;
  final String? photoThumbPath;
  final String? milestoneId;
  final String? milestoneTitle;
  final DateTime? readAt;

  bool get isUnread => readAt == null;

  /// "Emma shared a new photo in My Love".
  String message(String groupName) {
    final who = actorName ?? 'Someone';
    return switch (kind) {
      NotificationKind.photoAdded => '$who shared a new photo in $groupName',
      NotificationKind.memberJoined => '$who joined $groupName',
      NotificationKind.milestoneAdded =>
        milestoneTitle == null
            ? '$who added a special moment in $groupName'
            : '$who added “$milestoneTitle” in $groupName',
      NotificationKind.unknown => 'New activity in $groupName',
    };
  }
}

@immutable
class NotificationPreferences {
  const NotificationPreferences({
    this.photos = true,
    this.members = true,
    this.milestones = true,
  });

  factory NotificationPreferences.fromJson(Map<String, dynamic> json) =>
      NotificationPreferences(
        photos: json['photos'] as bool? ?? true,
        members: json['members'] as bool? ?? true,
        milestones: json['milestones'] as bool? ?? true,
      );

  final bool photos;
  final bool members;
  final bool milestones;

  NotificationPreferences copyWith({
    bool? photos,
    bool? members,
    bool? milestones,
  }) => NotificationPreferences(
    photos: photos ?? this.photos,
    members: members ?? this.members,
    milestones: milestones ?? this.milestones,
  );

  Map<String, dynamic> toJson() => {
    'photos': photos,
    'members': members,
    'milestones': milestones,
  };

  @override
  bool operator ==(Object other) =>
      other is NotificationPreferences &&
      other.photos == photos &&
      other.members == members &&
      other.milestones == milestones;

  @override
  int get hashCode => Object.hash(photos, members, milestones);
}

@immutable
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    this.avatarPath,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: json['id'] as String,
    displayName: json['display_name'] as String,
    avatarPath: json['avatar_path'] as String?,
  );

  final String id;
  final String displayName;
  final String? avatarPath;
}
