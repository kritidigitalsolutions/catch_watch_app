import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../res/app_colors.dart';
import '../../../utils/text_style.dart';
import '../../../view_model/after_login_provider/profile_provider.dart';
import '../../../view_model/before_login_provider/auth_providers.dart';

/// Displays the two-step confirmation flow for deleting the user's account.
void showDeleteAccountDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => DeleteAccountDialog(parentContext: context),
  );
}

class DeleteAccountDialog extends StatefulWidget {
  final BuildContext? parentContext;
  const DeleteAccountDialog({super.key, this.parentContext});

  @override
  State<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends State<DeleteAccountDialog> {
  int _currentStep = 1;
  String? _selectedReason;
  late final TextEditingController _otherReasonController;

  static const List<String> _reasons = [
    'I no longer use Catch & Watch',
    'I have privacy concerns',
    'I\'m facing technical issues',
    'I don\'t like the app',
    'I found another app',
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _otherReasonController = TextEditingController();
  }

  @override
  void dispose() {
    _otherReasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ProfileProvider>(
      builder: (dialogCtx, profileProvider, _) {
        final isDeleting = profileProvider.isDeletingAccount;
        final effectiveContext = widget.parentContext ?? context;

        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (!isDeleting) {
              if (_currentStep == 2) {
                setState(() => _currentStep = 1);
              } else {
                Navigator.pop(dialogCtx);
              }
            }
          },
          child: AlertDialog(
            backgroundColor: AppColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            contentPadding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            content: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.75,
              ),
              child: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: _currentStep == 1
                      ? _buildStep1(dialogCtx)
                      : _buildStep2(isDeleting),
                ),
              ),
            ),
            actions: _currentStep == 1
                ? _buildStep1Actions(dialogCtx)
                : _buildStep2Actions(dialogCtx, profileProvider, effectiveContext),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // STEP 1 — Deletion Reason Popup
  // ---------------------------------------------------------------------------
  Widget _buildStep1(BuildContext dialogCtx) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Why are you leaving?',
          style: text18(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Help us improve Catch & Watch. (Optional)',
          style: text12(
            color: AppColors.textSecondary,
          ),
        ),
        const SizedBox(height: 14),
        ..._reasons.map((reason) => _buildReasonOption(reason)),
        if (_selectedReason == 'Other') ...[
          const SizedBox(height: 4),
          TextField(
            controller: _otherReasonController,
            maxLines: 2,
            minLines: 1,
            style: text12(color: AppColors.textPrimary),
            decoration: InputDecoration(
              hintText: 'Please tell us why',
              hintStyle: text12(color: AppColors.hintText),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              filled: true,
              fillColor: AppColors.grey50,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.grey200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ],
    );
  }

  Widget _buildReasonOption(String reason) {
    final isSelected = _selectedReason == reason;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () {
          setState(() {
            if (_selectedReason == reason) {
              _selectedReason = null;
            } else {
              _selectedReason = reason;
            }
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFFFF0E8) : AppColors.grey50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.grey200,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                size: 16,
                color: isSelected ? AppColors.primary : AppColors.grey400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  reason,
                  style: text12(
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStep1Actions(BuildContext dialogCtx) {
    return [
      TextButton(
        onPressed: () => Navigator.pop(dialogCtx),
        child: Text(
          'Cancel',
          style: text14(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ElevatedButton(
        onPressed: () {
          setState(() {
            _currentStep = 2;
          });
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        ),
        child: Text(
          'Continue',
          style: text14(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // STEP 2 — Final Delete Confirmation Popup
  // ---------------------------------------------------------------------------
  Widget _buildStep2(bool isDeleting) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            GestureDetector(
              onTap: isDeleting ? null : () => setState(() => _currentStep = 1),
              child: const Padding(
                padding: EdgeInsets.only(right: 8),
                child: Icon(
                  Icons.arrow_back_rounded,
                  size: 20,
                  color: AppColors.grey600,
                ),
              ),
            ),
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF0F0),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.error,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Delete Account',
                style: text18(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Are you sure you want to delete your account? This action is permanent and cannot be undone.',
          style: text13(
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.grey50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.grey200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What will be deleted',
                style: text12(
                  color: AppColors.grey800,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _bulletPoint('Your profile and uploaded content'),
              _bulletPoint('Watch history, bookmarks and likes'),
              _bulletPoint('Other account-related data as applicable'),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStep2Actions(
    BuildContext dialogCtx,
    ProfileProvider profileProvider,
    BuildContext effectiveContext,
  ) {
    final isDeleting = profileProvider.isDeletingAccount;
    return [
      TextButton(
        onPressed: isDeleting ? null : () => Navigator.pop(dialogCtx),
        child: Text(
          'Cancel',
          style: text14(
            color: isDeleting ? AppColors.grey400 : AppColors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      ElevatedButton(
        onPressed: isDeleting
            ? null
            : () async {
                final scaffoldMessenger = ScaffoldMessenger.of(effectiveContext);
                final navigator = Navigator.of(effectiveContext);

                final String? reason = _selectedReason;
                final String? reasonDetails = (_selectedReason == 'Other')
                    ? _otherReasonController.text.trim()
                    : null;

                final success = await profileProvider.deleteAccount(
                  reason: reason,
                  reasonDetails: reasonDetails,
                  context: effectiveContext,
                );

                if (dialogCtx.mounted) {
                  Navigator.pop(dialogCtx);
                }

                if (success) {
                  if (effectiveContext.mounted) {
                    try {
                      Provider.of<AuthProvider>(effectiveContext, listen: false)
                          .resetAuthState(clearPhone: true);
                    } catch (e) {
                      debugPrint('Error resetting AuthProvider during deleteAccount: $e');
                    }
                  }
                  navigator.pushNamedAndRemoveUntil(
                    '/login',
                    (route) => false,
                  );
                  scaffoldMessenger.showSnackBar(
                    const SnackBar(
                      content: Text('Account deleted successfully.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                } else {
                  scaffoldMessenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        profileProvider.deleteAccountError ??
                            'Unable to delete your account right now. Please try again.',
                      ),
                      backgroundColor: AppColors.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.error,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.error.withOpacity(0.5),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
        child: isDeleting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                'Delete Account',
                style: text14(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    ];
  }

  static Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ', style: TextStyle(color: AppColors.grey600, fontSize: 12)),
          Expanded(
            child: Text(
              text,
              style: text11(color: AppColors.grey600),
            ),
          ),
        ],
      ),
    );
  }
}
