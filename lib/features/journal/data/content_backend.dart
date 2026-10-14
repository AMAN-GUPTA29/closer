import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/widgets.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;
import 'package:uuid/uuid.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/backend_errors.dart';
import '../../notifications/domain/notification_models.dart';
import '../domain/journal_models.dart';

/// Journal, milestones, notifications and the user's own profile.
abstract interface class ContentBackend {
  /// Mixed journal, newest first. [groupId] null = all of my groups.
  Future<JournalPage> journal({
    String? groupId,
    JournalCursor? before,
    int limit = 30,
  });

  Future<List<Milestone>> milestones(String groupId);
  Future<Milestone> createMilestone(String groupId, MilestoneDraft draft);
  Future<Milestone> updateMilestone(String id, MilestoneDraft draft);
  Future<void> deleteMilestone(String id);

  Future<List<AppNotification>> notifications({int limit = 50});
  Future<void> markNotificationsRead([List<int>? ids]);
  Future<NotificationPreferences> notificationPreferences();
  Future<void> saveNotificationPreferences(NotificationPreferences prefs);

  Future<UserProfile> myProfile();
  Future<void> updateDisplayName(String name);

  /// Stores a JPEG avatar and points the profile at it.
  Future<void> setAvatar(Uint8List jpeg);
  Future<void> removeAvatar();
  Future<ImageProvider> avatarImage(String path);

  /// Permanently deletes the signed-in account (server-side).
  Future<void> deleteAccount();
}

class UnconfiguredContentBackend implements ContentBackend {
  const UnconfiguredContentBackend();

  static const _f = NotConfiguredFailure(
    'This needs the Closer backend, which is not configured in this build.',
  );

  @override
  Future<JournalPage> journal({
    String? groupId,
    JournalCursor? before,
    int limit = 30,
  }) => Future.error(_f);
  @override
  Future<List<Milestone>> milestones(String groupId) => Future.error(_f);
  @override
  Future<Milestone> createMilestone(String groupId, MilestoneDraft draft) =>
      Future.error(_f);
  @override
  Future<Milestone> updateMilestone(String id, MilestoneDraft draft) =>
      Future.error(_f);
  @override
  Future<void> deleteMilestone(String id) => Future.error(_f);
  @override
  Future<List<AppNotification>> notifications({int limit = 50}) =>
      Future.error(_f);
  @override
  Future<void> markNotificationsRead([List<int>? ids]) => Future.error(_f);
  @override
  Future<NotificationPreferences> notificationPreferences() => Future.error(_f);
  @override
  Future<void> saveNotificationPreferences(NotificationPreferences prefs) =>
      Future.error(_f);
  @override
  Future<UserProfile> myProfile() => Future.error(_f);
  @override
  Future<void> updateDisplayName(String name) => Future.error(_f);
  @override
  Future<void> setAvatar(Uint8List jpeg) => Future.error(_f);
  @override
  Future<void> removeAvatar() => Future.error(_f);
  @override
  Future<ImageProvider> avatarImage(String path) => Future.error(_f);
  @override
  Future<void> deleteAccount() => Future.error(_f);
}

class SupabaseContentBackend implements ContentBackend {
  SupabaseContentBackend(this._db);

