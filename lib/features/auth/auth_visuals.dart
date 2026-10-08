import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_strings.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';

/// Shared visual language for auth screens (login / email / OTP).
class AuthVisuals {
  AuthVisuals._();

  static const Color brand = AppColors.primary;
  static const Color button = AppColors.primaryLight;
  static const Color fieldFill = AppColors.softGreen;
  static const Color fieldBorder = AppColors.softGreenBorder;
  static const Color muted = Color(0xFF8D8D92);
  static const Color footer = Color(0xFFB0B0B4);
  static const Color hintColor = Color(0xFFB4B4BA);
  static const Color text = Color(0xFF2C2C2E);

  static bool get ar => LocalizationService.instance.currentLanguage == 'ar';

  static TextStyle titleStyle({double size = 28}) => GoogleFonts.cairo(
        fontSize: size,
        height: 1.15,
        fontWeight: FontWeight.w800,
        color: brand,
      );

  static TextStyle bodyStyle({
    double size = 15,
    Color color = muted,
    FontWeight weight = FontWeight.w500,
  }) =>
      GoogleFonts.cairo(fontSize: size, color: color, fontWeight: weight);

  /// Pops when possible; otherwise runs [onRootBack] (e.g. go to MainShell).
  static Widget backButton(
    BuildContext context, {
    VoidCallback? onRootBack,
  }) {
    return Align(
      alignment: Alignment.centerRight,
      child: IconButton(
        onPressed: () {
          if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
            return;
          }
          onRootBack?.call();
        },
        icon: const Icon(
          Iconsax.arrow_right_3,
          color: Color(0xFF1C1C1E),
          size: 28,
        ),
      ),
    );
  }

  static Widget logoMark({double size = 96}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 28,
            spreadRadius: 2,
          ),
          BoxShadow(
            color: AppColors.softGreen.withValues(alpha: 0.95),
            blurRadius: 36,
            spreadRadius: 10,
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Image.asset('assets/images/Logo.png', fit: BoxFit.contain),
    );
  }

  static Widget brandTitle({String? title}) {
    return Text(
      title ?? AppStrings.appName,
      textAlign: TextAlign.center,
      style: titleStyle(size: title == null ? 32 : 26),
    );
  }

  static InputDecoration softInputDecoration({
    required String hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.cairo(
        fontSize: 15,
        color: hintColor,
        fontWeight: FontWeight.w600,
      ),
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fieldFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: fieldBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: fieldBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: brand, width: 1.6),
      ),
    );
  }

  static Widget primaryButton({
    required String label,
    required VoidCallback? onPressed,
    bool loading = false,
    IconData icon = Iconsax.sms,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: button,
          disabledBackgroundColor: button.withValues(alpha: 0.7),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                textDirection: TextDirection.rtl,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.cairo(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, size: 22, color: Colors.white),
                ],
              ),
      ),
    );
  }

  static Widget footerText(String text) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: GoogleFonts.cairo(
        fontSize: 12,
        height: 1.7,
        color: footer,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static Widget otpRow({
    required List<TextEditingController> controllers,
    required List<FocusNode> focusNodes,
    required void Function(int index, String value) onChanged,
  }) {
    assert(controllers.length == focusNodes.length);
    final count = controllers.length;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: Row(
          children: List.generate(count, (index) {
            return Expanded(
              child: Padding(
                padding: EdgeInsetsDirectional.only(
                  end: index == count - 1 ? 0 : 6,
                ),
                child: TextField(
                  controller: controllers[index],
                  focusNode: focusNodes[index],
                  textDirection: TextDirection.ltr,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 1,
                  style: GoogleFonts.cairo(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: brand,
                  ),
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    counterText: '',
                    filled: true,
                    fillColor: fieldFill,
                    contentPadding: EdgeInsets.zero,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: fieldBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: fieldBorder),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: brand, width: 1.6),
                    ),
                  ),
                  onChanged: (value) => onChanged(index, value),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
