import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Product IDs for App Store Connect In-App Purchases
const String orangeTickProductId = 'com.app.catchWatch.sub.creator.orangetick';
const String ottWeeklyProductId = 'com.app.catchWatch.sub.premium.weekly';
const String ottMonthlyProductId = 'com.app.catchWatch.sub.premium.monthly';
const String ottYearlyProductId = 'com.app.catchWatch.sub.premium.yearly';

/// All configured In-App Purchase product IDs
const Set<String> allAppProductIds = {
  ottWeeklyProductId,
  ottMonthlyProductId,
  ottYearlyProductId,
  orangeTickProductId,
};

/// Service responsible for managing Apple In-App Purchases (StoreKit).
/// Handles querying products, purchase stream listening, duplicate transaction
/// prevention, and safe completion after backend verification.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

  final Set<String> _notFoundProductIds = {};
  Set<String> get notFoundProductIds => _notFoundProductIds;

  final Set<String> _queriedProductIds = {};
  Set<String> get queriedProductIds => _queriedProductIds;

  bool _isLoadingProducts = false;
  bool get isLoadingProducts => _isLoadingProducts;

  final Set<String> _processedTransactionIds = {};
  final Set<String> _inFlightTransactionIds = {};
  final Set<String> _verifiedTransactionIds = {};
  final Set<String> _terminalTransactionIds = {};
  final Map<String, String> _terminalTransactionReasons = {};

  bool isTransactionVerified(String txId) =>
      _verifiedTransactionIds.contains(txId);
  void markTransactionVerified(String txId) =>
      _verifiedTransactionIds.add(txId);

  bool isTransactionTerminal(String txId) =>
      _terminalTransactionIds.contains(txId);
  String? getTerminalReason(String txId) => _terminalTransactionReasons[txId];
  void markTransactionTerminal(String txId, {String reason = 'terminal'}) {
    _terminalTransactionIds.add(txId);
    _terminalTransactionReasons[txId] = reason;
    if (_unresolvedOrangeTickPurchase?.purchaseID == txId) {
      _unresolvedOrangeTickPurchase = null;
    }
  }

  final Set<String> _allKnownTransactionIds = {};
  Set<String> _preExistingTransactionIds = {};

  // Unresolved pending/unfinished Orange Tick transaction from StoreKit queue
  PurchaseDetails? _unresolvedOrangeTickPurchase;
  PurchaseDetails? get unresolvedOrangeTickPurchase =>
      _unresolvedOrangeTickPurchase;
  void clearUnresolvedOrangeTickPurchase() {
    _unresolvedOrangeTickPurchase = null;
  }

  // Persistent Orange Tick purchase state & handlers
  Future<bool> Function(PurchaseDetails purchase)? orangeTickPurchaseHandler;
  String? activeOrangeTickPlanId;
  String? activeOrangeTickOrderId;
  bool isRestoring = false;
  bool isPurchasingOrangeTick = false;
  bool get hasInFlightTransaction => _inFlightTransactionIds.isNotEmpty;

  /// Begins a fresh Orange Tick purchase attempt.
  /// Captures all currently known transaction IDs so any pre-existing queue events
  /// cannot be mistaken for the result of this new purchase attempt.
  void beginOrangeTickPurchaseAttempt({
    required String orderId,
    required String planId,
  }) {
    debugPrint(
      '[ORANGE_TICK_IAP] Beginning fresh purchase attempt (orderId: $orderId, planId: $planId)',
    );
    isPurchasingOrangeTick = true;
    activeOrangeTickOrderId = orderId;
    activeOrangeTickPlanId = planId;
    _preExistingTransactionIds = Set<String>.from(_allKnownTransactionIds);
  }

  /// Ends the active Orange Tick purchase attempt.
  void endOrangeTickPurchaseAttempt() {
    debugPrint('[ORANGE_TICK_IAP] Ending purchase attempt');
    isPurchasingOrangeTick = false;
    activeOrangeTickOrderId = null;
    activeOrangeTickPlanId = null;
    _preExistingTransactionIds.clear();
  }

  /// Safely completes and marks resolved an already processed transaction
  Future<void> resolveAndCompleteTransaction(PurchaseDetails purchase) async {
    final txId = purchase.purchaseID;
    if (txId != null && txId.isNotEmpty) {
      _processedTransactionIds.add(txId);
      _verifiedTransactionIds.add(txId);
      _inFlightTransactionIds.remove(txId);
    }
    if (_unresolvedOrangeTickPurchase?.purchaseID == txId) {
      _unresolvedOrangeTickPurchase = null;
    }
    if (purchase.pendingCompletePurchase) {
      debugPrint(
        '[ORANGE_TICK_IAP] Completing settled transaction $txId in StoreKit',
      );
      await completePurchase(purchase);
    }
  }

  /// Safely completes and marks a terminal transaction (e.g. verified expired)
  /// so StoreKit removes it from the payment queue and stops redelivering it.
  Future<void> resolveAndCompleteTerminalTransaction(
    PurchaseDetails purchase, {
    String reason = 'terminal',
  }) async {
    final txId = purchase.purchaseID;
    if (txId != null && txId.isNotEmpty) {
      _terminalTransactionIds.add(txId);
      _terminalTransactionReasons[txId] = reason;
      _inFlightTransactionIds.remove(txId);
    }
    if (_unresolvedOrangeTickPurchase?.purchaseID == txId) {
      _unresolvedOrangeTickPurchase = null;
    }
    if (purchase.pendingCompletePurchase) {
      debugPrint(
        '[ORANGE_TICK_IAP] Completing terminal transaction $txId ($reason) in StoreKit',
      );
      await completePurchase(purchase);
    }
  }

  // Callbacks registered by the active subscription view/provider
  Future<bool> Function(PurchaseDetails purchase)? onVerifyPurchase;
  void Function(PurchaseDetails purchase)? onPurchaseSuccess;
  void Function(String errorMessage)? onError;
  void Function(bool isPending)? onPending;
  void Function()? onCanceled;

  /// Checks if StoreKit / IAP is available on this device
  Future<bool> isAvailable() async {
    try {
      return await _iap.isAvailable();
    } catch (e) {
      debugPrint('[IAP] isAvailable error: $e');
      return false;
    }
  }

  /// Sets up listeners and callbacks for IAP purchase events
  void initialize({
    required Future<bool> Function(PurchaseDetails purchase) onVerifyPurchase,
    required void Function(PurchaseDetails purchase) onPurchaseSuccess,
    required void Function(String errorMessage) onError,
    required void Function(bool isPending) onPending,
    required void Function() onCanceled,
  }) {
    this.onVerifyPurchase = onVerifyPurchase;
    this.onPurchaseSuccess = onPurchaseSuccess;
    this.onError = onError;
    this.onPending = onPending;
    this.onCanceled = onCanceled;

    ensurePurchaseStreamInitialized();
  }

  /// Ensures a single effective purchaseStream listener is active across the app session
  void ensurePurchaseStreamInitialized() {
    if (_subscription != null) return;
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseStreamData,
      onDone: () {
        debugPrint('[IAP] purchaseStream onDone');
        _subscription?.cancel();
        _subscription = null;
      },
      onError: (error) {
        debugPrint('[IAP] purchaseStream error: $error');
        onError?.call(error.toString());
      },
    );
  }

  /// Queries StoreKit for the product details corresponding to given IDs
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    if (productIds.isEmpty) return [];

    _isLoadingProducts = true;
    final available = await isAvailable();
    if (!available) {
      debugPrint('[IAP] Store is not available');
      _queriedProductIds.addAll(productIds);
      _notFoundProductIds.addAll(productIds);
      _isLoadingProducts = false;
      return [];
    }

    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        productIds,
      );
      if (response.error != null) {
        debugPrint('[IAP] queryProductDetails error: ${response.error}');
      }
      _queriedProductIds.addAll(productIds);
      for (final product in response.productDetails) {
        _products[product.id] = product;
        _notFoundProductIds.remove(product.id);
      }
      for (final notFoundId in response.notFoundIDs) {
        _notFoundProductIds.add(notFoundId);
        _products.remove(notFoundId);
      }
      for (final id in productIds) {
        if (!_products.containsKey(id)) {
          _notFoundProductIds.add(id);
        }
      }
      return response.productDetails;
    } catch (e) {
      debugPrint('[IAP] loadProducts exception: $e');
      _queriedProductIds.addAll(productIds);
      return [];
    } finally {
      _isLoadingProducts = false;
    }
  }

  /// Returns a cached ProductDetails if available
  ProductDetails? getProduct(String productId) => _products[productId];

  /// Returns whether a product has been successfully fetched and cached
  bool isProductLoaded(String productId) => _products.containsKey(productId);

  /// Returns whether a product was reported as not found by StoreKit
  bool isProductNotFound(String productId) =>
      _notFoundProductIds.contains(productId);

  /// Returns whether StoreKit has completed querying this product ID
  bool isProductQueried(String productId) =>
      _queriedProductIds.contains(productId);

  /// Initiates an Apple In-App Purchase for an Auto-Renewable Subscription
  Future<bool> buyProduct(ProductDetails product) async {
    final purchaseParam = PurchaseParam(productDetails: product);
    try {
      return await _iap.buyNonConsumable(purchaseParam: purchaseParam);
    } on PlatformException catch (e) {
      debugPrint(
        '[IAP] buyProduct PlatformException: ${e.code} - ${e.message}',
      );
      if (e.code == 'storekit_duplicate_product_object' ||
          (e.message?.contains('pending transaction') ?? false)) {
        // Re-throw so caller can route the pending transaction or handle specifically
        rethrow;
      }
      onError?.call(
        'Unable to initiate purchase: ${e.message ?? e.toString()}',
      );
      return false;
    } catch (e) {
      debugPrint('[IAP] buyProduct error: $e');
      onError?.call('Unable to initiate purchase: $e');
      return false;
    }
  }

  /// Initiates restore purchases flow
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[IAP] restorePurchases error: $e');
      onError?.call('Unable to restore purchases: $e');
      rethrow;
    }
  }

  /// Completes the StoreKit transaction when safe to do so
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      final txId = purchaseDetails.purchaseID ?? 'unknown';
      try {
        await _iap.completePurchase(purchaseDetails);
        debugPrint('[IAP] Transaction completed: $txId');
      } catch (e) {
        debugPrint('[IAP] completePurchase error for transaction $txId: $e');
      }
    }
  }

  /// Decodes the unencrypted payload of a signed JWS transaction token (StoreKit 2)
  Map<String, dynamic>? decodeJwsPayload(String serverVerificationData) {
    if (serverVerificationData.isEmpty ||
        !serverVerificationData.contains('.')) {
      return null;
    }
    try {
      final parts = serverVerificationData.split('.');
      if (parts.length >= 2) {
        final normalized = base64Url.normalize(parts[1]);
        final decodedBytes = base64Url.decode(normalized);
        final payloadJson = utf8.decode(decodedBytes);
        final dynamic data = jsonDecode(payloadJson);
        if (data is Map<String, dynamic>) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('[IAP] Error decoding JWS payload: $e');
    }
    return null;
  }

  /// Safely extracts the original transaction ID for both StoreKit 1 and StoreKit 2.
  /// For StoreKit 2, decodes the unencrypted payload of the signed JWS transaction.
  /// Does NOT fall back to purchaseID for StoreKit 2 renewals or restores.
  String? extractOriginalTransactionId(PurchaseDetails purchaseDetails) {
    // 1. StoreKit 1 (AppStorePurchaseDetails)
    if (purchaseDetails is AppStorePurchaseDetails) {
      final sk1OriginalId = purchaseDetails
          .skPaymentTransaction
          .originalTransaction
          ?.transactionIdentifier;
      if (sk1OriginalId != null && sk1OriginalId.isNotEmpty) {
        return sk1OriginalId;
      }
      return purchaseDetails.purchaseID;
    }

    // 2. StoreKit 2 (Signed JWS transaction token in serverVerificationData)
    final data = decodeJwsPayload(
      purchaseDetails.verificationData.serverVerificationData,
    );
    if (data != null) {
      final originalId =
          data['originalTransactionId'] ?? data['original_transaction_id'];
      if (originalId != null && originalId.toString().isNotEmpty) {
        return originalId.toString();
      }
    }

    return null;
  }

  /// Extracts the subscription expiration date from purchase details if available
  DateTime? extractExpirationDate(PurchaseDetails purchaseDetails) {
    final data = decodeJwsPayload(
      purchaseDetails.verificationData.serverVerificationData,
    );
    if (data != null) {
      final exp = data['expiresDate'] ?? data['expires_date'];
      if (exp is int) {
        return DateTime.fromMillisecondsSinceEpoch(exp);
      } else if (exp is String) {
        final parsed = int.tryParse(exp);
        if (parsed != null) return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
    }
    return null;
  }

  /// Returns whether the transaction is known to have expired locally based on signed JWS payload
  bool isTransactionExpired(PurchaseDetails purchaseDetails) {
    final expDate = extractExpirationDate(purchaseDetails);
    if (expDate != null) {
      return expDate.isBefore(DateTime.now());
    }
    return false;
  }

  /// Internal handler for purchaseStream events
  Future<void> _onPurchaseStreamData(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      debugPrint(
        '[IAP] Processing purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}, id: ${purchaseDetails.purchaseID}',
      );

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          onPending?.call(true);
          break;

        case PurchaseStatus.error:
          onPending?.call(false);
          if (purchaseDetails.productID == orangeTickProductId &&
              _unresolvedOrangeTickPurchase?.purchaseID ==
                  purchaseDetails.purchaseID) {
            _unresolvedOrangeTickPurchase = null;
          }
          final message =
              purchaseDetails.error?.message ??
              'An error occurred during the transaction.';
          onError?.call(message);
          // StoreKit requires completion of error transactions
          if (purchaseDetails.pendingCompletePurchase) {
            await completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.canceled:
          onPending?.call(false);
          if (purchaseDetails.productID == orangeTickProductId &&
              _unresolvedOrangeTickPurchase?.purchaseID ==
                  purchaseDetails.purchaseID) {
            _unresolvedOrangeTickPurchase = null;
          }
          onCanceled?.call();
          // StoreKit requires completion of canceled transactions
          if (purchaseDetails.pendingCompletePurchase) {
            await completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          await _handleSuccessfulOrRestoredPurchase(purchaseDetails);
          break;
      }
    }
  }

  /// Registers a dedicated handler for Orange Tick purchases that survives widget lifecycle transitions
  void registerOrangeTickHandler({
    required Future<bool> Function(PurchaseDetails purchase) onVerify,
    String? planId,
    String? orderId,
  }) {
    if (orangeTickPurchaseHandler == onVerify &&
        activeOrangeTickPlanId == planId &&
        activeOrangeTickOrderId == orderId) {
      debugPrint(
        '[ORANGE_TICK_IAP] Orange Tick purchase handler already registered (planId: $planId, orderId: $orderId). Skipping duplicate.',
      );
      return;
    }
    debugPrint(
      '[ORANGE_TICK_IAP] Registering Orange Tick purchase handler (planId: $planId, orderId: $orderId)',
    );
    orangeTickPurchaseHandler = onVerify;
    if (planId != null && planId.isNotEmpty) {
      activeOrangeTickPlanId = planId;
    }
    if (orderId != null && orderId.isNotEmpty) {
      activeOrangeTickOrderId = orderId;
    }
  }

  /// Unregisters the dedicated Orange Tick purchase handler once terminal state reached
  void unregisterOrangeTickHandler() {
    debugPrint('[ORANGE_TICK_IAP] Unregistering Orange Tick purchase handler');
    orangeTickPurchaseHandler = null;
    activeOrangeTickPlanId = null;
    activeOrangeTickOrderId = null;
    isPurchasingOrangeTick = false;
    _preExistingTransactionIds.clear();
  }

  /// Handles purchased and restored states
  Future<void> _handleSuccessfulOrRestoredPurchase(
    PurchaseDetails purchaseDetails,
  ) async {
    final String? txId = purchaseDetails.purchaseID;
    final isOrangeTick = purchaseDetails.productID == orangeTickProductId;

    if (txId != null && txId.isNotEmpty) {
      _allKnownTransactionIds.add(txId);
    }

    if (isOrangeTick) {
      debugPrint('[ORANGE_TICK_IAP] Purchase received');
      debugPrint(
        '[ORANGE_TICK_IAP] Status: ${purchaseDetails.status == PurchaseStatus.purchased ? "purchased" : purchaseDetails.status.name}',
      );
      debugPrint('[ORANGE_TICK_IAP] Product ID: ${purchaseDetails.productID}');
      debugPrint('[ORANGE_TICK_IAP] Transaction ID: $txId');
    }

    // Prevent duplicate or concurrent processing of the same transaction
    if (txId != null && txId.isNotEmpty) {
      if (_terminalTransactionIds.contains(txId)) {
        debugPrint(
          '[IAP] Transaction $txId was already confirmed terminal (${_terminalTransactionReasons[txId] ?? 'terminal'}). Completing in StoreKit if pending.',
        );
        if (purchaseDetails.pendingCompletePurchase) {
          await completePurchase(purchaseDetails);
        }
        if (_unresolvedOrangeTickPurchase?.purchaseID == txId) {
          _unresolvedOrangeTickPurchase = null;
        }
        return;
      }
      if (_processedTransactionIds.contains(txId) ||
          _verifiedTransactionIds.contains(txId) ||
          _inFlightTransactionIds.contains(txId)) {
        debugPrint(
          '[IAP] Transaction $txId was already processed or is currently in-flight. Completing if needed.',
        );
        if ((_processedTransactionIds.contains(txId) ||
                _verifiedTransactionIds.contains(txId)) &&
            purchaseDetails.pendingCompletePurchase) {
          await completePurchase(purchaseDetails);
        }
        return;
      }
      _inFlightTransactionIds.add(txId);
    }

    if (isOrangeTick) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Enforce handler readiness:
        // If an active purchase or explicit recovery handler is registered, process it immediately.
        // Otherwise, cache the unprompted StoreKit queue transaction until the user submits the form or initiates recovery.
        if (!isPurchasingOrangeTick || orangeTickPurchaseHandler == null) {
          if (isTransactionExpired(purchaseDetails)) {
            debugPrint(
              '[ORANGE_TICK_IAP] Unprompted transaction $txId is expired locally (expiresDate: ${extractExpirationDate(purchaseDetails)}). Not caching as active purchase.',
            );
            debugPrint(
              '[ORANGE_TICK_IAP] Completing expired/unprompted transaction $txId in StoreKit to clear pending queue',
            );
            if (purchaseDetails.pendingCompletePurchase) {
              await completePurchase(purchaseDetails);
            }
            if (_unresolvedOrangeTickPurchase?.purchaseID == txId) {
              _unresolvedOrangeTickPurchase = null;
            }
            if (txId != null && txId.isNotEmpty) {
              _inFlightTransactionIds.remove(txId);
              _terminalTransactionIds.add(txId);
              _terminalTransactionReasons[txId] = 'expired';
            }
            return;
          }
          debugPrint(
            '[ORANGE_TICK_IAP] Caching unprompted Orange Tick transaction (txId: $txId, status: ${purchaseDetails.status.name}) awaiting user submission',
          );
          _unresolvedOrangeTickPurchase = purchaseDetails;
          if (txId != null && txId.isNotEmpty) {
            _inFlightTransactionIds.remove(txId);
          }
          return;
        }
        debugPrint(
          '[ORANGE_TICK_IAP] Correlated active attempt transaction (txId: $txId, status: ${purchaseDetails.status.name})',
        );
      }
    } else {
      // Non-Orange Tick (OTT Subscription): distinguish normal purchase vs restore flow
      if (purchaseDetails.status == PurchaseStatus.restored && !isRestoring) {
        debugPrint(
          '[IAP] Ignoring restored transaction $txId as restore flow is not active. Completing if pending.',
        );
        if (purchaseDetails.pendingCompletePurchase) {
          await completePurchase(purchaseDetails);
        }
        if (txId != null && txId.isNotEmpty) {
          _inFlightTransactionIds.remove(txId);
        }
        return;
      }
    }

    onPending?.call(true);

    try {
      bool verified = false;

      if (isOrangeTick) {
        // Dedicated Orange Tick handler only (active when user tapped Submit & Subscribe or during active restore)
        if (orangeTickPurchaseHandler != null) {
          debugPrint(
            '[ORANGE_TICK_IAP] Dispatching to registered Orange Tick purchase handler',
          );
          verified = await orangeTickPurchaseHandler!(purchaseDetails);
        } else if (isRestoring && onVerifyPurchase != null) {
          debugPrint(
            '[ORANGE_TICK_IAP] Dispatching restore to active onVerifyPurchase handler',
          );
          verified = await onVerifyPurchase!(purchaseDetails);
        } else {
          debugPrint(
            '[ORANGE_TICK_IAP] Orange Tick event received without active handler. Dropping.',
          );
        }
      } else {
        // Non-Orange Tick (OTT Subscription)
        if (onVerifyPurchase != null) {
          debugPrint(
            '[IAP] Dispatching OTT purchase to active onVerifyPurchase handler',
          );
          verified = await onVerifyPurchase!(purchaseDetails);
        } else {
          debugPrint('[IAP] No OTT verification handler registered.');
        }
      }

      onPending?.call(false);

      if (verified) {
        if (txId != null && txId.isNotEmpty) {
          _processedTransactionIds.add(txId);
          _verifiedTransactionIds.add(txId);
        }
        if (isOrangeTick) {
          _unresolvedOrangeTickPurchase = null;
          debugPrint('[ORANGE_TICK_IAP] Backend verification success');
          debugPrint('[ORANGE_TICK_IAP] Completing Apple transaction');
        }
        // Never complete transaction before backend verification succeeds
        if (purchaseDetails.pendingCompletePurchase) {
          await completePurchase(purchaseDetails);
        }
        onPurchaseSuccess?.call(purchaseDetails);
      } else {
        // Backend verification failed: Do NOT complete transaction so it can be retried/recovered
        // UNLESS the caller definitively verified that this transaction is terminal (expired)
        debugPrint('[IAP] Backend verification failed.');
        if (txId != null && _terminalTransactionIds.contains(txId)) {
          debugPrint(
            '[IAP] Transaction $txId was marked terminal during verification. Not retaining as unresolved.',
          );
          if (_unresolvedOrangeTickPurchase?.purchaseID == txId) {
            _unresolvedOrangeTickPurchase = null;
          }
        } else {
          if (isOrangeTick) {
            _unresolvedOrangeTickPurchase = purchaseDetails;
          }
          if (purchaseDetails.status == PurchaseStatus.purchased ||
              purchaseDetails.status == PurchaseStatus.restored) {
            onError?.call(
              'Subscription verification failed. Please contact support if amount was deducted.',
            );
          }
        }
      }
    } catch (e) {
      onPending?.call(false);
      debugPrint('[IAP] Verification error: $e');
      onError?.call('Verification error: $e');
    } finally {
      if (txId != null && txId.isNotEmpty) {
        _inFlightTransactionIds.remove(txId);
      }
    }
  }

  /// Disposes the purchase stream subscription and clears callbacks
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _inFlightTransactionIds.clear();
    _terminalTransactionIds.clear();
    _terminalTransactionReasons.clear();
    onVerifyPurchase = null;
    onPurchaseSuccess = null;
    onError = null;
    onPending = null;
    onCanceled = null;
    orangeTickPurchaseHandler = null;
    activeOrangeTickPlanId = null;
    activeOrangeTickOrderId = null;
    isRestoring = false;
    isPurchasingOrangeTick = false;
    _unresolvedOrangeTickPurchase = null;
  }
}