  final sb.SupabaseClient _db;
  final _signed = <String, (String, DateTime)>{};

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) {
      throw const AuthFailure('Please sign in again.');
    }
    return id;
  }

  @override
  Future<JournalPage> journal({
    String? groupId,
    JournalCursor? before,
    int limit = 30,
  }) => guardBackend(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'journal_entries',
      params: {
        'p_group_id': groupId,
        'p_before_at': before?.occurredAt.toUtc().toIso8601String(),
        'p_before_id': before?.id,
        'p_limit': limit + 1,
      },
    );
    final entries = rows
        .map((r) => JournalEntry.fromJson(r as Map<String, dynamic>))
        .whereType<JournalEntry>()
        .toList();
    final hasMore = entries.length > limit;
    return JournalPage(
      entries: hasMore ? entries.sublist(0, limit) : entries,
      hasMore: hasMore,
    );
  });

  @override
  Future<List<Milestone>> milestones(String groupId) => guardBackend(() async {
    final rows = await _db
        .from('milestones')
        .select('*, cover:photos!cover_photo_id(thumb_path)')
        .eq('group_id', groupId)
        .order('event_date', ascending: false);
    return rows.map(Milestone.fromJson).toList();
  });

  @override
  Future<Milestone> createMilestone(String groupId, MilestoneDraft draft) =>
      guardBackend(() async {
        final row = await _db
            .from('milestones')
            .insert({...draft.toJson(), 'group_id': groupId})
            .select()
            .single();
        return Milestone.fromJson(row);
      });

  @override
  Future<Milestone> updateMilestone(
    String id,
    MilestoneDraft draft,
  ) => guardBackend(() async {
    final rows = await _db
        .from('milestones')
        .update(draft.toJson())
        .eq('id', id)
        .select();
    if (rows.isEmpty) {
      throw const PermissionFailure(
        'Only the person who added this moment or the group owner can edit it.',
      );
    }
    return Milestone.fromJson(rows.first);
  });

  @override
  Future<void> deleteMilestone(String id) => guardBackend(() async {
    final rows = await _db
        .from('milestones')
        .delete()
        .eq('id', id)
        .select('id');
    if (rows.isEmpty) {
      throw const PermissionFailure(
        'Only the person who added this moment or the group owner can delete it.',
      );
    }
  });

  @override
  Future<List<AppNotification>> notifications({int limit = 50}) => guardBackend(
    () async {
      final rows = await _db
          .from('notifications')
          .select(
            'id, group_id, kind, created_at, read_at, photo_id, milestone_id, '
            'actor:profiles!actor_id(display_name), '
            'photo:photos!photo_id(thumb_path), '
            'milestone:milestones!milestone_id(title)',
          )
          .order('created_at', ascending: false)
          .order('id', ascending: false)
          .limit(limit);
      return rows.map(AppNotification.fromJson).toList();
    },
  );

  @override
  Future<void> markNotificationsRead([List<int>? ids]) => guardBackend(
    () => _db.rpc<void>('mark_notifications_read', params: {'p_ids': ids}),
  );

  @override
  Future<NotificationPreferences> notificationPreferences() =>
      guardBackend(() async {
        final row = await _db
            .from('notification_preferences')
            .select()
            .eq('user_id', _uid)
            .maybeSingle();
        return row == null
            ? const NotificationPreferences()
            : NotificationPreferences.fromJson(row);
      });

  @override
  Future<void> saveNotificationPreferences(NotificationPreferences prefs) =>
      guardBackend(
        () => _db.from('notification_preferences').upsert({
          'user_id': _uid,
          ...prefs.toJson(),
        }),
      );

  @override
  Future<UserProfile> myProfile() => guardBackend(() async {
    final row = await _db.from('profiles').select().eq('id', _uid).single();
    return UserProfile.fromJson(row);
  });

  @override
  Future<void> updateDisplayName(String name) => guardBackend(() async {
    await _db
        .from('profiles')
        .update({'display_name': name.trim()})
        .eq('id', _uid);
    // Keep the auth metadata in sync for greetings on other devices.
    await _db.auth.updateUser(
      sb.UserAttributes(data: {'display_name': name.trim()}),
    );
  });

  @override
  Future<void> setAvatar(Uint8List jpeg) => guardBackend(() async {
    final path = '$_uid/${const Uuid().v4().replaceAll('-', '')}.jpg';
    await _db.storage
        .from('avatars')
        .uploadBinary(
          path,
          jpeg,
          fileOptions: const sb.FileOptions(contentType: 'image/jpeg'),
        );
    await _db.rpc<void>('set_avatar', params: {'p_path': path});
  });

  @override
  Future<void> removeAvatar() =>
      guardBackend(() => _db.rpc<void>('set_avatar', params: {'p_path': null}));

  @override
  Future<ImageProvider> avatarImage(String path) => guardBackend(() async {
    final cached = _signed[path];
    String url;
    if (cached != null && cached.$2.isAfter(DateTime.now())) {
      url = cached.$1;
    } else {
      url = await _db.storage.from('avatars').createSignedUrl(path, 3600);
      _signed[path] = (url, DateTime.now().add(const Duration(minutes: 50)));
    }
    return CachedNetworkImageProvider(url, cacheKey: 'avatar-$path');
  });

  @override
  Future<void> deleteAccount() => guardBackend(() async {
    final res = await _db.functions.invoke(
      'delete-account',
      body: {'confirm': 'DELETE'},
    );
    if (res.status != 200) {
      throw const UnexpectedFailure(
        'Your account couldn’t be deleted. Please try again.',
      );
    }
    await _db.auth.signOut();
  });
}
