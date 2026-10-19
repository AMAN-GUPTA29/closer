// End-to-end journey against a real Supabase stack (database, auth, storage,
// Edge Functions), driven through the app's own Supabase repositories.
//
// Skipped unless E2E_SUPABASE_URL, E2E_ANON_KEY and E2E_SERVICE_ROLE_KEY are
// set. CI runs it against a throwaway local stack (`supabase start`); never
// point it at the hosted project.
@Tags(['e2e'])
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:closer/core/config/app_config.dart';
import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/features/auth/data/auth_repository.dart';
import 'package:closer/features/groups/data/groups_repository.dart';
import 'package:closer/features/invitations/domain/invitation_models.dart';
import 'package:closer/features/journal/data/content_backend.dart';
import 'package:closer/features/journal/domain/journal_models.dart';
import 'package:closer/features/notifications/domain/notification_models.dart';
import 'package:closer/features/notifications/push/push_service.dart';
import 'package:closer/features/photos/data/photos_backend.dart';
import 'package:closer/features/photos/domain/photo_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

final _env = Platform.environment;
final _url = _env['E2E_SUPABASE_URL'] ?? '';
final _anon = _env['E2E_ANON_KEY'] ?? '';
final _service = _env['E2E_SERVICE_ROLE_KEY'] ?? '';

/// Throwaway password for the local stack's test accounts.
final _pw = 'Pw${DateTime.now().microsecondsSinceEpoch}x';
final _mailpit = _env['E2E_MAILPIT_URL'] ?? 'http://127.0.0.1:54324';

/// One signed-in person using the app's real data layer.
class Person {
  Person(this.client)
    : groups = SupabaseGroupsRepository(client),
      photos = SupabasePhotosBackend(client),
      content = SupabaseContentBackend(client),
      devices = SupabaseDeviceRegistry(client);

  final sb.SupabaseClient client;
  final SupabaseGroupsRepository groups;
  final SupabasePhotosBackend photos;
  final SupabaseContentBackend content;
  final SupabaseDeviceRegistry devices;

  String get id => client.auth.currentUser!.id;

  /// The app's upload sequence: reserve a slot, upload both files, finalize.
  Future<UploadResult> share(
    String groupId,
    List<int> jpeg, {
    required String key,
    String? caption,
  }) async {
    final slot = await photos.requestUpload(
      groupId,
      clientUploadId: key,
      caption: caption,
      width: 1200,
      height: 900,
      byteSize: jpeg.length,
    );
    await photos.putObject(slot.storagePath, Uint8List.fromList(jpeg));
    await photos.putObject(slot.thumbPath, Uint8List.fromList(jpeg));
    return photos.finalize(slot.photoId);
  }
}

sb.SupabaseClient _client([String? key]) => sb.SupabaseClient(
  _url,
  key ?? _anon,
  authOptions: const sb.AuthClientOptions(
    authFlowType: sb.AuthFlowType.implicit,
  ),
);

const _config = AppConfig(
  supabaseUrl: '',
  supabaseAnonKey: '',
  googleAuthEnabled: false,
  appleAuthEnabled: false,
  privacyPolicyUrl: '',
  termsUrl: '',
  supportEmail: '',
  authRedirectUrl: AppConfig.defaultAuthRedirectUrl,
);

Future<Map<String, dynamic>> _getJson(String url) async {
  final http = HttpClient();
  try {
    final res = await (await http.getUrl(Uri.parse(url))).close();
    return jsonDecode(await res.transform(utf8.decoder).join())
        as Map<String, dynamic>;
  } finally {
    http.close();
  }
}

