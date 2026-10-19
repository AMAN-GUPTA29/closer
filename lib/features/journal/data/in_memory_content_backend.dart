import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/backend_errors.dart';
import '../../../core/utils/validators.dart';
import '../../groups/data/in_memory_groups_repository.dart';
import '../../notifications/domain/notification_models.dart';
import '../domain/journal_models.dart';
import 'content_backend.dart';

/// In-memory journal, milestones, notifications and profile for the debug
/// Preview mode and widget tests. Shares groups and photos with
/// [InMemoryGroupsRepository] and mirrors the server's rules.
class InMemoryContentBackend implements ContentBackend {
  InMemoryContentBackend(this.groups, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now {
    groups.photoRemovedListeners.add((photoId) {
      for (final id in _milestones.keys.toList()) {
        final m = _milestones[id]!;
        if (m.coverPhotoId == photoId) _milestones[id] = _copy(m, cover: null);
      }
    });
  }

  final InMemoryGroupsRepository groups;
  final DateTime Function() _clock;
  final _milestones = <String, Milestone>{};
  final _notifications = <AppNotification>[];
  var _prefs = const NotificationPreferences();
  Uint8List? _avatar;
  String? _avatarPath;
  String? _nameOverride;

  /// Preview/tests start with a username; set to null to test the gate.
  late String? username = Validators.normalizeUsername(
    groups.currentUserName.replaceAll(' ', '.'),
  );

  /// Usernames other (pretend) people already use.
  final takenUsernames = <String>{'sam', 'taken.name'};
  int _seq = 0;
  bool accountDeleted = false;

  Never _fail(String key) =>
      throw BackendFailure(backendMessage(key), key: key);

  void _requireMember(String groupId) {
    if (!groups.isMemberOf(groupId)) _fail('not_a_member');
  }

  Milestone _copy(Milestone m, {Object? cover = _keep, bool? pinned}) =>
      Milestone(
        id: m.id,
        groupId: m.groupId,
        title: m.title,
        type: m.type,
        eventDate: m.eventDate,
        theme: m.theme,
        description: m.description,
        coverPhotoId: identical(cover, _keep)
            ? m.coverPhotoId
            : cover as String?,
        createdBy: m.createdBy,
        isPinned: pinned ?? m.isPinned,
      );

  static const _keep = Object();

  /// Test/preview helper: adds a notification for the current user.
  void addNotification(AppNotification n) => _notifications.insert(0, n);

  @override
  Future<JournalPage> journal({
    String? groupId,
    JournalCursor? before,
    int limit = 30,
  }) async {
    final ids = groupId == null ? groups.myGroupIds() : [groupId];
    if (groupId != null) _requireMember(groupId);
    final today = _clock();
    final endOfToday = DateTime(today.year, today.month, today.day + 1);
    final entries = <JournalEntry>[
      for (final g in ids)
        for (final p in groups.activePhotosOf(g))
          PhotoEntry(p, p.takenAt ?? p.uploadedAt),
      for (final m in _milestones.values)
        if (ids.contains(m.groupId) && m.eventDate.isBefore(endOfToday))
          MilestoneEntry(
            _withCover(m),
            DateTime(
              m.eventDate.year,
              m.eventDate.month,
              m.eventDate.day,
              23,
              59,
              59,
            ),
          ),
    ];
    int cmp(JournalEntry a, JournalEntry b) {
      final c = b.occurredAt.compareTo(a.occurredAt);
      return c != 0 ? c : b.id.compareTo(a.id);
    }

    entries.sort(cmp);
    var list = entries;
    if (before != null) {
      list = list.where((e) {
        final c = e.occurredAt.compareTo(before.occurredAt);
        return c < 0 || (c == 0 && e.id.compareTo(before.id) < 0);
      }).toList();
    }
    return JournalPage(
      entries: list.take(limit).toList(),
      hasMore: list.length > limit,
    );
  }

  /// Adds the cover thumbnail path the server would join in.
  Milestone _withCover(Milestone m) {
    final photo = m.coverPhotoId == null
        ? null
        : groups
              .activePhotosOf(m.groupId)
              .where((p) => p.id == m.coverPhotoId)
              .firstOrNull;
    return Milestone(
      id: m.id,
      groupId: m.groupId,
      title: m.title,
      type: m.type,
      eventDate: m.eventDate,
      theme: m.theme,
      description: m.description,
      coverPhotoId: m.coverPhotoId,
      coverThumbPath: photo?.thumbPath,
      createdBy: m.createdBy,
      isPinned: m.isPinned,
    );
  }

  @override
  Future<List<Milestone>> milestones(String groupId) async {
    _requireMember(groupId);
    return _milestones.values
        .where((m) => m.groupId == groupId)
        .map(_withCover)
        .toList()
      ..sort((a, b) => b.eventDate.compareTo(a.eventDate));
  }

  void _validateCover(String groupId, String? photoId) {
    if (photoId != null && !groups.isActivePhotoIn(photoId, groupId)) {
      _fail('invalid_cover_photo');
    }
  }

  @override
  Future<Milestone> createMilestone(String groupId, MilestoneDraft d) async {
    _requireMember(groupId);
    _validateCover(groupId, d.coverPhotoId);
    if (d.title.trim().isEmpty) {
      throw const UnexpectedFailure('Give this moment a title.');
    }
    final m = Milestone(
      id: 'milestone-${++_seq}',
      groupId: groupId,
      title: d.title.trim(),
      type: d.type,
      eventDate: d.eventDate,
      theme: d.theme,
      description: d.description?.trim().isEmpty ?? true
          ? null
          : d.description!.trim(),
      coverPhotoId: d.coverPhotoId,
      createdBy: groups.currentUserId,
      isPinned: d.isPinned,
    );
    _milestones[m.id] = m;
    return m;
  }

  bool _canEdit(Milestone m) =>
      m.createdBy == groups.currentUserId || groups.isOwnerOf(m.groupId);

  @override
  Future<Milestone> updateMilestone(String id, MilestoneDraft d) async {
    final m = _milestones[id];
    if (m == null || !groups.isMemberOf(m.groupId) || !_canEdit(m)) {
      throw const PermissionFailure(
        'Only the person who added this moment or the group owner can edit it.',
      );
    }
    _validateCover(m.groupId, d.coverPhotoId);
    final updated = Milestone(
      id: id,
      groupId: m.groupId,
      title: d.title.trim(),
      type: d.type,
      eventDate: d.eventDate,
      theme: d.theme,
      description: d.description?.trim().isEmpty ?? true
          ? null
          : d.description!.trim(),
      coverPhotoId: d.coverPhotoId,
      createdBy: m.createdBy,
      isPinned: d.isPinned,
    );
    _milestones[id] = updated;
    return updated;
  }

  @override
  Future<void> deleteMilestone(String id) async {
    final m = _milestones[id];
    if (m == null || !groups.isMemberOf(m.groupId) || !_canEdit(m)) {
      throw const PermissionFailure(
        'Only the person who added this moment or the group owner can delete it.',
      );
    }
    _milestones.remove(id);
  }

  @override
  Future<List<AppNotification>> notifications({int limit = 50}) async =>
      _notifications
          .where((n) => groups.isMemberOf(n.groupId))
          .take(limit)
          .toList();

  @override
  Future<void> markNotificationsRead([List<int>? ids]) async {
    for (var i = 0; i < _notifications.length; i++) {
      final n = _notifications[i];
      if (n.isUnread && (ids == null || ids.contains(n.id))) {
        _notifications[i] = AppNotification(
          id: n.id,
          groupId: n.groupId,
          kind: n.kind,
          createdAt: n.createdAt,
          actorName: n.actorName,
          photoId: n.photoId,
          photoThumbPath: n.photoThumbPath,
          milestoneId: n.milestoneId,
          milestoneTitle: n.milestoneTitle,
          readAt: _clock(),
        );
      }
    }
  }

  @override
  Future<NotificationPreferences> notificationPreferences() async => _prefs;

  @override
  Future<void> saveNotificationPreferences(NotificationPreferences p) async =>
      _prefs = p;

  @override
  Future<UserProfile> myProfile() async => UserProfile(
    id: groups.currentUserId,
    displayName: _nameOverride ?? groups.currentUserName,
    avatarPath: _avatarPath,
    username: username,
    createdAt: joinedAt,
  );

  /// Account creation time shown by the welcome message.
  DateTime joinedAt = DateTime.now().subtract(const Duration(days: 3));

  @override
  Future<String> setUsername(String value) async {
    final v = Validators.normalizeUsername(value);
    if (Validators.username(v) != null) {
      _fail('invalid_username');
    }
    if (takenUsernames.contains(v)) {
      _fail('username_taken');
    }
    username = v;
    return v;
  }

  @override
  Future<bool> usernameAvailable(String value) async {
    final v = Validators.normalizeUsername(value);
    return Validators.username(v) == null && !takenUsernames.contains(v);
  }

  @override
  Future<void> updateDisplayName(String name) async {
    _nameOverride = name.trim();
    groups.currentUserName = name.trim();
  }

  @override
  Future<void> setAvatar(Uint8List jpeg) async {
    _avatar = jpeg;
    _avatarPath = '${groups.currentUserId}/avatar-${++_seq}.jpg';
  }

  @override
  Future<void> removeAvatar() async {
    _avatar = null;
    _avatarPath = null;
  }

  @override
  Future<ImageProvider> avatarImage(String path) async {
    final bytes = _avatar;
    if (bytes == null || path != _avatarPath) _fail('invalid_avatar');
    return MemoryImage(bytes);
  }

  @override
  Future<void> deleteAccount() async {
    accountDeleted = true;
  }

  /// Seeds preview content (milestones and a few notifications).
  void seedPreview() {
    final now = _clock();
    final ids = groups.myGroupIds();
    if (ids.isEmpty) return;
    final couple = ids.first;
    _milestones['milestone-p1'] = Milestone(
      id: 'milestone-p1',
      groupId: couple,
      title: '100 days together',
      type: MilestoneType.daysTogether,
      eventDate: DateTime(now.year, now.month, now.day - 82),
      theme: parseTheme('heart'),
      description: 'A hundred days of little moments that became big memories.',
      createdBy: groups.currentUserId,
      isPinned: true,
    );
    _milestones['milestone-p2'] = Milestone(
      id: 'milestone-p2',
      groupId: couple,
      title: 'Our first trip',
      type: MilestoneType.firstTrip,
      eventDate: DateTime(now.year, now.month, now.day - 40),
      theme: parseTheme('celebration'),
      createdBy: 'preview-partner',
    );
    _notifications.addAll([
      AppNotification(
        id: 1,
        groupId: couple,
        kind: NotificationKind.milestoneAdded,
        createdAt: now.subtract(const Duration(hours: 4)),
        actorName: 'Emma Rose',
        milestoneId: 'milestone-p2',
        milestoneTitle: 'Our first trip',
      ),
      if (ids.length > 1)
        AppNotification(
          id: 2,
          groupId: ids[1],
          kind: NotificationKind.memberJoined,
          createdAt: now.subtract(const Duration(days: 1, hours: 2)),
          actorName: 'Mia',
        ),
    ]);
  }
}
