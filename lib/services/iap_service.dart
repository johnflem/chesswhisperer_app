import 'dart:async';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'ad_service.dart';

class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Product ID for removing ads - must match what you set up in Play Console
  static const String removeAdsProductId = 'remove_ads';

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isPurchasing = false;

  bool get isAvailable => _isAvailable;
  bool get isPurchasing => _isPurchasing;
  List<ProductDetails> get products => _products;

  Future<void> initialize() async {
    _isAvailable = await _iap.isAvailable();

    if (_isAvailable) {
      await _loadProducts();
      _listenToPurchases();
    }
  }

  Future<void> _loadProducts() async {
    const Set<String> ids = {removeAdsProductId};
    final ProductDetailsResponse response = await _iap.queryProductDetails(ids);

    if (response.notFoundIDs.isNotEmpty) {
      print('Products not found: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
  }

  void _listenToPurchases() {
    _subscription = _iap.purchaseStream.listen(
      (List<PurchaseDetails> purchases) {
        _handlePurchases(purchases);
      },
      onError: (error) {
        print('Purchase stream error: $error');
      },
    );
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // User successfully purchased ad removal
        await AdService().removeAds();

        // Complete the purchase
        if (purchase.pendingCompletePurchase) {
          await _iap.completePurchase(purchase);
        }
      } else if (purchase.status == PurchaseStatus.error) {
        print('Purchase error: ${purchase.error}');
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }

    _isPurchasing = false;
  }

  Future<bool> purchaseRemoveAds() async {
    if (!_isAvailable || _products.isEmpty) {
      return false;
    }

    final product = _products.firstWhere(
      (p) => p.id == removeAdsProductId,
      orElse: () => throw Exception('Product not found'),
    );

    _isPurchasing = true;

    final PurchaseParam param = PurchaseParam(productDetails: product);
    return await _iap.buyNonConsumable(purchaseParam: param);
  }

  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    await _iap.restorePurchases();
  }

  void dispose() {
    _subscription?.cancel();
  }
}
