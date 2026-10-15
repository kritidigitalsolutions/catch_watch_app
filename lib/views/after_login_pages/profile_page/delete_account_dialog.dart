import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/plan_model.dart';
import '../../../res/app_colors.dart';
import '../../../services/iap_service.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';
import '../../../view_model/after_login_provider/subscription_provider.dart';
import '../../../view_model/before_login_provider/auth_providers.dart';

bool _isDeleteAccountDialogOpen = false;

/// Displays the compliant confirmation flow for deleting the user's account,
/// including StoreKit subscription guidance for Apple users.
void showDeleteAccountDialog(BuildContext context, {String entryPoint = 'unknown'}) {
  if (_isDeleteAccountDialogOpen) {
    debugPrint(
      '[DELETE_ACCOUNT] Dialog already open, ignoring duplicate request (entryPoint: $entryPoint)',
    );
    return;
  }
  _isDeleteAccountDialogOpen = true;
  debugPrint('[DELETE_ACCOUNT] Dialog opened from entryPoint: $entryPoint');

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => DeleteAccountDialog(
      parentContext: context,
      entryPoint: entryPoint,
    ),
  ).then((_) {
    _isDeleteAccountDialogOpen = false;
    debugPrint('[DELETE_ACCOUNT] Dialog dismissed/popped from navigation stack');
  });
}

class DeleteAccountDialog extends StatefulWidget {
  final BuildContext? parentContext;
  final String entryPoint;

  /// Test hook to simulate iOS platform behavior in test runners
  static bool? debugMockIsIOS;

