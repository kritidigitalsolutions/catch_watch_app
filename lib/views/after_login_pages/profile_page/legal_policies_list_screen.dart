import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/legal_provider.dart';
import 'package:catch_watch/views/after_login_pages/profile_page/policy_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LegalPoliciesListScreen extends StatefulWidget {
  const LegalPoliciesListScreen({super.key});

  @override
  State<LegalPoliciesListScreen> createState() => _LegalPoliciesListScreenState();
}

class _LegalPoliciesListScreenState extends State<LegalPoliciesListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LegalProvider>().fetchLegalDocuments();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: AppBar(
        title: Text('Legal Policies', style: text18(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<LegalProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          if (provider.error != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(provider.error!, style: text14(color: AppColors.error)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => provider.fetchLegalDocuments(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (provider.documents.isEmpty) {
            return const Center(child: Text('No policies found.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 16),
            itemCount: provider.documents.length,
            separatorBuilder: (context, index) => const Divider(height: 1, indent: 64),
            itemBuilder: (context, index) {
              final doc = provider.documents[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_outlined, color: AppColors.primary, size: 20),
                ),
                title: Text(
                  doc.title?.toUpperCase() ?? 'POLICY',
                  style: text15(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.grey400),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PolicyScreen(type: doc.type ?? ''),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
