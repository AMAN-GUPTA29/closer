// Accessibility review (Phase 6): every main screen at 200 % text size must lay
// out without overflow, and meet Flutter's tap-target, labelling and contrast
// guidelines at normal size.
import 'package:closer/app/app.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/routing/app_router.dart';
import 'package:closer/core/routing/routes.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/journal/application/content_providers.dart';
import 'package:closer/features/journal/data/in_memory_content_backend.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late InMemoryGroupsRepository groups;
  late String couple;
  late String family;

  setUp(() async {
    auth = FakeAuthRepository(initialUser: testUser);
    groups = memoryGroups(userId: testUser.id);
    couple = await groups.createGroup(
      name: 'Us two, with a rather long group name',
      type: GroupType.couple,
      relationshipStartDate: DateTime.now().subtract(const Duration(days: 400)),
    );
    family = await groups.createGroup(name: 'Family', type: GroupType.family);
  });
  tearDown(() => auth.dispose());

  Future<void> open(WidgetTester tester, String route) async {
    await pumpCloserApp(
      tester,
      repository: auth,
      groups: groups,
      extra: [
        contentBackendProvider.overrideWithValue(
          InMemoryContentBackend(groups),
        ),
      ],
    );
    final container = ProviderScope.containerOf(
      tester.element(find.byType(CloserApp)),
    );
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  final signedInRoutes = <String, String Function()>{
    'Home': () => Routes.home,
    'Journal': () => Routes.journal,
    'Notifications': () => Routes.notifications,
    'Notification preferences': () => Routes.notificationPreferences,
    'Profile': () => Routes.profile,
    'Edit profile': () => Routes.editProfile,
    'Purchased groups': () => Routes.purchases,
    'Delete account': () => Routes.deleteAccount,
    'Widget setup': () => Routes.widgetSetup,
    'Create group': () => Routes.createGroup,
    'Join group': () => Routes.joinGroup,
    'Couple group home': () => Routes.group(couple),
    'Family group home': () => Routes.group(family),
    'Invite': () => Routes.invite(couple),
    'Members': () => Routes.members(family),
    'Group settings': () => Routes.groupSettings(couple),
    'Upgrade': () => Routes.upgrade(family),
    'New special moment': () => Routes.newMoment(couple),
  };

  group('200 % text size', () {
    for (final entry in signedInRoutes.entries) {
      testWidgets('${entry.key} lays out without overflow', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await open(tester, entry.value());
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('signed-out screens lay out without overflow', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final out = FakeAuthRepository();
      addTearDown(out.dispose);
      await pumpCloserApp(tester, repository: out);
      expect(tester.takeException(), isNull, reason: 'onboarding');
      final router = ProviderScope.containerOf(
        tester.element(find.byType(CloserApp)),
      ).read(routerProvider);
      for (final route in [
        Routes.welcome,
        Routes.signIn,
        Routes.signUp,
        Routes.forgotPassword,
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: route);
      }
    });
  });

  group('guidelines', () {
    for (final name in [
      'Home',
      'Profile',
      'Couple group home',
      'Notification preferences',
    ]) {
      testWidgets('$name: tap targets and labels', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, signedInRoutes[name]!());
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    for (final name in ['Home', 'Profile', 'Notification preferences']) {
      testWidgets('$name: text contrast', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, signedInRoutes[name]!());
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  });
}
