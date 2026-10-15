import 'package:catch_watch/res/app_colors.dart';
import 'package:catch_watch/utils/text_style.dart';
import 'package:flutter/material.dart';

/// Shows a confirmation dialog before blocking a user.
///
/// Returns `true` if the block operation completed successfully, or `false`/`null` if cancelled.
Future<bool?> showBlockConfirmationDialog({
  required BuildContext context,
  required String userId,
  String? username,
  String? name,
  required Future<bool> Function() onConfirmBlock,
}) {
  final String displayHandle = (username != null && username.trim().isNotEmpty)
      ? (username.trim().startsWith('@') ? username.trim() : '@${username.trim()}')
      : ((name != null && name.trim().isNotEmpty) ? name.trim() : 'this user');

  bool isSubmitting = false;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Block $displayHandle?',
              style: text18(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'You will no longer see this user\'s content. You and this user will unfollow each other.',
              style: text14(color: Colors.white70),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white60,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          final success = await onConfirmBlock();
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, success);
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setState(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.error.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Block', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}

/// Shows a confirmation dialog before unblocking a user.
///
/// Returns `true` if the unblock operation completed successfully, or `false`/`null` if cancelled.
Future<bool?> showUnblockConfirmationDialog({
  required BuildContext context,
  required String userId,
  String? username,
  String? name,
  required Future<bool> Function() onConfirmUnblock,
}) {
  final String displayHandle = (username != null && username.trim().isNotEmpty)
      ? (username.trim().startsWith('@') ? username.trim() : '@${username.trim()}')
      : ((name != null && name.trim().isNotEmpty) ? name.trim() : 'this user');

  bool isSubmitting = false;

  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogCtx) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: const Color(0xFF222222),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              'Unblock $displayHandle?',
              style: text18(color: Colors.white, fontWeight: FontWeight.bold),
            ),
            content: Text(
              'They will be able to see your content and follow you. Catch&Watch won\'t notify them that you unblocked them.',
              style: text14(color: Colors.white70),
            ),
            actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            actions: [
              TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(dialogCtx, false),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white60,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () async {
                        setState(() => isSubmitting = true);
                        try {
                          final success = await onConfirmUnblock();
                          if (dialogCtx.mounted) {
                            Navigator.pop(dialogCtx, success);
                          }
                        } catch (e) {
                          if (dialogCtx.mounted) {
                            setState(() => isSubmitting = false);
                          }
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Unblock', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      );
    },
  );
}
