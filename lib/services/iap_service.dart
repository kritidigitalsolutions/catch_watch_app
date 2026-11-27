import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:catch_watch/utils/iap_transaction_deduplicator.dart';
import 'package:catch_watch/utils/iap_transaction_metadata.dart';
import 'package:catch_watch/utils/shared_purchase_stream_listener.dart';
import 'package:catch_watch/utils/post_frame_event_queue.dart';

/// Product IDs for App Store Connect In-App Purchases (Non-Renewing Subscriptions)
const String orangeTickProductId = 'com.app.catchWatch.creator.orangetick';
const String ottWeeklyProductId = 'com.app.catchWatch.premium.weekly';
const String ottMonthlyProductId = 'com.app.catchWatch.premium.monthly';
const String ottYearlyProductId = 'com.app.catchWatch.premium.yearly';

/// Legacy Product IDs (retained for backward compatibility and restoring past purchases)
const String legacyOrangeTickProductId =
    'com.app.catchWatch.sub.creator.orangetick';
const String legacyOttWeeklyProductId =
    'com.app.catchWatch.sub.premium.weekly';
const String legacyOttMonthlyProductId =
    'com.app.catchWatch.sub.premium.monthly';
const String legacyOttYearlyProductId =
    'com.app.catchWatch.sub.premium.yearly';

/// Active (current) In-App Purchase product IDs
const Set<String> currentAppProductIds = {
  ottWeeklyProductId,
  ottMonthlyProductId,
  ottYearlyProductId,
  orangeTickProductId,
};

/// All configured In-App Purchase product IDs (current + legacy)
const Set<String> allAppProductIds = {
  ottWeeklyProductId,
  ottMonthlyProductId,
  ottYearlyProductId,
  orangeTickProductId,
  legacyOttWeeklyProductId,
  legacyOttMonthlyProductId,
  legacyOttYearlyProductId,
  legacyOrangeTickProductId,
};

/// Helpers to identify product categories across current and legacy IDs
bool isOrangeTickProduct(String? productId) =>
    productId == orangeTickProductId ||
    productId == legacyOrangeTickProductId;

bool isOttWeeklyProduct(String? productId) =>
    productId == ottWeeklyProductId ||
    productId == legacyOttWeeklyProductId;

bool isOttMonthlyProduct(String? productId) =>
    productId == ottMonthlyProductId ||
    productId == legacyOttMonthlyProductId;

bool isOttYearlyProduct(String? productId) =>
    productId == ottYearlyProductId ||
    productId == legacyOttYearlyProductId;

bool isOttProduct(String? productId) =>
    isOttWeeklyProduct(productId) ||
    isOttMonthlyProduct(productId) ||
    isOttYearlyProduct(productId);

enum IapProductState {
  notStarted,
  loading,
  available,
  productNotFound,
  storeKitUnavailable,
  queryError,
}

/// Service responsible for managing Apple In-App Purchases (StoreKit).
/// Handles querying products, purchase stream listening, duplicate transaction
/// prevention, and safe completion after backend verification.
class IapService {
  IapService._();
  static final IapService instance = IapService._();

  final InAppPurchase _iap = InAppPurchase.instance;
  final SharedPurchaseStreamListener<List<PurchaseDetails>> _purchaseListener =
      SharedPurchaseStreamListener<List<PurchaseDetails>>();
  final PostFrameEventQueue<PurchaseDetails> _queuedOttTransactions =
      PostFrameEventQueue<PurchaseDetails>();

  final Map<String, ProductDetails> _products = {};
  Map<String, ProductDetails> get products => _products;

  final Set<String> _notFoundProductIds = {};
  Set<String> get notFoundProductIds => _notFoundProductIds;

  final Set<String> _queriedProductIds = {};
  Set<String> get queriedProductIds => _queriedProductIds;

  bool _isLoadingProducts = false;
  bool get isLoadingProducts => _isLoadingProducts;
  final Map<String, IapProductState> _productStates = {};
  IapProductState productState(String productId) =>
      _productStates[productId] ?? IapProductState.notStarted;

