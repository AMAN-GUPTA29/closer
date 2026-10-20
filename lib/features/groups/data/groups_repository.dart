import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/backend_errors.dart';
import '../../../core/models/group_type.dart';
import '../../invitations/domain/invitation_models.dart';
import '../domain/group_models.dart';

abstract interface class GroupsRepository {
  Future<List<Group>> myGroups();
  Future<Group> group(String groupId);
  Future<List<GroupMember>> members(String groupId);

  /// Returns the new group's id.
  Future<String> createGroup({
    required String name,
    required GroupType type,
    DateTime? relationshipStartDate,
  });

  Future<void> updateGroup(
    String groupId, {
    String? name,
    DateTime? relationshipStartDate,
    bool clearRelationshipStartDate = false,
    bool? showRelationshipCounter,
  });

  Future<void> leaveGroup(String groupId);
  Future<void> transferOwnership(String groupId, String newOwnerId);
  Future<void> removeMember(String groupId, String userId);
  Future<void> deleteGroup(String groupId);

  /// Owner chooses a cover photo; null = use the newest photo.
  Future<void> setCover(String groupId, String? photoId);
}

abstract interface class InvitationsRepository {
  Future<List<Invitation>> invitations(String groupId);

  /// [expiresIn] null = never expires; [maxRedemptions] null = unlimited.
  Future<CreatedInvitation> create(
    String groupId, {
    Duration? expiresIn,
    int? maxRedemptions,
  });
  Future<void> revoke(String invitationId);
  Future<InvitePreview> preview(String secret);
  Future<RedeemResult> redeem(String secret);
}

/// One backend object serves both interfaces (they share a connection and,
/// for the in-memory version, the same state).
abstract interface class GroupsBackend
    implements GroupsRepository, InvitationsRepository {}

const _notConfigured = NotConfiguredFailure(
  'Groups need the Keeploom backend, which is not configured in this build.',
);

class UnconfiguredGroupsRepository implements GroupsBackend {
  const UnconfiguredGroupsRepository();

  Never _fail() => throw _notConfigured;

  @override
  Future<List<Group>> myGroups() async => _fail();
  @override
  Future<Group> group(String groupId) async => _fail();
  @override
  Future<List<GroupMember>> members(String groupId) async => _fail();
  @override
  Future<String> createGroup({
    required String name,
    required GroupType type,
    DateTime? relationshipStartDate,
  }) async => _fail();
  @override
  Future<void> updateGroup(
    String groupId, {
    String? name,
    DateTime? relationshipStartDate,
    bool clearRelationshipStartDate = false,
    bool? showRelationshipCounter,
  }) async => _fail();
  @override
  Future<void> leaveGroup(String groupId) async => _fail();
  @override
  Future<void> transferOwnership(String groupId, String newOwnerId) async =>
      _fail();
  @override
  Future<void> removeMember(String groupId, String userId) async => _fail();
  @override
  Future<void> deleteGroup(String groupId) async => _fail();
  @override
  Future<void> setCover(String groupId, String? photoId) async => _fail();
  @override
  Future<List<Invitation>> invitations(String groupId) async => _fail();
  @override
  Future<CreatedInvitation> create(
    String groupId, {
    Duration? expiresIn,
    int? maxRedemptions,
  }) async => _fail();
  @override
  Future<void> revoke(String invitationId) async => _fail();
  @override
  Future<InvitePreview> preview(String secret) async => _fail();
  @override
  Future<RedeemResult> redeem(String secret) async => _fail();
}

/// Talks to Supabase. Reads go through RLS; every mutation that involves
/// membership, roles or invitations calls a trusted database function.
class SupabaseGroupsRepository implements GroupsBackend {
  SupabaseGroupsRepository(this._db);

  final sb.SupabaseClient _db;

  @override
  Future<List<Group>> myGroups() => guardBackend(() async {
    final rows = await _db
        .from('group_summaries')
        .select()
        .order('last_activity_at', ascending: false);
    return rows.map(Group.fromJson).toList();
  });

  @override
  Future<Group> group(String groupId) => guardBackend(() async {
    final row = await _db
        .from('group_summaries')
        .select()
        .eq('id', groupId)
        .maybeSingle();
    if (row == null) {
      throw const PermissionFailure(
        'This group isn’t available. You may no longer be a member.',
      );
    }
    return Group.fromJson(row);
  });

