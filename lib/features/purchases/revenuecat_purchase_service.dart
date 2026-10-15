import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart' as rc;
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import 'purchases.dart';

/// RevenueCat public SDK keys (client-safe). Empty = purchases disabled.
abstract final class RevenueCatKeys {
  static const android = String.fromEnvironment('REVENUECAT_ANDROID_KEY');
  static const ios = String.fromEnvironment('REVENUECAT_IOS_KEY');

  static String get forPlatform {
    if (Platform.isAndroid) return android;
    if (Platform.isIOS) return ios;
    return '';
  }
}

/// Server confirmation of a store transaction for a group.
enum VerifyStatus { granted, notFoundYet, refused, unavailable }

/// Calls the `verify-purchase` Edge Function.
abstract interface class PurchaseVerifier {
  Future<VerifyStatus> verify({
    required String groupId,
    required String transactionId,
    required String productId,
  });
}

class SupabasePurchaseVerifier implements PurchaseVerifier {
  SupabasePurchaseVerifier(this._db);

  final sb.SupabaseClient _db;

  @override
  Future<VerifyStatus> verify({
    required String groupId,
    required String transactionId,
    required String productId,
  }) async {
    try {
      final res = await _db.functions.invoke(
        'verify-purchase',
        body: {
          'group_id': groupId,
          'transaction_id': transactionId,
          'product_id': productId,
        },
      );
      return res.status == 200 ? VerifyStatus.granted : VerifyStatus.refused;
    } on sb.FunctionException catch (e) {
      return switch (e.status) {
        404 => VerifyStatus.notFoundYet,
        403 || 409 || 400 => VerifyStatus.refused,
        _ => VerifyStatus.unavailable,
      };
    } catch (_) {
      return VerifyStatus.unavailable;
    }
  }
}

/// Thin seam over the RevenueCat SDK so the flow can be unit tested.
abstract interface class StoreGateway {
  Future<void> configure(String apiKey, String appUserId);
  Future<StoreProduct?> product(String productId);

  /// Returns the store transaction id, or throws [StoreError].
  Future<String> purchase(String productId);
  Future<void> restore();
}

enum StoreErrorKind { cancelled, pending, other }

class StoreError implements Exception {
  const StoreError(this.kind);
  final StoreErrorKind kind;
}

class RevenueCatGateway implements StoreGateway {
  rc.StoreProduct? _cached;

  @override
  Future<void> configure(String apiKey, String appUserId) async {
    final config = rc.PurchasesConfiguration(apiKey)..appUserID = appUserId;
    await rc.Purchases.configure(config);
  }

  Future<rc.StoreProduct?> _product(String id) async {
    if (_cached?.identifier == id) return _cached;
    final list = await rc.Purchases.getProducts([
      id,
    ], productCategory: rc.ProductCategory.nonSubscription);
    return _cached = list.firstOrNull;
  }

  @override
  Future<StoreProduct?> product(String productId) async {
    final p = await _product(productId);
    if (p == null) return null;
    return StoreProduct(
      id: p.identifier,
      title: p.title,
      priceLabel: p.priceString,
    );
  }

  @override
  Future<String> purchase(String productId) async {
    final p = await _product(productId);
    if (p == null) throw const StoreError(StoreErrorKind.other);
    try {
      final result = await rc.Purchases.purchase(
        rc.PurchaseParams.storeProduct(p),
      );
      return result.storeTransaction.transactionIdentifier;
    } on PlatformException catch (e) {
      final code = rc.PurchasesErrorHelper.getErrorCode(e);
      throw StoreError(switch (code) {
        rc.PurchasesErrorCode.purchaseCancelledError =>
          StoreErrorKind.cancelled,
        rc.PurchasesErrorCode.paymentPendingError => StoreErrorKind.pending,
        _ => StoreErrorKind.other,
      });
    }
  }

  @override
  Future<void> restore() => rc.Purchases.restorePurchases();
}

/// Buys Closer Memories through RevenueCat and asks our server to verify the
/// transaction and unlock the group. The app never unlocks anything itself.
class RevenueCatPurchaseService implements PurchaseService {
  RevenueCatPurchaseService({
    required this.apiKey,
    required this.userId,
    required this._store,
    required this._verifier,
    required this._loadUnassigned,
    this.productId = ProductIds.memoriesGroup,
    this.retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 8),
    ],
  });

  final String apiKey;
  final String userId;
  final String productId;

  /// The store may take a moment to report a new purchase to RevenueCat.
  final List<Duration> retryDelays;
  final StoreGateway _store;
  final PurchaseVerifier _verifier;
  final Future<List<UnassignedPurchase>> Function() _loadUnassigned;
  Future<void>? _configured;

  Future<void> _ready() => _configured ??= _store.configure(apiKey, userId);

  @override
  String? get unavailableReason => null;

  @override
  Future<StoreProduct?> memoriesProduct() async {
    await _ready();
    return _store.product(productId);
  }

  Future<PurchaseOutcome> _verify(String groupId, String transactionId) async {
    for (var attempt = 0; ; attempt++) {
      final status = await _verifier.verify(
        groupId: groupId,
        transactionId: transactionId,
        productId: productId,
      );
      switch (status) {
        case VerifyStatus.granted:
          return PurchaseOutcome.unlocked;
        case VerifyStatus.refused:
          return PurchaseOutcome.failed;
        case VerifyStatus.notFoundYet:
        case VerifyStatus.unavailable:
          if (attempt >= retryDelays.length) {
            // Paid but not confirmed yet: it stays recoverable via restore.
            return PurchaseOutcome.pending;
          }
          await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  @override
  Future<PurchaseOutcome> buyMemories(String groupId) async {
    await _ready();
    final String transactionId;
    try {
      transactionId = await _store.purchase(productId);
    } on StoreError catch (e) {
      return switch (e.kind) {
        StoreErrorKind.cancelled => PurchaseOutcome.cancelled,
        StoreErrorKind.pending => PurchaseOutcome.pending,
        StoreErrorKind.other => PurchaseOutcome.failed,
      };
    }
    return _verify(groupId, transactionId);
  }

  @override
  Future<void> restore() async {
    await _ready();
    await _store.restore();
  }

  @override
  Future<List<UnassignedPurchase>> unassignedPurchases() => _loadUnassigned();

  @override
  Future<PurchaseOutcome> applyPurchase(String transactionId, String groupId) =>
      _verify(groupId, transactionId);
}
