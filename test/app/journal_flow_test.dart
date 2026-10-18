import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/widgets/widgets.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/home/presentation/home_screen.dart';
import 'package:closer/features/journal/application/content_providers.dart';
import 'package:closer/features/journal/data/in_memory_content_backend.dart';
import 'package:closer/features/journal/presentation/special_moment_screen.dart';
import 'package:closer/features/notifications/domain/notification_models.dart';
import 'package:closer/features/onboarding/presentation/onboarding_screen.dart';
import 'package:closer/features/photos/application/photo_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/photo_fakes.dart';

Future<void> tapButton(WidgetTester tester, String label) async {
  // Let any floating snack bar time out so it can't cover the button.
  await tester.pump(const Duration(seconds: 5));
  await tester.pumpAndSettle();
  if (find.text(label).evaluate().isEmpty) {
    // Lazily built lists only create visible children: scroll to it.
    await tester.scrollUntilVisible(
      find.text(label),
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
  }
  final finder = find.widgetWithText(InkWell, label).last;
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  late FakeAuthRepository auth;
  late InMemoryGroupsRepository groups;
  late InMemoryContentBackend content;
  late String couple;

  setUp(() async {
    auth = FakeAuthRepository(initialUser: testUser);
    groups = memoryGroups(userId: testUser.id);
    content = InMemoryContentBackend(groups);
    couple = await groups.createGroup(
      name: 'Us',
      type: GroupType.couple,
      relationshipStartDate: DateTime.now().subtract(const Duration(days: 91)),
    );
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester, {bool online = true}) => pumpCloserApp(
    tester,
    repository: auth,
    groups: groups,
    online: online,
    extra: [
      contentBackendProvider.overrideWithValue(content),
      imageProcessorProvider.overrideWithValue(FakeImageProcessor()),
      photoPickerProvider.overrideWithValue((_) async => tinyPng),
    ],
  );

  Future<void> openGroup(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
  }

  testWidgets('couple counter and countdown on the Milestones tab', (
    tester,
  ) async {
    await pump(tester);
    await openGroup(tester, 'Us');
    await tester.tap(find.text('Milestones'));
    await tester.pumpAndSettle();
    expect(find.text('92'), findsWidgets);
    expect(find.textContaining('100 days together in 8 days'), findsOneWidget);
  });

  testWidgets('create, pin, edit and delete a special moment', (tester) async {
    await pump(tester);
    await openGroup(tester, 'Us');
    await tester.tap(find.text('Milestones'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Create a special moment');
    expect(find.byType(SpecialMomentScreen), findsOneWidget);

    await tester.tap(find.text('First date'));
    await tester.pumpAndSettle();
    expect(
      find.widgetWithText(TextFormField, 'Our first date'),
      findsOneWidget,
    );
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'Coffee that lasted all day',
    );
    await tapButton(tester, 'Save Moment');
    expect(find.text('Moment saved'), findsOneWidget);

    final saved = (await content.milestones(couple)).single;
    expect(saved.title, 'Our first date');
    expect(saved.theme, MilestoneTheme.heart);

    // Open it from the list and pin it.
    await tester.ensureVisible(find.text('Our first date').last);
    await tester.tap(find.text('Our first date').last);
    await tester.pumpAndSettle();
    await tapButton(tester, 'Pin to top');
    expect((await content.milestones(couple)).single.isPinned, isTrue);

    // Edit.
    await tester.tap(find.text('Our first date').last);
    await tester.pumpAndSettle();
    await tapButton(tester, 'Edit');
    await tester.enterText(find.byType(TextFormField).first, 'First date ever');
    await tapButton(tester, 'Save Moment');
    expect((await content.milestones(couple)).single.title, 'First date ever');

    // Delete with confirmation.
    await tester.tap(find.text('First date ever').last);
    await tester.pumpAndSettle();
    await tapButton(tester, 'Delete');
    expect(find.text('Delete “First date ever”?'), findsOneWidget);
    await tapButton(tester, 'Delete');
    expect(await content.milestones(couple), isEmpty);
  });

  testWidgets('share a photo as a special moment pre-selects its cover', (
    tester,
  ) async {
    await pump(tester);
    await openGroup(tester, 'Us');
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Choose from gallery');
    await tester.tap(find.text('Mark as special moment'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Share Photo');

    expect(find.byType(SpecialMomentScreen), findsOneWidget);
    await tester.enterText(
      find.byType(TextFormField).first,
      'Sunset on the pier',
    );
    await tapButton(tester, 'Save Moment');
    final m = (await content.milestones(couple)).single;
    final photo = (await groups.photos(couple)).photos.single;
    expect(m.coverPhotoId, photo.id);
  });

  testWidgets('the Journal tab shows memories from every group', (
    tester,
  ) async {
    final friends = await groups.createGroup(
      name: 'Crew',
      type: GroupType.friends,
    );
    await seedPhotos(groups, couple, 1, caption: 'Beach');
    await seedPhotos(groups, friends, 1, caption: 'Hike');
    await pump(tester);
    await tester.tap(find.text('Journal'));
    await tester.pumpAndSettle();
    expect(find.text('Beach 1'), findsOneWidget);
    expect(find.text('Hike 1'), findsOneWidget);
    expect(find.text('Crew'), findsOneWidget, reason: 'cards name their group');
  });

  testWidgets('notifications: badge, open, mark read, preferences', (
    tester,
  ) async {
    content.addNotification(
      AppNotification(
        id: 1,
        groupId: couple,
        kind: NotificationKind.photoAdded,
        createdAt: DateTime.now(),
        actorName: 'Emma',
      ),
    );
    await pump(tester);
    expect(find.bySemanticsLabel('Notifications, 1 unread'), findsOneWidget);

    await tester.tap(find.text('Alerts'));
    await tester.pumpAndSettle();
    expect(find.text('Emma shared a new photo in Us'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    await tester.tap(find.text('Emma shared a new photo in Us'));
    await tester.pumpAndSettle();
    expect((await content.notifications()).single.isUnread, isFalse);

    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notification preferences'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('New photos'));
    await tester.pumpAndSettle();
    expect((await content.notificationPreferences()).photos, isFalse);
  });

  testWidgets('phone notifications and reminders can be switched off', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notification preferences'));
    await tester.pumpAndSettle();
    expect(find.textContaining('arrive in a later update'), findsNothing);
    await tester.tap(find.text('Phone notifications'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Reminders'));
    await tester.pumpAndSettle();
    final prefs = await content.notificationPreferences();
    expect(prefs.push, isFalse);
    expect(prefs.reminders, isFalse);
    expect(prefs.toJson()['push'], isFalse, reason: 'saved to the server row');
  });

  testWidgets('edit profile name', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Alexandra');
    await tapButton(tester, 'Save');
    expect(find.text('Profile updated'), findsOneWidget);
    expect(find.text('Alexandra'), findsOneWidget);
  });

  testWidgets('edit username: taken names are refused, free ones saved', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    expect(find.text('@alex.kim'), findsOneWidget);
    await tester.tap(find.text('Edit profile'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField).last, 'taken.name');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Taken: try another one'), findsOneWidget);

    await tester.enterText(find.byType(TextFormField).last, '@Alex_K');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Available'), findsOneWidget);
    await tapButton(tester, 'Save');
    expect(content.username, 'alex_k');
  });

  testWidgets('people without a username must choose one first', (
    tester,
  ) async {
    content.username = null;
    await pump(tester);
    expect(find.text('Pick a username'), findsOneWidget);
    expect(find.byType(HomeScreen), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'sam');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.text('Taken: try another one'), findsOneWidget);
    await tapButton(tester, 'Continue');
    expect(find.byType(HomeScreen), findsNothing);

    await tester.enterText(find.byType(TextFormField), 'alex.k');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Continue');
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(content.username, 'alex.k');
  });

  testWidgets('account deletion needs the typed confirmation', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Delete account'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    final button = find.widgetWithText(CloserButton, 'Delete my account');
    expect(tester.widget<CloserButton>(button).onPressed, isNull);

    await tester.enterText(find.byType(TextFormField), 'delete');
    await tester.pump();
    expect(
      tester.widget<CloserButton>(button).onPressed,
      isNull,
      reason: 'the phrase must match exactly',
    );
    await tester.enterText(find.byType(TextFormField), 'DELETE');
    await tester.pump();
    expect(tester.widget<CloserButton>(button).onPressed, isNotNull);

    await tapButton(tester, 'Delete my account');
    expect(find.text('Delete your account?'), findsOneWidget);
    await tapButton(tester, 'Delete my account');
    expect(content.accountDeleted, isTrue);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets('owner chooses a cover photo', (tester) async {
    final ids = await seedPhotos(groups, couple, 2);
    await pump(tester);
    await openGroup(tester, 'Us');
    await tester.tap(find.byTooltip('Group settings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.bySemanticsLabel('Change cover photo'));
    await tester.tap(find.bySemanticsLabel('Change cover photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('Choose Photo 1'));
    await tester.pumpAndSettle();
    expect((await groups.group(couple)).coverPhotoId, ids.first);
  });

  testWidgets('offline banner appears when the connection drops', (
    tester,
  ) async {
    await pump(tester, online: false);
    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.textContaining('Offline'), findsOneWidget);
  });
}
