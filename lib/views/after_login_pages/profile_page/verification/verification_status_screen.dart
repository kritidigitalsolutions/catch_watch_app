import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/models/verification_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:catch_watch/services/iap_service.dart';
import 'verification_form_screen.dart';

class VerificationStatusScreen extends StatefulWidget {
  const VerificationStatusScreen({super.key});

  @override
  State<VerificationStatusScreen> createState() =>
      _VerificationStatusScreenState();
}

class _VerificationStatusScreenState extends State<VerificationStatusScreen> {
  bool _isNavigatingToReapply = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<VerificationProvider>();
      if (provider.orangetickPlans.isEmpty && !provider.isFetchingPlans) {
        provider.fetchOrangetickPlans();
      }
    });
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      title: Text(
        'Verification Status',
        style: text18(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 20,
          color: AppColors.textPrimary,
        ),
        onPressed: () {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();
    final app = provider.currentApplication;

    // Loading / Empty / Error state guards
    if (app == null) {
      if (provider.isFetchingStatus) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context),
          body: const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }

      if (provider.statusError != null) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(context),
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
                    'Unable to Load Status',
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
                    onPressed: () =>
                        provider.fetchVerificationStatus(forceRefresh: true),
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

      // Clean empty state fallback
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: _buildAppBar(context),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: AppColors.grey500,
                  size: 48,
                ),
                const SizedBox(height: 16),
                Text(
                  'No Verification Request Found',
                  style: text16(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'You currently have no active verification application.',
                  textAlign: TextAlign.center,
                  style: text13(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
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
                    'Go Back',
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

    final rawStatus = (provider.effectiveStatus.isNotEmpty &&
            provider.effectiveStatus != 'NOT_VERIFIED')
        ? provider.effectiveStatus
        : (app.status ?? 'PENDING');
    final normalizedStatus = rawStatus.toLowerCase();
    final isPending =
        normalizedStatus == 'pending' ||
        normalizedStatus == 'under_review' ||
        normalizedStatus == 'in_review' ||
        normalizedStatus == 'processing';
    final isApproved =
        normalizedStatus == 'approved' ||
        normalizedStatus == 'verified' ||
        normalizedStatus == 'active';
    final isRejected = normalizedStatus == 'rejected';
    final isCancelled =
        normalizedStatus == 'cancelled' ||
        normalizedStatus == 'canceled' ||
        normalizedStatus == 'admin_cancelled' ||
        normalizedStatus == 'admin_canceled' ||
        normalizedStatus == 'closed';

    final fullName = _resolveFullName(app, context);
    final idType = _resolveIdType(app.governmentIdType);
    final planName = _resolvePlanName(app, provider);
    final appliedOn = _formatDate(app.createdAt);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildStatusCard(rawStatus),
              const SizedBox(height: 24),
              _buildDetailsCard(
                fullName: fullName,
                idType: idType,
                planName: planName,
                appliedOn: appliedOn,
                status: rawStatus,
              ),
              const SizedBox(height: 16),
              if (isPending) ...[
                _buildReviewNoticeCard(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final rawPlan =
                          app.plan ??
                          provider.orangetickPlans.cast<Plan?>().firstWhere(
                            (p) => p?.id == app.planId,
                            orElse: () =>
                                Plan(id: app.planId, name: 'Orange Tick Plan'),
                          ) ??
                          Plan(name: 'Orange Tick Plan');

                      final planToUse = Plan(
                        id: rawPlan.id ?? app.planId,
                        name: rawPlan.name ?? 'Orange Tick Plan',
                        category: rawPlan.category ?? 'orange_tick',
                        planCategory: rawPlan.planCategory ?? 'orange_tick',
                        planType: rawPlan.planType ?? 'creator_verification',
                        duration: rawPlan.duration ?? 30,
                        price: rawPlan.price,
                        appleProductId:
                            (rawPlan.appleProductId != null &&
                                rawPlan.appleProductId!.isNotEmpty)
                            ? rawPlan.appleProductId
                            : orangeTickProductId,
                        isRecommended: rawPlan.isRecommended,
                        isActive: rawPlan.isActive,
                        features: rawPlan.features,
                      );

                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerificationFormScreen(
                            plan: planToUse,
                            existingApplication: app,
                            isReapplication: provider.canReapply,
                          ),
                        ),
                      ).then((updated) {
                        if (updated == true && context.mounted) {
                          provider.fetchVerificationStatus(forceRefresh: true);
                        }
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Update Details',
                      style: text14(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ] else if (isApproved) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.success.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        color: AppColors.success,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your profile is verified. Orange Tick badge is actively displayed on your profile.',
                          style: text13(
                            color: AppColors.success,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ] else if (isRejected) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Not Approved',
                        style: text14(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        app.reason != null && app.reason!.isNotEmpty
                            ? app.reason!
                            : 'Your submitted documents did not meet our verification requirements. Please contact support or apply again with updated documents.',
                        style: text13(
                          color: AppColors.textSecondary,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildApplyAgainButton(app, provider),
              ] else if (isCancelled) ...[
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE05638).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE05638).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Application Cancelled',
                        style: text14(
                          color: const Color(0xFFE05638),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        app.reason != null && app.reason!.isNotEmpty
                            ? app.reason!
                            : 'This verification request was cancelled by admin. You can review your details and submit a new verification application.',
                        style: text13(
                          color: AppColors.textSecondary,
                        ).copyWith(height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buildApplyAgainButton(app, provider),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplyAgainButton(
    VerificationApplication app,
    VerificationProvider provider,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isNavigatingToReapply
            ? null
            : () => _handleApplyAgain(app, provider),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.6),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: _isNavigatingToReapply
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.refresh_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Apply Again',
                    style: text14(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _handleApplyAgain(
    VerificationApplication app,
    VerificationProvider provider,
  ) async {
    if (_isNavigatingToReapply) return;

    setState(() {
      _isNavigatingToReapply = true;
    });

    try {
      if (provider.orangetickPlans.isEmpty && !provider.isFetchingPlans) {
        await provider.fetchOrangetickPlans(forceRefresh: true);
      }

      if (!mounted) return;

      Plan? selectedPlan;
      if (app.plan != null && app.plan!.id != null) {
        selectedPlan = app.plan;
      } else if (app.planId != null && app.planId!.isNotEmpty) {
        selectedPlan = provider.orangetickPlans.cast<Plan?>().firstWhere(
              (p) => p?.id == app.planId,
              orElse: () => null,
            );
      }

      if (selectedPlan == null && provider.orangetickPlans.isNotEmpty) {
        selectedPlan = provider.orangetickPlans.firstWhere(
          (p) => p.isActive == true,
          orElse: () => provider.orangetickPlans.first,
        );
      }

      final rawPlan = selectedPlan ??
          Plan(
            id: app.planId,
            name: 'Orange Tick Plan',
          );

      final planToUse = Plan(
        id: rawPlan.id ?? app.planId,
        name: rawPlan.name ?? 'Orange Tick Plan',
        category: rawPlan.category ?? 'orange_tick',
        planCategory: rawPlan.planCategory ?? 'orange_tick',
        planType: rawPlan.planType ?? 'creator_verification',
        duration: rawPlan.duration ?? 30,
        price: rawPlan.price,
        appleProductId: (rawPlan.appleProductId != null &&
                rawPlan.appleProductId!.isNotEmpty)
            ? rawPlan.appleProductId
            : orangeTickProductId,
        isRecommended: rawPlan.isRecommended,
        isActive: rawPlan.isActive,
        features: rawPlan.features,
      );

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => VerificationFormScreen(
            plan: planToUse,
            existingApplication: app,
            isReapplication: true,
          ),
        ),
      );

      if (mounted && context.mounted) {
        await provider.fetchVerificationStatus(forceRefresh: true);
      }
    } catch (e) {
      debugPrint('[ORANGE_TICK_FLOW] Error navigating to reapply form: $e');
      if (mounted && context.mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          SnackBar(
            content: Text('Failed to load application form: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNavigatingToReapply = false;
        });
      }
    }
  }

  Widget _buildStatusCard(String status) {
    final lowerStatus = status.toLowerCase();
    final bool isApproved =
        lowerStatus == 'approved' ||
        lowerStatus == 'verified' ||
        lowerStatus == 'active';
    final bool isRejected = lowerStatus == 'rejected';
    final bool isCancelled =
        lowerStatus == 'cancelled' ||
        lowerStatus == 'canceled' ||
        lowerStatus == 'admin_cancelled' ||
        lowerStatus == 'admin_canceled' ||
        lowerStatus == 'closed';

    final Color statusColor = isApproved
        ? AppColors.success
        : isRejected
            ? AppColors.error
            : isCancelled
                ? const Color(0xFFE05638)
                : AppColors.primary;

    final IconData statusIcon = isApproved
        ? Icons.verified_rounded
        : isRejected
            ? Icons.cancel_outlined
            : isCancelled
                ? Icons.highlight_off_rounded
                : Icons.hourglass_top_rounded;

    final String statusTitle = isApproved
        ? 'Application Approved'
        : isRejected
            ? 'Application Rejected'
            : isCancelled
                ? 'Application Cancelled'
                : 'Application Under Review';

    final String statusMessage = isApproved
        ? 'Your verification application has been approved. You are now a verified Orange Tick creator.'
        : isRejected
            ? 'Your verification request was not approved.'
            : isCancelled
                ? 'Your verification request was cancelled by the administrator.'
                : 'Your verification application has been submitted and is awaiting review.';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 28),
          ),
          const SizedBox(height: 14),
          Text(
            statusTitle,
            textAlign: TextAlign.center,
            style: text18(color: statusColor, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            statusMessage,
            textAlign: TextAlign.center,
            style: text13(color: AppColors.textSecondary).copyWith(height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard({
    required String fullName,
    required String idType,
    required String planName,
    required String appliedOn,
    required String status,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.grey200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.grey100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'Application Details',
                style: text15(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Divider(height: 1, color: AppColors.grey200),
          const SizedBox(height: 14),
          _buildDetailRow('Full Name', fullName),
          const SizedBox(height: 12),
          _buildDetailRow('ID Type', idType),
          const SizedBox(height: 12),
          _buildDetailRow('Plan', planName),
          const SizedBox(height: 12),
          _buildDetailRow('Applied On', appliedOn),
          const SizedBox(height: 12),
          _buildDetailRow('Status', _resolveDisplayStatus(status)),
        ],
      ),
    );
  }

  String _resolveDisplayStatus(String status) {
    final lower = status.toLowerCase();
    if (lower == 'approved' || lower == 'verified' || lower == 'active') {
      return 'Approved';
    }
    if (lower == 'pending' ||
        lower == 'under_review' ||
        lower == 'in_review' ||
        lower == 'processing') {
      return 'Under Review';
    }
    if (lower == 'rejected') {
      return 'Rejected';
    }
    if (lower == 'cancelled' ||
        lower == 'canceled' ||
        lower == 'admin_cancelled' ||
        lower == 'admin_canceled' ||
        lower == 'closed') {
      return 'Cancelled by Admin';
    }
    return status;
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: text13(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: text14(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReviewNoticeCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.grey200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: AppColors.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Our verification team reviews applications within 24–48 hours. You will receive an update once the review is complete.',
              style: text12(
                color: AppColors.textSecondary,
              ).copyWith(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  String _resolveFullName(VerificationApplication? app, BuildContext context) {
    if (app?.fullName != null && app!.fullName!.trim().isNotEmpty) {
      return app.fullName!.trim();
    }
    try {
      final profileUser = context.read<ProfileProvider>().user;
      if (profileUser?.name != null && profileUser!.name!.trim().isNotEmpty) {
        return profileUser.name!.trim();
      }
    } catch (_) {}
    if (app?.username != null && app!.username!.trim().isNotEmpty) {
      return app.username!.trim();
    }
    return '—';
  }

  String _resolveIdType(String? rawType) {
    if (rawType == null || rawType.trim().isEmpty) return '—';
    final trimmed = rawType.trim();
    final lower = trimmed.toLowerCase();
    if (lower == 'aadhaar' || lower == 'aadhar') return 'Aadhaar';
    if (lower == 'passport') return 'Passport';
    if (lower == 'driving license' ||
        lower == 'driving_license' ||
        lower == 'drivinglicense' ||
        lower == 'dl') {
      return 'Driving License';
    }
    if (lower == 'pan' || lower == 'pan_card' || lower == 'pancard') {
      return 'PAN';
    }
    if (lower == 'voter_id' || lower == 'voterid') {
      return 'Voter ID';
    }
    return trimmed
        .split(RegExp(r'[_\s-]+'))
        .where((w) => w.isNotEmpty)
        .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  String _resolvePlanName(
    VerificationApplication? app,
    VerificationProvider provider,
  ) {
    if (app?.plan?.name != null && app!.plan!.name!.trim().isNotEmpty) {
      return app.plan!.name!.trim();
    }
    final planId = app?.planId ?? app?.plan?.id;
    if (planId != null &&
        planId.trim().isNotEmpty &&
        provider.orangetickPlans.isNotEmpty) {
      final foundPlan = provider.orangetickPlans.cast<Plan?>().firstWhere(
        (p) => p?.id == planId,
        orElse: () => null,
      );
      if (foundPlan?.name != null && foundPlan!.name!.trim().isNotEmpty) {
        return foundPlan.name!.trim();
      }
    }
    return '—';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.trim().isEmpty) return '—';
    try {
      final date = DateTime.parse(dateStr.trim()).toLocal();
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final day = date.day.toString().padLeft(2, '0');
      final month = months[date.month - 1];
      final year = date.year;
      return '$day $month $year';
    } catch (_) {
      return dateStr.trim();
    }
  }
}
