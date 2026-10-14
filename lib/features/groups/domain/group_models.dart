import 'package:flutter/foundation.dart';

import '../../../core/models/group_type.dart';

enum MemberRole {
  owner,
  member;

  static MemberRole parse(String? value) =>
      value == 'owner' ? MemberRole.owner : MemberRole.member;
}

/// A group as listed on Home (from the `group_summaries` view).
@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.lastActivityAt,
    required this.memberCount,
    required this.myRole,
    this.createdBy,
    this.coverPath,
    this.relationshipStartDate,
    this.showRelationshipCounter = true,
    this.photoCount = 0,
    this.isPremium = false,
    this.latestThumbPath,
    this.coverPhotoId,
  });

  factory Group.fromJson(Map<String, dynamic> json) {
    final start = json['relationship_start_date'] as String?;
    return Group(
      id: json['id'] as String,
      name: json['name'] as String,
      type: GroupType.parse(json['type'] as String),
      createdBy: json['created_by'] as String?,
      coverPath: json['cover_path'] as String?,
      relationshipStartDate: start == null ? null : parseDate(start),
      showRelationshipCounter:
          json['show_relationship_counter'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastActivityAt: DateTime.parse(json['last_activity_at'] as String),
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
      myRole: MemberRole.parse(json['my_role'] as String?),
      photoCount: (json['photo_count'] as num?)?.toInt() ?? 0,
      isPremium: json['is_premium'] as bool? ?? false,
      latestThumbPath: json['latest_thumb_path'] as String?,
      coverPhotoId: json['cover_photo_id'] as String?,
    );
  }

  /// Photos kept by a Basic group (mirrors `basic_photo_limit()` on the
  /// server, which is authoritative).
  static const basicPhotoLimit = 10;

  final String id;
  final String name;
  final GroupType type;
  final String? createdBy;
  final String? coverPath;

  /// Calendar date (no time zone) for couple groups.
  final DateTime? relationshipStartDate;
  final bool showRelationshipCounter;
  final DateTime createdAt;
  final DateTime lastActivityAt;
  final int memberCount;
  final MemberRole myRole;

  /// Active photos in the group.
  final int photoCount;

  /// Closer Memories (server-side entitlement, including grace period).
  final bool isPremium;

  /// Thumbnail of the cover: the chosen cover photo, else the newest photo.
  final String? latestThumbPath;

  /// Photo explicitly chosen as cover by the owner (null = newest photo).
  final String? coverPhotoId;

  /// True when the next upload will remove the oldest photo.
  bool get nextUploadRemovesOldest =>
      !isPremium && photoCount >= basicPhotoLimit;

  bool get isOwner => myRole == MemberRole.owner;

  /// Couple groups are full at two members.
  bool get isFull =>
      type.maxMembers != null && memberCount >= (type.maxMembers ?? 0);

  bool get hasCounter =>
      type == GroupType.couple &&
      showRelationshipCounter &&
      relationshipStartDate != null;

  /// Stable placeholder art per group until real covers exist.
  int get placeholderVariant => id.codeUnits.fold(0, (a, b) => a + b) % 4;

  Group copyWith({
    String? name,
    DateTime? relationshipStartDate,
    bool clearRelationshipStartDate = false,
    bool? showRelationshipCounter,
    int? memberCount,
    MemberRole? myRole,
    int? photoCount,
    bool? isPremium,
  }) {
    return Group(
      id: id,
      name: name ?? this.name,
      type: type,
      createdBy: createdBy,
      coverPath: coverPath,
      relationshipStartDate: clearRelationshipStartDate
          ? null
          : relationshipStartDate ?? this.relationshipStartDate,
      showRelationshipCounter:
          showRelationshipCounter ?? this.showRelationshipCounter,
      createdAt: createdAt,
      lastActivityAt: lastActivityAt,
      memberCount: memberCount ?? this.memberCount,
      myRole: myRole ?? this.myRole,
      photoCount: photoCount ?? this.photoCount,
      isPremium: isPremium ?? this.isPremium,
      latestThumbPath: latestThumbPath,
      coverPhotoId: coverPhotoId,
    );
  }
}

@immutable
class GroupMember {
  const GroupMember({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.joinedAt,
    this.avatarPath,
  });

  factory GroupMember.fromJson(Map<String, dynamic> json) {
    final profile = json['profiles'] as Map<String, dynamic>?;
    return GroupMember(
      userId: json['user_id'] as String,
      displayName: profile?['display_name'] as String? ?? 'Member',
      avatarPath: profile?['avatar_path'] as String?,
      role: MemberRole.parse(json['role'] as String?),
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }

  final String userId;
  final String displayName;
  final String? avatarPath;
  final MemberRole role;
  final DateTime joinedAt;

  bool get isOwner => role == MemberRole.owner;
}

/// Parses a `date` column ("2024-04-12") as a local calendar date.
DateTime parseDate(String value) {
  final p = value.split('-').map(int.parse).toList();
  return DateTime(p[0], p[1], p[2]);
}

/// Formats a calendar date for a `date` column.
String formatDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
