import 'package:catch_watch/models/report_model.dart';
import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/hive_service/hive_service.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:catch_watch/view_model/after_login_provider/report_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// Opens the reusable UGC reporting bottom sheet for a reel, comment, or user profile.
Future<void> showReportBottomSheet(
  BuildContext context, {
  required String targetType,
  required String targetId,
  String? targetTitle,
}) async {
  final trimmedId = targetId.trim();
  if (trimmedId.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cannot report: missing item identifier.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Prevent users from reporting their own profile
  if (targetType.toLowerCase() == 'user' && trimmedId == HiveService.userId) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('You cannot report your own profile.'),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  // Handle unauthenticated users using existing auth flow
  if (!HiveService.isLogin()) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Sign In Required', style: text18(fontWeight: FontWeight.bold)),
        content: Text(
          'You need to be signed in to submit a report. Please sign in to continue.',
          style: text14(color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: text14(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(context, '/login');
            },
            child: Text('Sign In', style: text14(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
    return;
  }

  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (modalCtx) => ReportBottomSheet(
      targetType: targetType,
      targetId: trimmedId,
      targetTitle: targetTitle,
      parentContext: context,
    ),
  );
}

class ReportBottomSheet extends StatefulWidget {
  final String targetType;
  final String targetId;
  final String? targetTitle;
  final BuildContext parentContext;

  const ReportBottomSheet({
    super.key,
    required this.targetType,
    required this.targetId,
    this.targetTitle,
    required this.parentContext,
  });

  @override
  State<ReportBottomSheet> createState() => _ReportBottomSheetState();
}

class _ReportBottomSheetState extends State<ReportBottomSheet> {
  ReportReason? _selectedReason;
  late final TextEditingController _descriptionController;
  String? _localError;

  @override
  void initState() {
    super.initState();
    _descriptionController = TextEditingController();
    // Clear any previous error state on provider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<ReportProvider>().clearState();
      }
    });
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  String _getDefaultTitle(String targetType) {
    switch (targetType.toLowerCase()) {
      case 'reel':
        return 'Report Reel';
      case 'comment':
        return 'Report Comment';
      case 'user':
        return 'Report Profile';
      default:
        return 'Report Content';
    }
  }

  Future<void> _handleSubmit(ReportProvider provider) async {
    if (provider.isSubmitting) return;

    if (_selectedReason == null) {
      setState(() {
        _localError = 'Please select a reason for reporting.';
      });
      return;
    }

    setState(() {
      _localError = null;
    });

    final String? description = _descriptionController.text.trim().isNotEmpty
        ? _descriptionController.text.trim()
        : null;

    final response = await provider.submitReport(
      targetType: widget.targetType,
      targetId: widget.targetId,
      reason: _selectedReason!.apiValue,
      description: description,
    );

    if (!mounted) return;

    if (response != null && response.success) {
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(widget.parentContext).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  response.message,
                  style: text13(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 4),
        ),
      );
    } else {
      // Failure stays open, displays message, allows retrying
      setState(() {
        _localError = provider.errorMessage ?? 'Failed to submit report. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReportProvider>();
    final isSubmitting = provider.isSubmitting;
    final title = widget.targetTitle ?? _getDefaultTitle(widget.targetType);
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.grey300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Header Row
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0E8),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.flag_rounded,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: text18(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Help keep Catch&Watch safe. Select a reason below.',
                            style: text12(color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.grey600),
                      onPressed: isSubmitting ? null : () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              const Divider(color: AppColors.grey200, height: 1),

              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Reason
                      Row(
                        children: [
                          Text(
                            'Reason for reporting',
                            style: text14(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            '*',
                            style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Reasons list
                      ...ReportReason.values.map((reason) {
                        final isSelected = _selectedReason == reason;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: InkWell(
                            onTap: isSubmitting
                                ? null
                                : () {
                                    setState(() {
                                      _selectedReason = reason;
                                      _localError = null;
                                    });
                                  },
                            borderRadius: BorderRadius.circular(12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              decoration: BoxDecoration(
                                color: isSelected ? const Color(0xFFFFF4EE) : AppColors.grey50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : AppColors.grey200,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 20,
                                    height: 20,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected ? AppColors.primary : AppColors.grey400,
                                        width: 2,
                                      ),
                                      color: isSelected ? AppColors.primary : Colors.transparent,
                                    ),
                                    child: isSelected
                                        ? const Center(
                                            child: Icon(Icons.check, size: 14, color: Colors.white),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      reason.label,
                                      style: text14(
                                        color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 14),

                      // Section: Description (Optional)
                      Text(
                        'Additional details (optional)',
                        style: text14(
                          color: AppColors.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Provide any additional context to assist our moderation team.',
                        style: text12(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 3,
                        enabled: !isSubmitting,
                        style: text13(color: AppColors.textPrimary),
                        decoration: InputDecoration(
                          hintText: 'Describe why this content violates guidelines...',
                          hintStyle: text13(color: AppColors.hintText),
                          filled: true,
                          fillColor: AppColors.grey50,
                          contentPadding: const EdgeInsets.all(12),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.grey200),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.grey200),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                          ),
                        ),
                      ),

                      // Inline Error display if failed
                      if (_localError != null || provider.errorMessage != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF0F0),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.error.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _localError ?? provider.errorMessage ?? '',
                                  style: text12(color: AppColors.error, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(color: AppColors.grey200, height: 1),

              // Bottom Actions Row
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: OutlinedButton(
                        onPressed: isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: const BorderSide(color: AppColors.grey300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          'Cancel',
                          style: text14(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: (_selectedReason == null || isSubmitting)
                            ? null
                            : () => _handleSubmit(provider),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withOpacity(0.4),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(
                                'Submit Report',
                                style: text14(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
