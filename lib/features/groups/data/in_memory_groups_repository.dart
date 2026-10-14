import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/widgets.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/backend_errors.dart';
import '../../../core/models/group_type.dart';
import '../../invitations/domain/invitation_models.dart';
import '../../photos/data/photos_backend.dart';
import '../../photos/domain/photo_models.dart';
import '../domain/group_models.dart';
import 'groups_repository.dart';

/// In-memory implementation used by the debug-only Preview mode and by
/// widget tests. It mirrors the server's rules (capacity, invitation
/// statuses, ownership hand-over) closely enough to exercise the UI, but it
/// is never used when a real backend is configured.
class InMemoryGroupsRepository implements GroupsBackend, PhotosBackend {
  InMemoryGroupsRepository({
    required this.currentUserId,
    this.currentUserName = 'You',
    DateTime Function()? clock,
    Random? random,
  }) : _clock = clock ?? DateTime.now,
       _random = random ?? Random();

  String currentUserId;
  String currentUserName;
  final DateTime Function() _clock;
  final Random _random;

  final _groups = <String, _GroupRow>{};
  final _members = <String, List<_MemberRow>>{};
  final _invites = <String, _InviteRow>{};
  final _names = <String, String>{};
  final _photos = <String, _PhotoRow>{};
  final _objects = <String, Uint8List>{};
  final _premium = <String>{};
  int _seq = 0;

  /// Test hook: fail the next [putObject] call (simulates a dropped upload).
  bool failNextPut = false;

  /// Test/preview helper: marks a group as Closer Memories.
  void grantPremium(String groupId) => _premium.add(groupId);

  /// Object paths currently stored (for tests).
  Set<String> get storedObjects => _objects.keys.toSet();

  /// Simulated network delay (0 in tests).
  Duration latency = Duration.zero;

  Future<void> _wait() =>
      latency == Duration.zero ? Future.value() : Future.delayed(latency);

  Never _fail(String key) =>
      throw BackendFailure(backendMessage(key), key: key);

  String _id(String prefix) => '$prefix-${++_seq}';

  void _requireMember(String groupId) {
    if (!(_members[groupId]?.any((m) => m.userId == currentUserId) ?? false)) {
      _fail('not_a_member');
    }
  }

  bool _isOwner(String groupId) =>
      _members[groupId]?.any(
        (m) => m.userId == currentUserId && m.role == MemberRole.owner,
      ) ??
      false;

  Group _toGroup(String id) {
    final g = _groups[id]!;
    final members = _members[id]!;
    final me = members.where((m) => m.userId == currentUserId).firstOrNull;
    return Group(
      id: id,
      name: g.name,
      type: g.type,
      createdBy: g.createdBy,
      relationshipStartDate: g.relationshipStartDate,
      showRelationshipCounter: g.showCounter,
      createdAt: g.createdAt,
      lastActivityAt: g.lastActivityAt,
      memberCount: members.length,
      myRole: me?.role ?? MemberRole.member,
      photoCount: _active(id).length,
      isPremium: _premium.contains(id),
      latestThumbPath: _active(id).firstOrNull?.thumbPath,
    );
  }

  /// Active photos of a group, newest first.
  List<_PhotoRow> _active(String groupId) =>
      _photos.values
          .where((p) => p.groupId == groupId && p.status == 'active')
          .toList()
        ..sort((a, b) {
          final c = b.uploadedAt!.compareTo(a.uploadedAt!);
          return c != 0 ? c : b.id.compareTo(a.id);
        });

  /// Test/preview helper: adds a user to a group directly.
  void addMember(String groupId, String userId, String name) {
    _names[userId] = name;
    final g = _groups[groupId]!;
    final cap = g.type.maxMembers;
    if (cap != null && _members[groupId]!.length >= cap) _fail('group_full');
    _members[groupId]!.add(
      _MemberRow(
        userId,
        MemberRole.member,
        _clock().add(Duration(seconds: ++_seq)),
      ),
    );
  }

  @override
  Future<List<Group>> myGroups() async {
    await _wait();
    final ids = _members.entries
        .where((e) => e.value.any((m) => m.userId == currentUserId))
        .map((e) => e.key);
    final list = ids.map(_toGroup).toList()
      ..sort((a, b) => b.lastActivityAt.compareTo(a.lastActivityAt));
    return list;
  }

