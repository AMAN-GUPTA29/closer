import 'dart:async';
import 'dart:convert';

import 'package:closer/core/models/group_type.dart';
import 'package:closer/core/sync/realtime_feed.dart';
import 'package:closer/features/auth/domain/auth_models.dart';
import 'package:closer/features/groups/data/in_memory_groups_repository.dart';
import 'package:closer/features/groups/presentation/group_home_screen.dart';
import 'package:closer/features/journal/application/content_providers.dart';
import 'package:closer/features/journal/data/in_memory_content_backend.dart';
import 'package:closer/features/notifications/domain/notification_models.dart';
import 'package:closer/features/notifications/push/push_service.dart';
import 'package:closer/features/onboarding/presentation/onboarding_screen.dart';
import 'package:closer/features/profile/presentation/purchased_groups_screen.dart';
import 'package:closer/features/purchases/purchases.dart';
import 'package:closer/features/widgets/widget_setup_screen.dart';
import 'package:closer/features/widgets/widget_sync.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

class FakePush implements PushService {
  final fg = StreamController<PushEvent>.broadcast();
  final op = StreamController<PushEvent>.broadcast();
  int starts = 0;
  int stops = 0;

  @override
  Future<void> start() async => starts++;
  @override
  Future<void> stop() async => stops++;
  @override
  Stream<PushEvent> get foreground => fg.stream;
  @override
  Stream<PushEvent> get opened => op.stream;
}

class FakeFeed implements RealtimeFeed {
  final changes = StreamController<RealtimeChange>.broadcast();
  String? startedFor;

  @override
  Stream<RealtimeChange> start(String userId) {
    startedFor = userId;
    return changes.stream;
  }

  @override
  Future<void> stop() async => startedFor = null;
}

class FakePurchases implements PurchaseService {
  final unassigned = <UnassignedPurchase>[
    UnassignedPurchase(
      transactionId: 'tx-7',
      store: 'play_store',
      purchasedAt: DateTime(2026, 10, 1),
    ),
  ];
  final applied = <(String, String)>[];

  @override
  String? get unavailableReason => null;
  @override
  Future<StoreProduct?> memoriesProduct() async => null;
  @override
  Future<PurchaseOutcome> buyMemories(String groupId) async =>
      PurchaseOutcome.unlocked;
  @override
  Future<void> restore() async {}
  @override
  Future<List<UnassignedPurchase>> unassignedPurchases() async =>
      List.of(unassigned);
  @override
  Future<PurchaseOutcome> applyPurchase(String tx, String groupId) async {
    applied.add((tx, groupId));
    unassigned.clear();
    return PurchaseOutcome.unlocked;
  }
}

