import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Store product identifiers. Prices come from the store at runtime, never
/// from code. Override with --dart-define for other environments.
abstract final class ProductIds {
  /// Repeatable ("consumable") store product: one purchase unlocks Closer
  /// Memories for one group. See docs/purchases-and-retention.md for why it
  /// is not a non-consumable.
  static const memoriesGroup = String.fromEnvironment(
    'MEMORIES_PRODUCT_ID',
    defaultValue: 'closer_memories_group',
  );
}

@immutable
class StoreProduct {
  const StoreProduct({
    required this.id,
    required this.title,
    required this.priceLabel,
  });

  final String id;
  final String title;

  /// Localised price from the store, e.g. "$9.99" or "₹899".
  final String priceLabel;
}

enum PurchaseOutcome {
  /// The server confirmed the entitlement for the group.
  unlocked,
  cancelled,

  /// Awaiting approval (e.g. Ask to Buy); the group unlocks when it completes.
  pending,
  failed,
}

/// Client side of buying Closer Memories. The client never decides
/// entitlement: a purchase only counts after the server verifies it.
abstract interface class PurchaseService {
  /// Null when purchases can be made; otherwise a user-facing reason.
  String? get unavailableReason;

  Future<StoreProduct?> memoriesProduct();
  Future<PurchaseOutcome> buyMemories(String groupId);

  /// Re-syncs past purchases with the server (e.g. after reinstalling).
  Future<void> restore();
}

/// Used until store billing is configured (Phase 5). Never pretends a
/// purchase succeeded.
class UnavailablePurchaseService implements PurchaseService {
  const UnavailablePurchaseService();

  @override
  String? get unavailableReason =>
      'Purchases aren’t available in this build yet. Closer Memories '
      'will be available once store billing is set up.';

  @override
  Future<StoreProduct?> memoriesProduct() async => null;

  @override
  Future<PurchaseOutcome> buyMemories(String groupId) async =>
      PurchaseOutcome.failed;

  @override
  Future<void> restore() async {}
}

final purchaseServiceProvider = Provider<PurchaseService>(
  (ref) => const UnavailablePurchaseService(),
);
