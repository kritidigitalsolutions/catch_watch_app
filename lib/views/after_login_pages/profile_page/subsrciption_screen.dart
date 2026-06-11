import 'package:catch_watch/models/plan_model.dart';
import 'package:catch_watch/view_model/after_login_provider/subscription_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? _expandedPlanId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SubscriptionProvider>().fetchPlans();
      context.read<SubscriptionProvider>().fetchSubscriptionStatus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<SubscriptionProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          _buildActiveSubscription(provider),
          Expanded(
            child: provider.isLoading && provider.plans.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text(provider.error!))
                    : RefreshIndicator(
                        onRefresh: () async {
                          await provider.fetchPlans();
                          await provider.fetchSubscriptionStatus();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          itemCount: provider.plans.length,
                          itemBuilder: (_, i) => _buildPlanCard(provider.plans[i], provider),
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
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 14,
        left: 16,
        right: 16,
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
          Text('Choose a Plan', style: text18(color: Colors.white, fontWeight: FontWeight.w800)),
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
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
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
                      final success = await provider.cancelSubscription();
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Subscription Cancelled Successfully')));
                      } else if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(provider.error ?? 'Failed to cancel subscription')));
                      }
                    },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.error),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text('Cancel Plan', style: text12(color: AppColors.error)),
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
            ? (provider.currentSubscription!.plan as Plan).id == plan.id
            : provider.currentSubscription!.plan == plan.id);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      decoration: BoxDecoration(
        border: Border.all(
          color: isOpen ? AppColors.primary : AppColors.grey200,
          width: isOpen ? 1.5 : 0.5,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: Column(
          children: [
            // Header
            InkWell(
              onTap: () => setState(() {
                _expandedPlanId = isOpen ? null : plan.id;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Text(plan.name ?? '',
                        style: text16(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        )),
                    if (plan.isRecommended == true) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text('RECOMMENDED',
                            style: text10(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                    const Spacer(),
                    Text('₹ ${plan.price}',
                        style: text16(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w900,
                        )),
                    const SizedBox(width: 8),
                    AnimatedRotation(
                      turns: isOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 250),
                      child: const Icon(Icons.keyboard_arrow_down_rounded,
                          color: AppColors.grey400, size: 22),
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

  Widget _buildPlanBody(Plan plan, SubscriptionProvider provider, bool isCurrent) {
    return Container(
      color: const Color(0xFFFFF5F0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Features grid
          if (plan.features != null)
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 4.5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              children: plan.features!
                  .map((f) => Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 17),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(f,
                                style: text12(
                                  color: const Color(0xFF993C1D),
                                  fontWeight: FontWeight.w700,
                                )),
                          ),
                        ],
                      ))
                  .toList(),
            ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isCurrent || provider.isLoading
                  ? null
                  : () async {
                      final success = await provider.subscribe(plan.id!);
                      if (success && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Subscribed Successfully!')));
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: isCurrent ? AppColors.grey400 : AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: provider.isLoading
                  ? const SizedBox(
                      width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(isCurrent ? 'Current Plan' : 'Subscribe Now',
                      style: text14(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
