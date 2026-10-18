import 'dart:typed_data';

import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/widgets/widgets.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/groups/presentation/group_home_screen.dart';
import 'package:closer/features/photos/application/photo_providers.dart';
import 'package:closer/features/photos/presentation/add_memory_screen.dart';
import 'package:closer/features/purchases/upgrade_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';
import '../helpers/photo_fakes.dart';

Future<void> tapButton(WidgetTester tester, String label) async {
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
    expect(find.text('Basic · 1 of 10 photos kept'), findsOneWidget);
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
    expect(find.textContaining('The oldest photo was removed'), findsOneWidget);
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

  testWidgets('upgrade screen never fakes a purchase', (tester) async {
    await pump(tester);
    await openGroup(tester);
    await tester.tap(find.text('Details'));
    await tester.pumpAndSettle();
    await tapButton(tester, 'Upgrade this group');
    expect(find.byType(UpgradeScreen), findsOneWidget);
    expect(find.text('Keep every memory from this group'), findsOneWidget);
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
    expect(find.text('Keeploom Memories · keeps every photo'), findsOneWidget);
    expect(find.text('Upgrade this group'), findsNothing);
  });

  testWidgets('the + button shares into a chosen group', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Share a memory'));
    await tester.pumpAndSettle();
    expect(find.byType(AddMemoryScreen), findsOneWidget);
    expect(find.text('Choose a group'), findsOneWidget);
    await addPhoto(tester);
    expect(
      find.text('Choose a group.'),
      findsOneWidget,
      reason: 'no group yet',
    );
    await tester.tap(find.text('Crew').last);
    await tester.pumpAndSettle();
    await tapButton(tester, 'Share');
    expect(find.text('Shared with Crew'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, hasLength(1));
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
      find.widgetWithText(InkWell, 'Share'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tapButton(tester, 'Share');
    expect(find.text('Shared 2 with Crew'), findsOneWidget);
    expect((await repo.photos(groupId)).photos, hasLength(2));
  });
}