  @override
  Future<Group> group(String groupId) async {
    await _wait();
    if (!_groups.containsKey(groupId)) _fail('not_a_member');
    _requireMember(groupId);
    return _toGroup(groupId);
  }

  @override
  Future<List<GroupMember>> members(String groupId) async {
    await _wait();
    _requireMember(groupId);
    return [
      for (final m in _members[groupId]!)
        GroupMember(
          userId: m.userId,
          displayName: m.userId == currentUserId
              ? currentUserName
              : _names[m.userId] ?? 'Member',
          role: m.role,
          joinedAt: m.joinedAt,
        ),
    ];
  }

  @override
  Future<String> createGroup({
    required String name,
    required GroupType type,
    DateTime? relationshipStartDate,
  }) async {
    await _wait();
    return _createGroupNow(name, type, relationshipStartDate);
  }

  String _createGroupNow(
    String name,
    GroupType type,
    DateTime? relationshipStartDate,
  ) {
    if (type != GroupType.couple && relationshipStartDate != null) {
      _fail('relationship_date_couples_only');
    }
    if (relationshipStartDate != null &&
        relationshipStartDate.isAfter(_clock())) {
      _fail('relationship_date_in_future');
    }
    final id = _id('group');
    final now = _clock();
    _groups[id] = _GroupRow(
      name: name.trim(),
      type: type,
      createdBy: currentUserId,
      relationshipStartDate: relationshipStartDate,
      createdAt: now,
      lastActivityAt: now,
    );
    _members[id] = [_MemberRow(currentUserId, MemberRole.owner, now)];
    return id;
  }

  @override
  Future<void> updateGroup(
    String groupId, {
    String? name,
    DateTime? relationshipStartDate,
    bool clearRelationshipStartDate = false,
    bool? showRelationshipCounter,
  }) async {
    await _wait();
    if (!_isOwner(groupId)) _fail('not_allowed');
    final g = _groups[groupId]!;
    if (name != null) g.name = name.trim();
    if (relationshipStartDate != null) {
      g.relationshipStartDate = relationshipStartDate;
    }
    if (clearRelationshipStartDate) g.relationshipStartDate = null;
    if (showRelationshipCounter != null) {
      g.showCounter = showRelationshipCounter;
    }
  }

  void _afterRemoval(String groupId) {
    final list = _members[groupId]!;
    if (list.isEmpty) {
      _dropPhotos(groupId);
      _groups.remove(groupId);
      _members.remove(groupId);
      _invites.removeWhere((_, i) => i.groupId == groupId);
      return;
    }
    if (!list.any((m) => m.role == MemberRole.owner)) {
      list.sort((a, b) => a.joinedAt.compareTo(b.joinedAt));
      list.first.role = MemberRole.owner;
    }
  }

  @override
  Future<void> leaveGroup(String groupId) async {
    await _wait();
    _requireMember(groupId);
    _members[groupId]!.removeWhere((m) => m.userId == currentUserId);
    _afterRemoval(groupId);
  }

  @override
  Future<void> transferOwnership(String groupId, String newOwnerId) async {
    await _wait();
    if (!_isOwner(groupId)) _fail('not_allowed');
    final list = _members[groupId]!;
    final target = list.where((m) => m.userId == newOwnerId).firstOrNull;
    if (target == null) _fail('not_a_member');
    for (final m in list) {
      m.role = m.userId == newOwnerId ? MemberRole.owner : MemberRole.member;
    }
  }

  @override
  Future<void> removeMember(String groupId, String userId) async {
    await _wait();
    if (!_isOwner(groupId)) _fail('not_allowed');
    if (userId == currentUserId) _fail('use_leave_group');
    final list = _members[groupId]!;
    final before = list.length;
    list.removeWhere((m) => m.userId == userId);
    if (list.length == before) _fail('not_a_member');
    _afterRemoval(groupId);
  }

  @override
  Future<void> deleteGroup(String groupId) async {
    await _wait();
    if (!_isOwner(groupId)) _fail('not_allowed');
    _dropPhotos(groupId);
    _groups.remove(groupId);
    _members.remove(groupId);
    _invites.removeWhere((_, i) => i.groupId == groupId);
  }

  // ---- Invitations ----------------------------------------------------------

