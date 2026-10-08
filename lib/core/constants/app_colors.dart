// app_colors.dart — GlobalFarm Brand Colors (unified green theme)
import 'package:flutter/material.dart';

class AppColors {
  // ── Primary (Farm Green)
  static const Color primary = Color(0xFF4A7C3F);
  static const Color primaryDark = Color(0xFF3A6230);
  static const Color primaryLight = Color(0xFF6A9C5F);

  // ── Secondary (same green family — no brown)
  static const Color secondary = primaryDark;
  static const Color secondaryDark = Color(0xFF2D4A24);
  static const Color secondaryLight = primaryLight;

  // ── Gradient
  static const LinearGradient brandGradient = LinearGradient(
    colors: [primaryLight, primary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient bgGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // ── Neutral
  static const Color black = Color(0xFF000000);
  static const Color white = Color(0xFFFFFFFF);
  static const Color grey = Color(0xFF9E9E9E);
  static const Color lightGrey = Color(0xFFF5F5F5);
  static const Color darkGrey = Color(0xFF424242);

  // ── Background
  static const Color background = Color(0xFFF3F6F1);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color cardBackground = Color(0xFFFFFFFF);
  static const Color softGreen = Color(0xFFF7FAF4);
  static const Color softGreenBorder = Color(0xFFE2E8DE);

  // ── Text
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color textHint = Color(0xFFBDBDBD);

  // ── Status
  static const Color success = Color(0xFF4CAF50);
  static const Color error = Color(0xFFF44336);
  static const Color warning = Color(0xFFFF9800);
  static const Color info = Color(0xFF2196F3);

  // ── Shopping
  static const Color priceColor = primary;
  static const Color discountColor = primary;
  static const Color cartColor = primaryLight;

  // ── Dark Mode
  static const Color darkBackground = Color(0xFF121A14);
  static const Color darkSurface = Color(0xFF1A241C);
  static const Color darkElevated = Color(0xFF243028);
  static const Color darkText = Color(0xFFFFFFFF);
  static const Color darkTextSecondary = Color(0xFFA8B5AA);
  static const Color darkBorder = Color(0x1AFFFFFF);

  /// Theme-aware text colors — prefer these over hardcoded [textPrimary].
  static Color textColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white
          : textPrimary;

  static Color textSecondaryColor(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Colors.white70
          : textSecondary;
}
