import 'package:flutter/material.dart';
import '../res/app_colors.dart';
import 'text_style.dart';

/// Reusable empty state widget for content categories and screens.
/// Follows the Catch & Watch design system (soft primary tint, rounded container,
/// clean typography, centered layout, and pull-to-refresh compatibility).
class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final IconData? icon;
  final double iconSize;
  final Widget? action;
  final bool isScrollable;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message = 'No content is available in this category yet.',
    this.icon,
    this.iconSize = 40,
    this.action,
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
            icon ?? Icons.movie_outlined,
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
          Text(
            message!,
            textAlign: TextAlign.center,
            style: text14(
              color: AppColors.textSecondary,
            ),
          ),
        ],
        if (action != null) ...[
          const SizedBox(height: 20),
          action!,
        ],
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
