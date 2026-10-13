import 'dart:async';

import 'package:closer/core/models/group_type.dart';
import 'package:closer/features/auth/domain/auth_models.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/groups/presentation/create_group_screen.dart';
import 'package:closer/features/groups/presentation/group_home_screen.dart';
import 'package:closer/features/home/presentation/home_screen.dart';
import 'package:closer/features/invitations/domain/invitation_models.dart';
import 'package:closer/features/invitations/presentation/invite_screen.dart';
import 'package:closer/features/invitations/presentation/join_group_screen.dart';
import 'package:closer/features/onboarding/presentation/onboarding_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

/// Taps the CloserButton/ghost/secondary whose label is [label].
Future<void> tapButton(WidgetTester tester, String label) async {
  final finder = find.widgetWithText(InkWell, label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthRepository auth;
  late InMemoryGroupsRepository groups;

  setUp(() {
    auth = FakeAuthRepository(initialUser: testUser);
    groups = memoryGroups(userId: testUser.id);
  });
  tearDown(() => auth.dispose());

  /// A couple group owned by someone else, with an invitation for us.
  Future<CreatedInvitation> someoneInvitesUs({
    GroupType type = GroupType.couple,
    String name = 'Emma & Alex',
    Duration? expiresIn = const Duration(days: 7),
  }) async {
    groups.currentUserId = 'emma';
    final id = await groups.createGroup(
      name: name,
      type: type,
      relationshipStartDate: type == GroupType.couple
          ? DateTime.now().subtract(const Duration(days: 181))
          : null,
    );
    final inv = await groups.create(id, expiresIn: expiresIn);
    groups.currentUserId = testUser.id;
    return inv;
  }

  testWidgets('create a couple group, then invite with a code', (tester) async {
    await pumpCloserApp(tester, repository: auth, groups: groups);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Start your first group'), findsOneWidget);

    await tapButton(tester, 'Create a group');
    expect(find.byType(CreateGroupScreen), findsOneWidget);

    // Validation: type and name are required.
    await tapButton(tester, 'Create Group');
    expect(find.text('Choose who this group is for.'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel(RegExp('^Couple')));
    await tester.pumpAndSettle();
    expect(find.text('Together since (optional)'), findsOneWidget);
    await tapButton(tester, 'Create Group');
    expect(find.text('Give your group a name.'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).first, 'My Love');
    await tapButton(tester, 'Create Group');

    expect(find.byType(InviteScreen), findsOneWidget);
    expect(find.text('Invite to My Love'), findsOneWidget);
    expect(
      find.text('Couple invitations work once — for your partner only.'),
      findsOneWidget,
    );

    await tapButton(tester, 'Create invite code');
    final created = (await groups.invitations(
      (await groups.myGroups()).single.id,
    )).single;
    expect(
      find.textContaining('Share this code or link with your partner'),
      findsOneWidget,
    );
    expect(find.textContaining('••${created.codeHint}'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Share Invite'), findsOneWidget);

    // Back to the group, then Home lists it.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupHomeScreen), findsOneWidget);
    expect(find.text('My Love'), findsWidgets);
    expect(find.text('Couple · 1 member'), findsOneWidget);
    await tester.tap(find.byTooltip('Back').first);
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('My Love'), findsOneWidget);
  });

  testWidgets('revoking an invitation asks first', (tester) async {
    final id = await groups.createGroup(name: 'Crew', type: GroupType.friends);
    await groups.create(id);
    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();

    await tapButton(tester, 'Cancel');
    expect(find.text('Cancel this invitation?'), findsOneWidget);
    await tapButton(tester, 'Cancel invitation');
    expect(find.text('Cancelled'), findsOneWidget);
    expect((await groups.invitations(id)).single.revokedAt, isNotNull);
  });

  testWidgets('join a group with a code and see the counter', (tester) async {
    final inv = await someoneInvitesUs();
    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tapButton(tester, 'Join with a code');
    expect(find.byType(JoinGroupScreen), findsOneWidget);

    await tester.enterText(find.byType(TextFormField), 'abc');
    await tester.tap(find.byTooltip('Check code'));
    await tester.pumpAndSettle();
    expect(
      find.text('Invitation codes have 8 letters and numbers.'),
      findsOneWidget,
    );

    await tester.enterText(
      find.byType(TextFormField),
      inv.displayCode.toLowerCase(),
    );
    await tester.tap(find.byTooltip('Check code'));
    await tester.pumpAndSettle();
    expect(find.text('Emma & Alex'), findsOneWidget);
    expect(find.text('Couple · 1 member'), findsOneWidget);
    expect(find.text('182 days together'), findsOneWidget);
    expect(find.text('Photos are only visible once you join.'), findsOneWidget);

    await tapButton(tester, 'Join Group');
    expect(find.byType(GroupHomeScreen), findsOneWidget);
    expect(find.text('182'), findsOneWidget);
    expect(find.text('days together'), findsOneWidget);
    // Couple is now complete: Invite does nothing.
    await tester.tap(find.text('Invite'));
    await tester.pumpAndSettle();
    expect(find.byType(InviteScreen), findsNothing);
  });

  testWidgets('join problems are explained', (tester) async {
    final first = await someoneInvitesUs(name: 'Taken');
    groups.currentUserId = 'emma';
    final full = await groups.create(
      (await groups.myGroups()).firstWhere((g) => g.name == 'Taken').id,
    );
    // Someone else fills the couple group with the first invitation.
    groups.currentUserId = 'zoe';
    await groups.redeem(first.code);
    groups.currentUserId = testUser.id;
    final expired = await someoneInvitesUs(
      name: 'Old',
      type: GroupType.friends,
      expiresIn: const Duration(microseconds: 1),
    );

    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tapButton(tester, 'Join with a code');

    await tester.enterText(find.byType(TextFormField), 'ZZZZ-ZZZZ');
    await tester.tap(find.byTooltip('Check code'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('couldn’t find that invitation'),
      findsOneWidget,
    );

    await tester.enterText(find.byType(TextFormField), full.displayCode);
    await tester.tap(find.byTooltip('Check code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('already has two people'), findsOneWidget);
    expect(find.text('Join Group'), findsNothing);

    await tester.enterText(find.byType(TextFormField), expired.displayCode);
    await tester.tap(find.byTooltip('Check code'));
    await tester.pumpAndSettle();
    expect(find.textContaining('has expired'), findsOneWidget);
  });

  testWidgets('pasting an invite message previews the group', (tester) async {
    final inv = await someoneInvitesUs(
      type: GroupType.family,
      name: 'Our Family',
    );
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async => call.method == 'Clipboard.getData'
          ? {
              'text': InviteCodes.shareMessage(
                groupName: 'Our Family',
                invitation: inv,
              ),
            }
          : null,
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tapButton(tester, 'Join with a code');
    await tapButton(tester, 'Paste invite link');
    expect(find.text('Our Family'), findsOneWidget);
    expect(find.text('Join Group'), findsOneWidget);
  });

  testWidgets('an invite link opens Join, even after signing in', (
    tester,
  ) async {
    final inv = await someoneInvitesUs(type: GroupType.friends, name: 'Crew');
    final links = StreamController<Uri>();
    addTearDown(links.close);
    final signedOut = FakeAuthRepository();
    addTearDown(signedOut.dispose);

    await pumpCloserApp(
      tester,
      repository: signedOut,
      groups: groups,
      links: links.stream,
    );
    expect(find.byType(OnboardingScreen), findsOneWidget);

    links.add(inv.link);
    await tester.pumpAndSettle();
    // Not signed in yet: stays on Welcome, the invite is kept.
    expect(find.byType(OnboardingScreen), findsOneWidget);

    signedOut.emit(const AuthEvent(user: testUser));
    await tester.pumpAndSettle();
    expect(find.byType(JoinGroupScreen), findsOneWidget);
    expect(find.text('Crew'), findsOneWidget);
  });

  testWidgets('owner manages members, renames and leaves', (tester) async {
    final id = await groups.createGroup(name: 'Crew', type: GroupType.friends);
    groups.addMember(id, 'bob', 'Bob Lee');
    groups.addMember(id, 'cat', 'Cat Wu');
    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Members'));
    await tester.pumpAndSettle();
    expect(find.text('Alex Kim (you)'), findsOneWidget);
    expect(find.text('Owner'), findsOneWidget);

    await tester.tap(find.byTooltip('Options for Bob Lee'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remove from group'));
    await tester.pumpAndSettle();
    expect(find.text('Remove Bob Lee?'), findsOneWidget);
    await tapButton(tester, 'Remove');
    expect(find.text('Bob Lee'), findsNothing);
    expect(find.text('2 members'), findsOneWidget);

    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Group settings'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Crew 2026');
    await tester.pumpAndSettle();
    await tapButton(tester, 'Save changes');
    expect(find.text('Group updated'), findsOneWidget);
    expect((await groups.group(id)).name, 'Crew 2026');

    await tapButton(tester, 'Leave group');
    expect(find.textContaining('Ownership passes'), findsOneWidget);
    await tapButton(tester, 'Leave group');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Start your first group'), findsOneWidget);
    groups.currentUserId = 'cat';
    expect(
      (await groups.group(id)).isOwner,
      isTrue,
      reason: 'ownership passed to the longest-standing member',
    );
  });

  testWidgets('non-owners see read-only settings', (tester) async {
    groups.currentUserId = 'emma';
    final id = await groups.createGroup(name: 'Family', type: GroupType.family);
    groups
      ..addMember(id, testUser.id, 'Alex Kim')
      ..currentUserId = testUser.id;
    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tester.tap(find.text('Family'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Group settings'));
    await tester.pumpAndSettle();
    expect(
      find.text('Only the group owner can change these settings.'),
      findsOneWidget,
    );
    expect(find.text('Delete group'), findsNothing);
    expect(find.text('Leave group'), findsOneWidget);
  });
}
