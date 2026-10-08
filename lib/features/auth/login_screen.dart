import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_strings.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class LoginScreenx extends StatefulWidget {
  const LoginScreenx({super.key});

  @override
  State<LoginScreenx> createState() => _LoginScreenxState();
}

class _LoginScreenxState extends State<LoginScreenx> {
  final TextEditingController _phoneController = TextEditingController();
  bool _isValidPhone = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(_validatePhone);
  }

  void _validatePhone() {
    final isValid = AuthService.isValidQatarPhone(_phoneController.text);
    if (_isValidPhone != isValid) {
      setState(() {
        _isValidPhone = isValid;
      });
    }
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

    // Navigate to OTP screen
    // Navigator.of(context).push(
    //   MaterialPageRoute(
    //     builder: (context) =>
    //         OTPScreen(countryCode: '',phoneNumber: _phoneController.text, generatedOTP: otp),
    //   ),
    // );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        backgroundColor: context.appSurface,
        appBar: AppBar(),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Logo
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.white,
                                    borderRadius: BorderRadius.circular(30),
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
                                  child: Padding(
                                    padding: const EdgeInsets.all(
                                      20,
                                    ), // تحكم في المسافة حوالين الشعار
                                    child: Image.asset(
                                      "assets/images/Logo.png",
                                      fit: BoxFit
                                          .contain, // الشعار هيتناسب مع المساحة المتاحة
                                    ),
                                  ),
                                ),

                                const SizedBox(height: 40),

                                // App Name
                                Text(
                                  AppStrings.appName,
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
                                  'مرحباً بك في عالم التسوق الذكي',
                                  style: Theme.of(context).textTheme.bodyLarge
                                      ?.copyWith(
                                        color: AppColors.textSecondaryColor(
                                          context,
                                        ),
                                      ),
                                ),

                                const SizedBox(height: 60),

                                // Phone Input
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
                                      LengthLimitingTextInputFormatter(8),
                                    ],
                                    decoration: InputDecoration(
                                      hintText: '12345678',
                                      hintStyle: TextStyle(
                                        color: AppColors.textHint,
                                        letterSpacing: 2,
                                      ),
                                      prefixIcon: Container(
                                        padding: const EdgeInsets.all(12),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: 24,
                                              height: 16,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(2),
                                                gradient: const LinearGradient(
                                                  colors: [
                                                    Color(0xFF8D1538),
                                                    Color(0xFFFFFFFF),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              '+974',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .titleMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w600,
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
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.lightGrey,
                                          width: 1,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        borderSide: BorderSide(
                                          color: AppColors.lightGrey,
                                          width: 1,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(16),
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
                                  'أدخل رقم هاتفك القطري (8 أرقام)',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.textSecondaryColor(
                                          context,
                                        ),
                                      ),
                                ),

                                const SizedBox(height: 40),

                                // Send OTP Button
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
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      elevation: _isValidPhone ? 8 : 0,
                                      shadowColor: AppColors.primary.withValues(
                                        alpha: 0.3,
                                      ),
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(Iconsax.sms, size: 20),
                                              const SizedBox(width: 8),
                                              Text(
                                                'إرسال كود التحقق',
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

                          // Footer
                          Text(
                            'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية',
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
    );
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }
}
