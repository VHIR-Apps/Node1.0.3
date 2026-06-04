import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../config/app_config.dart';
import 'database_service.dart';


class PurchaseService {
  static final InAppPurchase _iap = InAppPurchase.instance;
  static StreamSubscription<List<PurchaseDetails>>? _subscription;

  static final Set<String> _productIds = {
    AppConfig.monthlyProductId,
    AppConfig.yearlyProductId,
  };

  static List<ProductDetails> _availableProducts = [];
  static bool _isAvailable = false;
  static bool _initialized = false;

  /// Local Pro status (used for features, ads removal, etc.)
  static final ValueNotifier<bool> proLocalNotifier =
  ValueNotifier<bool>(false);

  /// Verified Pro (trusted) — use for global/public crown only.
  static final ValueNotifier<bool> proVerifiedNotifier =
  ValueNotifier<bool>(false);

  static List<ProductDetails> get availableProducts =>
      List<ProductDetails>.unmodifiable(_availableProducts);

  static bool get isStoreAvailable => _isAvailable;

  /// Initializes IAP purchase stream + loads products.
  /// Safe to call multiple times; subsequent calls will no-op.
  static Future<void> initialize() async {
    if (!AppConfig.enableProVersion) return;
    if (_initialized) {
      // Keep notifiers in sync with local state.
      proLocalNotifier.value = DatabaseService.isProUser();
      // Verified crown is read-only; best-effort refresh.
      unawaited(refreshProVerifiedFromClaimsBestEffort());
      return;
    }

    _initialized = true;

    // Sync initial local state
    proLocalNotifier.value = DatabaseService.isProUser();

    try {
      _isAvailable = await _iap.isAvailable();
      if (!_isAvailable) {
        debugPrint('⚠️ IAP is not available on this device/store.');
        return;
      }

      // Stream Listen
      await _subscription?.cancel();
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () async {
          try {
            await _subscription?.cancel();
          } catch (_) {}
        },
        onError: (error) {
          debugPrint('❌ Purchase stream error: $error');
        },
      );

      // Pre-fetch products
      await loadProducts();

      // Auto-restore on startup (no UI prompt)
      await restorePurchases(silent: true);

      // Verified crown: best-effort refresh from claims.
      await refreshProVerifiedFromClaimsBestEffort();
    } catch (e) {
      debugPrint('❌ Purchase initialize error: $e');
    }
  }

  /// Load products from Play Store.
  static Future<List<ProductDetails>> loadProducts() async {
    if (!AppConfig.enableProVersion) return <ProductDetails>[];
    if (!_isAvailable) return <ProductDetails>[];

    try {
      final ProductDetailsResponse response =
      await _iap.queryProductDetails(_productIds);

      if (response.error != null) {
        debugPrint('❌ Error loading products: ${response.error!.message}');
        return <ProductDetails>[];
      }

      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('⚠️ Product IDs not found in Store: ${response.notFoundIDs}');
      }

      _availableProducts = response.productDetails;
      return availableProducts;
    } catch (e) {
      debugPrint('❌ Load products exception: $e');
      return <ProductDetails>[];
    }
  }

  static Future<void> _onPurchaseUpdate(
      List<PurchaseDetails> purchaseDetailsList,
      ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      try {
        switch (purchaseDetails.status) {
          case PurchaseStatus.pending:
            debugPrint('⏳ Purchase is pending...');
            break;

          case PurchaseStatus.error:
            debugPrint('❌ Purchase error: ${purchaseDetails.error?.message}');
            break;

          case PurchaseStatus.purchased:
          case PurchaseStatus.restored:
            debugPrint('✅ Purchase: ${purchaseDetails.status} ${purchaseDetails.productID}');
            await _deliverProduct(purchaseDetails);
            break;

          case PurchaseStatus.canceled:
            debugPrint('ℹ️ Purchase canceled by user.');
            break;
        }

        if (purchaseDetails.pendingCompletePurchase) {
          try {
            await _iap.completePurchase(purchaseDetails);
            debugPrint('✅ Purchase completed & acknowledged');
          } catch (e) {
            debugPrint('❌ Complete purchase error: $e');
          }
        }
      } catch (e) {
        debugPrint('❌ Purchase handling error: $e');
      }
    }
  }

  static Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    // Check if it's one of our active products or legacy products.
    final id = purchaseDetails.productID;

    final isKnown = _productIds.contains(id) ||
        id == AppConfig.proProductId ||
        id == 'habitflow_pro' ||
        id == 'habitflow_lifetime';

    if (!isKnown) return;

    try {
      await DatabaseService.setProUser(true);
      await DatabaseService.setPurchasedPlan(id);

      proLocalNotifier.value = true;

      debugPrint('💎 Pro unlocked! Plan: $id');

      // Verified crown is independent; do NOT set it here.
      // That must be server/admin verified.
      unawaited(refreshProVerifiedFromClaimsBestEffort());
    } catch (e) {
      debugPrint('❌ Deliver product failed: $e');
    }
  }

  /// Buys a product.
  /// For Android, we use GooglePlayPurchaseParam where possible.
  static Future<bool> buyProduct(String productId) async {
    if (!AppConfig.enableProVersion) return false;
    if (!_isAvailable) {
      debugPrint('❌ IAP Not Available');
      return false;
    }

    try {
      // Find the product in cache
      ProductDetails? product;
      for (final p in _availableProducts) {
        if (p.id == productId) {
          product = p;
          break;
        }
      }

      // If not cached, try fetching again
      product ??= await _fetchSingleProduct(productId);

      if (product == null) {
        debugPrint('❌ Product not found in store: $productId');
        return false;
      }

      final PurchaseParam purchaseParam = Platform.isAndroid
          ? GooglePlayPurchaseParam(productDetails: product)
          : PurchaseParam(productDetails: product);

      // Subscriptions and non-consumables both use buyNonConsumable().
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } catch (e) {
      debugPrint('❌ Buy exception: $e');
      return false;
    }
  }

  static Future<ProductDetails?> _fetchSingleProduct(String productId) async {
    try {
      final response = await _iap.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) {
        return response.productDetails.first;
      }
    } catch (e) {
      debugPrint('❌ Fetch product exception: $e');
    }
    return null;
  }

  static Future<bool> restorePurchases({bool silent = false}) async {
    if (!AppConfig.enableProVersion) return false;
    if (!_isAvailable) return false;

    try {
      if (!silent) debugPrint('🔄 Restoring purchases...');
      await _iap.restorePurchases();

      // Note: delivery happens via purchaseStream updates.
      return true;
    } catch (e) {
      debugPrint('❌ Restore error: $e');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Verified Pro Crown (Secure)
  // ─────────────────────────────────────────────

  /// Reads a trusted Pro verification from Firebase custom claims.
  ///
  /// Claim key (recommended): `proVerified`
  ///
  /// Returns:
  /// - true if the claim exists and equals true
  /// - false otherwise
  static Future<bool> isProVerifiedFromClaims() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return false;

      // Force refresh to get latest claims (best-effort).
      final token = await user.getIdTokenResult(true);
      final claims = token.claims ?? const <String, dynamic>{};

      final raw = claims['proVerified'];
      if (raw is bool) return raw;

      // Allow alternate key if you prefer:
      final raw2 = claims['isProVerified'];
      if (raw2 is bool) return raw2;

      return false;
    } catch (e) {
      debugPrint('⚠️ Pro verified claims read failed: $e');
      return false;
    }
  }

  /// Best-effort refresh of the verified pro notifier.
  /// Safe to call anytime; does not throw.
  static Future<void> refreshProVerifiedFromClaimsBestEffort() async {
    final verified = await isProVerifiedFromClaims();
    proVerifiedNotifier.value = verified;
  }

  static void dispose() {
    try {
      _subscription?.cancel();
    } catch (_) {}
  }
}