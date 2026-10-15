import 'package:flutter/material.dart';
import '../res/app_colors.dart';
import 'custom_button.dart';
import 'text_style.dart';

/// Reusable error state widget for Catch & Watch screens.
/// Features a centered layout, soft tint container, error/offline icon,
/// user-friendly messaging, and an actionable Retry button with loading state.
class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final VoidCallback onRetry;
  final bool isLoading;
  final IconData? icon;
  final double iconSize;
  final bool isScrollable;

  const ErrorStateWidget({
    super.key,
    this.title = 'Unable to load content',
    this.message = 'Please check your internet connection and try again.',
    required this.onRetry,
    this.isLoading = false,
    this.icon,
    this.iconSize = 40,
    this.isScrollable = true,
  });

  @override
  Widget build(BuildContext context) {
    final content = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF0E8),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            icon ?? Icons.cloud_off_rounded,
            color: AppColors.primary,
            size: iconSize,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: text18(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (message != null && message!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              message!,
              textAlign: TextAlign.center,
              style: text14(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: 150,
          child: AppButton(
            title: 'Retry',
            isLoading: isLoading,
            onTap: isLoading ? null : onRetry,
          ),
        ),
      ],
    );

    if (!isScrollable) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Center(child: content),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final double minHeight = constraints.hasBoundedHeight ? constraints.maxHeight : 300.0;
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (minHeight - 64).clamp(100.0, double.infinity),
            ),
            child: Center(child: content),
          ),
        );
      },
    );
  }
}
