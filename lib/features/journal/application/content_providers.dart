import 'dart:typed_data';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';
import '../../groups/application/group_providers.dart';
import '../../groups/data/in_memory_groups_repository.dart';
import '../../notifications/domain/notification_models.dart';
import '../data/content_backend.dart';
import '../data/in_memory_content_backend.dart';
import '../domain/journal_models.dart';

/// Content backend for the session. In Preview mode it shares state with
/// the in-memory groups backend.
final contentBackendProvider = Provider<ContentBackend>((ref) {
  final groups = ref.watch(groupsBackendProvider);
  if (groups is InMemoryGroupsRepository) {
    final backend = InMemoryContentBackend(groups);
    // Sample milestones/notifications only for the debug Preview mode.
    if (ref.read(authControllerProvider) is PreviewSession) {
      backend.seedPreview();
    }
    return backend;
  }
  if (!ref.watch(authRepositoryProvider).isConfigured) {
    return const UnconfiguredContentBackend();
  }
  return SupabaseContentBackend(sb.Supabase.instance.client);
});

// ---------------------------------------------------------------- journal

class JournalFeed {
  const JournalFeed({
    required this.entries,
    required this.hasMore,
    this.loadingMore = false,
  });

  final List<JournalEntry> entries;
  final bool hasMore;
  final bool loadingMore;
}

/// Journal for one group, or for all groups when the key is null.
final journalProvider = AsyncNotifierProvider.autoDispose
    .family<JournalNotifier, JournalFeed, String?>(JournalNotifier.new);

class JournalNotifier extends AsyncNotifier<JournalFeed> {
  JournalNotifier(this.groupId);

  final String? groupId;
  static const pageSize = 20;

  @override
  Future<JournalFeed> build() async {
    final page = await ref
        .watch(contentBackendProvider)
        .journal(groupId: groupId, limit: pageSize);
    return JournalFeed(entries: page.entries, hasMore: page.hasMore);
  }

  /// Appends the next page. Existing items stay in place, so the scroll
  /// position is stable; new content appears on refresh.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(
      JournalFeed(entries: current.entries, hasMore: true, loadingMore: true),
    );
    try {
      final page = await ref
          .read(contentBackendProvider)
          .journal(
            groupId: groupId,
            before: JournalCursor.after(current.entries.last),
            limit: pageSize,
          );
      final seen = current.entries.map((e) => e.id).toSet();
      state = AsyncData(
        JournalFeed(
          entries: [
            ...current.entries,
            ...page.entries.where((e) => !seen.contains(e.id)),
          ],
          hasMore: page.hasMore,
        ),
      );
    } catch (_) {
      state = AsyncData(
        JournalFeed(entries: current.entries, hasMore: current.hasMore),
      );
    }
  }
}

// ------------------------------------------------------------- milestones

final milestonesProvider = FutureProvider.autoDispose
    .family<List<Milestone>, String>(
      (ref, groupId) => ref.watch(contentBackendProvider).milestones(groupId),
    );

final milestoneActionsProvider = Provider<MilestoneActions>(
  MilestoneActions.new,
);

class MilestoneActions {
  MilestoneActions(this._ref);

  final Ref _ref;

  ContentBackend get _backend => _ref.read(contentBackendProvider);

  void _refresh(String groupId) {
    _ref
      ..invalidate(milestonesProvider(groupId))
      ..invalidate(journalProvider(groupId))
      ..invalidate(journalProvider(null));
  }

  Future<Milestone> create(String groupId, MilestoneDraft draft) async {
    final m = await _backend.createMilestone(groupId, draft);
    _refresh(groupId);
    return m;
  }

  Future<Milestone> update(Milestone m, MilestoneDraft draft) async {
    final updated = await _backend.updateMilestone(m.id, draft);
    _refresh(m.groupId);
    return updated;
  }

  Future<void> delete(Milestone m) async {
    await _backend.deleteMilestone(m.id);
    _refresh(m.groupId);
  }

  Future<void> setPinned(Milestone m, bool pinned) async {
    await _backend.updateMilestone(
      m.id,
      MilestoneDraft(
        title: m.title,
        type: m.type,
        eventDate: m.eventDate,
        theme: m.theme,
        description: m.description,
        coverPhotoId: m.coverPhotoId,
        isPinned: pinned,
      ),
    );
    _refresh(m.groupId);
  }
}

// ----------------------------------------------------------- notifications

final notificationsProvider = FutureProvider.autoDispose<List<AppNotification>>(
  (ref) => ref.watch(contentBackendProvider).notifications(),
);

final unreadCountProvider = Provider.autoDispose<int>(
  (ref) =>
      ref.watch(notificationsProvider).value?.where((n) => n.isUnread).length ??
      0,
);

final notificationPreferencesProvider =
    FutureProvider.autoDispose<NotificationPreferences>(
      (ref) => ref.watch(contentBackendProvider).notificationPreferences(),
    );

// ----------------------------------------------------------------- profile

final myProfileProvider = FutureProvider.autoDispose<UserProfile>(
  (ref) => ref.watch(contentBackendProvider).myProfile(),
);

/// True when a signed-in, confirmed user still has to choose a username.
/// False while the profile is loading or can't be read (never blocks offline).
final needsUsernameProvider = Provider<bool>((ref) {
  final status = ref.watch(authControllerProvider);
  if (status is! SignedIn || !status.user.emailConfirmed) return false;
  final profile = ref.watch(myProfileProvider).value;
  return profile != null && profile.username == null;
});

final avatarImageProvider = FutureProvider.autoDispose
    .family<ImageProvider, String>(
      (ref, path) => ref.watch(contentBackendProvider).avatarImage(path),
    );

final profileActionsProvider = Provider<ProfileActions>(ProfileActions.new);

class ProfileActions {
  ProfileActions(this._ref);

  final Ref _ref;

  ContentBackend get _backend => _ref.read(contentBackendProvider);

  Future<void> rename(String name) async {
    await _backend.updateDisplayName(name);
    _ref
      ..invalidate(myProfileProvider)
      ..invalidate(myGroupsProvider);
  }

  Future<String> setUsername(String username) async {
    final v = await _backend.setUsername(username);
    _ref.invalidate(myProfileProvider);
    return v;
  }

  Future<void> setAvatar(Uint8List jpeg) async {
    await _backend.setAvatar(jpeg);
    _ref.invalidate(myProfileProvider);
  }

  Future<void> removeAvatar() async {
    await _backend.removeAvatar();
    _ref.invalidate(myProfileProvider);
  }

  Future<void> deleteAccount() async {
    await _backend.deleteAccount();
    await _ref.read(authControllerProvider.notifier).signOut();
  }
}
