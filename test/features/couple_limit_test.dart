// One couple group per person (product rule 2026-10-15). The server enforces it
// with a trigger (pgTAP 009); the in-memory backend and the UI mirror it.
import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/routing/app_router.dart';
import 'package:closer/core/routing/routes.dart';
import 'package:closer/app/app.dart';
import 'package:closer/features/invitations/domain/invitation_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  test(
    'a second couple group cannot be created; others are unlimited',
    () async {
      final repo = memoryGroups(userId: 'u1');
      await repo.createGroup(name: 'Us', type: GroupType.couple);
      await expectLater(
        repo.createGroup(name: 'Again', type: GroupType.couple),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.message,
            'message',
            contains('already in a couple group'),
          ),
        ),
      );
      await repo.createGroup(name: 'Crew', type: GroupType.friends);
      await repo.createGroup(name: 'Fam', type: GroupType.family);
    },
  );

  test('someone in a couple group cannot join another one', () async {
    final repo = memoryGroups(userId: 'ann');
    final annCouple = await repo.createGroup(
      name: 'Ann',
      type: GroupType.couple,
    );
    final inv = await repo.create(annCouple);

    repo.currentUserId = 'ben';
    await repo.createGroup(name: 'Ben', type: GroupType.couple);
    expect((await repo.preview(inv.code)).status, InviteStatus.alreadyInCouple);
    expect((await repo.redeem(inv.code)).status, InviteStatus.alreadyInCouple);
    expect(InviteStatus.alreadyInCouple.problem, contains('Leave it first'));

    repo.currentUserId = 'cat';
    expect((await repo.redeem(inv.code)).status, InviteStatus.joined);
  });

  test('the server status parses', () {
    expect(
      InviteStatus.parse('already_in_couple'),
      InviteStatus.alreadyInCouple,
    );
  });

  testWidgets('the Couple option is disabled when you already have one', (
    tester,
  ) async {
    final auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(auth.dispose);
    final groups = memoryGroups(userId: testUser.id);
    await groups.createGroup(name: 'Us', type: GroupType.couple);
    await pumpCloserApp(tester, repository: auth, groups: groups);
    ProviderScope.containerOf(tester.element(find.byType(CloserApp)))
        .read(routerProvider)
        .go(Routes.createGroup);
    await tester.pumpAndSettle();

    expect(find.text('You’re already in a couple group'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel(RegExp('^Couple')));
    await tester.pumpAndSettle();
    expect(
      find.text('Together since (optional)'),
      findsNothing,
      reason: 'tapping the disabled option does nothing',
    );
  });
}
