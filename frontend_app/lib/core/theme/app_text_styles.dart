import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTextStyles {
  static TextStyle get h1 => const TextStyle(
    fontFamily: 'Manrope',
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.ink,
    height: 1.2,
    letterSpacing: -.8,
  );
  static TextStyle get h2 => h1.copyWith(fontSize: 24);
  static TextStyle get h3 => h1.copyWith(fontSize: 20);
  static TextStyle get h4 => h1.copyWith(fontSize: 18);
  static TextStyle get bodyLarge => const TextStyle(
    fontFamily: 'Manrope',
    fontSize: 15,
    color: AppColors.ink,
    height: 1.65,
  );
  static TextStyle get bodyMedium =>
      bodyLarge.copyWith(fontSize: 14, height: 1.5);
  static TextStyle get bodySmall =>
      bodyLarge.copyWith(fontSize: 12, color: AppColors.muted, height: 1.5);
  static TextStyle get button =>
      bodyLarge.copyWith(fontWeight: FontWeight.w800, color: Colors.white);
  static TextStyle get label =>
      bodyMedium.copyWith(fontWeight: FontWeight.w700);
}
