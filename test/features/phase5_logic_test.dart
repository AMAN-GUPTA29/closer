import 'dart:convert';
import 'dart:typed_data';

import 'package:closer/core/models/group_type.dart';
import 'package:closer/features/groups/domain/group_models.dart';
import 'package:closer/features/invitations/application/invite_links.dart';
import 'package:closer/features/notifications/push/push_service.dart';
import 'package:closer/features/purchases/purchases.dart';
import 'package:closer/features/purchases/revenuecat_purchase_service.dart';
import 'package:closer/features/widgets/widget_sync.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/fakes.dart';

Group mkGroup(
  String id,
  String name, {
  GroupType type = GroupType.friends,
  DateTime? start,
  int photos = 0,
  String? thumb,
}) => Group(
  id: id,
  name: name,
  type: type,
  createdAt: DateTime(2024),
  lastActivityAt: DateTime(2026, 10, 14, 10),
  memberCount: 3,
  myRole: MemberRole.owner,
  relationshipStartDate: start,
  photoCount: photos,
  latestThumbPath: thumb,
);

class FakeGateway implements StoreGateway {
  FakeGateway({this.purchaseError, this.tx = 'tx-1'});

  StoreError? purchaseError;
  String tx;
  int configured = 0;
  int restores = 0;

  @override
  Future<void> configure(String apiKey, String appUserId) async => configured++;
  @override
  Future<StoreProduct?> product(String productId) async => StoreProduct(
    id: productId,
    title: 'Closer Memories',
    priceLabel: r'$9.99',
  );
  @override
  Future<String> purchase(String productId) async {
    final e = purchaseError;
    if (e != null) throw e;
    return tx;
  }

  @override
  Future<void> restore() async => restores++;
}

class FakeVerifier implements PurchaseVerifier {
  FakeVerifier(this.answers);

  final List<VerifyStatus> answers;
  final calls = <(String, String)>[];

  @override
  Future<VerifyStatus> verify({
    required String groupId,
    required String transactionId,
    required String productId,
  }) async {
    calls.add((groupId, transactionId));
    return answers.length > 1 ? answers.removeAt(0) : answers.single;
  }
}

RevenueCatPurchaseService service(FakeGateway g, FakeVerifier v) =>
    RevenueCatPurchaseService(
      apiKey: 'appl_test',
      userId: 'u1',
      store: g,
      verifier: v,
      loadUnassigned: () async => const [],
      retryDelays: const [Duration.zero, Duration.zero],
    );

