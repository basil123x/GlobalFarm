import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'otp_screen.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  static const String _qatarDialCode = '+974';
  static const int _qatarMaxLength = 8;
  static const String _qatarFlagUrl = 'https://flagcdn.com/w40/qa.png';

  final TextEditingController _phoneController = TextEditingController();
  bool _isValidPhone = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  void _validatePhone() {
    setState(() {
      _isValidPhone = AuthService.isValidQatarPhone(_phoneController.text);
    });
  }

  void _sendOTP() async {
    if (!_isValidPhone) return;

    setState(() {
      _isLoading = true;
    });

    final otp = AuthService.generateOTP();

    setState(() {
      _isLoading = false;
    });

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OTPScreen(
          countryCode: _qatarDialCode,
          phoneNumber: _phoneController.text,
          generatedOTP: otp,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
          backgroundColor: context.appSurface,
          appBar: AppBar(
            backgroundColor: context.appSurface,
            elevation: 0,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: IntrinsicHeight(
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // Icon
                                  Container(
                                    width: 100,
                                    height: 100,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [
                                          AppColors.primary,
                                          AppColors.primary.withValues(
                                            alpha: 0.7,
                                          ),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(25),
                                      boxShadow: [
                                        BoxShadow(
                                          color: AppColors.primary.withValues(
                                            alpha: 0.3,
                                          ),
                                          blurRadius: 20,
                                          offset: const Offset(0, 10),
                                        ),
                                      ],
                                    ),
                                    child: Icon(
                                      Iconsax.mobile,
                                      size: 50,
                                      color: Colors.white,
                                    ),
                                  ),

                                  const SizedBox(height: 40),

                                  Text(
                                    textAlign: TextAlign.center,
                                    lang == 'ar'
                                        ? 'تسجيل الدخول برقم الهاتف'
                                        : 'Login with Phone Number',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),

                                  const SizedBox(height: 8),

                                  Text(
                                    lang == 'ar'
                                        ? 'سنرسل لك رمز التحقق عبر رسالة نصية'
                                        : 'We will send you a verification code via SMS',
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context).textTheme.bodyLarge
                                        ?.copyWith(
                                          color: AppColors.textSecondaryColor(
                                            context,
                                          ),
                                        ),
                                  ),

                                  const SizedBox(height: 60),

                                  Container(
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.05,
                                          ),
                                          blurRadius: 10,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                    ),
                                    child: TextField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.number,
                                      textAlign: TextAlign.center,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 2,
                                          ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(
                                          _qatarMaxLength,
                                        ),
                                      ],
                                      decoration: InputDecoration(
                                        hintText: '12345678',
                                        hintStyle: TextStyle(
                                          color: AppColors.textHint,
                                          letterSpacing: 2,
                                        ),
                                        prefixIcon: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(3),
                                                child: Image.network(
                                                  _qatarFlagUrl,
                                                  width: 30,
                                                  height: 20,
                                                  fit: BoxFit.cover,
                                                  errorBuilder:
                                                      (
                                                        context,
                                                        error,
                                                        stackTrace,
                                                      ) => Text(
                                                        _qatarDialCode,
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                _qatarDialCode,
                                                style: Theme.of(context)
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                width: 1,
                                                height: 20,
                                                color: AppColors.lightGrey,
                                              ),
                                            ],
                                          ),
                                        ),
                                        suffixIcon: Container(
                                          padding: _isValidPhone
                                              ? EdgeInsets.all(12)
                                              : EdgeInsets.all(0),
                                          child: IconButton(
                                            onPressed: () {},
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                            splashRadius: 20,
                                            icon: Icon(
                                              _isValidPhone
                                                  ? Iconsax.tick_circle5
                                                  : Iconsax.close_circle5,
                                              color: _isValidPhone
                                                  ? AppColors.success
                                                  : AppColors.error,
                                              size: 24,
                                            ),
                                          ),
                                        ),
                                        filled: true,
                                        fillColor: context.appSurface,
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 1,
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.lightGrey,
                                            width: 1,
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          borderSide: BorderSide(
                                            color: AppColors.primary,
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 20,
                                            ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 12),

                                  Text(
                                    '${lang == 'ar' ? 'أدخل رقم هاتفك' : 'Enter your phone number'} ($_qatarMaxLength)',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textSecondaryColor(
                                            context,
                                          ),
                                        ),
                                  ),

                                  const SizedBox(height: 40),

                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: _isValidPhone && !_isLoading
                                          ? _sendOTP
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: _isValidPhone ? 8 : 0,
                                        shadowColor: AppColors.primary
                                            .withValues(alpha: 0.3),
                                      ),
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 20,
                                              width: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                const Icon(
                                                  Iconsax.sms,
                                                  size: 20,
                                                ),
                                                const SizedBox(width: 8),
                                                Text(
                                                  lang == 'ar'
                                                      ? 'إرسال كود التحقق'
                                                      : 'Send Verification Code',
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .titleMedium
                                                      ?.copyWith(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 24),

                            Text(
                              lang == 'ar'
                                  ? 'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية'
                                  : 'By continuing, you agree to our Terms and Privacy Policy',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: AppColors.textHint),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
