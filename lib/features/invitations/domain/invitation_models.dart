import 'package:flutter/foundation.dart';

import '../../../core/models/group_type.dart';
import '../../groups/domain/group_models.dart';

/// Outcome codes returned by `preview_invitation` / `redeem_invitation`.
enum InviteStatus {
  valid,
  joined,
  alreadyMember,
  invalid,
  expired,
  revoked,
  exhausted,
  full,
  alreadyInCouple,
  rateLimited;

  static InviteStatus parse(String? value) => switch (value) {
    'valid' => InviteStatus.valid,
    'joined' => InviteStatus.joined,
    'already_member' => InviteStatus.alreadyMember,
    'expired' => InviteStatus.expired,
    'revoked' => InviteStatus.revoked,
    'exhausted' => InviteStatus.exhausted,
    'full' => InviteStatus.full,
    'already_in_couple' => InviteStatus.alreadyInCouple,
    'rate_limited' => InviteStatus.rateLimited,
    _ => InviteStatus.invalid,
  };

  /// User-facing explanation for statuses that block joining.
  String? get problem => switch (this) {
    InviteStatus.invalid =>
      'We couldn’t find that invitation. Check the code and try again.',
    InviteStatus.expired => 'This invitation has expired. Ask for a new one.',
    InviteStatus.revoked =>
      'This invitation was cancelled by the group. Ask for a new one.',
    InviteStatus.exhausted =>
      'This invitation has already been used. Ask for a new one.',
    InviteStatus.full =>
      'This couple group already has two people, so it can’t take anyone else.',
    InviteStatus.alreadyInCouple =>
      'You’re already in a couple group. Leave it first to join this one.',
    InviteStatus.rateLimited =>
      'Too many attempts. Please wait 15 minutes and try again.',
    _ => null,
  };
}

/// An invitation as members see it. The code itself is never stored, only
/// its last two characters ([codeHint]).
@immutable
class Invitation {
  const Invitation({
    required this.id,
    required this.groupId,
    required this.codeHint,
    required this.createdAt,
    required this.redemptionCount,
    this.createdBy,
    this.expiresAt,
    this.revokedAt,
    this.maxRedemptions,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    DateTime? ts(String key) {
      final v = json[key] as String?;
      return v == null ? null : DateTime.parse(v);
    }

    return Invitation(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      codeHint: json['code_hint'] as String,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: ts('expires_at'),
      revokedAt: ts('revoked_at'),
      maxRedemptions: (json['max_redemptions'] as num?)?.toInt(),
      redemptionCount: (json['redemption_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String groupId;
  final String codeHint;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final DateTime? revokedAt;
  final int? maxRedemptions;
  final int redemptionCount;

  InviteStatus statusAt(DateTime now) {
    if (revokedAt != null) return InviteStatus.revoked;
    if (expiresAt != null && !expiresAt!.isAfter(now)) {
      return InviteStatus.expired;
    }
    if (maxRedemptions != null && redemptionCount >= maxRedemptions!) {
      return InviteStatus.exhausted;
    }
    return InviteStatus.valid;
  }
}

/// Returned once, right after creation: the only time the secrets exist in
/// plaintext.
@immutable
class CreatedInvitation {
  const CreatedInvitation({
    required this.invitationId,
    required this.code,
    required this.token,
    this.expiresAt,
  });

  final String invitationId;
  final String code;
  final String token;
  final DateTime? expiresAt;

  String get displayCode => InviteCodes.format(code);
  Uri get link => InviteCodes.linkFor(token);
}

@immutable
class InvitePreview {
  const InvitePreview({
    required this.status,
    this.groupId,
    this.groupName,
    this.groupType,
    this.memberCount,
    this.relationshipStartDate,
    this.expiresAt,
  });

  factory InvitePreview.fromJson(Map<String, dynamic> json) {
    final type = json['group_type'] as String?;
    final start = json['relationship_start_date'] as String?;
    final expires = json['expires_at'] as String?;
    return InvitePreview(
      status: InviteStatus.parse(json['status'] as String?),
      groupId: json['group_id'] as String?,
      groupName: json['group_name'] as String?,
      groupType: type == null ? null : GroupType.parse(type),
      memberCount: (json['member_count'] as num?)?.toInt(),
      relationshipStartDate: start == null ? null : parseDate(start),
      expiresAt: expires == null ? null : DateTime.parse(expires),
    );
  }

  final InviteStatus status;
  final String? groupId;
  final String? groupName;
  final GroupType? groupType;
  final int? memberCount;
  final DateTime? relationshipStartDate;
  final DateTime? expiresAt;

  bool get canJoin => status == InviteStatus.valid;
}

@immutable
class RedeemResult {
  const RedeemResult({required this.status, this.groupId});

  factory RedeemResult.fromJson(Map<String, dynamic> json) => RedeemResult(
    status: InviteStatus.parse(json['status'] as String?),
    groupId: json['group_id'] as String?,
  );

  final InviteStatus status;
  final String? groupId;

  bool get isMember =>
      status == InviteStatus.joined || status == InviteStatus.alreadyMember;
}

/// Invite code and link helpers (pure, unit tested).
abstract final class InviteCodes {
  static const scheme = 'com.closerapp.closer';
  static const host = 'invite';
  static const codeLength = 8;

  /// Strips formatting: " abcd-efgh " → "ABCDEFGH".
  static String normalize(String input) =>
      input.toUpperCase().replaceAll(RegExp('[^A-Z0-9]'), '');

  /// "ABCDEFGH" → "ABCD-EFGH".
  static String format(String code) {
    final c = normalize(code);
    if (c.length != codeLength) return c;
    return '${c.substring(0, 4)}-${c.substring(4)}';
  }

  static bool looksLikeCode(String input) =>
      normalize(input).length == codeLength;

  static Uri linkFor(String token) =>
      Uri(scheme: scheme, host: host, queryParameters: {'t': token});

  /// Pulls an invitation secret out of a pasted link or code. Returns null
  /// when nothing usable is found.
  static String? extractSecret(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;
    final match = RegExp('$scheme://$host\\S*').firstMatch(text);
    if (match != null) {
      final uri = Uri.tryParse(match.group(0)!);
      final token = uri?.queryParameters['t'];
      if (token != null && token.isNotEmpty) return token;
    }
    if (looksLikeCode(text)) return normalize(text);
    return null;
  }

  /// Text for the system share sheet. Contains no private group content.
  static String shareMessage({
    required String groupName,
    required CreatedInvitation invitation,
  }) {
    return 'Join "$groupName" on Keeploom.\n'
        'Invite code: ${invitation.displayCode}\n'
        'Or open: ${invitation.link}';
  }
}