void main() {
  group('WidgetSync', () {
    late FakeWidgetPlatform platform;
    late WidgetSync sync;
    final now = DateTime(2026, 10, 14, 12);

    setUp(() {
      platform = FakeWidgetPlatform();
      sync = WidgetSync(platform, clock: () => now);
    });

    test('writes an index, a snapshot per group and covers', () async {
      await sync.syncAll(
        [
          mkGroup(
            'a',
            'My Love',
            type: GroupType.couple,
            start: DateTime(2026, 4, 16),
          ),
          mkGroup('b', 'Family', photos: 3, thumb: 'b/p/thumb.jpg'),
        ],
        coverBytes: (g) async =>
            g.latestThumbPath == null ? null : Uint8List(5),
      );
      final index = jsonDecode(platform.values[WidgetKeys.groupIndex]!) as List;
      expect(index.map((e) => e['id']), ['a', 'b']);
      final a = jsonDecode(platform.values[WidgetKeys.group('a')]!) as Map;
      expect(a['subtitle'], '182 days');
      expect(a['type'], 'couple');
      final b = jsonDecode(platform.values[WidgetKeys.group('b')]!) as Map;
      expect(b['subtitle'], startsWith('New memory'));
      expect(b['imagePath'], '/widgets/b.jpg');
      expect(platform.images.keys, ['b']);
      expect(platform.values[WidgetKeys.signedIn], 'true');
      expect(platform.refreshes, [null], reason: 'one refresh for all widgets');
    });

    test('revoked groups disappear from widgets', () async {
      await sync.syncAll([
        mkGroup('a', 'A', thumb: 'x'),
        mkGroup('b', 'B', thumb: 'y'),
      ], coverBytes: (_) async => Uint8List(1));
      await sync.syncAll([
        mkGroup('a', 'A', thumb: 'x'),
      ], coverBytes: (_) async => Uint8List(1));
      expect(platform.values.containsKey(WidgetKeys.group('b')), isFalse);
      expect(platform.images.containsKey('b'), isFalse);
    });

    test('a failing cover download does not block other data', () async {
      await sync.syncAll([
        mkGroup('a', 'A', thumb: 'x'),
      ], coverBytes: (_) => Future.error(Exception('offline')));
      expect(platform.values[WidgetKeys.group('a')], isNotNull);
    });

    test('sign-out wipes everything widgets could show', () async {
      await sync.syncAll([
        mkGroup('a', 'A', thumb: 'x'),
      ], coverBytes: (_) async => Uint8List(1));
      await sync.clear();
      expect(platform.values.keys, [WidgetKeys.signedIn]);
      expect(platform.values[WidgetKeys.signedIn], 'false');
      expect(platform.images, isEmpty);
    });

    test('updating one group refreshes only its widgets', () async {
      await sync.updateGroup(mkGroup('a', 'A'));
      expect(platform.refreshes, ['a']);
    });
  });

  group('Links and pushes', () {
    test('group links from widgets and notifications', () {
      const id = '5f0c6d2e-1a2b-4c3d-8e9f-0a1b2c3d4e5f';
      expect(groupIdFromUri(Uri.parse('com.closerapp.closer://group/$id')), id);
      expect(
        groupIdFromUri(Uri.parse('com.closerapp.closer://group/group-1')),
        'group-1',
        reason: 'Preview ids',
      );
      expect(
        groupIdFromUri(Uri.parse('com.closerapp.closer://group/a/b')),
        isNull,
      );
      expect(
        groupIdFromUri(Uri.parse('com.closerapp.closer://group/bad%20id')),
        isNull,
      );
      expect(
        groupIdFromUri(Uri.parse('https://evil.example/group/$id')),
        isNull,
      );
    });

    test('push payloads carry ids only', () {
      final e = PushEvent.fromData({
        'type': 'photo_added',
        'group_id': 'g1',
        'notification_id': '42',
      });
      expect(e.groupId, 'g1');
      expect(e.notificationId, 42);
      expect(PushEvent.fromData(const {}).type, 'unknown');
    });
  });

  group('RevenueCat purchase flow', () {
    test('a verified purchase unlocks the group', () async {
      final v = FakeVerifier([VerifyStatus.granted]);
      final g = FakeGateway();
      expect(await service(g, v).buyMemories('g1'), PurchaseOutcome.unlocked);
      expect(v.calls, [('g1', 'tx-1')]);
      expect(g.configured, 1);
    });

    test('cancelled and pending store results', () async {
      final v = FakeVerifier([VerifyStatus.granted]);
      expect(
        await service(
          FakeGateway(
            purchaseError: const StoreError(StoreErrorKind.cancelled),
          ),
          v,
        ).buyMemories('g1'),
        PurchaseOutcome.cancelled,
      );
      expect(
        await service(
          FakeGateway(purchaseError: const StoreError(StoreErrorKind.pending)),
          v,
        ).buyMemories('g1'),
        PurchaseOutcome.pending,
      );
      expect(v.calls, isEmpty, reason: 'nothing to verify');
    });

    test('waits for the store to report the purchase', () async {
      final v = FakeVerifier([VerifyStatus.notFoundYet, VerifyStatus.granted]);
      expect(
        await service(FakeGateway(), v).buyMemories('g1'),
        PurchaseOutcome.unlocked,
      );
      expect(v.calls, hasLength(2));
    });

    test(
      'stays pending (recoverable) when the server never confirms',
      () async {
        final v = FakeVerifier([VerifyStatus.notFoundYet]);
        expect(
          await service(FakeGateway(), v).buyMemories('g1'),
          PurchaseOutcome.pending,
        );
        expect(v.calls, hasLength(3), reason: 'first try + 2 retries');
      },
    );

    test('server refusals fail without unlocking', () async {
      final v = FakeVerifier([VerifyStatus.refused]);
      expect(
        await service(FakeGateway(), v).buyMemories('g1'),
        PurchaseOutcome.failed,
      );
    });

    test('unassigned purchases are applied through verification', () async {
      final v = FakeVerifier([VerifyStatus.granted]);
      expect(
        await service(FakeGateway(), v).applyPurchase('tx-9', 'g2'),
        PurchaseOutcome.unlocked,
      );
      expect(v.calls, [('g2', 'tx-9')]);
    });

    test('the unavailable service never pretends', () async {
      const s = UnavailablePurchaseService();
      expect(s.unavailableReason, isNotNull);
      expect(await s.buyMemories('g'), PurchaseOutcome.failed);
      expect(await s.unassignedPurchases(), isEmpty);
    });
  });
}
