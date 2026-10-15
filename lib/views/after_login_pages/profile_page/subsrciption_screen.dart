import 'dart:convert';
import 'dart:io';

import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/services/iap_service.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:provider/provider.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen>
    with WidgetsBindingObserver {
  String? _expandedPlanId;

  // Android Razorpay instance
  late Razorpay _razorpay;
  String? _pendingPlanId;
  bool _pendingIsUpgrade = false;
  String? _pendingCurrentSubscriptionId;

  // iOS Apple IAP state
  bool _isPurchasing = false;
  String? _pendingApplePlanId;
  bool _pendingAppleIsUpgrade = false;
  String? _pendingAppleCurrentSubscriptionId;
  bool _isRestoring = false;
  int _inFlightVerificationCount = 0;
  int _restoredSuccessCount = 0;

  // Debounce guard to prevent rapid repeated taps
  bool _isProcessingPayment = false;

  // Dialog guard to prevent multiple/duplicate alerts
  bool _isErrorDialogShowing = false;
  String? _lastShownErrorMessage;
  DateTime? _lastShownErrorTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    if (!Platform.isIOS) {
      _razorpay = Razorpay();
      _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _handlePaymentSuccess);
      _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _handlePaymentError);
      _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _handleExternalWallet);
    } else {
      _initIap();
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPlansAndStatus();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && Platform.isIOS) {
      debugPrint('[SUBSCRIPTION] App resumed from background. Refreshing subscription status...');
      _loadPlansAndStatus();
    }
  }

  /// Initializes Apple StoreKit purchase listeners
  void _initIap() {
    IapService.instance.initialize(
      onVerifyPurchase: _verifyApplePurchase,
      onPurchaseSuccess: _onApplePurchaseSuccess,
      onError: (message) {
        if (mounted) {
          final bool wasUserInitiated =
              _isPurchasing || _pendingApplePlanId != null || _isRestoring;
          setState(() {
            _isPurchasing = false;
            _pendingApplePlanId = null;
            _pendingAppleIsUpgrade = false;
            _pendingAppleCurrentSubscriptionId = null;
          });

          final lower = message.toLowerCase();
          final bool isExpired = lower.contains('expired');

          // If this is an unprompted background event for an expired subscription
          // where the user did not tap to purchase or restore, do not disrupt the user
          // with a blocking error popup on screen entry.
          if (!wasUserInitiated && isExpired) {
            debugPrint(
              '[SUBSCRIPTION] Suppressed unprompted expired subscription error popup on screen entry: $message',
            );
            return;
          }

          final isCrossAccount = lower.contains('another catch & watch account') ||
              lower.contains('cross-account') ||
              lower.contains('another account');
          _showErrorPopup(message, !isCrossAccount && wasUserInitiated);
        }
      },
      onPending: (isPending) {
        if (mounted && _isPurchasing != isPending) {
          setState(() {
            _isPurchasing = isPending;
          });
        }
      },
      onCanceled: () {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _pendingApplePlanId = null;
          });
        }
      },
    );
  }

  /// Fetches plans and subscription status, querying StoreKit details on iOS
  Future<void> _loadPlansAndStatus() async {
    final provider = context.read<SubscriptionProvider>();
    await provider.fetchPlans();
    await provider.fetchSubscriptionStatus();

    if (Platform.isIOS) {
      final Set<String> productIds = {
        'com.app.catchWatch.sub.premium.weekly',
        'com.app.catchWatch.sub.premium.monthly',
        'com.app.catchWatch.sub.premium.yearly',
      };
      if (provider.plans.isNotEmpty) {
        productIds.addAll(provider.plans.map((p) => p.effectiveAppleProductId));
      }
      await IapService.instance.loadProducts(productIds);
      if (mounted) {
        if (_expandedPlanId == null) {
          final plans = _getEffectivePlans(provider.plans);
          if (plans.isNotEmpty) {
            final rec = plans.firstWhere(
              (p) => p.isRecommended == true,
              orElse: () => plans.length > 1 ? plans[1] : plans.first,
            );
            _expandedPlanId = rec.id;
          }
        }
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _isErrorDialogShowing = false;
    WidgetsBinding.instance.removeObserver(this);
    if (!Platform.isIOS) {
      _razorpay.clear();
    } else {
      IapService.instance.dispose();
    }
    super.dispose();
  }

  // ─── Android Razorpay Callbacks ─────────────────────────────────────────────

  void _handlePaymentSuccess(PaymentSuccessResponse response) async {
    final provider = context.read<SubscriptionProvider>();
    if (_pendingPlanId == null) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    final success = await provider.verifyPayment({
      "razorpay_order_id": response.orderId,
      "razorpay_payment_id": response.paymentId,
      "razorpay_signature": response.signature,
      "planId": _pendingPlanId,
      if (_pendingIsUpgrade) "isUpgrade": true,
      if (_pendingCurrentSubscriptionId != null)
        "currentSubscriptionId": _pendingCurrentSubscriptionId,
    });

    if (mounted) Navigator.pop(context); // Close loading dialog

    if (success && mounted) {
      context.read<ProfileProvider>().fetchProfile();
      _showSuccessPopup();
    } else if (mounted) {
      _showErrorPopup(provider.error ?? 'Payment verification failed', true);
    }
    _pendingPlanId = null;
    _pendingIsUpgrade = false;
    _pendingCurrentSubscriptionId = null;
    _isProcessingPayment = false;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    _pendingPlanId = null;
    _pendingIsUpgrade = false;
    _pendingCurrentSubscriptionId = null;
    _isProcessingPayment = false;
    if (mounted) {
      _showErrorPopup('Payment Failed: ${response.message}', true);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
  }

  // ─── iOS Apple IAP Callbacks ────────────────────────────────────────────────

  Future<void> _startApplePurchase(
    Plan plan, {
    bool isUpgrade = false,
    String? currentSubscriptionId,
  }) async {
    if (plan.id == null ||
        plan.id!.isEmpty ||
        plan.id == 'weekly' ||
        plan.id == 'monthly' ||
        plan.id == 'yearly') {
      _showErrorPopup(
        'Invalid subscription plan. Please refresh and try again.',
        false,
      );
      return;
    }

    final productId = plan.effectiveAppleProductId;
    var product = IapService.instance.getProduct(productId);

    if (product == null) {
      if (IapService.instance.isProductNotFound(productId) ||
          IapService.instance.isProductQueried(productId)) {
        _showErrorPopup(
          'Subscription product is currently unavailable in the App Store. Please try again later.',
          false,
        );
        return;
      }
      setState(() {
        _isPurchasing = true;
        _pendingApplePlanId = plan.id;
        _pendingAppleIsUpgrade = isUpgrade;
        _pendingAppleCurrentSubscriptionId = currentSubscriptionId;
      });
      final loaded = await IapService.instance.loadProducts({productId});
      if (loaded.isNotEmpty) {
        product = IapService.instance.getProduct(productId);
      }
    }

    if (product == null) {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _pendingApplePlanId = null;
          _pendingAppleIsUpgrade = false;
          _pendingAppleCurrentSubscriptionId = null;
        });
        _showErrorPopup(
          'Subscription product is currently unavailable in the App Store. Please try again later.',
          false,
        );
      }
      return;
    }

    setState(() {
      _isPurchasing = true;
      _pendingApplePlanId = plan.id;
      _pendingAppleIsUpgrade = isUpgrade;
      _pendingAppleCurrentSubscriptionId = currentSubscriptionId;
    });

    final launched = await IapService.instance.buyProduct(product);
    if (!launched && mounted) {
      setState(() {
        _isPurchasing = false;
        _pendingApplePlanId = null;
        _pendingAppleIsUpgrade = false;
        _pendingAppleCurrentSubscriptionId = null;
      });
    }
  }

  /// Safely extracts the original transaction ID for both StoreKit 1 and StoreKit 2.
  /// For StoreKit 2, decodes the unencrypted payload of the signed JWS transaction.
  /// Does NOT fall back to purchaseID for StoreKit 2 renewals or restores.
  String? _extractOriginalTransactionId(PurchaseDetails purchaseDetails) {
    // 1. StoreKit 1 (AppStorePurchaseDetails)
    if (purchaseDetails is AppStorePurchaseDetails) {
      final sk1OriginalId = purchaseDetails
          .skPaymentTransaction.originalTransaction?.transactionIdentifier;
      if (sk1OriginalId != null && sk1OriginalId.isNotEmpty) {
        return sk1OriginalId;
      }
      // On StoreKit 1 initial purchase, originalTransaction is null and purchaseID is the original ID
      return purchaseDetails.purchaseID;
    }

    // 2. StoreKit 2 (Signed JWS transaction token in serverVerificationData)
    final serverData = purchaseDetails.verificationData.serverVerificationData;
    if (serverData.isNotEmpty && serverData.contains('.')) {
      try {
        final parts = serverData.split('.');
        if (parts.length >= 2) {
          final normalized = base64Url.normalize(parts[1]);
          final decodedBytes = base64Url.decode(normalized);
          final payloadJson = utf8.decode(decodedBytes);
          final dynamic data = jsonDecode(payloadJson);
          if (data is Map<String, dynamic>) {
            final originalId = data['originalTransactionId'] ?? data['original_transaction_id'];
            if (originalId != null && originalId.toString().isNotEmpty) {
              return originalId.toString();
            }
          }
        }
      } catch (e) {
        debugPrint('[IAP] Error extracting originalTransactionId from JWS: $e');
      }
    }

    // Never fall back to purchaseDetails.purchaseID for StoreKit 2.
    return null;
  }

  Future<bool> _verifyApplePurchase(PurchaseDetails purchaseDetails) async {
    _inFlightVerificationCount++;
    try {
      final provider = context.read<SubscriptionProvider>();

      // Ensure plans are loaded so matching works reliably
      if (provider.plans.isEmpty) {
        await provider.fetchPlans();
      }

      final allPlans = _getEffectivePlans(provider.plans);

      Plan? matchedPlan;
      if (_pendingApplePlanId != null) {
        matchedPlan = allPlans.firstWhere(
          (p) =>
              p.id == _pendingApplePlanId &&
              p.effectiveAppleProductId == purchaseDetails.productID,
          orElse: () => Plan(),
        );
      }
      if (matchedPlan == null || matchedPlan.id == null) {
        final matchingPlans = allPlans
            .where((p) => p.effectiveAppleProductId == purchaseDetails.productID)
            .toList();
        if (matchingPlans.length == 1) {
          matchedPlan = matchingPlans.first;
        } else if (matchingPlans.length > 1) {
          debugPrint(
            '[IAP] Verification aborted: Ambiguous plan mapping for product ${purchaseDetails.productID}. Found ${matchingPlans.length} matching plans.',
          );
          if (mounted) {
            _showErrorPopup(
              'Ambiguous subscription plan mapping for product: ${purchaseDetails.productID}. Please contact support.',
              false,
            );
          }
          return false;
        }
      }

      final resolvedPlanId = matchedPlan?.id;
      if (resolvedPlanId == null ||
          resolvedPlanId.isEmpty ||
          resolvedPlanId == 'weekly' ||
          resolvedPlanId == 'monthly' ||
          resolvedPlanId == 'yearly') {
        debugPrint(
          '[IAP] Verification aborted: Unable to resolve valid backend planId for product ${purchaseDetails.productID}',
        );
        if (mounted) {
          _showErrorPopup(
            'Unable to resolve subscription plan for product: ${purchaseDetails.productID}. Please try again later or contact support.',
            false,
          );
        }
        return false;
      }

      final String? originalTxId = _extractOriginalTransactionId(purchaseDetails);
      if (originalTxId == null || originalTxId.isEmpty) {
        debugPrint('[IAP] Verification aborted: Unable to obtain valid originalTransactionId for ${purchaseDetails.productID}');
        if (mounted) {
          _showErrorPopup(
            'Unable to verify transaction authenticity. Please contact support.',
            false,
          );
        }
        return false;
      }

      final bool isUpgrade = _pendingAppleIsUpgrade ||
          (provider.currentSubscription != null &&
              provider.currentSubscription!.isCurrentlyValid(remainingDays: provider.remainingDays) &&
              matchedPlan != null &&
              matchedPlan.effectiveLevel > provider.currentSubscription!.getEffectiveLevel(allPlans));

      final String? currentSubId = _pendingAppleCurrentSubscriptionId ??
          (isUpgrade ? provider.currentSubscription?.id : null);

      final payload = {
        "planId": resolvedPlanId,
        "productId": purchaseDetails.productID,
        "transactionId": purchaseDetails.purchaseID ?? '',
        "originalTransactionId": originalTxId,
        "serverVerificationData":
            purchaseDetails.verificationData.serverVerificationData,
        if (isUpgrade) "isUpgrade": true,
        "currentSubscriptionId": ?currentSubId,
      };

      final env = IapService.instance.extractEnvironment(purchaseDetails) ?? 'Unknown';
      debugPrint(
        '[IAP] Verifying Apple purchase: Product=${purchaseDetails.productID}, PlanId=$resolvedPlanId, IsUpgrade=$isUpgrade, Env=$env',
      );

      final bool success = await provider.verifyApplePayment(payload);
      if (!success) {
        final serverError = provider.error;
        if (serverError != null && serverError.isNotEmpty) {
          IapService.instance.lastVerificationErrorMessage = serverError;
        }
        final lower = (serverError ?? '').toLowerCase();
        if (lower.contains('expired') ||
            IapService.instance.isTransactionExpired(purchaseDetails)) {
          debugPrint(
            '[IAP] Transaction ${purchaseDetails.purchaseID} confirmed expired by backend ($serverError). Marking terminal and completing in StoreKit.',
          );
          await IapService.instance.resolveAndCompleteTerminalTransaction(
            purchaseDetails,
            reason: 'expired',
          );
        }
      }
      if (success && _isRestoring) {
        _restoredSuccessCount++;
      }
      return success;
    } finally {
      _inFlightVerificationCount--;
    }
  }

  void _onApplePurchaseSuccess(PurchaseDetails purchaseDetails) {
    if (!mounted) return;
    if (!_isRestoring) {
      final provider = context.read<SubscriptionProvider>();
      final allPlans = _getEffectivePlans(provider.plans);

      // Automatically update the expanded plan to the newly active plan
      final activeSub = provider.currentSubscription;
      final activePlanId = activeSub?.planId;
      if (activePlanId != null) {
        _expandedPlanId = activePlanId;
      } else {
        final matched = allPlans.firstWhere(
          (p) => p.effectiveAppleProductId == purchaseDetails.productID,
          orElse: () => Plan(),
        );
        if (matched.id != null) {
          _expandedPlanId = matched.id;
        }
      }

      setState(() {
        _isPurchasing = false;
        _pendingApplePlanId = null;
        _pendingAppleIsUpgrade = false;
        _pendingAppleCurrentSubscriptionId = null;
      });
      // Refresh user profile so premium access is applied everywhere
      context.read<ProfileProvider>().fetchProfile();
      _showSuccessPopup();
    }
  }

  Future<void> _restorePurchases() async {
    if (_isPurchasing || _isRestoring) return;

    setState(() {
      _isPurchasing = true;
      _isRestoring = true;
      _restoredSuccessCount = 0;
    });

    try {
      final provider = context.read<SubscriptionProvider>();
      if (provider.plans.isEmpty) {
        await provider.fetchPlans();
      }

      await IapService.instance.restorePurchases();

      // Wait for any in-flight transaction verifications dispatched by purchaseStream
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 30));
      while (_inFlightVerificationCount > 0 && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Brief debounce pause to ensure any queued stream events are delivered
      await Future.delayed(const Duration(milliseconds: 500));
      while (_inFlightVerificationCount > 0 && DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;

      // Refresh latest subscription status from backend
      await provider.fetchSubscriptionStatus();
      if (!mounted) return;

      if (_restoredSuccessCount > 0 || provider.currentSubscription != null) {
        context.read<ProfileProvider>().fetchProfile();
        _showSuccessPopup();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No previous active subscriptions found to restore.'),
          ),
        );
      }
    } catch (e) {
      debugPrint('[IAP] Restore error: $e');
      if (mounted) {
        _showErrorPopup('Restore failed: $e', false);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPurchasing = false;
          _isRestoring = false;
        });
      }
    }
  }

  Future<void> _manageAppleSubscription() async {
    final provider = context.read<SubscriptionProvider>();
    final activeSub = provider.currentSubscription;
    final activePlan = activeSub?.planObject;
    final String prodId = activePlan?.effectiveAppleProductId ??
        activeSub?.planId ??
        'unknown';
    debugPrint(
      '[IAP] Managing Apple subscription: URL=https://apps.apple.com/account/subscriptions, Product=$prodId',
    );

    const url = 'https://apps.apple.com/account/subscriptions';
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please open Settings > Apple ID > Subscriptions to manage your subscription. (For Sandbox accounts: Settings > App Store > Sandbox Account)',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[IAP] Error opening subscription URL: $e');
    }
  }

  // ─── Purchase Initiation & Upgrade Flow ─────────────────────────────────────

  void _showUpgradeConfirmationDialog(Plan targetPlan) {
    final provider = context.read<SubscriptionProvider>();
    final allPlans = _getEffectivePlans(provider.plans);
    final activeSub = provider.currentSubscription;
    final remainingDays = provider.remainingDays ?? 0;

    Plan activePlan;
    if (activeSub?.plan is Plan) {
      activePlan = activeSub!.plan as Plan;
    } else {
      activePlan = allPlans.firstWhere(
        (p) => p.id == activeSub?.planId,
        orElse: () => Plan(
          id: activeSub?.planId,
          name: activeSub?.planName ?? 'Current Plan',
          price: activeSub?.amount ?? 0,
        ),
      );
    }

    final quote = UpgradeQuote.calculateEstimate(
      currentPlan: activePlan,
      targetPlan: targetPlan,
      remainingDays: remainingDays,
    );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20),
          actionsPadding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.upgrade_rounded, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Upgrade Plan', style: text18(fontWeight: FontWeight.w800)),
                    Text(
                      'Upgrade to ${targetPlan.name ?? 'New Plan'}',
                      style: text12(color: AppColors.grey500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                if (Platform.isIOS) ...[
                  // iOS StoreKit upgrade explanation with vertical hierarchy and resilient layout
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Target Plan',
                          style: text12(
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          targetPlan.name ?? 'Premium Plan',
                          style: text15(
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1, color: AppColors.grey200),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              'App Store Price',
                              style: text13(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Flexible(
                              child: _buildPriceText(targetPlan),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFF1D4ED8),
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Apple StoreKit switches your subscription immediately. Apple automatically issues a prorated refund for the unused time of your current plan directly to your Apple ID payment method.',
                            style: appTextStyle(
                              fontSize: 11,
                              color: const Color(0xFF1E40AF),
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else ...[
                  // Android Razorpay prorated breakdown (unchanged business logic)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.grey200),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'New Plan Price',
                                style: text13(color: AppColors.textSecondary),
                              ),
                            ),
                            Text(
                              '₹ ${quote.originalPrice}',
                              style: text13(fontWeight: FontWeight.w700),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Unused Plan Credit ($remainingDays days left)',
                                style: text13(color: const Color(0xFF1B873F)),
                              ),
                            ),
                            Text(
                              '- ₹ ${quote.creditAmount}',
                              style: text13(
                                color: const Color(0xFF1B873F),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 18, color: AppColors.grey300),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                'Final Amount Payable',
                                style: text14(fontWeight: FontWeight.w800),
                              ),
                            ),
                            Text(
                              '₹ ${quote.payableAmount}',
                              style: text16(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (quote.isCreditExceeding) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Your unused credit fully covers this upgrade! No additional payment required.',
                        style: text11(
                          color: const Color(0xFF2E7D32),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    'Your new plan activates immediately. The remaining credit of your current plan is applied toward this upgrade.',
                    style: text11(color: AppColors.grey500),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: Text('Cancel', style: text14(color: AppColors.grey600)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                _startPayment(targetPlan, isUpgrade: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              child: Text(
                Platform.isIOS
                    ? 'Upgrade via App Store'
                    : (quote.payableAmount == 0 ? 'Confirm Free Upgrade' : 'Pay ₹${quote.payableAmount} & Upgrade'),
                style: text13(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _startPayment(Plan plan, {bool isUpgrade = false}) async {
    // 1. Rapid repeated tap debounce protection
    if (_isProcessingPayment || _isPurchasing || context.read<SubscriptionProvider>().isLoading) {
      debugPrint('[SUBSCRIPTION] Purchase tap ignored: another operation is in progress');
      return;
    }
    _isProcessingPayment = true;

    final provider = context.read<SubscriptionProvider>();
    final allPlans = _getEffectivePlans(provider.plans);

    // 2. Validate action against backend-verified active subscription
    final actionType = determinePlanAction(
      targetPlan: plan,
      currentSubscription: provider.currentSubscription,
      remainingDays: provider.remainingDays,
      allPlans: allPlans,
    );

    if (actionType == PlanActionType.downgrade) {
      _isProcessingPayment = false;
      final currentName = provider.currentSubscription?.planName ?? 'Premium';
      _showErrorPopup(
        'You already have an active $currentName plan. You cannot switch to a lower plan until your current subscription expires.',
        false,
      );
      return;
    }

    if (actionType == PlanActionType.current) {
      _isProcessingPayment = false;
      _showErrorPopup(
        'You already have an active subscription to this plan.',
        false,
      );
      return;
    }

    // 3. iOS Apple IAP Flow
    if (Platform.isIOS) {
      try {
        await _startApplePurchase(
          plan,
          isUpgrade: isUpgrade,
          currentSubscriptionId: isUpgrade ? provider.currentSubscription?.id : null,
        );
      } finally {
        _isProcessingPayment = false;
      }
      return;
    }

    // 4. Android Razorpay flow
    final user = context.read<ProfileProvider>().user;
    _pendingPlanId = plan.id;
    _pendingIsUpgrade = isUpgrade;
    _pendingCurrentSubscriptionId = isUpgrade ? provider.currentSubscription?.id : null;

    try {
      final response = await provider.createOrder(
        plan.id!,
        isUpgrade: isUpgrade,
        currentSubscriptionId: _pendingCurrentSubscriptionId,
      );

      if (response != null && response['order'] != null) {
        final order = response['order'];
        final dynamic rawAmount = order['amount'];
        final int amount = rawAmount is int
            ? rawAmount
            : (int.tryParse(rawAmount?.toString() ?? '0') ?? 0);

        // Handle case where eligible credit fully covers the upgrade (amount == 0)
        if (amount <= 0) {
          if (mounted) {
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (_) => const Center(child: CircularProgressIndicator()),
            );
          }
          final success = await provider.verifyPayment({
            "razorpay_order_id": order['id'] ?? 'credit_covered',
            "razorpay_payment_id": 'credit_covered',
            "razorpay_signature": 'credit_covered',
            "planId": plan.id,
            "isUpgrade": true,
            if (_pendingCurrentSubscriptionId != null)
              "currentSubscriptionId": _pendingCurrentSubscriptionId,
          });
          if (mounted) Navigator.pop(context); // Close loading dialog

          if (success && mounted) {
            context.read<ProfileProvider>().fetchProfile();
            _showSuccessPopup();
          } else if (mounted) {
            _showErrorPopup(provider.error ?? 'Upgrade activation failed', true);
          }
          _pendingPlanId = null;
          _pendingIsUpgrade = false;
          _pendingCurrentSubscriptionId = null;
          return;
        }

        final rawKey = response['key'];
        final razorpayKey =
            (rawKey is String && rawKey.trim().isNotEmpty) ? rawKey.trim() : null;

        if (razorpayKey == null) {
          debugPrint(
            '[SUBSCRIPTION_FLOW] Payment initialization failed: missing or empty Razorpay key',
          );
          _pendingPlanId = null;
          _pendingIsUpgrade = false;
          _pendingCurrentSubscriptionId = null;
          if (mounted) {
            _showErrorPopup(
              'Payment gateway configuration error. Please contact support.',
              false,
            );
          }
          return;
        }

        var options = {
          'key': razorpayKey,
          'amount': amount,
          'name': 'Catch Watch',
          'order_id': order['id'],
          'description': isUpgrade
              ? 'Upgrade to ${plan.name}'
              : (plan.name ?? 'Subscription'),
          'prefill': {
            'contact': user?.phone ?? '',
            'email': '',
          },
          'external': {
            'wallets': ['paytm']
          }
        };

        try {
          _razorpay.open(options);
        } catch (e) {
          debugPrint('Error opening Razorpay: $e');
          _pendingPlanId = null;
          _pendingIsUpgrade = false;
          _pendingCurrentSubscriptionId = null;
          if (mounted) {
            _showErrorPopup('Unable to open payment gateway: $e', false);
          }
        }
      } else {
        _pendingPlanId = null;
        _pendingIsUpgrade = false;
        _pendingCurrentSubscriptionId = null;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(provider.error ?? 'Failed to create order')),
          );
        }
      }
    } catch (e) {
      _pendingPlanId = null;
      _pendingIsUpgrade = false;
      _pendingCurrentSubscriptionId = null;
      if (mounted) {
        _showErrorPopup('Unable to start payment: $e', false);
      }
    } finally {
      _isProcessingPayment = false;
    }
  }

  // ─── Plan Helpers ───────────────────────────────────────────────────────────

  /// Returns the Catch & Watch OTT viewer subscription plans: Weekly, Monthly, and Yearly.
  /// Reuses matching backend plans from [providerPlans] to preserve backend IDs.
  /// Returns only valid backend plans and never synthesizes mock plan IDs.
  List<Plan> _getEffectivePlans(List<Plan> providerPlans) {
    final validPlans = providerPlans.where((p) {
      final id = p.id;
      return id != null &&
          id.isNotEmpty &&
          id != 'weekly' &&
          id != 'monthly' &&
          id != 'yearly';
    }).toList();

    if (validPlans.isEmpty) {
      return const <Plan>[];
    }

    if (!Platform.isIOS) {
      return validPlans;
    }

    Plan? weeklyPlan;
    Plan? monthlyPlan;
    Plan? yearlyPlan;

    for (final p in validPlans) {
      final prodId = p.effectiveAppleProductId;
      if (prodId == 'com.app.catchWatch.sub.premium.weekly' && weeklyPlan == null) {
        weeklyPlan = p;
      } else if (prodId == 'com.app.catchWatch.sub.premium.yearly' && yearlyPlan == null) {
        yearlyPlan = p;
      } else if (prodId == 'com.app.catchWatch.sub.premium.monthly' && monthlyPlan == null) {
        monthlyPlan = p;
      }
    }

    final List<Plan> effective = [];
    if (weeklyPlan != null) effective.add(weeklyPlan);
    if (monthlyPlan != null) effective.add(monthlyPlan);
    if (yearlyPlan != null) effective.add(yearlyPlan);

    // If backend plans didn't match the standard 3 tier product IDs, use all valid plans
    if (effective.isEmpty) {
      return validPlans;
    }
    return effective;
  }

  String _getPlanSubtitle(Plan plan) {
    final prodId = plan.effectiveAppleProductId;
    if (prodId == 'com.app.catchWatch.sub.premium.weekly') {
      return '7-day access';
    }
    if (prodId == 'com.app.catchWatch.sub.premium.yearly') {
      return '12-month access';
    }
    return 'Monthly access';
  }

  String _getPlanDescription(Plan plan) {
    final prodId = plan.effectiveAppleProductId;
    if (prodId == 'com.app.catchWatch.sub.premium.weekly') {
      return 'Entry plan for users who want short-term access.';
    }
    if (prodId == 'com.app.catchWatch.sub.premium.yearly') {
      return 'Highest-value plan for long-term members.';
    }
    return 'Core recurring plan for regular Catch & Watch viewers.';
  }

  // ─── Dialogs ────────────────────────────────────────────────────────────────

  void _showSuccessPopup() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 64),
            const SizedBox(height: 16),
            Text('Payment Successful!', style: text18(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Text(
              'Your Premium subscription is now active.',
              textAlign: TextAlign.center,
              style: text14(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Done', style: text14(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorPopup(String message, bool showTryAgain) {
    if (!mounted || _isErrorDialogShowing) {
      debugPrint('[SUBSCRIPTION] Suppressed duplicate/overlapping Payment Status dialog: $message');
      return;
    }

    final now = DateTime.now();
    if (_lastShownErrorMessage == message &&
        _lastShownErrorTime != null &&
        now.difference(_lastShownErrorTime!).inMilliseconds < 1500) {
      debugPrint('[SUBSCRIPTION] Debounced identical Payment Status dialog: $message');
      return;
    }

    _isErrorDialogShowing = true;
    _lastShownErrorMessage = message;
    _lastShownErrorTime = now;

    final pendingId = Platform.isIOS ? _pendingApplePlanId : _pendingPlanId;
    final allPlans = _getEffectivePlans(context.read<SubscriptionProvider>().plans);
    final plan = allPlans.firstWhere(
          (p) => p.id == pendingId,
          orElse: () => Plan(),
        );

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Payment Status', style: text18(fontWeight: FontWeight.w800)),
        content: Text(message, style: text14(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: Text('Cancel', style: text14(color: AppColors.textSecondary)),
          ),
          if (showTryAgain && plan.id != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _startPayment(plan);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Try Again', style: text14(color: Colors.white)),
            ),
        ],
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _isErrorDialogShowing = false;
        });
        context.read<SubscriptionProvider>().clearError();
      } else {
        _isErrorDialogShowing = false;
      }
    });
  }

  // ─── Build UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();
    final displayPlans = _getEffectivePlans(provider.plans);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          _buildActiveSubscription(provider),
          Expanded(
            child: provider.isLoading && provider.plans.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && displayPlans.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 48,
                                color: AppColors.error,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                provider.error!,
                                textAlign: TextAlign.center,
                                style: text14(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadPlansAndStatus,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text('Retry', style: text14(color: Colors.white)),
                              ),
                            ],
                          ),
                        ),
                      )
                    : displayPlans.isEmpty
                        ? RefreshIndicator(
                            onRefresh: () async {
                              await _loadPlansAndStatus();
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) => SingleChildScrollView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                child: ConstrainedBox(
                                  constraints: BoxConstraints(
                                    minHeight: constraints.maxHeight,
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.info_outline_rounded,
                                            size: 48,
                                            color: AppColors.grey400,
                                          ),
                                          const SizedBox(height: 12),
                                          Text(
                                            'No subscription plans available at this time.',
                                            textAlign: TextAlign.center,
                                            style: text14(color: AppColors.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () async {
                              await _loadPlansAndStatus();
                            },
                            child: ListView.builder(
                              padding: const EdgeInsets.only(top: 14, bottom: 8),
                              itemCount: displayPlans.length + (Platform.isIOS ? 1 : 0),
                              itemBuilder: (_, i) {
                                if (i < displayPlans.length) {
                                  return _buildPlanCard(displayPlans[i], provider);
                                }
                                return _buildAppleSubscriptionDisclosures();
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 10,
        bottom: 12,
        left: 20,
        right: 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _glassBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Choose a Plan',
              style: text18(color: Colors.white, fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (Platform.isIOS)
            TextButton(
              onPressed: _isPurchasing ? null : _restorePurchases,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.white.withValues(alpha: 0.18),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(
                'Restore',
                style: text13(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildActiveSubscription(SubscriptionProvider provider) {
    if (provider.currentSubscription == null) return const SizedBox();

    final sub = provider.currentSubscription!;
    final plan = sub.plan is Plan ? (sub.plan as Plan) : null;
    final planName = plan?.name ?? sub.planName ?? 'Premium Plan';
    final int level = sub.getEffectiveLevel(_getEffectivePlans(provider.plans));
    final String levelLabel = level == 1
        ? 'Tier 1 • Weekly'
        : (level == 2 ? 'Tier 2 • Monthly' : (level == 3 ? 'Tier 3 • Yearly' : 'Tier $level'));

    final String expiryText = provider.remainingDays != null && provider.remainingDays! > 0
        ? 'Expires in ${provider.remainingDays} days'
        : 'Expired';

    String? formattedEndDate;
    if (sub.endDate != null && sub.endDate!.isNotEmpty) {
      try {
        final dt = DateTime.parse(sub.endDate!).toLocal();
        final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
        formattedEndDate = '${dt.day} ${months[dt.month - 1]} ${dt.year}';
      } catch (_) {
        formattedEndDate = sub.endDate;
      }
    }

    final bool isStillValid = sub.isCurrentlyValid(remainingDays: provider.remainingDays);

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isStillValid ? const Color(0xFFFFF0E8) : const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isStillValid ? AppColors.primary.withValues(alpha: 0.3) : AppColors.grey300,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text('ACTIVE PLAN',
                      style: text12(color: AppColors.primary, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      levelLabel,
                      style: text10(color: AppColors.primary, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: isStillValid
                      ? AppColors.success.withValues(alpha: 0.2)
                      : AppColors.grey300,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  isStillValid ? 'Active' : (sub.status ?? 'Expired'),
                  style: text10(
                    color: isStillValid ? AppColors.success : AppColors.grey600,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(planName, style: text18(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(expiryText, style: text13(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
              if (formattedEndDate != null) ...[
                Text(' • Ends on $formattedEndDate',
                    style: text12(color: AppColors.grey500)),
              ],
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 36,
            child: OutlinedButton(
              onPressed: provider.isLoading
                  ? null
                  : () async {
                      if (Platform.isIOS) {
                        await _manageAppleSubscription();
                      } else {
                        final success = await provider.cancelSubscription();
                        if (success && mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Subscription Cancelled Successfully')));
                        } else if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(provider.error ?? 'Failed to cancel subscription')));
                        }
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(Platform.isIOS ? 'Manage Subscription' : 'Cancel Plan',
                      style: text12(color: AppColors.error)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Plan plan, SubscriptionProvider provider) {
    final isOpen = _expandedPlanId == plan.id;
    final allPlans = _getEffectivePlans(provider.plans);
    final actionType = determinePlanAction(
      targetPlan: plan,
      currentSubscription: provider.currentSubscription,
      remainingDays: provider.remainingDays,
      allPlans: allPlans,
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: isOpen ? AppColors.primary : AppColors.grey200,
          width: isOpen ? 1.5 : 1.0,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: isOpen
            ? [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isOpen ? 14.5 : 15.0),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () => setState(() {
                _expandedPlanId = isOpen ? null : plan.id;
              }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  plan.name ?? '',
                                  style: text16(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (actionType == PlanActionType.current) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey500,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'CURRENT PLAN',
                                    style: text10(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ] else if (actionType == PlanActionType.upgrade) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1B873F),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'UPGRADE',
                                    style: text10(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ] else if (plan.isRecommended == true) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'RECOMMENDED',
                                    style: text10(color: Colors.white, fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _getPlanSubtitle(plan),
                            style: text11(color: AppColors.grey500, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _buildPriceText(plan),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.grey400,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Expanded body
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: _buildPlanBody(plan, provider, actionType),
              crossFadeState: isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPriceText(Plan plan) {
    if (Platform.isIOS) {
      final productId = plan.effectiveAppleProductId;
      final product = IapService.instance.getProduct(productId);
      if (product != null && product.price.isNotEmpty) {
        return Text(
          product.price,
          style: text16(
            color: AppColors.primary,
            fontWeight: FontWeight.w900,
          ),
          textAlign: TextAlign.end,
        );
      }
      // If product has been queried and was not found or is unavailable, show stable Unavailable
      if (IapService.instance.isProductNotFound(productId) ||
          (IapService.instance.isProductQueried(productId) && product == null)) {
        return Text(
          'Unavailable',
          style: text13(
            color: AppColors.grey500,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.end,
        );
      }
      // On iOS, never fall back to backend/website price (₹).
      // Display neutral loading state while StoreKit query is actively in progress.
      return Text(
        'Loading...',
        style: text13(
          color: AppColors.grey500,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.end,
      );
    }
    return Text(
      '₹ ${plan.price}',
      style: text16(
        color: AppColors.primary,
        fontWeight: FontWeight.w900,
      ),
      textAlign: TextAlign.end,
    );
  }

  Widget _buildPlanBody(
    Plan plan,
    SubscriptionProvider provider,
    PlanActionType actionType,
  ) {
    final bool isThisPlanPurchasing = Platform.isIOS
        ? (_isPurchasing && _pendingApplePlanId == plan.id)
        : (provider.isLoading && _pendingPlanId == plan.id);
    final ProductDetails? appleProduct = Platform.isIOS
        ? IapService.instance.getProduct(plan.effectiveAppleProductId)
        : null;
    final bool isProductLoading = Platform.isIOS &&
        !IapService.instance.isProductQueried(plan.effectiveAppleProductId);
    final bool isProductUnavailable = Platform.isIOS &&
        !isProductLoading &&
        (IapService.instance.isProductNotFound(plan.effectiveAppleProductId) ||
         appleProduct == null);

    final bool isDowngrade = actionType == PlanActionType.downgrade;
    final bool isCurrent = actionType == PlanActionType.current;
    final bool isUpgrade = actionType == PlanActionType.upgrade;

    final bool isButtonDisabled = isCurrent ||
        isDowngrade ||
        provider.isLoading ||
        _isPurchasing ||
        _isProcessingPayment ||
        isProductUnavailable ||
        isProductLoading;
    final String description = _getPlanDescription(plan);
    final currentPlanName = provider.currentSubscription?.planName ?? 'Premium';

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFFFF5F0),
        border: Border(
          top: BorderSide(color: Color(0xFFFFE0D1), width: 0.8),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isDowngrade) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3CD),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFFFEEBA)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.info_outline_rounded, color: Color(0xFF856404), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You already have an active $currentPlanName plan. You cannot switch to a lower plan until your current subscription expires.',
                      style: text12(color: const Color(0xFF856404), fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (description.isNotEmpty) ...[
            Text(
              description,
              style: text12(
                color: const Color(0xFF993C1D),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
          ],
          // Features grid
          if (plan.features != null)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 3.6,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: plan.features!
                  .map((f) => Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 16),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              f,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text12(
                                color: const Color(0xFF993C1D),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isButtonDisabled
                  ? null
                  : () {
                      if (isUpgrade) {
                        _showUpgradeConfirmationDialog(plan);
                      } else {
                        _startPayment(plan);
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent || isDowngrade || isProductUnavailable
                    ? AppColors.grey400
                    : (isUpgrade ? const Color(0xFF1B873F) : AppColors.primary),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isThisPlanPurchasing
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isCurrent
                          ? 'Current Plan'
                          : (isDowngrade
                              ? 'Downgrade Not Allowed'
                              : (isUpgrade
                                  ? 'Upgrade Plan'
                                  : (isProductLoading
                                      ? 'Loading...'
                                      : (isProductUnavailable ? 'Unavailable' : 'Subscribe Now')))),
                      style: text14(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  /// Apple App Store required subscription disclosures and legal links
  Widget _buildAppleSubscriptionDisclosures() {
    final linkStyle = text12(color: AppColors.primary, fontWeight: FontWeight.w600);
    final dotStyle = text12(color: AppColors.grey400, fontWeight: FontWeight.w600);
    final btnStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      child: Column(
        children: [
          Text(
            'Payment will be charged to your Apple Account at confirmation of purchase. Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple Account settings.',
            textAlign: TextAlign.center,
            style: text11(color: AppColors.grey500),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 380) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PolicyScreen(type: 'terms-conditions'),
                          ),
                        );
                      },
                      style: btnStyle,
                      child: Text('Terms of Use', style: linkStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('•', style: dotStyle),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PolicyScreen(type: 'privacy-policy'),
                          ),
                        );
                      },
                      style: btnStyle,
                      child: Text('Privacy Policy', style: linkStyle),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text('•', style: dotStyle),
                    ),
                    TextButton(
                      onPressed: _isPurchasing ? null : _restorePurchases,
                      style: btnStyle,
                      child: Text('Restore Purchases', style: linkStyle),
                    ),
                  ],
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(type: 'terms-conditions'),
                            ),
                          );
                        },
                        style: btnStyle,
                        child: Text('Terms of Use', style: linkStyle),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('•', style: dotStyle),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const PolicyScreen(type: 'privacy-policy'),
                            ),
                          );
                        },
                        style: btnStyle,
                        child: Text('Privacy Policy', style: linkStyle),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  TextButton(
                    onPressed: _isPurchasing ? null : _restorePurchases,
                    style: btnStyle,
                    child: Text('Restore Purchases', style: linkStyle),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
