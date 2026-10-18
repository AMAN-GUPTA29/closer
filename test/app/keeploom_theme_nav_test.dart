// Keeploom redesign: appearance (light / dark / system) with persistence,
// and the floating dock's five destinations.
import 'package:closer/app/app.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/theme/appearance.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/home/presentation/home_screen.dart';
import 'package:closer/features/journal/presentation/all_journal_screen.dart';
import 'package:closer/features/notifications/presentation/notifications_screen.dart';
import 'package:closer/features/profile/presentation/profile_screen.dart';
import 'package:closer/features/shell/keeploom_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

void main() {
  late FakeAuthRepository auth;
  late InMemoryGroupsRepository groups;

  setUp(() async {
    auth = FakeAuthRepository(initialUser: testUser);
    groups = memoryGroups(userId: testUser.id);
    await groups.createGroup(name: 'Us', type: GroupType.couple);
  });
  tearDown(() => auth.dispose());

  Brightness brightness(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(KeeploomBottomNav))).brightness;

  ThemeMode mode(WidgetTester tester) =>
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode!;

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Appearance'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
  }

  group('Appearance', () {
    testWidgets('defaults to the system setting', (tester) async {
      await pumpCloserApp(tester, repository: auth, groups: groups);
      expect(mode(tester), ThemeMode.system);
    });

    testWidgets('switching applies immediately and is saved', (tester) async {
      final store = MemoryAppearanceStore();
      await pumpCloserApp(
        tester,
        repository: auth,
        groups: groups,
        extra: [appearanceStoreProvider.overrideWithValue(store)],
      );
      await openProfile(tester);

      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(mode(tester), ThemeMode.dark);
      expect(brightness(tester), Brightness.dark);
      expect(store.value, ThemeMode.dark);

      await tester.tap(find.text('Light'));
      await tester.pumpAndSettle();
      expect(brightness(tester), Brightness.light);
      expect(store.value, ThemeMode.light);

      await tester.tap(find.text('System'));
      await tester.pumpAndSettle();
      expect(store.value, ThemeMode.system);
    });

    testWidgets('the saved choice is used on the next launch', (tester) async {
      await pumpCloserApp(
        tester,
        repository: auth,
        groups: groups,
        extra: [
          appearanceStoreProvider.overrideWithValue(
            MemoryAppearanceStore(ThemeMode.dark),
          ),
        ],
      );
      expect(brightness(tester), Brightness.dark);
    });

    test('device preferences round-trip', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = PrefsAppearanceStore(prefs);
      expect(store.read(), isNull);
      await store.write(ThemeMode.dark);
      expect(PrefsAppearanceStore(prefs).read(), ThemeMode.dark);
      await prefs.setString(PrefsAppearanceStore.key, 'nonsense');
      expect(store.read(), isNull, reason: 'unknown values fall back');
    });

    testWidgets('dark mode meets text contrast on Home and Profile', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpCloserApp(
        tester,
        repository: auth,
        groups: groups,
        extra: [
          appearanceStoreProvider.overrideWithValue(
            MemoryAppearanceStore(ThemeMode.dark),
          ),
        ],
      );
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  });

  group('Floating dock', () {
    testWidgets('reaches all destinations and keeps the selection', (
      tester,
    ) async {
      await pumpCloserApp(tester, repository: auth, groups: groups);
      expect(find.byType(HomeScreen), findsOneWidget);

      await tester.tap(find.text('Journal'));
      await tester.pumpAndSettle();
      expect(find.byType(AllJournalScreen), findsOneWidget);

      await tester.tap(find.text('Alerts'));
      await tester.pumpAndSettle();
      expect(find.byType(NotificationsScreen), findsOneWidget);

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);

      await tester.tap(find.text('Home'));
      await tester.pumpAndSettle();
      expect(find.byType(HomeScreen), findsOneWidget);
      final nav = tester.widget<KeeploomBottomNav>(
        find.byType(KeeploomBottomNav),
      );
      expect(nav.selectedIndex, 0);
    });

    testWidgets('Add opens the share sheet and it can be dismissed', (
      tester,
    ) async {
      await pumpCloserApp(tester, repository: auth, groups: groups);
      await tester.tap(find.byTooltip('Share a memory'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group'), findsOneWidget);
      expect(find.text('Us'), findsWidgets);

      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(find.text('Choose a group'), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget, reason: 'no new page');
    });

    testWidgets('the brand name is Keeploom', (tester) async {
      await pumpCloserApp(tester, repository: auth, groups: groups);
      expect(
        tester.widget<MaterialApp>(find.byType(MaterialApp)).title,
        'Keeploom',
      );
      expect(find.byType(CloserApp), findsOneWidget);
    });
  });
}
