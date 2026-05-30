import 'package:catch_watch/utils/text_style.dart';
import 'package:flutter/material.dart';

import '../res/app_colors.dart';

class AppButton extends StatelessWidget {
  final String title;
  final VoidCallback? onTap;
  final bool isLoading;
  final Color? color;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  const AppButton({
    super.key,
    required this.title,
    this.onTap,
    this.isLoading = false,
    this.color,
    this.height = 45,
    this.radius = 30,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color ?? AppColors.button,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: isLoading
            ? SizedBox(
          width: 22,
          height: 22,
          child: const CircularProgressIndicator(
            strokeWidth: 1,
            color: AppColors.white,
          ),
        )
            : Text(
          title,
          style:
          textStyle ??
              text15(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class AppOutlineButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  const AppOutlineButton({
    super.key,
    required this.title,
    required this.onTap,
    this.color,
    this.height = 45,
    this.radius = 30,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.button),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Text(
          title,
          style:
          textStyle ??
              text14(color: AppColors.button, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class CustomElevatedButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final bool isLoading;
  final Color? color;
  final double height;
  final double radius;
  final TextStyle? textStyle;

  const CustomElevatedButton({
    super.key,
    required this.title,
    required this.onTap,
    this.isLoading = false,
    this.color,
    this.height = 50,
    this.radius = 30,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          backgroundColor: color ?? AppColors.button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          elevation: 2,
        ),
        child: isLoading
            ? const SizedBox(
          height: 22,
          width: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Colors.white,
          ),
        )
            : Text(
          title,
          style:
          textStyle ??
              text15(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class CustomElevatedIconButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? backgroundColor;
  final Color? textColor;
  final double borderRadius;
  final double height;
  final double iconSize;
  final EdgeInsetsGeometry padding;
  final TextStyle? textStyle;

  const CustomElevatedIconButton({
    super.key,
    required this.text,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.textColor,
    this.borderRadius = 30,
    this.height = 45,
    this.iconSize = 20,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 10),
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: iconSize, color: textColor ?? AppColors.white),
        label: Text(
          text,
          style:
          textStyle ??
              text15(color: AppColors.white, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor ?? AppColors.button,
          padding: padding,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(borderRadius),
          ),
          elevation: 2,
        ),
      ),
    );
  }
}

class CustomTextButton extends StatelessWidget {
  final String title;
  final VoidCallback onTap;
  final TextStyle? textStyle;
  // 🧱 Layout options
  final EdgeInsetsGeometry padding;
  final Alignment alignment;

  const CustomTextButton({
    super.key,
    required this.title,
    required this.onTap,
    this.textStyle,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: padding,
          splashFactory: InkRipple.splashFactory,
        ),
        child: Text(
          title,
          style:
          textStyle ??
              text14(color: AppColors.button, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}


class CustomIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final double size;
  final Color? splashColor;
  final EdgeInsetsGeometry padding;
  final String? tooltip;

  const CustomIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.size = 24.0,
    this.splashColor,
    this.padding = const EdgeInsets.all(4.0),
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        icon,
        size: size,
        color: color ?? Theme.of(context).iconTheme.color,
      ),
      onPressed: onPressed,
      padding: padding,
      splashColor: splashColor,
      tooltip: tooltip,
    );
  }
}