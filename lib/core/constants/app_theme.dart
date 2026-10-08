import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        secondary: AppColors.primaryDark,
      ),
      scaffoldBackgroundColor: AppColors.background,

      // App Bar Theme
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
      ),

      // Bottom Navigation Bar Theme
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.white,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),

      // Card Theme
      cardTheme: CardThemeData(
        color: AppColors.cardBackground,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),

      // Elevated Button Theme
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),

      // Text Button Theme
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),

      // Input Decoration Theme
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightGrey,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),

      // Text Theme with Google Fonts
      textTheme: _getTextTheme(),

      // Icon Theme
      iconTheme: const IconThemeData(color: AppColors.textPrimary, size: 24),

      // Floating Action Button Theme
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
        elevation: 4,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBackground,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.primaryLight,
        surface: AppColors.darkSurface,
        onSurface: AppColors.darkText,
        onPrimary: AppColors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkSurface,
        foregroundColor: AppColors.darkText,
        elevation: 0,
        centerTitle: true,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.darkBorder),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryLight,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error, width: 1),
        ),
        hintStyle: const TextStyle(color: AppColors.darkTextSecondary),
        labelStyle: const TextStyle(color: AppColors.darkTextSecondary),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      textTheme: _getDarkTextTheme(),
      iconTheme: const IconThemeData(color: AppColors.darkText, size: 24),
      listTileTheme: const ListTileThemeData(
        textColor: AppColors.darkText,
        iconColor: AppColors.darkText,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.darkTextSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary.withOpacity(0.4);
          }
          return AppColors.darkBorder;
        }),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.darkSurface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.darkTextSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      dividerColor: AppColors.darkBorder,
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.white,
      ),
    );
  }

  static TextTheme _getDarkTextTheme() {
    return GoogleFonts.cairoTextTheme().copyWith(
      headlineLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.darkText,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.darkText,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.darkText,
      ),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: AppColors.darkText),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        color: AppColors.darkTextSecondary,
      ),
      bodySmall: GoogleFonts.cairo(
        fontSize: 12,
        color: AppColors.darkTextSecondary,
      ),
    );
  }

  static TextTheme _getTextTheme() {
    // Detect if the current locale is Arabic
    return GoogleFonts.cairoTextTheme().copyWith(
      headlineLarge: GoogleFonts.cairo(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.cairo(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.cairo(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.cairo(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.cairo(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.cairo(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.cairo(fontSize: 16, color: AppColors.textPrimary),
      bodyMedium: GoogleFonts.cairo(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.cairo(fontSize: 12, color: AppColors.textHint),
    );
  }

  static TextTheme getEnglishTextTheme() {
    return GoogleFonts.ubuntuTextTheme().copyWith(
      headlineLarge: GoogleFonts.ubuntu(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineMedium: GoogleFonts.ubuntu(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: AppColors.textPrimary,
      ),
      headlineSmall: GoogleFonts.ubuntu(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: GoogleFonts.ubuntu(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: GoogleFonts.ubuntu(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      titleSmall: GoogleFonts.ubuntu(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.ubuntu(fontSize: 16, color: AppColors.textPrimary),
      bodyMedium: GoogleFonts.ubuntu(
        fontSize: 14,
        color: AppColors.textSecondary,
      ),
      bodySmall: GoogleFonts.ubuntu(fontSize: 12, color: AppColors.textHint),
    );
  }
}