/// Finds the newest email to [to] in Mailpit and returns its first link
/// containing [linkPart].
Future<String> _emailLink(String to, String linkPart) async {
  for (var i = 0; i < 30; i++) {
    final list = await _getJson('$_mailpit/api/v1/search?query=to:$to');
    final messages = (list['messages'] as List).cast<Map<String, dynamic>>();
    if (messages.isNotEmpty) {
      final msg = await _getJson(
        '$_mailpit/api/v1/message/${messages.first['ID']}',
      );
      final body = '${msg['HTML']} ${msg['Text']}';
      final match = RegExp(
        'https?://[^"\'\\s<>]*${RegExp.escape(linkPart)}[^"\'\\s<>]*',
      ).firstMatch(body);
      if (match != null) return match.group(0)!.replaceAll('&amp;', '&');
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError('No "$linkPart" email for $to');
}

/// Opens a link without following the redirect back into the app.
Future<int> _visit(String url) async {
  final http = HttpClient();
  try {
    final req = await http.getUrl(Uri.parse(url));
    req.followRedirects = false;
    final res = await req.close();
    await res.drain<void>();
    return res.statusCode;
  } finally {
    http.close();
  }
}

Future<Person> _confirmedPerson(String email, String name) async {
  final admin = _client(_service);
  await admin.auth.admin.createUser(
    sb.AdminUserAttributes(
      email: email,
      password: _pw,
      emailConfirm: true,
      userMetadata: {'display_name': name},
    ),
  );
  final c = _client();
  await c.auth.signInWithPassword(email: email, password: _pw);
  return Person(c);
}

Matcher _fails([Type? type]) => throwsA(
  type == null ? isA<AppFailure>() : predicate((e) => e.runtimeType == type),
);

void main() {
  final skip = _url.isEmpty || _anon.isEmpty || _service.isEmpty
      ? 'Set E2E_SUPABASE_URL, E2E_ANON_KEY and E2E_SERVICE_ROLE_KEY'
      : null;

  // The widget-test binding fakes HTTP; this suite needs the real network.
  setUpAll(() => HttpOverrides.global = null);

  final jpeg = File('assets/onboarding/couple.jpg').readAsBytesSync();
  final stamp = DateTime.now().millisecondsSinceEpoch;
  String mail(String who) => '$who.$stamp@example.test';

  late Person asha, ben, cara;
  late String couple, friends;

  test('sign up, confirm email, sign in, profile and username', () async {
    final authClient = _client();
    final auth = SupabaseAuthRepository(authClient.auth, _config);
    final result = await auth.signUp(
      email: mail('asha'),
      password: _pw,
      displayName: 'Asha',
      username: 'asha_$stamp'.substring(0, 16),
    );
    expect(result.needsEmailConfirmation, isTrue);
    await expectLater(
      auth.signIn(email: mail('asha'), password: _pw),
      _fails(),
      reason: 'unconfirmed accounts cannot sign in',
    );

    final link = await _emailLink(mail('asha'), '/verify');
    expect(await _visit(link), anyOf(302, 303));
    await auth.signIn(email: mail('asha'), password: _pw);
    expect(auth.currentUser?.emailConfirmed, isTrue);
    asha = Person(authClient);

    final profile = await asha.content.myProfile();
    expect(profile.displayName, 'Asha');
    expect(profile.username, 'asha_$stamp'.substring(0, 16));
    await asha.content.updateDisplayName('Asha Rao');
    expect((await asha.content.myProfile()).displayName, 'Asha Rao');
    expect(
      await asha.content.usernameAvailable(profile.username!),
      isTrue,
      reason: 'your own username counts as available to you',
    );

    await asha.content.setAvatar(Uint8List.fromList(jpeg));
    expect((await asha.content.myProfile()).avatarPath, isNotNull);
    await asha.content.removeAvatar();
    expect((await asha.content.myProfile()).avatarPath, isNull);

    ben = await _confirmedPerson(mail('ben'), 'Ben');
    cara = await _confirmedPerson(mail('cara'), 'Cara');
    expect(await ben.content.usernameAvailable(profile.username!), isFalse);
    expect(
      await ben.content.setUsername('ben_$stamp'.substring(0, 14)),
      isNotEmpty,
    );
    await expectLater(
      cara.content.setUsername(profile.username!),
      _fails(),
      reason: 'usernames are unique',
    );
  }, skip: skip);

  test('password reset email is sent', () async {
    final auth = SupabaseAuthRepository(_client().auth, _config);
    await auth.sendPasswordReset(mail('cara'));
    expect(
      await _emailLink(mail('cara'), '/verify'),
      contains('type=recovery'),
    );
  }, skip: skip);

  test('couple group: invite, join, capacity, one couple per person', () async {
    couple = await asha.groups.createGroup(
      name: 'Us',
      type: GroupType.couple,
      relationshipStartDate: DateTime(2025, 2, 14),
    );
    await expectLater(
      asha.groups.createGroup(name: 'Second', type: GroupType.couple),
      _fails(),
      reason: 'one couple group per person',
    );

    final invite = await asha.groups.create(
      couple,
      expiresIn: const Duration(days: 7),
    );
    final preview = await ben.groups.preview(invite.code);
    expect(preview.status, InviteStatus.valid);
    expect(preview.groupName, 'Us');
    expect((await ben.groups.redeem(invite.token)).status, InviteStatus.joined);
    expect(
      (await ben.groups.redeem(invite.code)).status,
      InviteStatus.alreadyMember,
    );
    expect((await cara.groups.redeem(invite.code)).status, InviteStatus.full);

    final members = await asha.groups.members(couple);
    expect(members.map((m) => m.userId), containsAll([asha.id, ben.id]));
    expect((await ben.groups.myGroups()).single.id, couple);
    expect(await cara.groups.myGroups(), isEmpty);
    await expectLater(cara.groups.group(couple), _fails());

    await asha.groups.revoke(invite.invitationId);
    expect(
      (await cara.groups.preview(invite.code)).status,
      InviteStatus.revoked,
    );
  }, skip: skip);

  test('photos: upload, see, caption, privacy, retention', () async {
    final first = await asha.share(
      couple,
      jpeg,
      key: 'e2e-$stamp-1',
      caption: 'Beach',
    );
    expect(first.removedCount, 0);
    // A retried upload with the same key does not duplicate.
    final again = await asha.share(
      couple,
      jpeg,
      key: 'e2e-$stamp-1',
      caption: 'Beach',
    );
    expect(again.photoId, first.photoId);

    final seen = await ben.photos.photos(couple);
    expect(seen.photos.single.caption, 'Beach');
    expect(
      await ben.photos.thumbnailBytes(seen.photos.single.thumbPath),
      isNotEmpty,
    );
    await expectLater(
      cara.photos.photos(couple),
      completion(predicate<PhotoPage>((p) => p.photos.isEmpty)),
    );
    await expectLater(
      cara.photos.thumbnailBytes(seen.photos.single.thumbPath),
      _fails(),
      reason: 'storage is private to members',
    );

    await asha.photos.updateCaption(first.photoId, 'Beach day');
    expect(
      (await ben.photos.photos(couple)).photos.single.caption,
      'Beach day',
    );
    await expectLater(
      asha.photos.setPinned(first.photoId, true),
      _fails(),
      reason: 'pinning is a Keeploom Memories feature',
    );
    await asha.groups.setCover(couple, first.photoId);
    expect((await ben.groups.group(couple)).coverPath, isNotNull);

    friends = await cara.groups.createGroup(
      name: 'Crew',
      type: GroupType.friends,
    );
    var removed = 0;
    for (var i = 0; i < 11; i++) {
      removed += (await cara.share(
        friends,
        jpeg,
        key: 'crew-$stamp-$i',
      )).removedCount;
    }
    expect(removed, 1, reason: 'Basic keeps the latest 10');
    expect((await cara.photos.photos(friends)).photos, hasLength(10));
  }, skip: skip);

  test('journal, milestones and notifications', () async {
    final draft = MilestoneDraft(
      title: '100 days',
      type: MilestoneType.daysTogether,
      eventDate: DateTime(2025, 5, 25),
      theme: parseTheme('heart'),
      description: 'Our first hundred',
    );
    final m = await asha.content.createMilestone(couple, draft);
    expect((await ben.content.milestones(couple)).single.title, '100 days');
    final updated = await asha.content.updateMilestone(
      m.id,
      MilestoneDraft(
        title: '100 days together',
        type: draft.type,
        eventDate: draft.eventDate,
        theme: draft.theme,
      ),
    );
    expect(updated.title, '100 days together');

    final feed = await ben.content.journal();
    expect(feed.entries.whereType<PhotoEntry>(), isNotEmpty);
    expect(
      feed.entries.whereType<MilestoneEntry>().single.milestone.title,
      '100 days together',
    );
    expect((await cara.content.journal(groupId: couple)).entries, isEmpty);

    final inbox = await ben.content.notifications();
    expect(
      inbox.map((n) => n.kind),
      containsAll([
        NotificationKind.photoAdded,
        NotificationKind.milestoneAdded,
      ]),
    );
    expect(inbox.where((n) => n.readAt == null), isNotEmpty);
    await ben.content.markNotificationsRead();
    expect(
      (await ben.content.notifications()).every((n) => n.readAt != null),
      isTrue,
    );
    expect(
      (await asha.content.notifications()).map((n) => n.kind),
      contains(NotificationKind.memberJoined),
    );

    const off = NotificationPreferences(photos: false, reminders: false);
    await ben.content.saveNotificationPreferences(off);
    final prefs = await ben.content.notificationPreferences();
    expect(prefs.photos, isFalse);
    expect(prefs.reminders, isFalse);
    expect(prefs.milestones, isTrue);

    await ben.devices.register('e2e-token-$stamp', 'android', '1.0.0');
    await ben.devices.unregister('e2e-token-$stamp');

    await asha.content.deleteMilestone(m.id);
    expect(await ben.content.milestones(couple), isEmpty);
  }, skip: skip);

  test('settings, ownership, leaving and deleting', () async {
    await asha.groups.updateGroup(
      couple,
      name: 'Us two',
      showRelationshipCounter: false,
    );
    final g = await ben.groups.group(couple);
    expect(g.name, 'Us two');
    expect(g.showRelationshipCounter, isFalse);
    await expectLater(
      ben.groups.updateGroup(couple, name: 'Mine'),
      _fails(),
      reason: 'only the owner edits the group',
    );
    await expectLater(ben.groups.removeMember(couple, asha.id), _fails());

    await asha.groups.transferOwnership(couple, ben.id);
    expect((await ben.groups.group(couple)).isOwner, isTrue);
    await asha.groups.leaveGroup(couple);
    expect(await asha.groups.myGroups(), isEmpty);
    expect((await ben.groups.group(couple)).memberCount, 1);

    final crewInvite = await cara.groups.create(friends);
    await ben.groups.redeem(crewInvite.code);
    await cara.groups.removeMember(friends, ben.id);
    expect(
      (await ben.groups.myGroups()).map((x) => x.id),
      isNot(contains(friends)),
    );

    await cara.groups.deleteGroup(friends);
    expect(await cara.groups.myGroups(), isEmpty);
  }, skip: skip);

  test('delete account removes the person and their solo groups', () async {
    final benId = ben.id;
    await ben.content.deleteAccount();
    final admin = _client(_service);
    await expectLater(admin.auth.admin.getUserById(benId), throwsA(anything));
    final rows = await admin
        .from('group_members')
        .select()
        .eq('user_id', benId);
    expect(rows, isEmpty);
    final groups = await admin.from('groups').select().eq('id', couple);
    expect(groups, isEmpty, reason: 'Ben was the last member of the couple');
  }, skip: skip);
}
