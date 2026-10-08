import 'package:flutter/material.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';

extension AppThemeContext on BuildContext {
  bool get isDarkMode => Theme.of(this).brightness == Brightness.dark;

  /// اتجاه النص حسب لغة التطبيق المختارة: rtl للعربية و ltr للإنجليزية.
  /// استخدمها بدلاً من TextDirection.rtl الثابت حتى تنقلب الشاشة مع اللغة.
  TextDirection get appTextDirection =>
      LocalizationService.instance.textDirection;

  bool get isArabicLocale => LocalizationService.instance.isArabic;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;

  Color get appSurface =>
      isDarkMode ? AppColors.darkSurface : AppColors.surface;

  Color get appSurfaceVariant => isDarkMode
      ? AppColors.darkElevated
      : AppColors.softGreen;

  Color get appTextPrimary =>
      isDarkMode ? AppColors.darkText : AppColors.textPrimary;

  Color get appTextSecondary =>
      isDarkMode ? AppColors.darkTextSecondary : AppColors.textSecondary;

  Color get appBorder =>
      isDarkMode ? AppColors.darkBorder : AppColors.softGreenBorder;

  Color get appCardBorder =>
      isDarkMode ? AppColors.darkBorder : AppColors.softGreenBorder;

  /// Flat green-tinted surfaces (no purple/lavender leftovers).
  List<Color> get surfaceGradientColors => isDarkMode
      ? [AppColors.darkSurface, AppColors.darkElevated]
      : [AppColors.softGreen, const Color(0xFFEEF4EC)];

  LinearGradient surfaceGradient({
    Alignment begin = Alignment.topLeft,
    Alignment end = Alignment.bottomRight,
  }) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: surfaceGradientColors,
    );
  }

  LinearGradient bottomBarGradient({
    Alignment begin = Alignment.topCenter,
    Alignment end = Alignment.bottomCenter,
  }) {
    if (isDarkMode) {
      return LinearGradient(
        begin: begin,
        end: end,
        colors: [AppColors.darkSurface, AppColors.darkElevated],
      );
    }
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [AppColors.softGreen, const Color(0xFFEEF4EC)],
    );
  }
}
