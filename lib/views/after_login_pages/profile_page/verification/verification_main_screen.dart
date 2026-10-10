import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'verification_plans_screen.dart';
import 'verification_status_screen.dart';
import 'verified_status_screen.dart';

class VerificationMainScreen extends StatefulWidget {
  const VerificationMainScreen({super.key});

  @override
  State<VerificationMainScreen> createState() => _VerificationMainScreenState();
}

class _VerificationMainScreenState extends State<VerificationMainScreen> {
  _VerificationMainScreenState() {
    debugPrint('[ORANGE_TICK_DEBUG] VerificationMainScreen CREATED');
  }

  bool _hasInitiatedFlow = false;

  @override
  void initState() {
    super.initState();
    debugPrint('[ORANGE_TICK_DEBUG] VerificationMainScreen.initState');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _hasInitiatedFlow) return;
      _hasInitiatedFlow = true;
      _initFlow();
    });
  }

  Future<void> _initFlow() async {
    final provider = context.read<VerificationProvider>();
    final profileProvider = context.read<ProfileProvider>();

    debugPrint('[ORANGE_TICK_FLOW] VerificationMainScreen._initFlow START');

    // 1. Fetch verification status: GET /api/verification/status
    await provider.fetchVerificationStatus(forceRefresh: true);
    if (!mounted) return;

    // Check if status API resulted in an error -> Do NOT fetch plans
    if (provider.statusError != null) {
      debugPrint(
        '[ORANGE_TICK_FLOW] Status fetch failed: ${provider.statusError}. Skipping plans fetch.',
      );
      if (mounted) setState(() {});
      return;
    }

    final isUserAlreadyVerified =
        provider.isVerifiedActive ||
        (profileProvider.user?.hasVerifiedTick == true) ||
        provider.effectiveStatus == 'VERIFIED';
    final hasPending =
        provider.hasActiveOrPendingApplication ||
        provider.effectiveStatus == 'PENDING';
    final isNotVerified =
        !isUserAlreadyVerified && !hasPending && provider.isNotVerified;

    debugPrint(
      '[ORANGE_TICK_FLOW] effectiveStatus=${provider.effectiveStatus}',
    );
    debugPrint('[ORANGE_TICK_FLOW] isNotVerified=$isNotVerified');
    debugPrint('[ORANGE_TICK_FLOW] isVerified=$isUserAlreadyVerified');
    debugPrint('[ORANGE_TICK_FLOW] hasPending=$hasPending');

    // 2. Conditional: Call GET /api/plan/orangetick ONLY when status is strictly NOT_VERIFIED
    if (isNotVerified) {
      debugPrint(
        '[ORANGE_TICK_FLOW] decision=FETCH_PLANS (Status is strictly NOT_VERIFIED)',
      );
      await provider.fetchOrangetickPlans(forceRefresh: true);
      if (mounted) setState(() {});
    } else {
      debugPrint(
        '[ORANGE_TICK_FLOW] decision=SKIP_PLANS (Status is not NOT_VERIFIED)',
      );
      if (mounted) setState(() {});
    }
    debugPrint('[ORANGE_TICK_FLOW] VerificationMainScreen._initFlow END');
  }

  Future<void> _retryPlansFetch() async {
    final provider = context.read<VerificationProvider>();
    debugPrint('[ORANGE_TICK_FLOW] Retrying orangetick plans fetch');
    await provider.fetchOrangetickPlans(forceRefresh: true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();
    final profileProvider = context.watch<ProfileProvider>();

    // 1. While fetching verification status
    if (provider.isFetchingStatus || !provider.isInitialStatusLoaded) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Verification',
            style: text18(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // 2. Status API error state
    if (provider.statusError != null) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            'Verification',
            style: text18(fontWeight: FontWeight.bold),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'Failed to fetch verification status',
                  style: text16(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  provider.statusError!,
                  textAlign: TextAlign.center,
                  style: text13(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    _initFlow();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: Text(
                    'Retry',
                    style: text14(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // 3. User is already verified -> Show VerifiedStatusScreen (No plans API called)
    if (provider.isVerifiedActive ||
        profileProvider.user?.hasVerifiedTick == true ||
        provider.effectiveStatus == 'VERIFIED') {
      return const VerifiedStatusScreen();
    }

    // 4. User has pending / under_review application -> Show VerificationStatusScreen (No plans API called)
    if (provider.hasActiveOrPendingApplication ||
        provider.effectiveStatus == 'PENDING') {
      return const VerificationStatusScreen();
    }

    // 5. User is strictly NOT_VERIFIED -> Show VerificationPlansScreen once plans loaded
    if (provider.isNotVerified) {
      // If plans have not been loaded or fetched yet, trigger fetch
      if (!provider.isOrangetickPlansLoaded &&
          !provider.isFetchingPlans &&
          provider.orangetickPlans.isEmpty &&
          provider.plansError == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _retryPlansFetch();
          }
        });
      }

      // While plans are loading
      if (provider.isFetchingPlans ||
          (!provider.isOrangetickPlansLoaded &&
              provider.orangetickPlans.isEmpty &&
              provider.plansError == null)) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Verification Plans',
              style: text18(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: const Center(child: CircularProgressIndicator()),
        );
      }

      // If plans fetch resulted in an error
      if (provider.plansError != null && provider.orangetickPlans.isEmpty) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              'Verification Plans',
              style: text18(fontWeight: FontWeight.bold),
            ),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: AppColors.error,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load verification plans',
                    style: text16(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.plansError!,
                    textAlign: TextAlign.center,
                    style: text13(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _retryPlansFetch,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                    ),
                    child: Text(
                      'Retry',
                      style: text14(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      return const VerificationPlansScreen();
    }

    // 6. Fallback for any other existing application state
    if (provider.currentApplication != null) {
      return const VerificationStatusScreen();
    }

    return const VerificationPlansScreen();
  }
}
