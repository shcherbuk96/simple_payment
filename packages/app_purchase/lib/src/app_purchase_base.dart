import 'dart:async';
import 'dart:io';

import 'package:app_purchase/src/payment_queue_delegate.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

final class AppPurchase {
  final List<String> productIds;

  AppPurchase(this.productIds) {
    _purchaseStream = StreamController<List<PurchaseDetails>?>.broadcast();

    _subscription = _inAppPurchase.purchaseStream.listen(
      (final purchaseDetailsList) async {
        await _listenToPurchaseUpdated(purchaseDetailsList);

        _purchaseStream.add(purchaseDetailsList);
      },
    );
  }

  var _notFoundIds = <String>[];
  var _products = <ProductDetails>[];
  var _purchases = <PurchaseDetails>[];
  var _purchasePending = false;
  var _isLoading = true;
  String? _productError;

  late StreamController<List<PurchaseDetails>?> _purchaseStream;

  late StreamSubscription<List<PurchaseDetails>?> _subscription;

  final _inAppPurchase = InAppPurchase.instance;

  Stream<List<PurchaseDetails>?> get purchaseStream => _purchaseStream.stream;

  InAppPurchaseStoreKitPlatformAddition get iosPlatformAddition =>
      _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();

  Future<bool> get isAvailable => _inAppPurchase.isAvailable();

  List<String> get notFoundIds => _notFoundIds;

  List<ProductDetails> get products => _products;

  List<PurchaseDetails> get purchases => _purchases;

  bool get purchasePending => _purchasePending;

  bool get isLoading => _isLoading;

  String? get productError => _productError;

  Future<void> initStoreInfo() async {
    if (!await isAvailable) {
      _notFoundIds = <String>[];
      _products = <ProductDetails>[];
      _purchases = <PurchaseDetails>[];
      _purchasePending = false;

      return;
    }

    if (Platform.isIOS) {
      await iosPlatformAddition.setDelegate(
        ExamplePaymentQueueDelegate(),
      );
    }

    final ProductDetailsResponse? productDetailResponse =
        await _getProductDetailResponse();

    if (productDetailResponse != null) {
      _products = productDetailResponse.productDetails;
      _notFoundIds = productDetailResponse.notFoundIDs;

      if (productDetailResponse.error != null) {
        _productError = productDetailResponse.error!.message;
      }
      if (productDetailResponse.productDetails.isEmpty) {
        _productError = null;
      }
    }

    _isLoading = false;
    _purchaseStream.add(null);
  }

  Future<void> confirmPriceChange() async {
    if (Platform.isIOS) {
      final iapStoreKitPlatformAddition = _inAppPurchase
          .getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
      await iapStoreKitPlatformAddition.showPriceConsentIfNeeded();

      // _purchaseStream.add(null);
    }
  }

  void buyPurchase(ProductDetails productDetails) {
    final PurchaseParam purchaseParam;

    if (Platform.isAndroid) {
      purchaseParam = GooglePlayPurchaseParam(productDetails: productDetails);
    } else {
      purchaseParam = PurchaseParam(productDetails: productDetails);
    }

    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  Future<void> restorePurchases() async {
    await _inAppPurchase.restorePurchases();
  }

  // This loading previous purchases code is just a demo. Please do not use this as it is.
  // In your app you should always verify the purchase data using the `verificationData` inside the [PurchaseDetails] object before trusting it.
  // We recommend that you use your own server to verify the purchase data.
  Map<String, PurchaseDetails> getPurchasesMap() {
    return Map<String, PurchaseDetails>.fromEntries(
      _purchases.map(
        (final PurchaseDetails purchase) {
          if (purchase.pendingCompletePurchase) {
            _completePurchase(purchase);
          }

          return MapEntry<String, PurchaseDetails>(
            purchase.productID,
            purchase,
          );
        },
      ),
    );
  }

  Future<ProductDetailsResponse?> _getProductDetailResponse() async {
    if (!await isAvailable) {
      return null;
    }

    return _inAppPurchase.queryProductDetails(productIds.toSet());
  }

  Future<void> _completePurchase(PurchaseDetails purchase) async {
    return _inAppPurchase.completePurchase(purchase);
  }

  Future<void> _deliverProduct(PurchaseDetails purchaseDetails) async {
    // IMPORTANT!! Always verify purchase details before delivering the product.
    _purchases.add(purchaseDetails);
    _purchasePending = false;
  }

  Future<void> _listenToPurchaseUpdated(
    final List<PurchaseDetails>? purchaseDetailsList,
  ) async {
    if (purchaseDetailsList == null) {
      return;
    }

    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          _handleError(purchaseDetails.error!);
        } else if (purchaseDetails.status == PurchaseStatus.canceled) {
          _purchasePending = false;
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final bool valid = await _verifyPurchase(purchaseDetails);
          if (valid) {
            _deliverProduct(purchaseDetails);
          } else {
            _handleInvalidPurchase(purchaseDetails);

            return;
          }
        }

        if (purchaseDetails.pendingCompletePurchase) {
          await _completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) {
    // IMPORTANT!! Always verify a purchase before delivering the product.
    // For the purpose of an example, we directly return true.

    // TODO: Send purchaseDetails to your server for validation.
    // bool isValid = await myServer.verifyPurchase(purchaseDetails);
    // return isValid;

    return Future<bool>.value(true);
  }

  void _handleInvalidPurchase(PurchaseDetails purchaseDetails) {}

  void _handleError(IAPError error) {
    _purchasePending = false;
  }

  void dispose() {
    if (Platform.isIOS) {
      iosPlatformAddition.setDelegate(null);
    }

    _purchaseStream.close();
    _subscription.cancel();
  }
}