void main() {
  late FakeAuthRepository auth;
  late InMemoryGroupsRepository groups;
  late FakePush push;
  late FakeFeed feed;
  late FakeWidgetPlatform widgets;
  late String us;

  setUp(() async {
    auth = FakeAuthRepository(initialUser: testUser);
    groups = memoryGroups(userId: testUser.id);
    push = FakePush();
    feed = FakeFeed();
    widgets = FakeWidgetPlatform();
    us = await groups.createGroup(
      name: 'Us',
      type: GroupType.couple,
      relationshipStartDate: DateTime.now().subtract(const Duration(days: 9)),
    );
  });
  tearDown(() => auth.dispose());

  Future<void> pump(WidgetTester tester, {List<Override> extra = const []}) =>
      pumpCloserApp(
        tester,
        repository: auth,
        groups: groups,
        widgets: widgets,
        push: push,
        feed: feed,
        extra: extra,
      );

  testWidgets('signing in starts push and realtime and fills the widgets', (
    tester,
  ) async {
    await pump(tester);
    await tester.pumpAndSettle();
    expect(push.starts, 1);
    expect(feed.startedFor, testUser.id);
    final snap = jsonDecode(widgets.values[WidgetKeys.group(us)]!) as Map;
    expect(snap['name'], 'Us');
    expect(snap['subtitle'], '10 days');
    expect(widgets.values[WidgetKeys.signedIn], 'true');
  });

  testWidgets('a tapped push opens its group', (tester) async {
    await pump(tester);
    push.op.add(PushEvent(type: 'photo_added', groupId: us));
    await tester.pumpAndSettle();
    expect(find.byType(GroupHomeScreen), findsOneWidget);
  });

  testWidgets('realtime changes refresh data and widgets', (tester) async {
    await pump(tester);
    final other = await groups.createGroup(
      name: 'Crew',
      type: GroupType.friends,
    );
    feed.changes.add(RealtimeChange('group_members', groupId: other));
    await tester.pumpAndSettle();
    expect(find.text('Crew'), findsOneWidget, reason: 'Home refetched');
    expect(widgets.values.containsKey(WidgetKeys.group(other)), isTrue);
  });

  testWidgets('a new notification shows a banner that opens its group', (
    tester,
  ) async {
    final content = InMemoryContentBackend(groups);
    await pump(
      tester,
      extra: [contentBackendProvider.overrideWithValue(content)],
    );
    content.addNotification(
      AppNotification(
        id: 77,
        groupId: us,
        kind: NotificationKind.photoAdded,
        createdAt: DateTime.now(),
        actorName: 'Sam',
      ),
    );
    feed.changes.add(RealtimeChange('notifications', groupId: us, rowId: 77));
    await tester.pumpAndSettle();
    expect(find.text('Sam shared a new photo in Us'), findsOneWidget);

    await tester.tap(find.text('Sam shared a new photo in Us'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupHomeScreen), findsOneWidget);
    expect(find.text('Sam shared a new photo in Us'), findsNothing);
    expect((await content.notifications()).single.isUnread, isFalse);
  });

  testWidgets('the banner hides itself after a few seconds', (tester) async {
    final content = InMemoryContentBackend(groups);
    await pump(
      tester,
      extra: [contentBackendProvider.overrideWithValue(content)],
    );
    content.addNotification(
      AppNotification(
        id: 78,
        groupId: us,
        kind: NotificationKind.memberJoined,
        createdAt: DateTime.now(),
        actorName: 'Sam',
      ),
    );
    feed.changes.add(RealtimeChange('notifications', groupId: us, rowId: 78));
    await tester.pumpAndSettle();
    expect(find.text('Sam joined Us'), findsOneWidget);
    await tester.pump(const Duration(seconds: 6));
    await tester.pumpAndSettle();
    expect(find.text('Sam joined Us'), findsNothing);
  });

  testWidgets('signing out stops push and clears widget data', (tester) async {
    await pump(tester);
    auth.emit(const AuthEvent(user: null));
    await tester.pumpAndSettle();
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(push.stops, 1);
    expect(widgets.values[WidgetKeys.signedIn], 'false');
    expect(widgets.values.containsKey(WidgetKeys.group(us)), isFalse);
  });

  testWidgets('widget setup previews groups and adds a widget', (tester) async {
    var pinned = 0;
    await pump(
      tester,
      extra: [
        canPinWidgetProvider.overrideWithValue(true),
        pinWidgetProvider.overrideWithValue(() async {
          pinned++;
          return true;
        }),
      ],
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Home screen widgets'));
    await tester.pumpAndSettle();
    expect(find.byType(WidgetSetupScreen), findsOneWidget);
    expect(
      find.bySemanticsLabel(RegExp('^Widget preview for Us')),
      findsOneWidget,
    );
    await tester.tap(find.text('Add a widget'));
    await tester.pumpAndSettle();
    expect(pinned, 1);
    expect(find.textContaining('Confirm on the next screen'), findsOneWidget);
  });

  testWidgets('an unused purchase can be applied to a group', (tester) async {
    final purchases = FakePurchases();
    await pump(
      tester,
      extra: [purchaseServiceProvider.overrideWithValue(purchases)],
    );
    await tester.tap(find.text('Profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Keeploom Memories'));
    await tester.pumpAndSettle();
    expect(find.byType(PurchasedGroupsScreen), findsOneWidget);
    expect(find.text('Unused Keeploom Memories purchase'), findsOneWidget);
    await tester.tap(find.text('Choose a group'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Us').last);
    await tester.pumpAndSettle();
    expect(purchases.applied, [('tx-7', us)]);
    expect(find.text('Us now keeps every memory.'), findsOneWidget);
  });
}
