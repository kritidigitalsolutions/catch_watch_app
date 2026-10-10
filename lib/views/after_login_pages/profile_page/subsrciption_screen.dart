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

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _expandedPlanId;

  // Android Razorpay instance
  late Razorpay _razorpay;
  String? _pendingPlanId;

  // iOS Apple IAP state
  bool _isPurchasing = false;
  String? _pendingApplePlanId;
  bool _isRestoring = false;
  int _inFlightVerificationCount = 0;
  int _restoredSuccessCount = 0;

  @override
  void initState() {
    super.initState();

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

  /// Initializes Apple StoreKit purchase listeners
  void _initIap() {
    IapService.instance.initialize(
      onVerifyPurchase: _verifyApplePurchase,
      onPurchaseSuccess: _onApplePurchaseSuccess,
      onError: (message) {
        if (mounted) {
          setState(() {
            _isPurchasing = false;
            _pendingApplePlanId = null;
          });
          _showErrorPopup(message, true);
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
          final rec = plans.firstWhere(
            (p) => p.isRecommended == true,
            orElse: () => plans.length > 1 ? plans[1] : plans.first,
          );
          _expandedPlanId = rec.id;
        }
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
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
    });

    if (mounted) Navigator.pop(context); // Close loading dialog

    if (success && mounted) {
      context.read<ProfileProvider>().fetchProfile();
      _showSuccessPopup();
    } else if (mounted) {
      _showErrorPopup(provider.error ?? 'Payment verification failed', true);
    }
    _pendingPlanId = null;
  }

  void _handlePaymentError(PaymentFailureResponse response) {
    if (mounted) {
      _showErrorPopup('Payment Failed: ${response.message}', true);
    }
  }

  void _handleExternalWallet(ExternalWalletResponse response) {
    debugPrint("External Wallet: ${response.walletName}");
  }

  // ─── iOS Apple IAP Callbacks ────────────────────────────────────────────────

  Future<void> _startApplePurchase(Plan plan) async {
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
      });
      final loaded = await IapService.instance.loadProducts({productId});
      setState(() {
        _isPurchasing = false;
        _pendingApplePlanId = null;
      });
      if (loaded.isNotEmpty) {
        product = IapService.instance.getProduct(productId);
      }
    }

    if (product == null) {
      _showErrorPopup(
        'Subscription product is currently unavailable in the App Store. Please try again later.',
        false,
      );
      return;
    }

    setState(() {
      _isPurchasing = true;
      _pendingApplePlanId = plan.id;
    });

    final launched = await IapService.instance.buyProduct(product);
    if (!launched && mounted) {
      setState(() {
        _isPurchasing = false;
        _pendingApplePlanId = null;
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
          (p) => p.id == _pendingApplePlanId,
          orElse: () => Plan(),
        );
      }
      if (matchedPlan == null || matchedPlan.id == null) {
        matchedPlan = allPlans.firstWhere(
          (p) => p.effectiveAppleProductId == purchaseDetails.productID,
          orElse: () => Plan(),
        );
      }
      if (matchedPlan == null || matchedPlan.id == null) {
        switch (purchaseDetails.productID) {
          case 'com.app.catchWatch.sub.premium.weekly':
            matchedPlan = allPlans.firstWhere(
              (p) =>
                  p.effectiveAppleProductId == 'com.app.catchWatch.sub.premium.weekly' ||
                  (p.name?.toLowerCase().contains('week') ?? false) ||
                  p.duration == 7 ||
                  p.price == 299,
              orElse: () => Plan(),
            );
            break;
          case 'com.app.catchWatch.sub.premium.yearly':
            matchedPlan = allPlans.firstWhere(
              (p) =>
                  p.effectiveAppleProductId == 'com.app.catchWatch.sub.premium.yearly' ||
                  (p.name?.toLowerCase().contains('year') ?? false) ||
                  (p.name?.toLowerCase().contains('annual') ?? false) ||
                  p.duration == 365 ||
                  p.duration == 12 ||
                  p.price == 999,
              orElse: () => Plan(),
            );
            break;
          case 'com.app.catchWatch.sub.premium.monthly':
          default:
            matchedPlan = allPlans.firstWhere(
              (p) =>
                  p.effectiveAppleProductId == 'com.app.catchWatch.sub.premium.monthly' ||
                  (p.name?.toLowerCase().contains('month') ?? false) ||
                  p.duration == 30 ||
                  p.duration == 1 ||
                  p.price == 699,
              orElse: () => Plan(),
            );
            break;
        }
      }

      final resolvedPlanId = matchedPlan?.id ?? _pendingApplePlanId;
      if (resolvedPlanId == null || resolvedPlanId.isEmpty) {
        debugPrint('[IAP] Verification aborted: Unable to resolve planId for product ${purchaseDetails.productID}');
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

      final payload = {
        "planId": resolvedPlanId,
        "productId": purchaseDetails.productID,
        "transactionId": purchaseDetails.purchaseID ?? '',
        "originalTransactionId": originalTxId,
        "serverVerificationData":
            purchaseDetails.verificationData.serverVerificationData,
      };

      final bool success = await provider.verifyApplePayment(payload);
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
      setState(() {
        _isPurchasing = false;
        _pendingApplePlanId = null;
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
                'Please open Settings > Apple ID > Subscriptions to manage your subscription.',
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error opening subscription URL: $e');
    }
  }

  // ─── Purchase Initiation ────────────────────────────────────────────────────

  Future<void> _startPayment(Plan plan) async {
    if (Platform.isIOS) {
      await _startApplePurchase(plan);
      return;
    }

    // Android Razorpay flow
    final provider = context.read<SubscriptionProvider>();
    final user = context.read<ProfileProvider>().user;

    _pendingPlanId = plan.id;
    final response = await provider.createOrder(plan.id!);

    if (response != null && response['order'] != null) {
      final order = response['order'];
      final razorpayKey = response['key'];

      var options = {
        'key': razorpayKey ?? 'rzp_test_SztpB3DjlEhcKW',
        'amount': order['amount'],
        'name': 'Catch Watch',
        'order_id': order['id'],
        'description': plan.name,
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
        debugPrint('Error: $e');
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.error ?? 'Failed to create order')),
        );
      }
    }
  }

  // ─── Plan Helpers ───────────────────────────────────────────────────────────

  /// Returns the three Catch & Watch OTT viewer subscription plans: Weekly, Monthly, and Yearly.
  /// Reuses matching backend plans from [providerPlans] to preserve backend IDs,
  /// while guaranteeing all 3 OTT tiers are available for selection and purchase.
  List<Plan> _getEffectivePlans(List<Plan> providerPlans) {
    Plan? weeklyPlan;
    Plan? monthlyPlan;
    Plan? yearlyPlan;

    for (final p in providerPlans) {
      final prodId = p.effectiveAppleProductId;
      if (prodId == 'com.app.catchWatch.sub.premium.weekly' && weeklyPlan == null) {
        weeklyPlan = p;
      } else if (prodId == 'com.app.catchWatch.sub.premium.yearly' && yearlyPlan == null) {
        yearlyPlan = p;
      } else if (prodId == 'com.app.catchWatch.sub.premium.monthly' && monthlyPlan == null) {
        monthlyPlan = p;
      }
    }

    weeklyPlan ??= Plan(
      id: 'weekly',
      name: 'Weekly',
      price: 299,
      duration: 7,
      isRecommended: false,
      appleProductId: 'com.app.catchWatch.sub.premium.weekly',
      features: const [
        '7-day access',
        'Entry plan for short-term access',
        'Ad-free premium video streaming',
        'Unlimited HD playback',
      ],
    );

    monthlyPlan ??= Plan(
      id: 'monthly',
      name: 'Monthly',
      price: 699,
      duration: 30,
      isRecommended: true,
      appleProductId: 'com.app.catchWatch.sub.premium.monthly',
      features: const [
        'Monthly access',
        'Core recurring plan for regular viewers',
        'Ad-free premium video streaming',
        'Unlimited HD playback',
      ],
    );

    yearlyPlan ??= Plan(
      id: 'yearly',
      name: 'Yearly',
      price: 999,
      duration: 365,
      isRecommended: false,
      appleProductId: 'com.app.catchWatch.sub.premium.yearly',
      features: const [
        '12-month access',
        'Highest-value plan for long-term members',
        'Ad-free premium video streaming',
        'Unlimited HD playback',
      ],
    );

    if (!Platform.isIOS && providerPlans.isNotEmpty) {
      return providerPlans;
    }

    return [weeklyPlan, monthlyPlan, yearlyPlan];
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
      builder: (context) => AlertDialog(
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
                onPressed: () => Navigator.pop(context),
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
    final pendingId = Platform.isIOS ? _pendingApplePlanId : _pendingPlanId;
    final allPlans = _getEffectivePlans(context.read<SubscriptionProvider>().plans);
    final plan = allPlans.firstWhere(
          (p) => p.id == pendingId,
          orElse: () => Plan(),
        );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Payment Status', style: text18(fontWeight: FontWeight.w800)),
        content: Text(message, style: text14(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: text14(color: AppColors.textSecondary)),
          ),
          if (showTryAgain && plan.id != null)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
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
    );
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
            child: provider.isLoading && provider.plans.isEmpty && !Platform.isIOS
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null && displayPlans.isEmpty
                    ? Center(child: Text(provider.error!))
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
                backgroundColor: Colors.white.withOpacity(0.18),
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
          color: Colors.white.withOpacity(0.18),
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
    final planName = plan?.name ?? 'Premium';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 14, 20, 2),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('ACTIVE PLAN',
                  style: text12(color: AppColors.primary, fontWeight: FontWeight.w800)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('Active',
                    style: text10(color: AppColors.success, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(planName, style: text18(fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
          const SizedBox(height: 4),
          Text('Expires in ${provider.remainingDays ?? 0} days',
              style: text13(color: AppColors.textSecondary)),
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
    final isCurrent = provider.currentSubscription != null &&
        (provider.currentSubscription!.plan is Plan
            ? ((provider.currentSubscription!.plan as Plan).id == plan.id ||
               (provider.currentSubscription!.plan as Plan).effectiveAppleProductId == plan.effectiveAppleProductId)
            : provider.currentSubscription!.plan == plan.id);

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
                  color: AppColors.primary.withOpacity(0.08),
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
                              if (plan.isRecommended == true) ...[
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
              secondChild: _buildPlanBody(plan, provider, isCurrent),
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

  Widget _buildPlanBody(Plan plan, SubscriptionProvider provider, bool isCurrent) {
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
    final bool isButtonDisabled =
        isCurrent || provider.isLoading || _isPurchasing || isProductUnavailable || isProductLoading;
    final String description = _getPlanDescription(plan);

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
              onPressed: isButtonDisabled ? null : () => _startPayment(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent || isProductUnavailable
                    ? AppColors.grey400
                    : AppColors.primary,
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
                          : (isProductLoading
                              ? 'Loading...'
                              : (isProductUnavailable ? 'Unavailable' : 'Subscribe Now')),
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
            'Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage or cancel your subscription in your Apple Account settings.',
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