  static const _alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  @override
  Future<List<Invitation>> invitations(String groupId) async {
    await _wait();
    _requireMember(groupId);
    final list = _invites.values.where((i) => i.groupId == groupId).map((i) {
      return Invitation(
        id: i.id,
        groupId: i.groupId,
        codeHint: i.code.substring(6),
        createdBy: i.createdBy,
        createdAt: i.createdAt,
        expiresAt: i.expiresAt,
        revokedAt: i.revokedAt,
        maxRedemptions: i.maxRedemptions,
        redemptionCount: i.redeemedBy.length,
      );
    }).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  @override
  Future<CreatedInvitation> create(
    String groupId, {
    Duration? expiresIn,
    int? maxRedemptions,
  }) async {
    await _wait();
    _requireMember(groupId);
    final g = _groups[groupId]!;
    var max = maxRedemptions;
    final cap = g.type.maxMembers;
    if (cap != null) {
      final free = cap - _members[groupId]!.length;
      if (free <= 0) _fail('group_full');
      max = min(max ?? free, free);
    }
    final code = List.generate(
      8,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join();
    final token = List.generate(
      32,
      (_) => _alphabet[_random.nextInt(_alphabet.length)],
    ).join().toLowerCase();
    final now = _clock();
    final row = _InviteRow(
      id: _id('invite'),
      groupId: groupId,
      code: code,
      token: token,
      createdBy: currentUserId,
      createdAt: now,
      expiresAt: expiresIn == null ? null : now.add(expiresIn),
      maxRedemptions: max,
    );
    _invites[row.id] = row;
    return CreatedInvitation(
      invitationId: row.id,
      code: code,
      token: token,
      expiresAt: row.expiresAt,
    );
  }

  @override
  Future<void> revoke(String invitationId) async {
    await _wait();
    final inv = _invites[invitationId];
    if (inv == null) _fail('invitation_not_found');
    _requireMember(inv.groupId);
    if (!_isOwner(inv.groupId) && inv.createdBy != currentUserId) {
      _fail('not_allowed');
    }
    inv.revokedAt ??= _clock();
  }

  _InviteRow? _find(String secret) {
    final code = InviteCodes.normalize(secret);
    for (final i in _invites.values) {
      if (i.code == code || i.token == secret.trim()) return i;
    }
    return null;
  }

  InviteStatus _status(_InviteRow i) {
    if (i.revokedAt != null) return InviteStatus.revoked;
    if (i.expiresAt != null && !i.expiresAt!.isAfter(_clock())) {
      return InviteStatus.expired;
    }
    if (i.maxRedemptions != null && i.redeemedBy.length >= i.maxRedemptions!) {
      return InviteStatus.exhausted;
    }
    return InviteStatus.valid;
  }

  @override
  Future<InvitePreview> preview(String secret) async {
    await _wait();
    final inv = _find(secret);
    if (inv == null) return const InvitePreview(status: InviteStatus.invalid);
    var status = _status(inv);
    if (status != InviteStatus.valid) return InvitePreview(status: status);
    final g = _groups[inv.groupId]!;
    final members = _members[inv.groupId]!;
    final isMember = members.any((m) => m.userId == currentUserId);
    final cap = g.type.maxMembers;
    if (isMember) {
      status = InviteStatus.alreadyMember;
    } else if (cap != null && members.length >= cap) {
      status = InviteStatus.full;
    }
    return InvitePreview(
      status: status,
      groupId: isMember ? inv.groupId : null,
      groupName: g.name,
      groupType: g.type,
      memberCount: members.length,
      relationshipStartDate: g.relationshipStartDate,
      expiresAt: inv.expiresAt,
    );
  }

  @override
  Future<RedeemResult> redeem(String secret) async {
    await _wait();
    final inv = _find(secret);
    if (inv == null) return const RedeemResult(status: InviteStatus.invalid);
    final members = _members[inv.groupId]!;
    if (members.any((m) => m.userId == currentUserId)) {
      return RedeemResult(
        status: InviteStatus.alreadyMember,
        groupId: inv.groupId,
      );
    }
    final status = _status(inv);
    if (status != InviteStatus.valid) return RedeemResult(status: status);
    final cap = _groups[inv.groupId]!.type.maxMembers;
    if (cap != null && members.length >= cap) {
      return const RedeemResult(status: InviteStatus.full);
    }
    members.add(_MemberRow(currentUserId, MemberRole.member, _clock()));
    inv.redeemedBy.add(currentUserId);
    _groups[inv.groupId]!.lastActivityAt = _clock();
    return RedeemResult(status: InviteStatus.joined, groupId: inv.groupId);
  }

  // ---- Photos ---------------------------------------------------------------

  void _dropPhotos(String groupId) {
    for (final p in _photos.values.where((p) => p.groupId == groupId)) {
      _objects
        ..remove(p.storagePath)
        ..remove(p.thumbPath);
    }
    _photos.removeWhere((_, p) => p.groupId == groupId);
  }

  Photo _toPhoto(_PhotoRow p) => Photo(
    id: p.id,
    groupId: p.groupId,
    uploaderId: p.uploaderId,
    uploaderName: p.uploaderId == currentUserId
        ? currentUserName
        : _names[p.uploaderId] ?? 'Member',
    storagePath: p.storagePath,
    thumbPath: p.thumbPath,
    caption: p.caption,
    takenAt: p.takenAt,
    uploadedAt: p.uploadedAt!,
    width: p.width,
    height: p.height,
    isPinned: p.isPinned,
  );

  @override
  Future<PhotoPage> photos(
    String groupId, {
    PhotoCursor? before,
    int limit = 30,
  }) async {
    await _wait();
    _requireMember(groupId);
    var list = _active(groupId);
    if (before != null) {
      list = list.where((p) {
        final c = p.uploadedAt!.compareTo(before.uploadedAt);
        return c < 0 || (c == 0 && p.id.compareTo(before.id) < 0);
      }).toList();
    }
    final hasMore = list.length > limit;
    return PhotoPage(
      photos: list.take(limit).map(_toPhoto).toList(),
      hasMore: hasMore,
    );
  }

  @override
  Future<UploadSlot> requestUpload(
    String groupId, {
    required String clientUploadId,
    String? caption,
    DateTime? takenAt,
    int? width,
    int? height,
    int? byteSize,
  }) async {
    await _wait();
    _requireMember(groupId);
    final existing = _photos.values
        .where(
          (p) =>
              p.uploaderId == currentUserId &&
              p.clientUploadId == clientUploadId,
        )
        .firstOrNull;
    final row =
        existing ??
        _PhotoRow(
          id: _id('photo'),
          groupId: groupId,
          uploaderId: currentUserId,
          clientUploadId: clientUploadId,
          caption: caption,
          takenAt: takenAt,
          width: width,
          height: height,
        );
    _photos[row.id] = row;
    return UploadSlot(
      photoId: row.id,
      storagePath: row.storagePath,
      thumbPath: row.thumbPath,
      alreadyActive: row.status == 'active',
    );
  }

  @override
  Future<void> putObject(String path, Uint8List bytes) async {
    await _wait();
    if (failNextPut) {
      failNextPut = false;
      throw const UnexpectedFailure(
        'The photo couldn’t be uploaded. Please try again.',
      );
    }
    final allowed = _photos.values.any(
      (p) =>
          p.status == 'pending' &&
          p.uploaderId == currentUserId &&
          (p.storagePath == path || p.thumbPath == path),
    );
    if (!allowed) throw const PermissionFailure();
    _objects.putIfAbsent(path, () => bytes);
  }

  @override
  Future<UploadResult> finalize(String photoId) async {
    await _wait();
    final p = _photos[photoId];
    if (p == null || p.uploaderId != currentUserId) _fail('photo_not_found');
    if (p.status == 'active') {
      return UploadResult(photoId: photoId, removedCount: 0);
    }
    if (!_objects.containsKey(p.storagePath) ||
        !_objects.containsKey(p.thumbPath)) {
      _fail('upload_incomplete');
    }
    p
      ..status = 'active'
      ..uploadedAt = _clock().add(Duration(microseconds: ++_seq));
    var removed = 0;
    if (!_premium.contains(p.groupId)) {
      final active = _active(p.groupId)
        ..sort((a, b) {
          if (a.isPinned != b.isPinned) return a.isPinned ? 1 : -1;
          return a.uploadedAt!.compareTo(b.uploadedAt!);
        });
      final excess = active.length - Group.basicPhotoLimit;
      for (final old in active.take(max(0, excess))) {
        old.status = 'removed';
        _objects
          ..remove(old.storagePath)
          ..remove(old.thumbPath);
        removed++;
      }
    }
    _groups[p.groupId]!.lastActivityAt = _clock();
    return UploadResult(photoId: photoId, removedCount: removed);
  }

  @override
  Future<void> deletePhoto(String photoId) async {
    await _wait();
    final p = _photos[photoId];
    if (p == null || p.status != 'active') _fail('photo_not_found');
    _requireMember(p.groupId);
    if (p.uploaderId != currentUserId && !_isOwner(p.groupId)) {
      _fail('not_allowed');
    }
    p.status = 'removed';
    _objects
      ..remove(p.storagePath)
      ..remove(p.thumbPath);
  }

  @override
  Future<void> updateCaption(String photoId, String? caption) async {
    await _wait();
    final p = _photos[photoId];
    if (p == null || p.uploaderId != currentUserId) _fail('photo_not_found');
    final t = caption?.trim();
    p.caption = (t == null || t.isEmpty) ? null : t;
  }

  @override
  Future<void> setPinned(String photoId, bool pinned) async {
    await _wait();
    final p = _photos[photoId];
    if (p == null || p.status != 'active') _fail('photo_not_found');
    if (pinned && !_premium.contains(p.groupId)) _fail('premium_required');
    p.isPinned = pinned;
  }

  @override
  Future<ImageProvider> image(Photo photo, PhotoVariant variant) async {
    final bytes = _objects[photo.pathFor(variant)];
    if (bytes == null) _fail('photo_not_found');
    return MemoryImage(bytes);
  }

  @override
  Future<void> requestCleanup() async {}

  /// Seeds sample groups so Preview mode has something to show. Runs
  /// synchronously so the first read already sees every sample group.
  void seedPreview() {
    final now = _clock();
    final couple = _createGroupNow(
      'My Love',
      GroupType.couple,
      now.subtract(const Duration(days: 181)),
    );
    addMember(couple, 'preview-partner', 'Emma Rose');
    final family = _createGroupNow('Our Family', GroupType.family, null);
    addMember(family, 'preview-mom', 'Mom');
    addMember(family, 'preview-dad', 'Dad');
    addMember(family, 'preview-sis', 'Mia');
    final crew = _createGroupNow('Travel Crew', GroupType.friends, null);
    _groups[crew]!.lastActivityAt = now.subtract(const Duration(hours: 2));
    _groups[family]!.lastActivityAt = now.subtract(const Duration(minutes: 30));
    _groups[couple]!.lastActivityAt = now;
  }
}

class _GroupRow {
  _GroupRow({
    required this.name,
    required this.type,
    required this.createdBy,
    required this.createdAt,
    required this.lastActivityAt,
    this.relationshipStartDate,
  });

  String name;
  final GroupType type;
  final String createdBy;
  DateTime? relationshipStartDate;
  bool showCounter = true;
  final DateTime createdAt;
  DateTime lastActivityAt;
}

class _MemberRow {
  _MemberRow(this.userId, this.role, this.joinedAt);
  final String userId;
  MemberRole role;
  final DateTime joinedAt;
}

class _InviteRow {
  _InviteRow({
    required this.id,
    required this.groupId,
    required this.code,
    required this.token,
    required this.createdBy,
    required this.createdAt,
    this.expiresAt,
    this.maxRedemptions,
  });

  final String id;
  final String groupId;
  final String code;
  final String token;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final int? maxRedemptions;
  DateTime? revokedAt;
  final redeemedBy = <String>{};
}

class _PhotoRow {
  _PhotoRow({
    required this.id,
    required this.groupId,
    required this.uploaderId,
    required this.clientUploadId,
    this.caption,
    this.takenAt,
    this.width,
    this.height,
  }) : storagePath = '$groupId/$id/original.jpg',
       thumbPath = '$groupId/$id/thumb.jpg';

  final String id;
  final String groupId;
  final String uploaderId;
  final String clientUploadId;
  final String storagePath;
  final String thumbPath;
  String? caption;
  final DateTime? takenAt;
  final int? width;
  final int? height;
  String status = 'pending';
  DateTime? uploadedAt;
  bool isPinned = false;
}
