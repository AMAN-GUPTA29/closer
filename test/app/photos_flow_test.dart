import 'dart:typed_data';

import 'package:closer/core/errors/app_failure.dart';
import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/widgets/widgets.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/groups/presentation/group_home_screen.dart';
import 'package:closer/features/photos/application/photo_providers.dart';
import 'package:closer/features/photos/domain/photo_models.dart';
import 'package:closer/features/photos/presentation/add_memory_screen.dart';
import 'package:closer/features/purchases/upgrade_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/photo_fakes.dart';

Future<void> tapButton(WidgetTester tester, String label) async {
  if (find.widgetWithText(InkWell, label).evaluate().isEmpty) {
    // Lazily built lists only create visible children: scroll to it.
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, label),
      300,
      scrollable: find.byType(Scrollable).first,
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
  late InMemoryGroupsRepository repo;
  late String groupId;

  setUp(() async {
    auth = FakeAuthRepository(initialUser: testUser);
    repo = memoryGroups(userId: testUser.id);
    groupId = await repo.createGroup(name: 'Crew', type: GroupType.friends);
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester, {Uint8List? picked}) => pumpCloserApp(
    tester,
    repository: auth,
    groups: repo,
    extra: [
      imageProcessorProvider.overrideWithValue(FakeImageProcessor()),
      photoPickerProvider.overrideWithValue((_) async => picked ?? tinyPng),
    ],
  );

  Future<void> addPhoto(WidgetTester tester) async {
    await tester.tap(find.text('Add photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
  }

  Future<void> openGroup(WidgetTester tester) async {
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupHomeScreen), findsOneWidget);
  }

  Future<void> openGroupWithHiddenPhotos(WidgetTester tester) async {
    await tester.tap(find.text('Crew'));
    await tester.pumpAndSettle();
    expect(
      find.text('Photos you reported are hidden for you.'),
      findsOneWidget,
    );
    expect(find.text('No memories yet'), findsNothing);
  }

  testWidgets('share a photo with a caption; it appears in the journal', (
    tester,
  ) async {
    await pump(tester);
    await openGroup(tester);
    expect(find.text('No memories yet'), findsOneWidget);

    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMemoryScreen), findsOneWidget);
    expect(find.text('The oldest photo will be removed'), findsNothing);

    await addPhoto(tester);
    await tester.enterText(find.byType(TextFormField), 'First dinner');
    await tapButton(tester, 'Share');

    expect(find.text('Shared with Crew'), findsOneWidget);
    expect(find.byType(GroupHomeScreen), findsOneWidget);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('1 of 10 (Basic)'), findsOneWidget);
    expect((await repo.photos(groupId)).photos.single.caption, 'First dinner');
  });

  testWidgets('full Basic group warns first, then removes the oldest', (
    tester,
  ) async {
    final ids = await seedPhotos(repo, groupId, 10);
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    expect(find.text('The oldest photo will be removed'), findsOneWidget);

    await addPhoto(tester);
    await tapButton(tester, 'Share');
    expect(find.textContaining('oldest photo was removed'), findsOneWidget);
    final photos = (await repo.photos(groupId)).photos;
    expect(photos, hasLength(10));
    expect(photos.map((p) => p.id), isNot(contains(ids.first)));
  });

  testWidgets('a failed upload shows Retry and does not duplicate', (
    tester,
  ) async {
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await addPhoto(tester);

    repo.failNextPut = true;
    await tapButton(tester, 'Share');
    expect(find.textContaining('couldn’t be uploaded'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, isEmpty);

    await tapButton(tester, 'Retry');
    expect(find.text('Shared with Crew'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, hasLength(1));
  });

  testWidgets('unsupported files are explained', (tester) async {
    await pump(tester, picked: Uint8List.fromList('%PDF-1.7 ......'.codeUnits));
    await openGroup(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await addPhoto(tester);
    expect(find.textContaining('isn’t supported'), findsOneWidget);
    final share = tester.widget<CloserButton>(
      find.widgetWithText(CloserButton, 'Share'),
    );
    expect(share.onPressed, isNull);
  });

  testWidgets('open a photo full screen and delete it', (tester) async {
    await seedPhotos(repo, groupId, 2, caption: 'Beach');
    await pump(tester);
    await openGroup(tester);

    await tester.ensureVisible(find.text('Beach 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Beach 2'));
    await tester.pumpAndSettle();
    expect(find.byType(PhotoViewer), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(PhotoViewer),
        matching: find.text('Beach 2'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 / 2'), findsOneWidget);

    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete photo'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this photo?'), findsOneWidget);
    await tapButton(tester, 'Delete');
    expect(find.byType(PhotoViewer), findsNothing);
    final left = (await repo.photos(groupId)).photos;
    expect(left.single.caption, 'Beach 1');
  });

  testWidgets('report a photo: a reason is needed, then it is hidden', (
    tester,
  ) async {
    repo
      ..addMember(groupId, 'rahul', 'Rahul')
      ..currentUserId = 'rahul';
    final ids = await seedPhotos(repo, groupId, 2, caption: 'Party');
    repo.currentUserId = testUser.id;
    await pump(tester);
    await openGroup(tester);

    await tester.ensureVisible(find.text('Party 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Party 2'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Report photo'));
    await tester.pumpAndSettle();

    final send = find.widgetWithText(CloserButton, 'Send report');
    expect(tester.widget<CloserButton>(send).onPressed, isNull);
    await tester.tap(find.text('Harassment or bullying'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Send report');

    expect(find.byType(PhotoViewer), findsNothing);
    expect(find.text('Reported. It’s now hidden for you.'), findsOneWidget);
    expect(find.text('Party 2'), findsNothing);
    expect(repo.reportBy(testUser.id, ids.last), ReportReason.harassment);
    expect((await repo.photos(groupId)).photos, hasLength(1));
    expect((await repo.group(groupId)).photoCount, 2);

    repo.currentUserId = 'rahul';
    expect((await repo.photos(groupId)).photos, hasLength(2));
  });

  testWidgets('your own photo has no report option', (tester) async {
    await seedPhotos(repo, groupId, 1, caption: 'Mine');
    await pump(tester);
    await openGroup(tester);
    await tester.ensureVisible(find.text('Mine 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mine 1'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Photo options'));
    await tester.pumpAndSettle();
    expect(find.text('Delete photo'), findsOneWidget);
    expect(find.text('Report photo'), findsNothing);
  });

  testWidgets('a reported photo stops being the cover', (tester) async {
    repo
      ..addMember(groupId, 'rahul', 'Rahul')
      ..currentUserId = 'rahul';
    final ids = await seedPhotos(repo, groupId, 1);
    repo.currentUserId = testUser.id;
    expect((await repo.group(groupId)).latestThumbPath, isNotNull);
    await repo.reportPhoto(ids.single, ReportReason.other);
    expect((await repo.group(groupId)).latestThumbPath, isNull);
    expect(await repo.pinnedPhotos(groupId), isEmpty);
    await pump(tester);
    await openGroupWithHiddenPhotos(tester);
  });

  testWidgets('upgrade screen never fakes a purchase', (tester) async {
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'See Keeploom Memories');
    expect(find.byType(UpgradeScreen), findsOneWidget);
    expect(find.text('Keep every memory from Crew'), findsOneWidget);
    expect(
      find.textContaining('aren’t available in this build'),
      findsOneWidget,
    );
    final buy = tester.widget<CloserButton>(
      find.widgetWithText(CloserButton, 'Upgrade Crew'),
    );
    expect(buy.onPressed, isNull);
  });

  testWidgets('Premium groups show their status instead of an upsell', (
    tester,
  ) async {
    repo.grantPremium(groupId);
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Every photo'), findsOneWidget);
    expect(find.text('Memories until'), findsOneWidget);
    expect(find.text('See Keeploom Memories'), findsNothing);
    expect(find.text('Renew Keeploom Memories'), findsNothing);
  });

  testWidgets('a yearly pass that ends soon asks for a renewal', (
    tester,
  ) async {
    repo.grantPremium(
      groupId,
      until: DateTime.now().add(const Duration(days: 10)),
    );
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Your pass ends on'), findsOneWidget);
    await tapButton(tester, 'Renew Keeploom Memories');
    expect(find.byType(UpgradeScreen), findsOneWidget);
    expect(find.textContaining('Keeploom Memories ends on'), findsOneWidget);
  });

  testWidgets('a lapsed pass keeps every photo during the grace period', (
    tester,
  ) async {
    repo.grantPremium(
      groupId,
      until: DateTime.now().subtract(const Duration(days: 5)),
    );
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('Every photo'), findsOneWidget);
    expect(find.text('Memories ended'), findsOneWidget);
    await tapButton(tester, 'Renew Keeploom Memories');
    expect(find.textContaining('Keeploom Memories ended on'), findsOneWidget);
    expect(find.textContaining('keeps every photo until'), findsOneWidget);
  });

  DateTime daysAgo(int n) => DateTime.now().subtract(Duration(days: n));

  testWidgets('during the 30 days the journal counts the photos at risk', (
    tester,
  ) async {
    repo.grantPremium(groupId);
    await seedPhotos(repo, groupId, 15);
    repo.grantPremium(groupId, until: daysAgo(5));
    await pump(tester);
    await openGroup(tester);
    expect(find.textContaining('Your pass ended on'), findsOneWidget);
    expect(
      find.textContaining('5 photos may be removed after'),
      findsOneWidget,
    );
    expect(find.text('Renew pass'), findsOneWidget);
  });

  testWidgets('after 30 days sharing pauses and nothing is removed', (
    tester,
  ) async {
    repo.grantPremium(groupId);
    await seedPhotos(repo, groupId, 15);
    repo.grantPremium(groupId, until: daysAgo(31));
    await pump(tester);
    await openGroup(tester);
    expect(
      find.text('Your pass ended. Renew to protect your photos.'),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await addPhoto(tester);
    expect(find.text('Renew to share with Crew'), findsOneWidget);
    expect(find.text('The oldest photo will be removed'), findsNothing);
    final share = tester.widget<CloserButton>(
      find.widgetWithText(CloserButton, 'Share'),
    );
    expect(share.onPressed, isNull);
    expect((await repo.photos(groupId)).photos, hasLength(15));
  });

  testWidgets('after 30 days the group offers a renewal, not an upgrade', (
    tester,
  ) async {
    repo.grantPremium(groupId, until: daysAgo(31));
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    expect(find.text('0 (pass ended)'), findsOneWidget);
    await tapButton(tester, 'Renew Keeploom Memories');
    expect(find.textContaining('Keeploom Memories ended on'), findsOneWidget);
    expect(find.text('Basic, what you have'), findsNothing);
  });

  testWidgets('with fewer than 10 a group whose pass ended can still share', (
    tester,
  ) async {
    await seedPhotos(repo, groupId, 9);
    repo.grantPremium(groupId, until: daysAgo(31));
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await addPhoto(tester);
    await tapButton(tester, 'Share');
    expect(find.text('Shared with Crew'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, hasLength(10));
  });

  testWidgets('the server refusal at the limit deletes nothing', (
    tester,
  ) async {
    await seedPhotos(repo, groupId, 10);
    repo.grantPremium(groupId, until: daysAgo(31));
    await expectLater(
      repo.requestUpload(groupId, clientUploadId: 'late'),
      throwsA(
        isA<BackendFailure>().having((f) => f.key, 'key', 'renewal_required'),
      ),
    );
    expect((await repo.photos(groupId)).photos, hasLength(10));
  });

  testWidgets('the + button shares into a chosen group', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMemoryScreen), findsOneWidget);
    expect(find.text('Share with'), findsOneWidget);
    await addPhoto(tester);
    expect(
      find.text('Choose at least one group.'),
      findsOneWidget,
      reason: 'no group yet',
    );
    await tester.tap(find.text('Crew').last);
    await tester.pumpAndSettle();
    await tapButton(tester, 'Share');
    expect(find.text('Shared with Crew'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, hasLength(1));
  });

  Future<void> pickBothAndShare(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await addPhoto(tester);
    await tester.tap(find.text('Crew').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Family').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'Together');
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, 'Share 1 photo with 2 groups'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(tester, 'Share 1 photo with 2 groups');
  }

  testWidgets('one share can go to several groups', (tester) async {
    final family = await repo.createGroup(
      name: 'Family',
      type: GroupType.family,
    );
    await pump(tester);
    await pickBothAndShare(tester);
    expect(find.text('Shared with Crew and Family'), findsOneWidget);
    expect((await repo.photos(groupId)).photos.single.caption, 'Together');
    expect((await repo.photos(family)).photos.single.caption, 'Together');
  });

  testWidgets('a retry only resends what failed (no duplicates)', (
    tester,
  ) async {
    final family = await repo.createGroup(
      name: 'Family',
      type: GroupType.family,
    );
    await pump(tester);
    repo.failNextPut = true;
    await pickBothAndShare(tester);
    expect(find.text('Retry'), findsOneWidget);
    await tapButton(tester, 'Retry');
    expect((await repo.photos(groupId)).photos, hasLength(1));
    expect((await repo.photos(family)).photos, hasLength(1));
  });

  testWidgets('several photos can be shared at once', (tester) async {
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    await addPhoto(tester);
    await tester.tap(find.text('Add more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from gallery'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Remove photo'), findsNWidgets(2));
    await tester.scrollUntilVisible(
      find.widgetWithText(InkWell, 'Share 2 photos with 1 group'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(tester, 'Share 2 photos with 1 group');
    expect(find.text('Shared 2 with Crew'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, hasLength(2));
  });
}
