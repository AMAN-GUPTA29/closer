import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../auth/application/auth_providers.dart';
import '../auth/domain/auth_models.dart';
import 'revenuecat_purchase_service.dart';

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

  /// Awaiting approval (e.g. Ask to Buy) or server confirmation; the group
  /// unlocks when it completes.
  pending,
  failed,
}

/// A verified store purchase that hasn't been applied to a group yet (e.g.
/// the app closed mid-purchase, or after reinstalling).
@immutable
class UnassignedPurchase {
  const UnassignedPurchase({
    required this.transactionId,
    required this.store,
    required this.purchasedAt,
  });

  factory UnassignedPurchase.fromJson(Map<String, dynamic> json) =>
      UnassignedPurchase(
        transactionId: json['transaction_id'] as String,
        store: json['store'] as String,
        purchasedAt: DateTime.parse(json['purchased_at'] as String),
      );

  final String transactionId;
  final String store;
  final DateTime purchasedAt;
}

/// Client side of buying Closer Memories. The client never decides
/// entitlement: a purchase only counts after the server verifies it.
abstract interface class PurchaseService {
  /// Null when purchases can be made; otherwise a user-facing reason.
  String? get unavailableReason;

  Future<StoreProduct?> memoriesProduct();
  Future<PurchaseOutcome> buyMemories(String groupId);

  /// Re-syncs past purchases with the store and the server.
  Future<void> restore();

  /// Purchases the user owns that aren't attached to a group yet.
  Future<List<UnassignedPurchase>> unassignedPurchases();

  /// Applies an unassigned purchase to a group (server-verified).
  Future<PurchaseOutcome> applyPurchase(String transactionId, String groupId);
}

/// Used until store billing is configured. Never pretends a purchase
/// succeeded.
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

  @override
  Future<List<UnassignedPurchase>> unassignedPurchases() async => const [];

  @override
  Future<PurchaseOutcome> applyPurchase(
    String transactionId,
    String groupId,
  ) async => PurchaseOutcome.failed;
}

/// RevenueCat when a platform key is configured and the user is signed in
/// to a real backend; otherwise purchases are clearly unavailable.
final purchaseServiceProvider = Provider<PurchaseService>((ref) {
  final status = ref.watch(authControllerProvider);
  final key = RevenueCatKeys.forPlatform;
  if (status is! SignedIn ||
      key.isEmpty ||
      !ref.watch(authRepositoryProvider).isConfigured) {
    return const UnavailablePurchaseService();
  }
  final db = sb.Supabase.instance.client;
  return RevenueCatPurchaseService(
    apiKey: key,
    // RevenueCat's app user id is the Supabase user id, so webhooks and
    // server verification can tie purchases to accounts.
    userId: status.user.id,
    store: RevenueCatGateway(),
    verifier: SupabasePurchaseVerifier(db),
    loadUnassigned: () async {
      final rows = await db
          .from('purchase_records')
          .select('transaction_id, store, purchased_at')
          .eq('status', 'unassigned')
          .order('purchased_at', ascending: false);
      return rows.map(UnassignedPurchase.fromJson).toList();
    },
  );
});
