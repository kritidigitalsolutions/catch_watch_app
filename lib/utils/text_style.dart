import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../res/app_colors.dart';

/// -------------------------------
/// BASE TEXT STYLE (REUSABLE)
/// -------------------------------
TextStyle appTextStyle({
  double fontSize = 14,
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
  double? letterSpacing,
  double? height,
}) {
  return GoogleFonts.poppins(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
    letterSpacing: letterSpacing,
    height: height,
  );
}

/// -------------------------------
/// PREDEFINED TEXT STYLES
/// -------------------------------

TextStyle text8({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 8, fontWeight: fontWeight, color: color);
}

TextStyle text10({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 10, fontWeight: fontWeight, color: color);
}

TextStyle text11({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 11, fontWeight: fontWeight, color: color);
}

TextStyle text12({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 12, fontWeight: fontWeight, color: color);
}

TextStyle text13({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 13, fontWeight: fontWeight, color: color);
}

TextStyle text14({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 14, fontWeight: fontWeight, color: color);
}

TextStyle text15({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 15, fontWeight: fontWeight, color: color);
}

TextStyle text16({
  FontWeight fontWeight = FontWeight.normal,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 16, fontWeight: fontWeight, color: color);
}

TextStyle text18({
  FontWeight fontWeight = FontWeight.w600,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 18, fontWeight: fontWeight, color: color);
}

TextStyle text20({
  FontWeight fontWeight = FontWeight.bold,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 20, fontWeight: fontWeight, color: color);
}

TextStyle text24({
  FontWeight fontWeight = FontWeight.bold,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 24, fontWeight: fontWeight, color: color);
}

TextStyle text26({
  FontWeight fontWeight = FontWeight.bold,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 26, fontWeight: fontWeight, color: color);
}

TextStyle text30({
  FontWeight fontWeight = FontWeight.bold,
  Color color = AppColors.textPrimary,
}) {
  return appTextStyle(fontSize: 30, fontWeight: fontWeight, color: color);
}

/// -------------------------------
/// SPECIAL STYLES
/// -------------------------------

TextStyle heading({Color color = AppColors.textPrimary}) {
  return appTextStyle(
    fontSize: 22,
    fontWeight: FontWeight.bold,
    color: color,
  );
}

TextStyle subtitle({Color color = AppColors.textSecondary}) {
  return appTextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: color,
  );
}