import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/models/group_type.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/domain/auth_models.dart';
import '../../invitations/domain/invitation_models.dart';
import '../data/groups_repository.dart';
import '../data/in_memory_groups_repository.dart';
import '../domain/group_models.dart';

/// The groups/invitations backend for the current session:
/// Supabase when configured, an in-memory sample in debug Preview mode,
/// otherwise a "not configured" implementation.
final groupsBackendProvider = Provider<GroupsBackend>((ref) {
  final status = ref.watch(authControllerProvider);
  if (status is PreviewSession) {
    return InMemoryGroupsRepository(
        currentUserId: PreviewSession.user.id,
        currentUserName: PreviewSession.user.displayName ?? 'Preview',
      )
      ..seedPreview()
      ..latency = const Duration(milliseconds: 250);
  }
  if (!ref.watch(authRepositoryProvider).isConfigured) {
    return const UnconfiguredGroupsRepository();
  }
  return SupabaseGroupsRepository(sb.Supabase.instance.client);
});

final currentUserIdProvider = Provider<String?>((ref) {
  return switch (ref.watch(authControllerProvider)) {
    SignedIn(:final user) || PasswordRecovery(:final user) => user.id,
    PreviewSession() => PreviewSession.user.id,
    SignedOut() => null,
  };
});

final myGroupsProvider = FutureProvider<List<Group>>(
  (ref) => ref.watch(groupsBackendProvider).myGroups(),
);

final groupProvider = FutureProvider.autoDispose.family<Group, String>(
  (ref, id) => ref.watch(groupsBackendProvider).group(id),
);

final groupMembersProvider = FutureProvider.autoDispose
    .family<List<GroupMember>, String>(
      (ref, id) => ref.watch(groupsBackendProvider).members(id),
    );

final invitationsProvider = FutureProvider.autoDispose
    .family<List<Invitation>, String>(
      (ref, id) => ref.watch(groupsBackendProvider).invitations(id),
    );

/// Mutations. Each refreshes the providers whose data it changed.
final groupActionsProvider = Provider<GroupActions>(GroupActions.new);

class GroupActions {
  GroupActions(this._ref);

  final Ref _ref;

  GroupsBackend get _backend => _ref.read(groupsBackendProvider);

  void _refreshGroup(String groupId) {
    _ref
      ..invalidate(myGroupsProvider)
      ..invalidate(groupProvider(groupId))
      ..invalidate(groupMembersProvider(groupId));
  }

  Future<String> createGroup({
    required String name,
    required GroupType type,
    DateTime? relationshipStartDate,
  }) async {
    final id = await _backend.createGroup(
      name: name,
      type: type,
      relationshipStartDate: relationshipStartDate,
    );
    _ref.invalidate(myGroupsProvider);
    return id;
  }

  Future<void> updateGroup(
    String groupId, {
    String? name,
    DateTime? relationshipStartDate,
    bool clearRelationshipStartDate = false,
    bool? showRelationshipCounter,
  }) async {
    await _backend.updateGroup(
      groupId,
      name: name,
      relationshipStartDate: relationshipStartDate,
      clearRelationshipStartDate: clearRelationshipStartDate,
      showRelationshipCounter: showRelationshipCounter,
    );
    _refreshGroup(groupId);
  }

  Future<void> leaveGroup(String groupId) async {
    await _backend.leaveGroup(groupId);
    _ref.invalidate(myGroupsProvider);
  }

  Future<void> deleteGroup(String groupId) async {
    await _backend.deleteGroup(groupId);
    _ref.invalidate(myGroupsProvider);
  }

  Future<void> setCover(String groupId, String? photoId) async {
    await _backend.setCover(groupId, photoId);
    _refreshGroup(groupId);
  }

  Future<void> transferOwnership(String groupId, String userId) async {
    await _backend.transferOwnership(groupId, userId);
    _refreshGroup(groupId);
  }

  Future<void> removeMember(String groupId, String userId) async {
    await _backend.removeMember(groupId, userId);
    _refreshGroup(groupId);
  }

  Future<CreatedInvitation> createInvitation(
    String groupId, {
    Duration? expiresIn,
    int? maxRedemptions,
  }) async {
    final created = await _backend.create(
      groupId,
      expiresIn: expiresIn,
      maxRedemptions: maxRedemptions,
    );
    _ref.invalidate(invitationsProvider(groupId));
    return created;
  }

  Future<void> revokeInvitation(String groupId, String invitationId) async {
    await _backend.revoke(invitationId);
    _ref.invalidate(invitationsProvider(groupId));
  }

  Future<InvitePreview> previewInvitation(String secret) =>
      _backend.preview(secret);

  Future<RedeemResult> redeemInvitation(String secret) async {
    final result = await _backend.redeem(secret);
    if (result.isMember) _ref.invalidate(myGroupsProvider);
    return result;
  }
}

/// An invitation secret received through a deep link, kept until the user
/// is signed in and the Join screen consumes it.
final pendingInviteProvider = NotifierProvider<PendingInvite, String?>(
  PendingInvite.new,
);

class PendingInvite extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String secret) => state = secret;

  void clear() => state = null;
}
