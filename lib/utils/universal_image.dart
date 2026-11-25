import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../res/app_colors.dart';

class UniversalImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;

  const UniversalImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return errorWidget ?? Container(
        width: width,
        height: height,
        color: AppColors.grey800,
        child: const Center(
          child: Icon(Icons.sports_cricket, color: Colors.white, size: 24),
        ),
      );
    }

    // Check if SVG format
    final lowerUrl = url.toLowerCase();
    final isSvg = lowerUrl.endsWith('.svg') || (lowerUrl.contains('.svg') && !lowerUrl.contains('.svg.png') && !lowerUrl.contains('.svg?'));

    if (isSvg) {
      return SvgPicture.network(
        url,
        width: width,
        height: height,
        fit: fit,
        placeholderBuilder: (_) => placeholder ?? Container(
          width: width,
          height: height,
          color: AppColors.grey200,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)),
        ),
        errorBuilder: (_, __, ___) => errorWidget ?? Container(
          width: width,
          height: height,
          color: AppColors.grey800,
          child: const Center(child: Icon(Icons.image_not_supported, color: Colors.white)),
        ),
      );
    }

    // Handles WebP, PNG, JPG, JPEG, GIF, AVIF natively via Image.network
    return Image.network(
      url,
      width: width,
      height: height,
      fit: fit,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return placeholder ?? Container(
          width: width,
          height: height,
          color: AppColors.grey200,
          child: Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / (loadingProgress.expectedTotalBytes ?? 1)
                  : null,
              strokeWidth: 2,
              color: AppColors.primary,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) {
        return errorWidget ?? Container(
          width: width,
          height: height,
          color: AppColors.grey800,
          child: const Center(
            child: Icon(Icons.sports_cricket, color: Colors.white, size: 30),
          ),
        );
      },
    );
  }
}
