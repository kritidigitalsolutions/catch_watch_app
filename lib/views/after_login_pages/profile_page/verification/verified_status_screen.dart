import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:flutter/material.dart';

class VerifiedStatusScreen extends StatelessWidget {
  const VerifiedStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('Verified Status', style: text18(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildHeader(),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Verification Benefits',
                    style: text18(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'As a verified creator, you now have access to premium features and enhanced security.',
                    style: text14(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  _buildBenefitsList(),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary.withValues(alpha: 0.1),
            AppColors.primary.withValues(alpha: 0.05),
          ],
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(
              Icons.verified_rounded,
              color: AppColors.primary,
              size: 60,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Verified Status Active',
            style: text24(fontWeight: FontWeight.w900, color: AppColors.primary),
          ),
          const SizedBox(height: 8),
          Text(
            'You are a verified user',
            style: text16(color: AppColors.textSecondary, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsList() {
    final benefits = [
      ('Official Verified Badge', 'Show authenticity with the verified badge.', Icons.verified_user_rounded),
      ('Advanced Account Protection', 'Enhanced security for your account data.', Icons.security_rounded),
      ('Fake Account Protection', 'Proactive monitoring for impersonation.', Icons.gpp_good_rounded),
      ('Priority Customer Support', 'Direct access to our specialized VIP team.', Icons.support_agent_rounded),
      ('Higher Search Ranking', 'Appear higher in search results across the app.', Icons.trending_up_rounded),
      ('Better Content Recommendations', 'Optimized algorithm for your posts.', Icons.auto_awesome_rounded),
      ('Highlighted Comments', 'Your comments stand out in every discussion.', Icons.mode_comment_rounded),
      ('Exclusive Creator Tools', 'Access to advanced analytics and insights.', Icons.construction_rounded),
      ('Early Access to New Features', 'Be the first to try upcoming updates.', Icons.rocket_launch_rounded),
    ];

    return Column(
      children: benefits.map((b) => _benefitItem(b.$3, b.$1, b.$2)).toList(),
    );
  }

  Widget _benefitItem(IconData icon, String title, String subtitle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: text15(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: text13(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
