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
    final doc = provider.getDocumentByType(widget.type);

    return Scaffold(
      backgroundColor: AppColors.white,
      body: Column(
        children: [
          _buildHeader(context, doc?.title?.toUpperCase() ?? _getDefaultTitle()),
          Expanded(
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.error != null
                    ? Center(child: Text(provider.error!))
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
    switch (widget.type) {
      case 'privacy-policy':
        return 'Privacy Policy';
      case 'terms-conditions':
        return 'Terms & Conditions';
      case 'refund-policy':
        return 'Refund Policy';
      default:
        return 'Legal';
    }
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
