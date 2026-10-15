import 'package:catch_watch/models/legal_model.dart';
import 'package:catch_watch/view_model/after_login_provider/legal_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:provider/provider.dart';

import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';

class PolicyScreen extends StatefulWidget {
  final String type;
  const PolicyScreen({super.key, required this.type});

  @override
  State<PolicyScreen> createState() => _PolicyScreenState();
}

class _PolicyScreenState extends State<PolicyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LegalProvider>().fetchLegalDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<LegalProvider>();
    final serverDoc = provider.getDocumentByType(widget.type);
    final doc = serverDoc ?? (provider.isLoading ? null : _getFallbackDocument(widget.type));

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildHeader(context, doc?.title?.toUpperCase() ?? _getDefaultTitle().toUpperCase()),
          Expanded(
            child: (provider.isLoading && doc == null)
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : doc == null
                    ? const Center(child: Text('Document not found'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildUpdatedCard(doc.updatedAt),
                            const SizedBox(height: 24),
                            if (doc.sections != null && doc.sections!.isNotEmpty)
                              ...doc.sections!.map((section) => _buildSection(section))
                            else
                              HtmlWidget(
                                doc.content ?? '',
                                textStyle: text14(color: AppColors.textSecondary),
                              ),
                            const SizedBox(height: 32),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.grey50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.grey200),
                              ),
                              child: Text(
                                'For questions about this policy, contact support@catchwatch.com.',
                                style: text13(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(LegalSection section) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.heading != null && section.heading!.isNotEmpty) ...[
            Text(
              section.heading!,
              style: text16(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
          ],
          if (section.paragraphs != null)
            ...section.paragraphs!.map((p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: HtmlWidget(
                    p,
                    textStyle: text14(color: AppColors.textSecondary),
                  ),
                )),
        ],
      ),
    );
  }

  String _getDefaultTitle() {
    final lower = widget.type.toLowerCase();
    if (lower.contains('privacy')) {
      return 'Privacy Policy';
    } else if (lower.contains('term')) {
      return 'Terms of Service';
    } else if (lower.contains('refund')) {
      return 'Refund Policy';
    }
    return 'Legal';
  }

  LegalDocument? _getFallbackDocument(String type) {
    final lower = type.toLowerCase();
    if (lower.contains('term')) {
      return LegalDocument(
        type: 'terms-conditions',
        title: 'Terms of Service',
        updatedAt: '2025-01-01T00:00:00.000Z',
        sections: [
          LegalSection(
            heading: '1. Acceptance of Terms',
            paragraphs: [
              'By accessing, downloading, or using Catch & Watch, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the application.',
            ],
          ),
          LegalSection(
            heading: '2. User Accounts & Eligibility',
            paragraphs: [
              'You must be at least 13 years old to use Catch & Watch. You are responsible for safeguarding your login credentials and for all activities that occur under your account. You agree to provide accurate and current information when registering.',
            ],
          ),
          LegalSection(
            heading: '3. Content & Acceptable Use',
            paragraphs: [
              'Catch & Watch allows users to watch stories, short films, and upload user-generated content. There is zero tolerance for objectionable, harmful, or abusive content. Users strictly agree not to upload, share, or transmit content that is unlawful, defamatory, obscene, sexually explicit, harassing, hateful, violent, infringing on intellectual property, or abusive.',
            ],
          ),
          LegalSection(
            heading: '4. Intellectual Property',
            paragraphs: [
              'All trademarks, logos, service marks, and content created by Catch & Watch remain the property of Catch & Watch and its licensors. You may not copy, reproduce, or distribute any part of the service without explicit permission.',
            ],
          ),
          LegalSection(
            heading: '5. Account Suspension & Termination',
            paragraphs: [
              'Catch & Watch enforces zero tolerance for abusive users. We reserve the right to immediately remove objectionable content and suspend or permanently terminate the account of any user who violates these terms or engages in abusive, harassing, or prohibited behavior.',
            ],
          ),
          LegalSection(
            heading: '6. Changes to Terms',
            paragraphs: [
              'We may modify these Terms of Service periodically. Your continued use of the Catch & Watch platform constitutes acceptance of any modified terms.',
            ],
          ),
        ],
      );
    } else if (lower.contains('privacy')) {
      return LegalDocument(
        type: 'privacy-policy',
        title: 'Privacy Policy',
        updatedAt: '2025-01-01T00:00:00.000Z',
        sections: [
          LegalSection(
            heading: '1. Information We Collect',
            paragraphs: [
              'We collect information required to operate and enhance our services, including: your phone number for authentication, user profile information (display name, username, profile photo), content preferences, and device information for security and push notifications.',
            ],
          ),
          LegalSection(
            heading: '2. How We Use Information',
            paragraphs: [
              'Your data is used to verify your identity via OTP, personalize your entertainment feed, enable messaging and calling features, manage subscriptions, and ensure the safety and integrity of our community.',
            ],
          ),
          LegalSection(
            heading: '3. Data Security & Encryption',
            paragraphs: [
              'We implement industry-standard encryption protocols and security measures to protect your personal data against unauthorized access, loss, or disclosure.',
            ],
          ),
          LegalSection(
            heading: '4. Sharing of Information',
            paragraphs: [
              'We do not sell, rent, or trade your personal information to third parties. Information may only be disclosed if required by law or in emergency situations to protect safety.',
            ],
          ),
          LegalSection(
            heading: '5. Account Deletion & Your Rights',
            paragraphs: [
              'You have full control over your data. You may request account deletion at any time directly through your Profile settings. Deleting your account permanently clears your profile, history, and uploaded content.',
            ],
          ),
          LegalSection(
            heading: '6. Contacting Us',
            paragraphs: [
              'For any questions or privacy inquiries, please contact us at support@catchwatch.com.',
            ],
          ),
        ],
      );
    } else if (lower.contains('refund')) {
      return LegalDocument(
        type: 'refund-policy',
        title: 'Refund Policy',
        updatedAt: '2025-01-01T00:00:00.000Z',
        sections: [
          LegalSection(
            heading: '1. Subscription Billing',
            paragraphs: [
              'Subscriptions are billed according to your selected billing cycle. You may cancel your subscription at any time through your account settings.',
            ],
          ),
          LegalSection(
            heading: '2. Refund Requests',
            paragraphs: [
              'Refunds are processed in accordance with applicable store policies and evaluated on a case-by-case basis. Contact support@catchwatch.com for billing support.',
            ],
          ),
        ],
      );
    }
    return null;
  }

  Widget _buildHeader(BuildContext context, String title) {
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: text20(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Legal Information & Policies',
                  style: text14(color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdatedCard(String? updatedAt) {
    String date = 'Recently';
    if (updatedAt != null) {
      try {
        final dateTime = DateTime.parse(updatedAt);
        final months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        date = "${dateTime.day} ${months[dateTime.month - 1]} ${dateTime.year}";
      } catch (e) {}
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.update_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Last updated',
                  style: text13(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(date, style: text12(color: AppColors.grey600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