  @override
  Future<List<GroupMember>> members(String groupId) => guardBackend(() async {
    final rows = await _db
        .from('group_members')
        .select('user_id, role, joined_at, profiles(display_name, avatar_path)')
        .eq('group_id', groupId)
        .order('joined_at');
    return rows.map(GroupMember.fromJson).toList();
  });

  @override
  Future<String> createGroup({
    required String name,
    required GroupType type,
    DateTime? relationshipStartDate,
  }) => guardBackend(() async {
    final id = await _db.rpc<String>(
      'create_group',
      params: {
        'p_name': name.trim(),
        'p_type': type.name,
        'p_relationship_start_date': relationshipStartDate == null
            ? null
            : formatDate(relationshipStartDate),
      },
    );
    return id;
  });

  @override
  Future<void> updateGroup(
    String groupId, {
    String? name,
    DateTime? relationshipStartDate,
    bool clearRelationshipStartDate = false,
    bool? showRelationshipCounter,
  }) => guardBackend(() async {
    final changes = <String, dynamic>{
      'name': ?name?.trim(),
      if (relationshipStartDate != null)
        'relationship_start_date': formatDate(relationshipStartDate),
      if (clearRelationshipStartDate) 'relationship_start_date': null,
      'show_relationship_counter': ?showRelationshipCounter,
    };
    if (changes.isEmpty) return;
    final updated = await _db
        .from('groups')
        .update(changes)
        .eq('id', groupId)
        .select('id');
    if (updated.isEmpty) throw const PermissionFailure();
  });

  Future<void> _rpc(String fn, Map<String, dynamic> params) =>
      guardBackend(() => _db.rpc<void>(fn, params: params));

  @override
  Future<void> leaveGroup(String groupId) =>
      _rpc('leave_group', {'p_group_id': groupId});

  @override
  Future<void> transferOwnership(String groupId, String newOwnerId) => _rpc(
    'transfer_ownership',
    {'p_group_id': groupId, 'p_new_owner': newOwnerId},
  );

  @override
  Future<void> removeMember(String groupId, String userId) =>
      _rpc('remove_member', {'p_group_id': groupId, 'p_user_id': userId});

  @override
  Future<void> deleteGroup(String groupId) =>
      _rpc('delete_group', {'p_group_id': groupId});

  @override
  Future<void> setCover(String groupId, String? photoId) =>
      _rpc('set_group_cover', {'p_group_id': groupId, 'p_photo_id': photoId});

  @override
  Future<List<Invitation>> invitations(String groupId) =>
      guardBackend(() async {
        final rows = await _db
            .from('invitations')
            .select(
              'id, group_id, code_hint, created_by, created_at, expires_at, '
              'revoked_at, max_redemptions, redemption_count',
            )
            .eq('group_id', groupId)
            .order('created_at', ascending: false)
            .limit(50);
        return rows.map(Invitation.fromJson).toList();
      });

  @override
  Future<CreatedInvitation> create(
    String groupId, {
    Duration? expiresIn,
    int? maxRedemptions,
  }) => guardBackend(() async {
    final rows = await _db.rpc<List<dynamic>>(
      'create_invitation',
      params: {
        'p_group_id': groupId,
        'p_expires_in_hours': expiresIn?.inHours,
        'p_max_redemptions': maxRedemptions,
      },
    );
    final row = rows.first as Map<String, dynamic>;
    final expires = row['expires_at'] as String?;
    return CreatedInvitation(
      invitationId: row['invitation_id'] as String,
      code: row['code'] as String,
      token: row['token'] as String,
      expiresAt: expires == null ? null : DateTime.parse(expires),
    );
  });

  @override
  Future<void> revoke(String invitationId) =>
      _rpc('revoke_invitation', {'p_invitation_id': invitationId});

  @override
  Future<InvitePreview> preview(String secret) => guardBackend(() async {
    final json = await _db.rpc<Map<String, dynamic>>(
      'preview_invitation',
      params: {'p_secret': secret},
    );
    return InvitePreview.fromJson(json);
  });

  @override
  Future<RedeemResult> redeem(String secret) => guardBackend(() async {
    final json = await _db.rpc<Map<String, dynamic>>(
      'redeem_invitation',
      params: {'p_secret': secret},
    );
    return RedeemResult.fromJson(json);
  });
}
