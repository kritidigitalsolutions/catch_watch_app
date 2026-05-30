import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

enum PlanType { monthly, quarterly, yearly }

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  PlanType? _expandedPlan = PlanType.quarterly;

  final List<_Plan> _plans = const [
    _Plan(type: PlanType.monthly, name: 'Monthly', price: '₹ 149', duration: '1 month',
        badge: null),
    _Plan(type: PlanType.quarterly, name: 'Quarterly', price: '₹ 349', duration: '3 months',
        badge: 'POPULAR'),
    _Plan(type: PlanType.yearly, name: 'Yearly', price: '₹ 1500', duration: '12 months',
        badge: 'BEST VALUE'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _buildTopBar(context),
          _buildSearchBar(),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _plans.length,
              itemBuilder: (_, i) => _buildPlanCard(_plans[i]),
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
        left: 16, right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          _glassBtn(Icons.arrow_back_ios_new_rounded, () => Navigator.pop(context)),
          const SizedBox(width: 12),
          Text('Choose a Plan',
              style: text18(color: Colors.white, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }

  Widget _glassBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 16),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.grey50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.grey200, width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppColors.grey400, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Search plans...',
                style: text14(color: AppColors.hintText)),
          ),
          const Icon(Icons.mic_rounded, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }

  Widget _buildPlanCard(_Plan plan) {
    final isOpen = _expandedPlan == plan.type;

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
                _expandedPlan = isOpen ? null : plan.type;
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Text(plan.name,
                        style: text16(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w800,
                        )),
                    if (plan.badge != null) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(plan.badge!,
                            style: text10(color: Colors.white, fontWeight: FontWeight.w800)),
                      ),
                    ],
                    const Spacer(),
                    Text(plan.price,
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
              secondChild: _buildPlanBody(plan),
              crossFadeState:
              isOpen ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlanBody(_Plan plan) {
    final features = [
      (Icons.hd_rounded, 'HD Streaming'),
      (Icons.download_rounded, 'Offline Download'),
      (Icons.devices_rounded, '2 Screens'),
      (Icons.block_rounded, 'Ad Free'),
    ];

    return Container(
      color: const Color(0xFFFFF5F0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      child: Column(
        children: [
          // Features grid
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 4.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: features.map((f) => Row(
              children: [
                Icon(f.$1, color: AppColors.primary, size: 17),
                const SizedBox(width: 6),
                Text(f.$2,
                    style: text12(
                      color: const Color(0xFF993C1D),
                      fontWeight: FontWeight.w700,
                    )),
              ],
            )).toList(),
          ),
          const SizedBox(height: 10),
          Text(
            'For more support call +91 1234567890',
            style: text11(color: const Color(0xFFCC4400)),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {

              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text('Subscribe Now',
                  style: text14(color: Colors.white, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

class _Plan {
  final PlanType type;
  final String name;
  final String price;
  final String duration;
  final String? badge;
  const _Plan({
    required this.type, required this.name, required this.price,
    required this.duration, required this.badge,
  });
}