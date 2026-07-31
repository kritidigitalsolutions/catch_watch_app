import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/verification_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'verification_form_screen.dart';

class VerificationStatusScreen extends StatelessWidget {
  const VerificationStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VerificationProvider>();
    final app = provider.currentApplication;

    if (app == null) return const SizedBox();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('Verification Status', style: text18(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildStatusCard(app.status ?? 'pending'),
            const SizedBox(height: 32),
            _buildInfoRow('Full Name', app.fullName ?? '-'),
            _buildInfoRow('ID Type', app.governmentIdType ?? '-'),
            _buildInfoRow('Plan', app.plan?.name ?? '-'),
            _buildInfoRow('Applied On', _formatDate(app.createdAt)),
            const SizedBox(height: 40),
            
            if (app.status == 'pending') ...[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (app.plan != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => VerificationFormScreen(
                            plan: app.plan!,
                            existingApplication: app,
                          ),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Update Details', style: text14(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => _showCancelDialog(context, provider),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: Text('Cancel Request', style: text14(color: AppColors.error, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
            
            if (app.status == 'approved')
              Text(
                'Congratulations! You are now a verified user.',
                textAlign: TextAlign.center,
                style: text14(color: Colors.green, fontWeight: FontWeight.bold),
              ),
              
            if (app.status == 'rejected')
              Column(
                children: [
                  Text(
                    'Your application was rejected.',
                    style: text14(color: AppColors.error, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please contact support for more information.',
                    style: text12(color: AppColors.grey600),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusCard(String status) {
    Color color;
    IconData icon;
    String title;
    String message;

    switch (status.toLowerCase()) {
      case 'approved':
        color = Colors.green;
        icon = Icons.verified_rounded;
        title = 'Approved';
        message = 'Your profile is now verified.';
        break;
      case 'rejected':
        color = AppColors.error;
        icon = Icons.error_outline_rounded;
        title = 'Rejected';
        message = 'Your verification request was not approved.';
        break;
      case 'pending':
      default:
        color = Colors.orange;
        icon = Icons.pending_actions_rounded;
        title = 'Pending';
        message = 'Your application is under review.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 60),
          const SizedBox(height: 16),
          Text(title, style: text20(color: color, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center, style: text14(color: AppColors.grey700)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: text14(color: AppColors.grey600)),
          Text(value, style: text14(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  void _showCancelDialog(BuildContext context, VerificationProvider provider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Request'),
        content: const Text('Are you sure you want to cancel your verification request?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final success = await provider.cancelVerification();
              if (success && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Verification request cancelled')),
                );
              }
            },
            child: const Text('Yes, Cancel', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
