import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

import 'ads/ad_manager.dart';
import 'analytics.dart';
import 'progress.dart';

/// In-app purchases: Remove Ads (non-consumable) and three coin packs
/// (consumable).
///
/// TODO(release): create these product ids in Play Console and App Store
/// Connect. Until they exist the store section simply shows as unavailable.
class Purchases extends ChangeNotifier {
  Purchases._();
  static final Purchases instance = Purchases._();

  static const String removeAds = 'eatup_remove_ads';
  static const Map<String, int> coinPacks = {
    'eatup_coins_small': 2000,
    'eatup_coins_medium': 6000,
    'eatup_coins_large': 20000,
  };
  static Set<String> get ids => {removeAds, ...coinPacks.keys};

  bool available = false;
  bool busy = false;
  final Map<String, ProductDetails> products = {};

  /// The last purchase's outcome, for a toast: true delivered, false failed.
  final ValueNotifier<bool?> lastResult = ValueNotifier(null);

  Progress? _progress;
  StreamSubscription<List<PurchaseDetails>>? _sub;

  Future<void> init(Progress progress) async {
    _progress = progress;
    if (progress.noAds) AdManager.instance.removeAds();
    final mobile = defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;
    if (kIsWeb || !mobile) return;
    try {
      final iap = InAppPurchase.instance;
      // Listen before anything else: pending purchases from a previous run
      // are delivered on this stream as soon as it's open.
      _sub ??= iap.purchaseStream.listen(_onPurchases, onError: (Object e) => debugPrint('IAP stream: $e'));
      available = await iap.isAvailable();
      if (!available) return;
      final res = await iap.queryProductDetails(ids);
      for (final p in res.productDetails) {
        products[p.id] = p;
      }
      if (res.notFoundIDs.isNotEmpty) debugPrint('IAP products not found: ${res.notFoundIDs}');
      notifyListeners();
    } catch (e) {
      debugPrint('IAP unavailable: $e');
      available = false;
    }
  }

  Future<void> buy(String id) async {
    final p = products[id];
    if (p == null || busy) return;
    busy = true;
    notifyListeners();
    try {
      final param = PurchaseParam(productDetails: p);
      if (id == removeAds) {
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: param);
      } else {
        await InAppPurchase.instance.buyConsumable(purchaseParam: param);
      }
    } catch (e) {
      debugPrint('Purchase failed to start: $e');
      busy = false;
      lastResult.value = false;
      notifyListeners();
    }
  }

  /// Settings -> Restore purchases (App Store requires it).
  Future<void> restore() async {
    if (!available) return;
    try {
      await InAppPurchase.instance.restorePurchases();
    } catch (e) {
      debugPrint('Restore failed: $e');
    }
  }

  Future<void> _onPurchases(List<PurchaseDetails> list) async {
    for (final pd in list) {
      switch (pd.status) {
        case PurchaseStatus.pending:
          continue;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          _deliver(pd);
          lastResult.value = true;
        case PurchaseStatus.error:
          lastResult.value = false;
        case PurchaseStatus.canceled:
          break;
      }
      if (pd.pendingCompletePurchase) {
        try {
          await InAppPurchase.instance.completePurchase(pd);
        } catch (e) {
          debugPrint('completePurchase failed: $e');
        }
      }
    }
    busy = false;
    notifyListeners();
  }

  void _deliver(PurchaseDetails pd) {
    final progress = _progress;
    if (progress == null) return;
    if (pd.productID == removeAds) {
      progress.setNoAds();
      AdManager.instance.removeAds();
      Analytics.instance.event('purchase', {'product': pd.productID});
      return;
    }
    final coins = coinPacks[pd.productID];
    if (coins == null) return;
    // Consumables are never "restored"; a re-delivered one is ignored.
    final key = pd.purchaseID ?? '${pd.productID}_${pd.transactionDate}';
    if (pd.status == PurchaseStatus.restored || progress.purchaseDelivered(key)) return;
    progress.markPurchaseDelivered(key);
    progress.addCoins(coins);
    Analytics.instance.event('purchase', {'product': pd.productID});
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
