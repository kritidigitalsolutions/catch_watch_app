import 'dart:io';

import 'package:catch_watch/data/exception/app_exception.dart';
import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/repository/plan_repository.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/services/iap_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:provider/provider.dart';
import 'verification_form_screen.dart';
import 'verification_status_screen.dart';
import 'verified_status_screen.dart';

class VerificationPlansScreen extends StatefulWidget {
  const VerificationPlansScreen({super.key});

  @override
  State<VerificationPlansScreen> createState() =>
      _VerificationPlansScreenState();
}

class _VerificationPlansScreenState extends State<VerificationPlansScreen> {
  _VerificationPlansScreenState() {
    debugPrint('[ORANGE_TICK_DEBUG] VerificationPlansScreen CREATED');
  }
  bool _isRestoring = false;
  int _inFlightVerificationCount = 0;

  @override
  void initState() {
    super.initState();
    debugPrint('[ORANGE_TICK_DEBUG] VerificationPlansScreen.initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  void _initIap() {
    IapService.instance.initialize(
      onVerifyPurchase: _verifyApplePurchase,
      onPurchaseSuccess: _onApplePurchaseSuccess,
      onError: (message) {
        if (!mounted) return;
        setState(() {
          _isRestoring = false;
        });
        try {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text(message)));
        } catch (e) {
          debugPrint(
            '[ORANGE_TICK_DEBUG] Ignored SnackBar error on deactivated context: $e',
          );
        }
      },
      onPending: (isPending) {},
      onCanceled: () {
        if (mounted) {
          setState(() {
            _isRestoring = false;
          });
        }
      },
    );
  }

  Future<void> _loadData() async {
    debugPrint('[ORANGE_TICK_DEBUG] VerificationPlansScreen._loadData START');
    final provider = context.read<VerificationProvider>();
    if (!provider.isOrangetickPlansLoaded &&
        !provider.isFetchingPlans &&
        provider.orangetickPlans.isEmpty) {
      await provider.fetchOrangetickPlans();
    }
    if (Platform.isIOS) {
      final Set<String> productIds = {orangeTickProductId};
      for (final p in provider.orangetickPlans) {
        productIds.add(p.effectiveAppleProductId);
      }
      await IapService.instance.loadProducts(productIds);
      if (mounted) setState(() {});
    }
    debugPrint('[ORANGE_TICK_DEBUG] VerificationPlansScreen._loadData END');
  }

  Future<bool> _verifyApplePurchase(PurchaseDetails purchaseDetails) async {
    // Strictly guard: VerificationPlansScreen ONLY handles active restore flows
    if (!_isRestoring || purchaseDetails.status != PurchaseStatus.restored) {
      debugPrint(
        '[ORANGE_TICK_IAP] VerificationPlansScreen: Ignoring transaction (status: ${purchaseDetails.status}, isRestoring: $_isRestoring)',
      );
      return false;
    }

    debugPrint(
      '[ORANGE_TICK_IAP] VerificationPlansScreen: Handling restore Orange Tick purchase',
    );

    _inFlightVerificationCount++;
    try {
      final String? originalTxId = IapService.instance
          .extractOriginalTransactionId(purchaseDetails);
      final payload = {
        "serverVerificationData":
            purchaseDetails.verificationData.serverVerificationData,
        "productId": purchaseDetails.productID,
        "transactionId": purchaseDetails.purchaseID ?? '',
        "originalTransactionId":
            originalTxId ?? purchaseDetails.purchaseID ?? '',
      };

      debugPrint('[ORANGE_TICK_IAP] POST verify-apple (restore)');
      final planRepo = PlanRepository();
      final response = await planRepo.verifyApplePayment(payload);
      final bool success = response != null && response['success'] == true;
      if (success) {
        debugPrint('[ORANGE_TICK_IAP] Backend verification success (restore)');
      } else {
        debugPrint('[ORANGE_TICK_IAP] Backend verification failed (restore)');
        final serverMsg = response?['message']?.toString() ?? '';
        if (serverMsg.toLowerCase().contains('expired') ||
            IapService.instance.isTransactionExpired(purchaseDetails)) {
          await IapService.instance.resolveAndCompleteTerminalTransaction(
            purchaseDetails,
            reason: 'expired',
          );
        }
      }
      return success;
    } catch (e) {
      debugPrint(
        '[ORANGE_TICK_IAP] Backend verification exception (restore): $e',
      );
      final errorMsg = e is AppException ? e.message : e.toString();
      if (errorMsg.toLowerCase().contains('expired') ||
          IapService.instance.isTransactionExpired(purchaseDetails)) {
        await IapService.instance.resolveAndCompleteTerminalTransaction(
          purchaseDetails,
          reason: 'expired',
        );
      }
      return false;
    } finally {
      _inFlightVerificationCount--;
    }
  }

  void _onApplePurchaseSuccess(PurchaseDetails purchaseDetails) {
    if (!mounted) return;
    try {
      context.read<ProfileProvider>().fetchProfile();
      context.read<VerificationProvider>().fetchVerificationStatus(
        forceRefresh: true,
      );
    } catch (e) {
      debugPrint('[ORANGE_TICK_DEBUG] Ignored context lookup on success: $e');
    }
  }

  Future<void> _restorePurchases() async {
    if (_isRestoring) return;

    setState(() {
      _isRestoring = true;
    });
    IapService.instance.isRestoring = true;

    try {
      _initIap();
      final verProvider = context.read<VerificationProvider>();
      if (!verProvider.isOrangetickPlansLoaded &&
          verProvider.orangetickPlans.isEmpty) {
        await verProvider.fetchOrangetickPlans();
      }

      await IapService.instance.restorePurchases();

      // Wait for any in-flight transaction verifications dispatched by purchaseStream
      final DateTime deadline = DateTime.now().add(const Duration(seconds: 25));
      while (_inFlightVerificationCount > 0 &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      await Future.delayed(const Duration(milliseconds: 500));
      while (_inFlightVerificationCount > 0 &&
          DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      if (!mounted) return;

      final profileProvider = context.read<ProfileProvider>();
      await verProvider.fetchVerificationStatus(forceRefresh: true);
      await profileProvider.fetchProfile();
      if (!mounted) return;

      if (verProvider.currentApplication?.status == 'approved' ||
          profileProvider.user?.hasVerifiedTick == true) {
        try {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text('Orange Tick subscription restored successfully!'),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerifiedStatusScreen()),
          );
        } catch (e) {
          debugPrint('[ORANGE_TICK_DEBUG] Ignored navigation error: $e');
        }
      } else if (verProvider.currentApplication != null) {
        try {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'Subscription restored. Your application is under review.',
              ),
            ),
          );
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const VerificationStatusScreen()),
          );
        } catch (e) {
          debugPrint('[ORANGE_TICK_DEBUG] Ignored navigation error: $e');
        }
      } else {
        try {
          ScaffoldMessenger.maybeOf(context)?.showSnackBar(
            const SnackBar(
              content: Text(
                'No active Orange Tick subscriptions found to restore.',
              ),
            ),
          );
        } catch (e) {
          debugPrint('[ORANGE_TICK_DEBUG] Ignored SnackBar error: $e');
        }
      }
    } catch (e) {
      debugPrint('[IAP] Restore error: $e');
      if (mounted) {
        try {
          ScaffoldMessenger.maybeOf(
            context,
          )?.showSnackBar(SnackBar(content: Text('Restore failed: $e')));
        } catch (err) {
          debugPrint('[ORANGE_TICK_DEBUG] Ignored SnackBar error: $err');
        }
      }
    } finally {
      IapService.instance.isRestoring = false;
      if (IapService.instance.onVerifyPurchase == _verifyApplePurchase) {
        IapService.instance.onVerifyPurchase = null;
        IapService.instance.onPurchaseSuccess = null;
        IapService.instance.onError = null;
        IapService.instance.onPending = null;
        IapService.instance.onCanceled = null;
      }
      if (mounted) {
        setState(() {
          _isRestoring = false;
        });
      }
    }
  }

  @override
  void dispose() {
    if (IapService.instance.onVerifyPurchase == _verifyApplePurchase) {
      IapService.instance.onVerifyPurchase = null;
      IapService.instance.onPurchaseSuccess = null;
      IapService.instance.onError = null;
      IapService.instance.onPending = null;
      IapService.instance.onCanceled = null;
    }
    super.dispose();
  }

  String _sanitizeFeature(String feature) {
    final trimmed = feature.trim();
    if (trimmed.toLowerCase() == 'profashional profile') {
      return 'Professional Profile';
    }
    if (trimmed.toLowerCase().contains('profashional')) {
      return trimmed.replaceAll(
        RegExp(r'profashional', caseSensitive: false),
        'Professional',
      );
    }
    return trimmed;
  }

  static const List<String> _orangeTickBenefits = [
    'Official Verified Badge',
    'Verified Profile Identity',
    'Advanced Account Protection',
    'Fake Account Protection',
    'Priority Creator Support',
    'Higher Search Visibility',
    'Better Content Discovery',
    'Highlighted Comments',
    'Verified Creator Dashboard',
    'Exclusive Creator Tools',
    'Early Access to New Features',
    'Eligible for Creator Rewards',
  ];

  List<Plan> _getEffectivePlans(List<Plan> backendPlans) {
    if (backendPlans.isEmpty) {
      return [];
    }

    // Filter out inactive plans and validate category to exclude Blue Tick plans
    final eligibleBackendPlans = backendPlans.where((p) {
      if (p.isActive == false) return false;
      if (p.isBlueTickPlan) {
        debugPrint(
          '[ORANGE_TICK_FLOW] Excluded Blue Tick plan: id=${p.id}, name=${p.name}, category=${p.category}',
        );
        return false;
      }
      return true;
    }).toList();

    // If explicit Orange Tick / Creator plans exist in the returned list, prioritize them
    final orangePlans = eligibleBackendPlans
        .where((p) => p.isOrangeTickPlan)
        .toList();
    final targetPlans = orangePlans.isNotEmpty
        ? orangePlans
        : eligibleBackendPlans;

    if (Platform.isIOS) {
      // On iOS: Render active backend plans enriched with StoreKit product ID
      return targetPlans.map((plan) {
        final String effectiveProdId =
            (plan.appleProductId != null && plan.appleProductId!.isNotEmpty)
            ? plan.appleProductId!
            : orangeTickProductId;

        return Plan(
          id: plan.id,
          name: (plan.name != null && plan.name!.isNotEmpty)
              ? plan.name
              : 'Monthly Plan',
          category: plan.category ?? plan.planCategory ?? 'orange_tick',
          planCategory: plan.planCategory ?? plan.category ?? 'orange_tick',
          planType: plan.planType ?? 'creator_verification',
          duration: plan.duration ?? 30,
          price: plan.price,
          appleProductId: effectiveProdId,
          isRecommended: plan.isRecommended ?? false,
          isActive: plan.isActive ?? true,
          features: (plan.features != null && plan.features!.isNotEmpty)
              ? plan.features!.map(_sanitizeFeature).toList()
              : const [
                  'Professional Profile',
                  'Official Orange Tick Creator Badge',
                  'Enhanced Account & Impersonation Protection',
                  'Priority Customer Support',
                  'Higher Search & Discovery Ranking',
                  'Exclusive Creator Tools & Analytics',
                ],
        );
      }).toList();
    }

    // Android: Preserve existing backend plans list & Razorpay flow
    return targetPlans.map((plan) {
      return Plan(
        id: plan.id,
        name: plan.name,
        category: plan.category,
        planCategory: plan.planCategory,
        planType: plan.planType,
        duration: plan.duration,
        price: plan.price,
        appleProductId: plan.appleProductId,
        isRecommended: plan.isRecommended,
        isActive: plan.isActive,
        features: plan.features != null && plan.features!.isNotEmpty
            ? plan.features!.map(_sanitizeFeature).toList()
            : null,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();
    final effectivePlans = _getEffectivePlans(provider.orangetickPlans);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(
            child:
                (provider.isLoading || provider.isFetchingPlans) &&
                    provider.orangetickPlans.isEmpty
                ? const SizedBox(
                    height: 300,
                    child: Center(child: CircularProgressIndicator()),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      _buildBenefitsSection(),
                      const SizedBox(height: 24),
                      if (effectivePlans.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            'Select a Plan',
                            style: text18(fontWeight: FontWeight.w800),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: effectivePlans.asMap().entries.map((
                              entry,
                            ) {
                              final isLast =
                                  entry.key == effectivePlans.length - 1;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: isLast ? 0 : 16,
                                ),
                                child: _buildEnhancedPlanCard(entry.value),
                              );
                            }).toList(),
                          ),
                        ),
                        if (Platform.isIOS) ...[
                          const SizedBox(height: 24),
                          _buildIosSubscriptionDisclosures(),
                        ],
                      ] else ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              vertical: 36,
                              horizontal: 20,
                            ),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: AppColors.grey50,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.grey200),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  provider.plansError != null
                                      ? Icons.error_outline_rounded
                                      : Icons.info_outline_rounded,
                                  size: 40,
                                  color: provider.plansError != null
                                      ? AppColors.error
                                      : AppColors.grey400,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  provider.plansError ??
                                      'No Orange Tick plans are currently available.',
                                  textAlign: TextAlign.center,
                                  style: text14(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                OutlinedButton.icon(
                                  onPressed: provider.isFetchingPlans
                                      ? null
                                      : () => provider.fetchOrangetickPlans(
                                          forceRefresh: true,
                                        ),
                                  icon: provider.isFetchingPlans
                                      ? const SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.refresh_rounded,
                                          size: 18,
                                        ),
                                  label: Text(
                                    provider.isFetchingPlans
                                        ? 'Retrying...'
                                        : 'Retry',
                                    style: text14(fontWeight: FontWeight.bold),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: AppColors.primary,
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppColors.primary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      actions: [
        if (Platform.isIOS)
          TextButton(
            onPressed: _isRestoring ? null : _restorePurchases,
            child: _isRestoring
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    'Restore',
                    style: text14(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
          ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, Color(0xFFCC3D00)],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                top: -30,
                right: -30,
                child: Icon(
                  Icons.verified_rounded,
                  size: 200,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 100, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: Colors.white,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'CREATOR VERIFICATION',
                            style: text10(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Get Your Orange Tick',
                      style: text26(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.grey200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: _orangeTickBenefits.asMap().entries.map((entry) {
          final isLast = entry.key == _orangeTickBenefits.length - 1;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppColors.success,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: text14(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildPriceWidget(Plan plan) {
    final String durationLabel = (plan.duration != null && plan.duration == 30)
        ? '/ Month'
        : (plan.duration != null ? '/ ${plan.duration} Days' : '/ Month');

    if (Platform.isIOS) {
      final String productId = plan.effectiveAppleProductId;
      final product = IapService.instance.getProduct(productId) ??
          IapService.instance.getProduct(orangeTickProductId);

      if (product != null && product.price.isNotEmpty) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Flexible(
              child: Text(
                product.price,
                style: text30(
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(
                durationLabel,
                style: text14(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      }

      final bool isUnavailable =
          IapService.instance.isProductNotFound(productId) ||
          (IapService.instance.isProductQueried(productId) &&
              IapService.instance.getProduct(productId) == null &&
              IapService.instance.getProduct(orangeTickProductId) == null);

      return Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Flexible(
            child: Text(
              isUnavailable ? 'Unavailable' : 'Loading...',
              style: text24(
                fontWeight: FontWeight.w800,
                color: AppColors.grey500,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: Text(
            '₹${plan.price ?? 0}',
            style: text30(
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            durationLabel,
            style: text14(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEnhancedPlanCard(Plan plan) {
    final bool isProductUnavailable =
        Platform.isIOS &&
        (IapService.instance.isProductNotFound(plan.effectiveAppleProductId) ||
            (IapService.instance.isProductQueried(
                  plan.effectiveAppleProductId,
                ) &&
                IapService.instance.getProduct(plan.effectiveAppleProductId) ==
                    null &&
                IapService.instance.getProduct(orangeTickProductId) == null));
    final bool isProductLoading =
        Platform.isIOS &&
        !isProductUnavailable &&
        IapService.instance.getProduct(plan.effectiveAppleProductId) == null &&
        IapService.instance.getProduct(orangeTickProductId) == null;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.white, Color(0xFFFFF9F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: plan.isRecommended == true
              ? AppColors.primary.withValues(alpha: 0.5)
              : AppColors.grey200,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          if (plan.isRecommended == true)
            Positioned(
              top: 0,
              right: 20,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                ),
                child: Text(
                  'MOST POPULAR',
                  style: text10(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    right: plan.isRecommended == true ? 90 : 0,
                  ),
                  child: Text(
                    plan.name?.toUpperCase() ?? 'MONTHLY PLAN',
                    style: text12(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _buildPriceWidget(plan),
                const SizedBox(height: 20),
                const Divider(height: 1, color: AppColors.grey200),
                const SizedBox(height: 18),
                if (plan.features != null && plan.features!.isNotEmpty) ...[
                  ...plan.features!.asMap().entries.map((entry) {
                    final isLast = entry.key == plan.features!.length - 1;
                    return Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.verified_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _sanitizeFeature(entry.value),
                              style: text14(
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: (isProductUnavailable || isProductLoading)
                        ? null
                        : () {
                            final provider =
                                context.read<VerificationProvider>();
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => VerificationFormScreen(
                                  plan: plan,
                                  existingApplication:
                                      provider.currentApplication,
                                  isReapplication: provider.canReapply,
                                ),
                              ),
                            );
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (isProductUnavailable || isProductLoading)
                          ? AppColors.grey400
                          : AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      isProductUnavailable
                          ? 'Currently Unavailable'
                          : (isProductLoading
                                ? 'Loading...'
                                : 'Apply for Orange Tick'),
                      style: text16(
                        fontWeight: FontWeight.w800,
                        color: AppColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIosSubscriptionDisclosures() {
    final linkStyle = text12(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
    );
    final bulletStyle = text11(
      color: AppColors.grey500,
      fontWeight: FontWeight.bold,
    );
    final textStyle = appTextStyle(
      fontSize: 11,
      color: AppColors.grey600,
      height: 1.45,
    );
    final btnStyle = TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      minimumSize: Size.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 8,
            children: [
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PolicyScreen(type: 'terms-conditions'),
                    ),
                  );
                },
                style: btnStyle,
                child: Text('Terms of Use', style: linkStyle),
              ),
              Text('•', style: bulletStyle),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          const PolicyScreen(type: 'privacy-policy'),
                    ),
                  );
                },
                style: btnStyle,
                child: Text('Privacy Policy', style: linkStyle),
              ),
              Text('•', style: bulletStyle),
              TextButton(
                onPressed: _isRestoring ? null : _restorePurchases,
                style: btnStyle,
                child: Text('Restore Purchases', style: linkStyle),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'CatchWatch Orange Tick is an auto-renewable monthly creator subscription. Payment is charged to your Apple ID account upon confirmation of purchase. Subscription automatically renews unless auto-renew is turned off at least 24 hours before the end of the current billing cycle. You may manage or cancel subscriptions in your App Store Account Settings.',
            textAlign: TextAlign.center,
            style: textStyle,
          ),
        ],
      ),
    );
  }
}