  const DeleteAccountDialog({
    super.key,
    this.parentContext,
    this.entryPoint = 'unknown',
  });

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog>
    with WidgetsBindingObserver {
  /// Step 1: Why are you leaving? (Reason selection)
  /// Step 2: Apple Subscription Check & Guidance (conditional on active/entitled Apple subscription or loading/error)
  /// Step 3: Final Permanent Account Deletion Confirmation
  int _currentStep = 1;

  String? _selectedReason;
  late final TextEditingController _otherReasonController;

  bool _isCheckingStatus = true;
  bool _hasFetchedStatus = false;
  String? _statusFetchError;
  bool _isRefreshingStatus = false;
  bool _hasAcknowledgedAppleWarning = false;
  String? _deletionError;
  Future<void>? _fetchStatusFuture;

  bool get _isIosPlatform => DeleteAccountDialog.debugMockIsIOS ?? Platform.isIOS;

  static const String _appleSubscriptionUrl =
      'https://apps.apple.com/account/subscriptions';

  static const List<String> _reasons = [
    'I no longer use Catch & Watch',
    'I have privacy concerns',
    'I\'m facing technical issues',
    'I don\'t like the app',
    'I found another app',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _otherReasonController = TextEditingController();
    WidgetsBinding.instance.addObserver(this);

    debugPrint(
      '[DELETE_ACCOUNT] Dialog instance created (hash: $hashCode, entryPoint: ${widget.entryPoint})',
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchSubscriptionStatus();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _otherReasonController.dispose();
    debugPrint(
      '[DELETE_ACCOUNT] Dialog instance disposed (hash: $hashCode)',
    );
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _isIosPlatform && mounted) {
      debugPrint(
        '[DELETE_ACCOUNT] App resumed from background. Re-fetching verified subscription status...',
      );
      _fetchSubscriptionStatus(isAutoResume: true);
    }
  }

  /// Fetches latest verified subscription status from the backend.
  Future<void> _fetchSubscriptionStatus({bool isAutoResume = false}) {
    if (!isAutoResume && _isCheckingStatus && _fetchStatusFuture != null) {
      return _fetchStatusFuture!;
    }
    _fetchStatusFuture = _doFetchSubscriptionStatus(isAutoResume: isAutoResume);
    return _fetchStatusFuture!;
  }

  Future<void> _doFetchSubscriptionStatus({bool isAutoResume = false}) async {
    if (!mounted) return;
    setState(() {
      if (isAutoResume) {
        _isRefreshingStatus = true;
      } else {
        _isCheckingStatus = true;
      }
      _statusFetchError = null;
    });

    debugPrint('[DELETE_ACCOUNT] Subscription request start (isAutoResume: $isAutoResume)');

    try {
      final subProvider =
          Provider.of<SubscriptionProvider>(context, listen: false);
      final success = await subProvider.fetchSubscriptionStatus();
      if (!mounted) return;

      _hasFetchedStatus = true;

      if (!success) {
        final err = subProvider.subscriptionStatusError ??
            'Unable to verify your subscription status with the server.';
        debugPrint('[DELETE_ACCOUNT] Subscription request result: error ($err)');
        setState(() {
          _isCheckingStatus = false;
          _isRefreshingStatus = false;
          _statusFetchError = err;
        });
        return;
      }

      final sub = subProvider.currentSubscription;
      final classification = sub?.getEntitlementClassification(
            remainingDays: subProvider.remainingDays,
          ) ??
          EntitlementClassification.none;

      String stateStr;
      switch (classification) {
        case EntitlementClassification.activeEntitlement:
          stateStr = 'active';
          break;
        case EntitlementClassification.cancelledWithEntitlement:
          stateStr = 'cancelled-with-entitlement';
          break;
        case EntitlementClassification.expired:
          stateStr = 'expired';
          break;
        case EntitlementClassification.none:
          stateStr = 'none';
          break;
      }

      debugPrint(
        '[DELETE_ACCOUNT] Subscription request result: $stateStr '
        '(classification=$classification, remainingDays=${subProvider.remainingDays}, planId=${sub?.planId})',
      );

      setState(() {
        _isCheckingStatus = false;
        _isRefreshingStatus = false;
        _statusFetchError = null;

        // If the user arrived at Step 2 while status was loading:
        if (_currentStep == 2) {
          if (!_isAppleSubscriptionActiveOrEntitled(subProvider)) {
            debugPrint('[DELETE_ACCOUNT] Step 2 loading complete, no active/entitled Apple subscription -> advancing to Step 3');
            _currentStep = 3;
          } else {
            debugPrint('[DELETE_ACCOUNT] Step 2 loading complete, active/entitled Apple subscription confirmed -> rendering Apple guidance');
          }
        }
      });
    } catch (e) {
      if (!mounted) return;
      final err = e.toString().replaceAll('Exception: ', '').trim();
      debugPrint('[DELETE_ACCOUNT] Subscription request result: error ($err)');
      setState(() {
        _hasFetchedStatus = true;
        _isCheckingStatus = false;
        _isRefreshingStatus = false;
        _statusFetchError = err;
      });
    }
  }

  bool _isAppleSubscriptionActiveOrEntitled(SubscriptionProvider subProvider) {
    final sub = subProvider.currentSubscription;
    if (sub != null) {
      final classification = sub.getEntitlementClassification(
        remainingDays: subProvider.remainingDays,
      );
      if (classification == EntitlementClassification.activeEntitlement ||
          classification == EntitlementClassification.cancelledWithEntitlement) {
        return true;
      }
    }
    // Check if StoreKit has an unresolved/pending transaction or if a purchase verification error occurred
    if (_isIosPlatform &&
        (IapService.instance.unresolvedOrangeTickPurchase != null ||
            IapService.instance.lastVerificationErrorMessage != null)) {
      return true;
    }
    return false;
  }

  Future<void> _openAppleSubscriptions(BuildContext context) async {
    final uri = Uri.parse(_appleSubscriptionUrl);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please open Settings > Apple ID > Subscriptions to manage your subscription.',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[DELETE_ACCOUNT] Error launching Apple subscriptions URL: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Unable to open Apple Subscriptions. Please open Settings > Apple ID > Subscriptions manually.',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ProfileProvider, SubscriptionProvider>(
      builder: (dialogCtx, profileProvider, subProvider, _) {
        final isDeleting = profileProvider.isDeletingAccount;
        final effectiveContext = widget.parentContext ?? context;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (!isDeleting) {
              if (_currentStep == 3) {
                _onBackFromStep3(subProvider);
              } else if (_currentStep == 2) {
                _onBackFromStep2();
              } else {
                debugPrint(
                  '[DELETE_ACCOUNT] Dialog dismissed via back gesture / PopScope (step: $_currentStep)',
                );
                Navigator.pop(dialogCtx);
              }
            }
          },
          child: AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.85,
              ),
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: _buildCurrentStepContent(
                    dialogCtx: dialogCtx,
                    profileProvider: profileProvider,
                    subProvider: subProvider,
                  ),
                ),
              ),
            ),
            actions: _buildCurrentStepActions(
              dialogCtx: dialogCtx,
              profileProvider: profileProvider,
              subProvider: subProvider,
              effectiveContext: effectiveContext,
            ),
          ),
        );
      },
    );
  }

  Widget _buildCurrentStepContent({
    required BuildContext dialogCtx,
    required ProfileProvider profileProvider,
    required SubscriptionProvider subProvider,
  }) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Reasons();
      case 2:
        return _buildStep2SubscriptionGuidance(subProvider);
      case 3:
      default:
        return _buildStep3FinalConfirmation(
          isDeleting: profileProvider.isDeletingAccount,
          subProvider: subProvider,
        );
    }
  }

  List<Widget> _buildCurrentStepActions({
    required BuildContext dialogCtx,
    required ProfileProvider profileProvider,
    required SubscriptionProvider subProvider,
    required BuildContext effectiveContext,
  }) {
    switch (_currentStep) {
      case 1:
        return _buildStep1Actions(dialogCtx, subProvider);
      case 2:
        return _buildStep2Actions(dialogCtx, subProvider);
      case 3:
      default:
        return _buildStep3Actions(dialogCtx, profileProvider, effectiveContext);
    }
  }

  // ---------------------------------------------------------------------------
  // STEP 1 — Departure Reason Selection
  // ---------------------------------------------------------------------------
  Widget _buildStep1Reasons() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why are you leaving?',
          style: text18(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us improve Catch & Watch. (Optional)',
          style: text12(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ..._reasons.map((reason) => _buildReasonOption(reason)),
        if (_selectedReason == 'Other') ...[
          const SizedBox(height: 4),
          TextField(
            controller: _otherReasonController,
            maxLines: 2,
            minLines: 1,
            style: text12(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Please tell us why',
              hintStyle: text12(color: AppColors.hintText),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: AppColors.grey50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildReasonOption(String reason) {
    final isSelected = _selectedReason == reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedReason == reason) {
              _selectedReason = null;
            } else {
              _selectedReason = reason;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF0E8) : AppColors.grey50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.grey200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.grey400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason,
                  style: text12(
                    color:
                        isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1Actions(
    BuildContext dialogCtx,
    SubscriptionProvider subProvider,
  ) {
    return [
      TextButton(
        onPressed: () {
          debugPrint(
            '[DELETE_ACCOUNT] Dialog dismissed via Cancel button on Step 1',
          );
          Navigator.pop(dialogCtx);
        },
        child: Text(
          'Cancel',
          style: text14(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ElevatedButton(
        onPressed: () => _onStep1Continue(subProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: _isCheckingStatus
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Continue',
                style: text14(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ];
  }

  Future<void> _onStep1Continue(SubscriptionProvider subProvider) async {
    final int stepBefore = _currentStep;

    // If subscription status is still actively loading, await the fetch so we don't
    // make a premature or incorrect step transition before status is known.
    if (_isCheckingStatus && _fetchStatusFuture != null) {
      debugPrint('[DELETE_ACCOUNT] Step 1 Continue tapped while checking status -> awaiting verification...');
      await _fetchStatusFuture;
      if (!mounted) return;
    }

    final sub = subProvider.currentSubscription;
    final classification = sub?.getEntitlementClassification(
          remainingDays: subProvider.remainingDays,
        ) ??
        EntitlementClassification.none;

    int stepAfter;
    String decisionReason;

    // 1. If subscription status fetch failed with error, transition to Step 2 error view
    if (_statusFetchError != null) {
      stepAfter = 2;
      decisionReason = 'status API failed with error ($_statusFetchError)';
    }
    // 2. If an active or still-entitled Apple subscription exists
    else if (classification == EntitlementClassification.activeEntitlement ||
        classification == EntitlementClassification.cancelledWithEntitlement ||
        _isAppleSubscriptionActiveOrEntitled(subProvider)) {
      stepAfter = 2;
      decisionReason = 'active or entitled subscription confirmed ($classification)';
    }
    // 3. Backend successfully confirmed no subscription or an expired subscription
    else {
      stepAfter = 3;
      decisionReason = 'backend confirmed no subscription or expired ($classification)';
    }

    debugPrint('[DELETE_ACCOUNT] Current step before Continue: $stepBefore');
    debugPrint('[DELETE_ACCOUNT] Selected entitlement classification: $classification');
    debugPrint('[DELETE_ACCOUNT] Current step after Continue: $stepAfter');
    debugPrint('[DELETE_ACCOUNT] Reason for choosing Step $stepAfter: $decisionReason');
    setState(() => _currentStep = stepAfter);
  }

  void _onBackFromStep2() {
    debugPrint('[DELETE_ACCOUNT] Step transition: from Step 2 to Step 1 (back tapped)');
    setState(() => _currentStep = 1);
  }

  void _onBackFromStep3(SubscriptionProvider subProvider) {
    final hasAppleSub = _isAppleSubscriptionActiveOrEntitled(subProvider);
    final int targetStep = (hasAppleSub || _statusFetchError != null) ? 2 : 1;
    debugPrint('[DELETE_ACCOUNT] Step transition: from Step 3 to Step $targetStep (back tapped)');
    setState(() => _currentStep = targetStep);
  }

  // ---------------------------------------------------------------------------
  // STEP 2 — Apple Subscription Guidance & Warning
  // ---------------------------------------------------------------------------
  Widget _buildStep2SubscriptionGuidance(SubscriptionProvider subProvider) {
    // 1. Loading state while querying backend
    if (_isCheckingStatus || !_hasFetchedStatus) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 32,
              height: 32,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Checking Subscription Status',
              style: text16(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Verifying active App Store entitlements with Catch & Watch servers...',
              textAlign: TextAlign.center,
              style: text12(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    // 2. Error state if status check failed
    if (_statusFetchError != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _onBackFromStep2,
                child: const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(
                    Icons.arrow_back_rounded,
                    size: 20,
                    color: AppColors.grey600,
                  ),
                ),
              ),
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF0F0),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 20,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Subscription Check Failed',
                  style: text16(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'We could not verify your subscription status with the server. Catch & Watch needs to check if you have an active Apple subscription so you aren\'t billed after deleting your account.',
            style: text13(color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.grey50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.grey200),
            ),
            child: Text(
              _statusFetchError!,
              style: text11(color: AppColors.error),
            ),
          ),
          const SizedBox(height: 12),
          if (_isIosPlatform) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openAppleSubscriptions(context),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: const Text('Manage Apple Subscription'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1C1C1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          InkWell(
            onTap: () {
              setState(() {
                _hasAcknowledgedAppleWarning = !_hasAcknowledgedAppleWarning;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: _hasAcknowledgedAppleWarning
                    ? const Color(0xFFFFF0E8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value: _hasAcknowledgedAppleWarning,
                      activeColor: AppColors.primary,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (val) {
                        setState(() {
                          _hasAcknowledgedAppleWarning = val ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'I understand my subscription status could not be verified with the server. If I have an active Apple subscription, deleting my account will not cancel recurring charges and I must manage it manually in Apple Settings.',
                      style: text11(
                        color: _hasAcknowledgedAppleWarning
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontWeight: _hasAcknowledgedAppleWarning
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // 3. Apple Subscription Active or Entitled Warning view
    final sub = subProvider.currentSubscription;
    final classification = sub?.getEntitlementClassification(
          remainingDays: subProvider.remainingDays,
        ) ??
        EntitlementClassification.none;

    final bool isAutoRenewing =
        classification == EntitlementClassification.activeEntitlement;
    final planName = sub?.getEffectivePlanName(subProvider.plans) ??
        'Catch & Watch Premium Subscription';
    final remainingDays = subProvider.remainingDays;
    final formattedEndDate = sub?.formattedEndDate;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: _onBackFromStep2,
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.grey600,
                ),
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: Color(0xFFE65100),
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Apple Subscription Notice',
                style: text16(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Active plan details card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      planName,
                      style: text13(
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isAutoRenewing
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFFF3E0),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isAutoRenewing ? 'Active' : 'Cancelled',
                      style: text11(
                        fontWeight: FontWeight.bold,
                        color: isAutoRenewing
                            ? const Color(0xFF2E7D32)
                            : const Color(0xFFE65100),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              if (formattedEndDate != null)
                Text(
                  isAutoRenewing
                      ? 'Next renewal: $formattedEndDate'
                      : 'Entitled until: $formattedEndDate',
                  style: text12(color: AppColors.grey800),
                ),
              if (remainingDays != null && remainingDays > 0)
                Text(
                  remainingDays == 1
                      ? '1 day remaining'
                      : '$remainingDays days remaining',
                  style: text11(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Prominent Apple StoreKit warning container
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFFD54F)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: Color(0xFFF57F17),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Important Apple Billing Guidance',
                      style: text12(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFF57F17),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _warningBullet(
                'Deleting your Catch & Watch account does not cancel your Apple subscription.',
              ),
              _warningBullet(
                isAutoRenewing
                    ? 'Apple will continue to charge your Apple ID on future renewal dates unless you cancel through Apple.'
                    : 'Account deletion does not trigger an Apple refund for remaining paid time.',
              ),
              _warningBullet(
                'You must manage or cancel this subscription directly in Apple ID Settings.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Action button to open Apple Subscription Settings
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _openAppleSubscriptions(context),
            icon: const Icon(Icons.open_in_new_rounded, size: 16),
            label: const Text('Manage Apple Subscription'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1C1C1E),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),

        // Delayed backend updates guidance card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.sync_rounded, size: 14, color: AppColors.grey700),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Recently cancelled in Apple Settings?',
                      style: text11(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Apple subscription updates may take a few moments to sync with our servers. Your cancellation is effective on Apple\'s side. You can refresh below or proceed to delete your account.',
                style: text11(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _isRefreshingStatus ? null : () => _fetchSubscriptionStatus(),
                  icon: _isRefreshingStatus
                      ? const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh_rounded, size: 14),
                  label: Text(
                    _isRefreshingStatus ? 'Refreshing...' : 'Refresh Status',
                    style: text11(fontWeight: FontWeight.bold),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),

        // Acknowledgment checkbox ensuring the user cannot proceed without understanding
        InkWell(
          onTap: () {
            setState(() {
              _hasAcknowledgedAppleWarning = !_hasAcknowledgedAppleWarning;
            });
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: _hasAcknowledgedAppleWarning
                  ? const Color(0xFFFFF0E8)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: Checkbox(
                    value: _hasAcknowledgedAppleWarning,
                    activeColor: AppColors.primary,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: (val) {
                      setState(() {
                        _hasAcknowledgedAppleWarning = val ?? false;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isAutoRenewing
                        ? 'I understand that my Apple subscription must be cancelled through Apple Settings to stop recurring charges, and deleting my account will not issue a refund.'
                        : 'I understand that deleting my account will immediately end my access and Apple does not issue automatic refunds for remaining days.',
                    style: text11(
                      color: _hasAcknowledgedAppleWarning
                          ? AppColors.primary
                          : AppColors.textPrimary,
                      fontWeight: _hasAcknowledgedAppleWarning
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStep2Actions(
    BuildContext dialogCtx,
    SubscriptionProvider subProvider,
  ) {
    if (_isCheckingStatus || !_hasFetchedStatus) {
      return [
        TextButton(
          onPressed: () {
            debugPrint(
              '[DELETE_ACCOUNT] Dialog dismissed via Cancel button on Step 2 (loading)',
            );
            Navigator.pop(dialogCtx);
          },
          child: Text(
            'Cancel',
            style: text14(color: AppColors.textSecondary),
          ),
        ),
      ];
    }

    if (_statusFetchError != null) {
      return [
        TextButton(
          onPressed: () {
            debugPrint(
              '[DELETE_ACCOUNT] Dialog dismissed via Cancel button on Step 2 (error)',
            );
            Navigator.pop(dialogCtx);
          },
          child: Text(
            'Cancel',
            style: text14(color: AppColors.textSecondary),
          ),
        ),
        OutlinedButton(
          onPressed:
              _isRefreshingStatus ? null : () => _fetchSubscriptionStatus(),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          ),
          child: _isRefreshingStatus
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  'Retry',
                  style: text14(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
        ),
        ElevatedButton(
          onPressed: _hasAcknowledgedAppleWarning
              ? () {
                  debugPrint(
                    '[DELETE_ACCOUNT] Step transition: from Step 2 (error) to Step 3 (acknowledged unverified status)',
                  );
                  setState(() => _currentStep = 3);
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.error,
            foregroundColor: Colors.white,
            disabledBackgroundColor: AppColors.grey200,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          child: Text(
            'Continue to Deletion',
            style: text14(
              color: _hasAcknowledgedAppleWarning
                  ? Colors.white
                  : AppColors.grey400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ];
    }

    return [
      TextButton(
        onPressed: () {
          debugPrint(
            '[DELETE_ACCOUNT] Dialog dismissed via Cancel button on Step 2',
          );
          Navigator.pop(dialogCtx);
        },
        child: Text(
          'Cancel',
          style: text14(color: AppColors.textSecondary),
        ),
      ),
      ElevatedButton(
        onPressed: _hasAcknowledgedAppleWarning
            ? () {
                debugPrint('[DELETE_ACCOUNT] Step transition: from Step 2 to Step 3 (acknowledged Apple warning)');
                setState(() => _currentStep = 3);
              }
            : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.grey200,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: Text(
          'Continue to Deletion',
          style: text14(
            color: _hasAcknowledgedAppleWarning
                ? Colors.white
                : AppColors.grey400,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // STEP 3 — Final Permanent Deletion Confirmation
  // ---------------------------------------------------------------------------
  Widget _buildStep3FinalConfirmation({
    required bool isDeleting,
    required SubscriptionProvider subProvider,
  }) {
    final hasAppleSub = _isAppleSubscriptionActiveOrEntitled(subProvider);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: isDeleting ? null : () => _onBackFromStep3(subProvider),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.grey600,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.delete_forever_rounded,
                color: AppColors.error,
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Account',
                style: text18(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
          style: text13(color: AppColors.textPrimary),
        ),
        const SizedBox(height: 14),

        if (hasAppleSub) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE65100),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Reminder: Deleting your account will NOT cancel your Apple subscription. You must cancel it directly in Apple Settings.',
                    style: text11(
                      color: const Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_statusFetchError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF3E0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFFFB74D)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFE65100),
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Warning: Subscription status could not be verified with the server. If you have an active Apple subscription, deleting your account will NOT cancel recurring charges. You must cancel it directly in Apple Settings.',
                    style: text11(
                      color: const Color(0xFFE65100),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        if (_deletionError != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF0F0),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.error,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _deletionError!,
                    style: text11(
                      color: AppColors.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],

        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What will be permanently erased',
                style: text12(
                  color: AppColors.grey800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _bulletPoint('Your profile, username, phone number and account credentials'),
              _bulletPoint('All uploaded videos, reels, comments and likes'),
              _bulletPoint('Watch history, bookmarks and chat messages'),
              _bulletPoint('Private encryption keys and local app session data'),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStep3Actions(
    BuildContext dialogCtx,
    ProfileProvider profileProvider,
    BuildContext effectiveContext,
  ) {
    final isDeleting = profileProvider.isDeletingAccount;

    return [
      TextButton(
        onPressed: isDeleting
            ? null
            : () {
                debugPrint(
                  '[DELETE_ACCOUNT] Dialog dismissed via Cancel button on Step 3',
                );
                Navigator.pop(dialogCtx);
              },
        child: Text(
          'Cancel',
          style: text14(
            color: isDeleting ? AppColors.grey400 : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ElevatedButton(
        onPressed: isDeleting
            ? null
            : () async {
                final scaffoldMessenger =
                    ScaffoldMessenger.of(effectiveContext);
                final navigator = Navigator.of(effectiveContext);

                final String? reason = _selectedReason;
                final String? reasonDetails = (_selectedReason == 'Other')
                    ? _otherReasonController.text.trim()
                    : null;

                debugPrint('[DELETE_ACCOUNT] Confirmed final deletion action initiated');

                setState(() => _deletionError = null);

                final success = await profileProvider.deleteAccount(
                  reason: reason,
                  reasonDetails: reasonDetails,
                  context: effectiveContext,
                );

                if (success) {
                  if (dialogCtx.mounted) {
                    Navigator.pop(dialogCtx);
                  }
                  debugPrint('[DELETE_ACCOUNT] Account successfully deleted -> routing to /login');
                  if (effectiveContext.mounted) {
                    try {
                      Provider.of<AuthProvider>(effectiveContext,
                              listen: false)
                          .resetAuthState(clearPhone: true);
                    } catch (e) {
                      debugPrint(
                          'Error resetting AuthProvider during deleteAccount: $e');
                    }
                  }
                  navigator.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Account deleted successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  debugPrint('[DELETE_ACCOUNT] Account deletion failed: ${profileProvider.deleteAccountError}');
                  final errorMsg = profileProvider.deleteAccountError ??
                      'Unable to delete your account right now. Please try again.';
                  setState(() {
                    _deletionError = errorMsg;
                  });
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.error.withValues(alpha: 0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: isDeleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Delete Account',
                style: text14(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ];
  }

  static Widget _warningBullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: Color(0xFFE65100), fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: text11(color: const Color(0xFF4E342E)),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(color: AppColors.grey600, fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: text11(color: AppColors.grey600),
            ),
          ),
        ],
      ),
    );
  }
}
