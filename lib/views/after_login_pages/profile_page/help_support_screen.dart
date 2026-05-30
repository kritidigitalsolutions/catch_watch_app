import 'package:flutter/material.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _searchController = TextEditingController();
  int? _expandedFaqIndex;

  final List<Map<String, dynamic>> _faqList = [
    {
      'question': 'How do I cancel my subscription?',
      'answer':
          'You can cancel your subscription anytime from Profile > Subscription > Cancel Plan. Your access continues until the end of the billing period.',
    },
    {
      'question': 'Why is my video not playing?',
      'answer':
          'Check your internet connection. If the issue persists, try clearing the app cache from Settings > App Info > Clear Cache, or reinstall the app.',
    },
    {
      'question': 'Can I download content for offline viewing?',
      'answer':
          'Yes! Premium and Standard plan users can download content. Tap the download icon on any movie or episode page to save it offline.',
    },
    {
      'question': 'How many devices can I use simultaneously?',
      'answer':
          'Basic plan: 1 device. Standard plan: 2 devices. Premium plan: up to 4 devices at the same time.',
    },
    {
      'question': 'How do I change my password?',
      'answer':
          'Go to Profile > Edit Profile > Change Password. You can also reset it from the login screen using "Forgot Password".',
    },
    {
      'question': 'What should I do if a payment fails?',
      'answer':
          'Verify your card details and billing address. Make sure your card is not expired or blocked for online transactions. Contact your bank if the issue continues.',
    },
  ];

  final List<Map<String, dynamic>> _contactOptions = [
    {
      'icon': Icons.chat_bubble_outline_rounded,
      'title': 'Live Chat',
      'subtitle': 'Chat with us now',
      'badge': 'Online',
      'badgeColor': AppColors.success,
    },
    {
      'icon': Icons.mail_outline_rounded,
      'title': 'Email Support',
      'subtitle': 'support@catchwatch.com',
      'badge': '24h reply',
      'badgeColor': AppColors.info,
    },
    {
      'icon': Icons.phone_outlined,
      'title': 'Call Us',
      'subtitle': '+1 800 000 0000',
      'badge': '9AM–6PM',
      'badgeColor': AppColors.warning,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildHeader(context),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _buildContactRow(),
                  const SizedBox(height: 24),
                  // _buildQuickLinks(),
                  // const SizedBox(height: 24),
                  _buildFaqSection(),
                  const SizedBox(height: 32),
                ],
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
          SizedBox(width: 10),
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

  Widget _buildContactRow() {
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
        SizedBox(
          height: 110,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            scrollDirection: Axis.horizontal,
            itemCount: _contactOptions.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final item = _contactOptions[index];
              return GestureDetector(
                onTap: () {},
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.grey200, width: 0.8),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item['icon'] as IconData,
                        color: AppColors.primary,
                        size: 24,
                      ),
                      const Spacer(),
                      Text(
                        item['title'],
                        style: text13(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: (item['badgeColor'] as Color).withOpacity(
                            0.12,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item['badge'],
                          style: text10(
                            color: item['badgeColor'] as Color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Widget _buildQuickLinks() {
  //   final links = [
  //     {'icon': Icons.receipt_long_outlined, 'label': 'Billing'},
  //     {'icon': Icons.play_circle_outline_rounded, 'label': 'Playback'},
  //     {'icon': Icons.account_circle_outlined, 'label': 'Account'},
  //     {'icon': Icons.security_outlined, 'label': 'Privacy'},
  //   ];

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 20),
  //         child: Text(
  //           'Browse Topics',
  //           style: text16(
  //             color: AppColors.textPrimary,
  //             fontWeight: FontWeight.w700,
  //           ),
  //         ),
  //       ),
  //       const SizedBox(height: 12),
  //       Padding(
  //         padding: const EdgeInsets.symmetric(horizontal: 20),
  //         child: Row(
  //           children: links
  //               .map(
  //                 (item) => Expanded(
  //                   child: GestureDetector(
  //                     onTap: () {},
  //                     child: Container(
  //                       margin: EdgeInsets.only(
  //                         right: item == links.last ? 0 : 10,
  //                       ),
  //                       padding: const EdgeInsets.symmetric(vertical: 14),
  //                       decoration: BoxDecoration(
  //                         color: const Color(0xFFFFF5F0),
  //                         borderRadius: BorderRadius.circular(14),
  //                       ),
  //                       child: Column(
  //                         children: [
  //                           Icon(
  //                             item['icon'] as IconData,
  //                             color: AppColors.primary,
  //                             size: 22,
  //                           ),
  //                           const SizedBox(height: 6),
  //                           Text(
  //                             item['label'] as String,
  //                             style: text11(
  //                               color: AppColors.textPrimary,
  //                               fontWeight: FontWeight.w600,
  //                             ),
  //                           ),
  //                         ],
  //                       ),
  //                     ),
  //                   ),
  //                 ),
  //               )
  //               .toList(),
  //         ),
  //       ),
  //     ],
  //   );
  // }

  Widget _buildFaqSection() {
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
        ...List.generate(_faqList.length, (index) {
          final item = _faqList[index];
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
                            item['question'],
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
                        item['answer'],
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
