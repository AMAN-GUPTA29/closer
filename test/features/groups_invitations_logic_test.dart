import 'dart:io';

import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/errors/backend_errors.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/routing/routes.dart';
import 'package:closer/core/utils/dates.dart';
import 'package:closer/features/auth/domain/auth_models.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/groups/domain/group_models.dart';
import 'package:closer/features/invitations/application/invite_links.dart';
import 'package:closer/features/invitations/domain/invitation_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../helpers/fakes.dart';

void main() {
  group('Group models', () {
    test('Group.fromJson reads the group_summaries row', () {
      final g = Group.fromJson({
        'id': 'g1',
        'name': 'My Love',
        'type': 'couple',
        'created_by': 'u1',
        'cover_path': null,
        'relationship_start_date': '2024-04-12',
        'show_relationship_counter': true,
        'created_at': '2024-04-12T10:00:00Z',
        'updated_at': '2024-04-12T10:00:00Z',
        'last_activity_at': '2024-05-01T10:00:00Z',
        'member_count': 2,
        'my_role': 'owner',
      });
      expect(g.type, GroupType.couple);
      expect(g.relationshipStartDate, DateTime(2024, 4, 12));
      expect(g.isOwner, isTrue);
      expect(g.isFull, isTrue);
      expect(g.hasCounter, isTrue);
      expect(g.copyWith(showRelationshipCounter: false).hasCounter, isFalse);
    });

    test('friends groups are never full', () {
      final g = Group(
        id: 'x',
        name: 'Crew',
        type: GroupType.friends,
        createdAt: DateTime(2024),
        lastActivityAt: DateTime(2024),
        memberCount: 40,
        myRole: MemberRole.member,
      );
      expect(g.isFull, isFalse);
      expect(g.hasCounter, isFalse);
    });

    test('GroupMember.fromJson reads the embedded profile', () {
      final m = GroupMember.fromJson({
        'user_id': 'u2',
        'role': 'member',
        'joined_at': '2024-04-12T10:00:00Z',
        'profiles': {'display_name': 'Emma', 'avatar_path': null},
      });
      expect(m.displayName, 'Emma');
      expect(m.isOwner, isFalse);
    });

    test('calendar dates round-trip', () {
      expect(parseDate('2024-02-29'), DateTime(2024, 2, 29));
      expect(formatDate(DateTime(2024, 2, 9)), '2024-02-09');
    });
  });

  group('Date policy', () {
    test('the start date is day 1', () {
      final start = DateTime(2024, 1, 1);
      expect(daysTogether(start, DateTime(2024, 1, 1, 23, 59)), 1);
      expect(daysTogether(start, DateTime(2024, 1, 2, 0, 1)), 2);
      expect(daysTogether(start, DateTime(2024, 4, 10)), 101);
    });

    test('leap years and future dates', () {
      expect(daysTogether(DateTime(2024, 2, 28), DateTime(2024, 3, 1)), 3);
      expect(daysTogether(DateTime(2030, 1, 1), DateTime(2024, 1, 1)), 0);
    });

    test('labels', () {
      expect(daysTogetherLabel(1), '1 day together');
      expect(daysTogetherLabel(182), '182 days together');
      final now = DateTime(2024, 5, 10, 12);
      expect(
        relativeTime(now.subtract(const Duration(seconds: 5)), now),
        'just now',
      );
      expect(
        relativeTime(now.subtract(const Duration(hours: 2)), now),
        '2h ago',
      );
      expect(
        relativeTime(now.subtract(const Duration(days: 3)), now),
        '3 days ago',
      );
      expect(expiryLabel(null, now), 'never expires');
      expect(
        expiryLabel(now.add(const Duration(days: 6, hours: 1)), now),
        'expires in 6 days',
      );
      expect(
        expiryLabel(now.subtract(const Duration(minutes: 1)), now),
        'expired',
      );
      expect(sentenceCase('expires in 1 day'), 'Expires in 1 day');
    });
  });

  group('InviteCodes', () {
    test('normalize and format', () {
      expect(InviteCodes.normalize(' abcd-ef23 '), 'ABCDEF23');
      expect(InviteCodes.format('abcdef23'), 'ABCD-EF23');
      expect(InviteCodes.looksLikeCode('ABCD EF23'), isTrue);
      expect(InviteCodes.looksLikeCode('ABC'), isFalse);
    });

    test('links carry only the token', () {
      final link = InviteCodes.linkFor('tok-_123');
      expect(link.toString(), 'com.closerapp.closer://invite?t=tok-_123');
      expect(inviteSecretFromUri(link), 'tok-_123');
    });

    test('extracts secrets from pasted messages', () {
      const message =
          'Join "Us" on Keeploom.\nInvite code: ABCD-EF23\n'
          'Or open: com.closerapp.closer://invite?t=Zx9_-token';
      expect(InviteCodes.extractSecret(message), 'Zx9_-token');
      expect(InviteCodes.extractSecret('abcd-ef23'), 'ABCDEF23');
      expect(InviteCodes.extractSecret('hello world'), isNull);
      expect(InviteCodes.extractSecret(''), isNull);
    });

    test('other app links are ignored', () {
      expect(
        inviteSecretFromUri(
          Uri.parse('com.closerapp.closer://auth-callback?code=x'),
        ),
        isNull,
      );
      expect(
        inviteSecretFromUri(Uri.parse('https://evil.example/invite?t=x')),
        isNull,
      );
      expect(
        inviteSecretFromUri(
          Uri.parse('com.closerapp.closer://invite?code=abcd-ef23'),
        ),
        'ABCDEF23',
      );
    });

    test('share message never includes private content', () {
      const inv = CreatedInvitation(
        invitationId: 'i',
        code: 'ABCDEF23',
        token: 'tok',
      );
      final text = InviteCodes.shareMessage(groupName: 'Us', invitation: inv);
      expect(text, contains('ABCD-EF23'));
      expect(text, contains('com.closerapp.closer://invite?t=tok'));
    });
  });

  group('Invitation statuses', () {
    test('parse server statuses', () {
      expect(InviteStatus.parse('already_member'), InviteStatus.alreadyMember);
      expect(InviteStatus.parse('rate_limited'), InviteStatus.rateLimited);
      expect(InviteStatus.parse('???'), InviteStatus.invalid);
      for (final s in [
        InviteStatus.invalid,
        InviteStatus.expired,
        InviteStatus.revoked,
        InviteStatus.exhausted,
        InviteStatus.full,
        InviteStatus.rateLimited,
      ]) {
        expect(s.problem, isNotNull, reason: '$s needs a message');
      }
      expect(InviteStatus.valid.problem, isNull);
    });

    test('Invitation.statusAt', () {
      final now = DateTime(2024, 5, 1);
      Invitation inv({
        DateTime? expires,
        DateTime? revoked,
        int? max,
        int used = 0,
      }) => Invitation(
        id: 'i',
        groupId: 'g',
        codeHint: 'XY',
        createdAt: DateTime(2024, 4, 1),
        expiresAt: expires,
        revokedAt: revoked,
        maxRedemptions: max,
        redemptionCount: used,
      );
      expect(inv().statusAt(now), InviteStatus.valid);
      expect(
        inv(expires: DateTime(2024, 4, 30)).statusAt(now),
        InviteStatus.expired,
      );
      expect(
        inv(revoked: DateTime(2024, 4, 2)).statusAt(now),
        InviteStatus.revoked,
      );
      expect(inv(max: 1, used: 1).statusAt(now), InviteStatus.exhausted);
    });

    test('preview and redeem results', () {
      final p = InvitePreview.fromJson({
        'status': 'valid',
        'group_id': null,
        'group_name': 'Us',
        'group_type': 'couple',
        'member_count': 1,
        'relationship_start_date': '2024-01-01',
        'expires_at': '2024-06-01T00:00:00Z',
      });
      expect(p.canJoin, isTrue);
      expect(p.groupType, GroupType.couple);
      final r = RedeemResult.fromJson({'status': 'joined', 'group_id': 'g1'});
      expect(r.isMember, isTrue);
      expect(RedeemResult.fromJson({'status': 'full'}).isMember, isFalse);
    });
  });

  group('mapBackendError', () {
    test('maps closer:* database errors', () {
      final f = mapBackendError(
        const PostgrestException(message: 'closer:group_full', code: 'P0001'),
      );
      expect(f, isA<BackendFailure>());
      expect((f as BackendFailure).key, 'group_full');
      expect(f.message, contains('two people'));
    });

    test('maps permission and network errors without leaking details', () {
      expect(
        mapBackendError(
          const PostgrestException(
            message: 'permission denied for table x',
            code: '42501',
          ),
        ),
        isA<PermissionFailure>(),
      );
      expect(
        mapBackendError(const SocketException('down')),
        isA<NetworkFailure>(),
      );
      final unknown = mapBackendError(
        const PostgrestException(
          message: 'syntax error at or near "secret"',
          code: '42601',
        ),
      );
      expect(unknown.message, isNot(contains('secret')));
    });
  });

  group('Pending invite redirect', () {
    test('signed-in users with a pending invite go to Join', () {
      expect(
        resolveRedirect(
          const SignedIn(testUser),
          Routes.home,
          hasPendingInvite: true,
        ),
        Routes.joinGroup,
      );
      expect(
        resolveRedirect(
          const SignedIn(testUser),
          Routes.joinGroup,
          hasPendingInvite: true,
        ),
        isNull,
      );
    });

    test('signed-out users still go to Welcome first', () {
      expect(
        resolveRedirect(
          const SignedOut(),
          Routes.joinGroup,
          hasPendingInvite: true,
        ),
        Routes.welcome,
      );
    });
  });

  group(
    'InMemoryGroupsRepository (preview/test backend) follows server rules',
    () {
      late InMemoryGroupsRepository repo;
      setUp(() => repo = InMemoryGroupsRepository(currentUserId: 'alice'));

      test('couple groups stop at two members', () async {
        final id = await repo.createGroup(name: 'Us', type: GroupType.couple);
        final a = await repo.create(id);
        final b = await repo.create(id);
        repo.currentUserId = 'bob';
        expect((await repo.redeem(a.code)).status, InviteStatus.joined);
        repo.currentUserId = 'carol';
        expect((await repo.preview(b.code)).status, InviteStatus.full);
        expect((await repo.redeem(b.code)).status, InviteStatus.full);
      });

      test('ownership passes on and empty groups disappear', () async {
        final id = await repo.createGroup(
          name: 'Crew',
          type: GroupType.friends,
        );
        repo.addMember(id, 'bob', 'Bob');
        await repo.leaveGroup(id);
        repo.currentUserId = 'bob';
        expect((await repo.group(id)).isOwner, isTrue);
        await repo.leaveGroup(id);
        expect(await repo.myGroups(), isEmpty);
      });
    },
  );
}