  final Set<String> _processedTransactionIds = {};
  final Set<String> _inFlightTransactionIds = {};
  final Set<String> _verifiedTransactionIds = {};
  final Set<String> _terminalTransactionIds = {};
  final Map<String, String> _terminalTransactionReasons = {};
  final IapTransactionDeduplicator _eventDeduplicator =
      IapTransactionDeduplicator();

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

  void allowFailedTransactionRetries() => _eventDeduplicator.allowRetries();

  // Persistent Orange Tick purchase state & handlers
  Future<bool> Function(PurchaseDetails purchase)? orangeTickPurchaseHandler;
  String? activeOrangeTickPlanId;
  String? activeOrangeTickOrderId;
  bool isOttRestoring = false;
  bool isOrangeTickRestoring = false;
  bool isPurchasingOrangeTick = false;
  bool get hasInFlightTransaction => _inFlightTransactionIds.isNotEmpty;
  String? lastVerificationErrorMessage;

  /// Begins a fresh Orange Tick purchase attempt.
  /// Captures all currently known transaction IDs so any pre-existing queue events
  /// cannot be mistaken for the result of this new purchase attempt.
  void beginOrangeTickPurchaseAttempt({
    required String orderId,
    required String planId,
  }) {
    debugPrint('[ORANGE_TICK_IAP] Beginning fresh purchase attempt');
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
    final eventKey = transactionEventKey(purchase);
    if (eventKey != null) _eventDeduplicator.markVerified(eventKey);
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
        '[ORANGE_TICK_IAP] Completing settled transaction in StoreKit',
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
    final eventKey = transactionEventKey(purchase);
    if (eventKey != null) _eventDeduplicator.markTerminal(eventKey);
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
        '[ORANGE_TICK_IAP] Completing terminal transaction ($reason) in StoreKit',
      );
      await completePurchase(purchase);
    }
  }

  // Callbacks registered by the active subscription view/provider
  Future<bool> Function(PurchaseDetails purchase)? onVerifyPurchase;
  Future<bool> Function(PurchaseDetails purchase)? onVerifyOrangeTickRestore;
  void Function(PurchaseDetails purchase)? onPurchaseSuccess;
  void Function(PurchaseDetails purchase)? onOrangeTickPurchaseSuccess;
  void Function(String errorMessage)? onError;
  void Function(String errorMessage)? onOrangeTickError;
  void Function(bool isPending)? onPending;
  void Function(bool isPending)? onOrangeTickPending;
  void Function()? onCanceled;
  void Function()? onOrangeTickCanceled;

  /// Checks if StoreKit / IAP is available on this device
  Future<bool> isAvailable() async {
    final stopwatch = Stopwatch()..start();
    try {
      final available = await _iap.isAvailable();
      debugPrint(
        '[IAP] StoreKit availability=$available (${stopwatch.elapsedMilliseconds}ms)',
      );
      return available;
    } catch (e) {
      debugPrint('[IAP] StoreKit availability error: ${_safeError(e)}');
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
    _drainQueuedOttTransactions();
  }

  void initializeOrangeTickRestore({
    required Future<bool> Function(PurchaseDetails purchase) onVerify,
    required void Function(PurchaseDetails purchase) onSuccess,
    required void Function(String errorMessage) onError,
    required void Function(bool isPending) onPending,
    required void Function() onCanceled,
  }) {
    onVerifyOrangeTickRestore = onVerify;
    onOrangeTickPurchaseSuccess = onSuccess;
    onOrangeTickError = onError;
    onOrangeTickPending = onPending;
    onOrangeTickCanceled = onCanceled;
    ensurePurchaseStreamInitialized();
  }

  void clearOrangeTickRestoreHandler(
    Future<bool> Function(PurchaseDetails purchase) handler,
  ) {
    if (onVerifyOrangeTickRestore == handler) {
      onVerifyOrangeTickRestore = null;
    }
  }

  void clearOrangeTickCallbacks() {
    onVerifyOrangeTickRestore = null;
    onOrangeTickPurchaseSuccess = null;
    onOrangeTickError = null;
    onOrangeTickPending = null;
    onOrangeTickCanceled = null;
  }

  /// Ensures a single effective purchaseStream listener is active across the app session
  void ensurePurchaseStreamInitialized() {
    if (_purchaseListener.isListening) {
      debugPrint('[IAP] Shared purchase listener already active.');
      return;
    }
    _purchaseListener.ensureListening(
      stream: _iap.purchaseStream,
      onEvent: _onPurchaseStreamData,
      onDone: () {
        debugPrint('[IAP] Shared purchase listener ended.');
      },
      onError: (error) {
        debugPrint('[IAP] purchaseStream error (${error.runtimeType}).');
        try {
          onError?.call('Purchase stream error: ${error.runtimeType}');
        } catch (callbackError) {
          debugPrint(
            '[IAP] Purchase stream error callback failed (${callbackError.runtimeType}).',
          );
        }
      },
    );
    debugPrint('[IAP] Shared purchase listener active.');
  }

  void _drainQueuedOttTransactions() {
    _queuedOttTransactions.scheduleDrain(
      isReady: () => onVerifyPurchase != null,
      schedulePostFrame: (callback) {
        WidgetsBinding.instance.addPostFrameCallback((_) => callback());
      },
      onEvent: (purchase) {
        unawaited(_handleSuccessfulOrRestoredPurchase(purchase));
      },
    );
  }

  /// Releases a screen-owned verification callback without canceling the shared
  /// StoreKit stream used by other IAP flows.
  void clearVerifyHandler(
    Future<bool> Function(PurchaseDetails purchase) handler,
  ) {
    if (onVerifyPurchase == handler) onVerifyPurchase = null;
  }

  /// Queries StoreKit for the product details corresponding to given IDs
  Future<List<ProductDetails>> loadProducts(Set<String> productIds) async {
    if (productIds.isEmpty) return [];

    final unexpectedIds = productIds.difference(allAppProductIds);
    if (unexpectedIds.isNotEmpty) {
      debugPrint(
        '[IAP] Ignoring unexpected Apple product IDs: ${unexpectedIds.toList()..sort()}',
      );
    }
    final requestedIds = productIds.intersection(allAppProductIds);
    if (requestedIds.isEmpty) return [];
    for (final id in requestedIds) {
      _productStates[id] = IapProductState.loading;
      _notFoundProductIds.remove(id);
    }
    debugPrint(
      '[IAP] Product query requested IDs: ${requestedIds.toList()..sort()}',
    );
    _isLoadingProducts = true;
    final available = await isAvailable();
    if (!available) {
      debugPrint('[IAP] StoreKit unavailable; products remain retryable');
      _queriedProductIds.addAll(requestedIds);
      for (final id in requestedIds) {
        _productStates[id] = IapProductState.storeKitUnavailable;
      }
      _isLoadingProducts = false;
      return [];
    }

    final stopwatch = Stopwatch()..start();
    try {
      final ProductDetailsResponse response = await _iap.queryProductDetails(
        requestedIds,
      );
      if (response.error != null) {
        debugPrint(
          '[IAP] Product query error: code=${response.error!.code}, message=${response.error!.message}',
        );
      }
      debugPrint(
        '[IAP] Product query returned IDs: ${response.productDetails.map((p) => p.id).toList()}',
      );
      debugPrint(
        '[IAP] Product query notFoundIDs: ${response.notFoundIDs.toList()}',
      );
      debugPrint(
        '[IAP] Product query duration=${stopwatch.elapsedMilliseconds}ms',
      );
      _queriedProductIds.addAll(requestedIds);
      for (final product in response.productDetails) {
        _products[product.id] = product;
        _notFoundProductIds.remove(product.id);
        _productStates[product.id] = IapProductState.available;
      }
      for (final notFoundId in response.notFoundIDs) {
        _notFoundProductIds.add(notFoundId);
        _products.remove(notFoundId);
        _productStates[notFoundId] = IapProductState.productNotFound;
      }
      for (final id in requestedIds) {
        if (!_products.containsKey(id) && !response.notFoundIDs.contains(id)) {
          _productStates[id] = IapProductState.queryError;
        }
      }
      return response.productDetails;
    } catch (e) {
      debugPrint(
        '[IAP] Product query exception after ${stopwatch.elapsedMilliseconds}ms: ${_safeError(e)}',
      );
      _queriedProductIds.addAll(requestedIds);
      for (final id in requestedIds) {
        _productStates[id] = IapProductState.queryError;
      }
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

  static String _safeError(Object error) {
    if (error is PlatformException) {
      return 'code=${error.code}, message=${error.message ?? 'unknown'}';
    }
    return error.runtimeType.toString();
  }

  /// Starts an Apple purchase for the configured product.
  ///
  /// The StoreKit product type is configured in App Store Connect; this
  /// Flutter purchase method does not determine whether a product renews.
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
      debugPrint('[IAP] buyProduct error (${e.runtimeType}).');
      onError?.call('Unable to initiate purchase: $e');
      return false;
    }
  }

  /// Initiates restore purchases flow
  Future<void> restorePurchases() async {
    try {
      await _iap.restorePurchases();
    } catch (e) {
      debugPrint('[IAP] restorePurchases error: ${e.runtimeType}');
      onError?.call('Unable to restore purchases: $e');
      rethrow;
    }
  }

  Future<void> restoreOttPurchases() async {
    isOttRestoring = true;
    try {
      await restorePurchases();
    } finally {
      isOttRestoring = false;
    }
  }

  Future<void> restoreOrangeTickPurchases() async {
    isOrangeTickRestoring = true;
    try {
      await restorePurchases();
    } finally {
      isOrangeTickRestoring = false;
    }
  }

  /// Completes the StoreKit transaction when safe to do so
  Future<void> completePurchase(PurchaseDetails purchaseDetails) async {
    final isVerificationRequired =
        purchaseDetails.status == PurchaseStatus.purchased ||
        purchaseDetails.status == PurchaseStatus.restored;
    final txId = extractTransactionId(purchaseDetails);
    if (isVerificationRequired &&
        (txId == null ||
            (!_verifiedTransactionIds.contains(txId) &&
                !_terminalTransactionIds.contains(txId)))) {
      debugPrint(
        '[IAP] Purchase transaction completion blocked until backend verification succeeds.',
      );
      return;
    }
    if (purchaseDetails.pendingCompletePurchase) {
      try {
        await _iap.completePurchase(purchaseDetails);
        debugPrint('[IAP] Transaction completed transactionId=$txId');
      } catch (e) {
        debugPrint(
          '[IAP] completePurchase failed transactionId=$txId error=${e.runtimeType}',
        );
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
      debugPrint('[IAP] Error decoding JWS payload: ${e.runtimeType}');
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
    return _transactionMetadata(purchaseDetails).expiryDate;
  }

  DateTime? extractPurchaseDate(PurchaseDetails purchaseDetails) {
    return _transactionMetadata(purchaseDetails).purchaseDate;
  }

  String? extractTransactionId(PurchaseDetails purchaseDetails) {
    return _transactionMetadata(purchaseDetails).transactionId;
  }

  IapTransactionMetadata _transactionMetadata(PurchaseDetails purchase) =>
      IapTransactionMetadata.fromStoreKit(
        purchaseId: purchase.purchaseID,
        transactionDate: purchase.transactionDate,
        serverVerificationData:
            purchase.verificationData.serverVerificationData,
      );

  void _logTransactionEvent(PurchaseDetails purchaseDetails) {
    final metadata = _transactionMetadata(purchaseDetails);
    final eventReceivedAt = DateTime.now().toUtc().toIso8601String();
    final transactionId = metadata.transactionId ?? 'unavailable';
    final originalTransactionId =
        extractOriginalTransactionId(purchaseDetails) ?? 'unavailable';
    final purchaseDate =
        metadata.purchaseDate?.toIso8601String() ?? 'unavailable';
    final expiryDate = metadata.expiryDate?.toIso8601String() ?? 'unavailable';
    debugPrint(
      '[IAP_EVENT] status=${purchaseDetails.status.name} '
      'eventReceivedAtUtc=$eventReceivedAt '
      'productId=${purchaseDetails.productID} '
      'transactionId=$transactionId '
      'originalTransactionId=$originalTransactionId '
      'purchaseDateUtc=$purchaseDate expiryDateUtc=$expiryDate',
    );
  }

  /// Stable event identity that distinguishes renewals sharing an original ID.
  String? transactionEventKey(PurchaseDetails purchaseDetails) {
    final data = decodeJwsPayload(
      purchaseDetails.verificationData.serverVerificationData,
    );
    final transactionId =
        purchaseDetails.purchaseID ??
        (data?['transactionId'] ?? data?['transaction_id'])?.toString();
    final originalTransactionId =
        extractOriginalTransactionId(purchaseDetails) ??
        (data?['originalTransactionId'] ?? data?['original_transaction_id'])
            ?.toString();
    // The signed data is used only as an in-memory fingerprint if StoreKit
    // supplies neither transaction ID. It is never emitted to logs.
    final serverData = purchaseDetails.verificationData.serverVerificationData;
    final fallback = serverData.isNotEmpty
        ? serverData.hashCode.toRadixString(16)
        : purchaseDetails.transactionDate;
    return iapTransactionEventKey(
      productId: purchaseDetails.productID,
      transactionId: transactionId,
      originalTransactionId: originalTransactionId,
      fallbackFingerprint: fallback,
    );
  }

  /// Returns whether the transaction is known to have expired locally based on signed JWS payload
  bool isTransactionExpired(PurchaseDetails purchaseDetails) {
    final expDate = extractExpirationDate(purchaseDetails);
    if (expDate != null) {
      final now = expDate.isUtc ? DateTime.now().toUtc() : DateTime.now();
      return expDate.isBefore(now);
    }
    return false;
  }

  /// Extracts the transaction environment ('Sandbox' vs 'Production') if available from JWS payload or StoreKit receipt
  String? extractEnvironment(PurchaseDetails purchaseDetails) {
    final data = decodeJwsPayload(
      purchaseDetails.verificationData.serverVerificationData,
    );
    if (data != null) {
      final env = data['environment'];
      if (env != null && env.toString().isNotEmpty) {
        return env.toString();
      }
    }
    if (purchaseDetails is AppStorePurchaseDetails) {
      final receipt = purchaseDetails.verificationData.localVerificationData;
      if (receipt.contains('sandbox') || receipt.contains('Sandbox')) {
        return 'Sandbox';
      }
    }
    return null;
  }

  /// Internal handler for purchaseStream events
  Future<void> _onPurchaseStreamData(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchaseDetails in purchaseDetailsList) {
      final env = extractEnvironment(purchaseDetails) ?? 'Unknown';
      debugPrint(
        '[IAP] Processing purchase: ${purchaseDetails.productID}, status: ${purchaseDetails.status}, env: $env',
      );

      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        _logTransactionEvent(purchaseDetails);
      }

      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          _onPending(purchaseDetails, true);
          break;

        case PurchaseStatus.error:
          _onPending(purchaseDetails, false);
          if (isOrangeTickProduct(purchaseDetails.productID) &&
              _unresolvedOrangeTickPurchase?.purchaseID ==
                  purchaseDetails.purchaseID) {
            _unresolvedOrangeTickPurchase = null;
          }
          final message =
              purchaseDetails.error?.message ??
              'An error occurred during the transaction.';
          _onError(purchaseDetails, message);
          // StoreKit requires completion of error transactions
          if (purchaseDetails.pendingCompletePurchase) {
            await completePurchase(purchaseDetails);
          }
          break;

        case PurchaseStatus.canceled:
          _onPending(purchaseDetails, false);
          if (isOrangeTickProduct(purchaseDetails.productID) &&
              _unresolvedOrangeTickPurchase?.purchaseID ==
                  purchaseDetails.purchaseID) {
            _unresolvedOrangeTickPurchase = null;
          }
          _onCanceled(purchaseDetails);
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

  void _onPending(PurchaseDetails purchase, bool pending) {
    if (isOrangeTickProduct(purchase.productID)) {
      onOrangeTickPending?.call(pending);
    } else {
      onPending?.call(pending);
    }
  }

  void _onError(PurchaseDetails purchase, String message) {
    if (isOrangeTickProduct(purchase.productID)) {
      onOrangeTickError?.call(message);
    } else {
      onError?.call(message);
    }
  }

  void _onCanceled(PurchaseDetails purchase) {
    if (isOrangeTickProduct(purchase.productID)) {
      onOrangeTickCanceled?.call();
    } else {
      onCanceled?.call();
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
        '[ORANGE_TICK_IAP] Orange Tick purchase handler already registered. Skipping duplicate.',
      );
      return;
    }
    debugPrint('[ORANGE_TICK_IAP] Registering Orange Tick purchase handler');
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
    final String? txId = extractTransactionId(purchaseDetails);
    final eventKey = transactionEventKey(purchaseDetails);
    final isOrangeTick = isOrangeTickProduct(purchaseDetails.productID);

    if (eventKey == null) {
      debugPrint('[IAP] Purchase event lacks a stable transaction identity.');
      return;
    }

    if (txId != null && txId.isNotEmpty) {
      _allKnownTransactionIds.add(txId);
    }

    if (isOrangeTick) {
      debugPrint('[ORANGE_TICK_IAP] Purchase received');
      debugPrint(
        '[ORANGE_TICK_IAP] Status: ${purchaseDetails.status == PurchaseStatus.purchased ? "purchased" : purchaseDetails.status.name}',
      );
      debugPrint('[ORANGE_TICK_IAP] Product ID: ${purchaseDetails.productID}');
    }

    // Prevent duplicate or concurrent processing of the same transaction
    if (txId != null && txId.isNotEmpty) {
      if (_terminalTransactionIds.contains(txId)) {
        debugPrint(
          '[IAP] Transaction was already confirmed terminal (${_terminalTransactionReasons[txId] ?? 'terminal'}). Completing in StoreKit if pending.',
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
          _verifiedTransactionIds.contains(txId)) {
        debugPrint(
          '[IAP] Transaction was already processed or is currently in-flight. Completing if needed.',
        );
        if ((_processedTransactionIds.contains(txId) ||
                _verifiedTransactionIds.contains(txId)) &&
            purchaseDetails.pendingCompletePurchase) {
          await completePurchase(purchaseDetails);
        }
        return;
      }
    }

    if (!isOrangeTick && onVerifyPurchase == null) {
      _queuedOttTransactions.add(eventKey, purchaseDetails);
      debugPrint(
        '[IAP] Queued OTT transaction until the backend verifier is registered.',
      );
      return;
    }

    if (!_eventDeduplicator.tryStart(eventKey)) {
      debugPrint(
        '[IAP] Duplicate or recently failed transaction event ignored.',
      );
      return;
    }
    if (txId != null && txId.isNotEmpty) _inFlightTransactionIds.add(txId);

    if (isOrangeTick) {
      if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Enforce handler readiness:
        // If an active purchase or explicit recovery handler is registered, process it immediately.
        // Otherwise, cache the unprompted StoreKit queue transaction until the user submits the form or initiates recovery.
        if ((!isPurchasingOrangeTick || orangeTickPurchaseHandler == null) &&
            !isOrangeTickRestoring) {
          debugPrint(
            '[ORANGE_TICK_IAP] Caching unprompted Orange Tick transaction (status: ${purchaseDetails.status.name}) awaiting user submission',
          );
          _unresolvedOrangeTickPurchase = purchaseDetails;
          if (txId != null && txId.isNotEmpty) {
            _inFlightTransactionIds.remove(txId);
          }
          _eventDeduplicator.abandon(eventKey);
          return;
        }
        debugPrint(
          '[ORANGE_TICK_IAP] Correlated active attempt transaction (status: ${purchaseDetails.status.name})',
        );
      }
    } else {
      // OTT purchased/restored events always go through backend verification,
      // including restored events delivered after the screen has been closed.
    }

    _onPending(purchaseDetails, true);

    try {
      bool verified = false;

      if (isOrangeTick) {
        // Dedicated Orange Tick handler only (active when user tapped Submit & Subscribe or during active restore)
        if (isOrangeTickRestoring && onVerifyOrangeTickRestore != null) {
          debugPrint(
            '[ORANGE_TICK_IAP] Dispatching restore to Orange Tick verifier',
          );
          verified = await onVerifyOrangeTickRestore!(purchaseDetails);
        } else if (orangeTickPurchaseHandler != null) {
          debugPrint(
            '[ORANGE_TICK_IAP] Dispatching to registered Orange Tick purchase handler',
          );
          verified = await orangeTickPurchaseHandler!(purchaseDetails);
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

      _onPending(purchaseDetails, false);

      if (verified) {
        if (txId != null && txId.isNotEmpty) {
          _processedTransactionIds.add(txId);
          _verifiedTransactionIds.add(txId);
        }
        _eventDeduplicator.markVerified(eventKey);
        if (isOrangeTick) {
          _unresolvedOrangeTickPurchase = null;
          debugPrint('[ORANGE_TICK_IAP] Backend verification success');
          debugPrint('[ORANGE_TICK_IAP] Completing Apple transaction');
        }
        // Never complete transaction before backend verification succeeds
        if (purchaseDetails.pendingCompletePurchase) {
          await completePurchase(purchaseDetails);
        }
        if (isOrangeTick) {
          onOrangeTickPurchaseSuccess?.call(purchaseDetails);
        } else {
          onPurchaseSuccess?.call(purchaseDetails);
        }
      } else {
        _eventDeduplicator.markFailed(eventKey);
        // Backend verification failed: Do NOT complete transaction so it can be retried/recovered
        // UNLESS the caller definitively verified that this transaction is terminal (expired)
        debugPrint('[IAP] Backend verification failed.');
        if (txId != null && _terminalTransactionIds.contains(txId)) {
          debugPrint(
            '[IAP] Transaction was marked terminal during verification. Not retaining as unresolved.',
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
            final errorMsg =
                lastVerificationErrorMessage ??
                'Subscription verification failed. Please contact support if amount was deducted.';
            lastVerificationErrorMessage = null;
            _onError(purchaseDetails, errorMsg);
          }
        }
      }
    } catch (e) {
      _eventDeduplicator.markFailed(eventKey);
      _onPending(purchaseDetails, false);
      debugPrint('[IAP] Verification error: ${e.runtimeType}');
      _onError(purchaseDetails, 'Verification error: ${e.runtimeType}');
    } finally {
      if (txId != null && txId.isNotEmpty) {
        _inFlightTransactionIds.remove(txId);
      }
    }
  }

  /// Disposes the purchase stream subscription and clears callbacks
  void dispose() {
    unawaited(_purchaseListener.cancel());
    _inFlightTransactionIds.clear();
    _terminalTransactionIds.clear();
    _terminalTransactionReasons.clear();
    _eventDeduplicator.clear();
    onVerifyPurchase = null;
    onVerifyOrangeTickRestore = null;
    onPurchaseSuccess = null;
    onOrangeTickPurchaseSuccess = null;
    onError = null;
    onOrangeTickError = null;
    onPending = null;
    onOrangeTickPending = null;
    onCanceled = null;
    onOrangeTickCanceled = null;
    orangeTickPurchaseHandler = null;
    activeOrangeTickPlanId = null;
    activeOrangeTickOrderId = null;
    isOttRestoring = false;
    isOrangeTickRestoring = false;
    isPurchasingOrangeTick = false;
    _unresolvedOrangeTickPurchase = null;
  }
}
