import 'package:closer/core/models/group_type.dart';
import 'package:closer/features/home/presentation/all_groups_screen.dart';
import 'package:closer/features/home/presentation/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  testWidgets(
    'Home shows the two most active groups; See all lists every group',
    (tester) async {
      final auth = FakeAuthRepository(initialUser: testUser);
      addTearDown(auth.dispose);
      final groups = memoryGroups(userId: testUser.id);
      for (final n in ['One', 'Two', 'Three', 'Four', 'Five']) {
        await groups.createGroup(name: n, type: GroupType.friends);
      }
      await pumpCloserApp(tester, repository: auth, groups: groups);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(HomeScreen),
          matching: find.textContaining(RegExp(r'^(One|Two|Three|Four|Five)$')),
        ),
        findsNWidgets(homeGroupLimit),
      );

      await tester.tap(find.text('See all').first);
      await tester.pumpAndSettle();
      expect(find.byType(AllGroupsScreen), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('One'),
        200,
        scrollable: find.byType(Scrollable).last,
      );
      expect(find.text('One'), findsOneWidget);
    },
  );

  testWidgets('Recent moments invites the first share', (tester) async {
    final auth = FakeAuthRepository(initialUser: testUser);
    addTearDown(auth.dispose);
    final groups = memoryGroups(userId: testUser.id);
    await groups.createGroup(name: 'Us', type: GroupType.couple);
    await pumpCloserApp(tester, repository: auth, groups: groups);
    await tester.scrollUntilVisible(
      find.text('Recent moments'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Recent moments'), findsOneWidget);
    await tester.tap(find.text('Share a\nmoment'));
    await tester.pumpAndSettle();
    expect(find.text('Choose a group'), findsOneWidget);
  });
}
