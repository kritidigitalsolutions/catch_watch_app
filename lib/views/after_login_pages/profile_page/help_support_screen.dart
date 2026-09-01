import 'package:catch_watch/view_model/after_login_provider/help_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/profile_provider.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/vip_support/vip_support_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  int? _expandedFaqIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HelpProvider>().fetchHelpData();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<HelpProvider>();

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: provider.fetchHelpData,
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          _buildContactRow(provider),
                          const SizedBox(height: 24),
                          _buildFaqSection(provider),
                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        bottom: 15,
        left: 16,
        right: 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF5F00), Color(0xFFCC3D00)],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Help & Support',
                style: text24(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                'How can we help you today?',
                style: text14(color: Colors.white70),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(HelpProvider provider) {
    final profileProvider = context.watch<ProfileProvider>();
    final verificationProvider = context.watch<VerificationProvider>();
    final isVerified = verificationProvider.currentApplication?.status == 'approved' || 
                       profileProvider.user?.isVerified == true || 
                       profileProvider.user?.blueTick == true;

    // Manually add Live Chat as instructed not to change it
    final List<Map<String, dynamic>> staticOptions = [
      {
        'icon': Icons.chat_bubble_outline_rounded,
        'title': 'Live Chat',
        'badge': 'Online',
        'badgeColor': AppColors.success,
        'onTap': () {},
      },
      if (isVerified)
        {
          'icon': Icons.support_agent_rounded,
          'title': 'VIP Support',
          'badge': 'Priority',
          'badgeColor': AppColors.primary,
          'onTap': () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const VipSupportScreen(),
              ),
            );
          },
        },
    ];

    // Map support items from API
    final List<Map<String, dynamic>> apiOptions = provider.supportItems.map((item) {
      bool isEmail = item.question?.toLowerCase().contains('email') ?? false;
      String contactInfo = isEmail ? (item.answer ?? '') : (item.supportNumber ?? '');
      
      return {
        'icon': isEmail ? Icons.mail_outline_rounded : Icons.phone_outlined,
        'title': item.question ?? '',
        'badge': contactInfo, // Show actual email or phone number here
        'badgeColor': isEmail ? AppColors.info : AppColors.warning,
        'onTap': () {
          if (isEmail) {
            provider.launchEmail(contactInfo);
          } else {
            provider.launchPhone(contactInfo);
          }
        },
      };
    }).toList();

    final allOptions = [...staticOptions, ...apiOptions];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Contact Us',
            style: text16(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: allOptions.length,
          separatorBuilder: (_, _) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final item = allOptions[index];
            return GestureDetector(
              onTap: item['onTap'],
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.grey200, width: 0.8),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        item['icon'] as IconData,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item['title'],
                            style: text14(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['badge'],
                            style: text12(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: AppColors.grey400,
                      size: 14,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFaqSection(HelpProvider provider) {
    if (provider.faqItems.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'Frequently Asked',
            style: text16(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...List.generate(provider.faqItems.length, (index) {
          final item = provider.faqItems[index];
          final isExpanded = _expandedFaqIndex == index;
          return GestureDetector(
            onTap: () {
              setState(() {
                _expandedFaqIndex = isExpanded ? null : index;
              });
            },
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              decoration: BoxDecoration(
                color: isExpanded ? const Color(0xFFFFF5F0) : AppColors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isExpanded
                      ? AppColors.primary.withOpacity(0.3)
                      : AppColors.grey200,
                  width: isExpanded ? 1.0 : 0.8,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.question ?? '',
                            style: text14(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.remove_rounded : Icons.add_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 10),
                      const Divider(color: AppColors.grey200, height: 1),
                      const SizedBox(height: 10),
                      Text(
                        item.answer ?? '',
                        style: text13(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}
