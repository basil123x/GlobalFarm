import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'auth_visuals.dart';
import 'email_otp_screen.dart';

class EmailLoginScreen extends StatefulWidget {
  const EmailLoginScreen({super.key});

  @override
  State<EmailLoginScreen> createState() => _EmailLoginScreenState();
}

class _EmailLoginScreenState extends State<EmailLoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isValidEmail = false;
  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String _passwordStrength = '';
  Color _passwordStrengthColor = AppColors.error;

  @override
  void initState() {
    super.initState();
    _emailController.addListener(_validateEmail);
    _passwordController.addListener(_checkPasswordStrength);
  }

  void _validateEmail() {
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    final isValid = emailRegex.hasMatch(_emailController.text);
    if (_isValidEmail != isValid) {
      setState(() {
        _isValidEmail = isValid;
      });
    }
  }

  void _checkPasswordStrength() {
    final lang = LocalizationService.instance.currentLanguage;
    final password = _passwordController.text;

    if (password.isEmpty) {
      setState(() {
        _passwordStrength = '';
      });
      return;
    }

    int strength = 0;

    if (password.length >= 8) strength++;
    if (password.length >= 12) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[a-z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    setState(() {
      if (strength <= 2) {
        _passwordStrength = lang == 'ar' ? 'ضعيفة' : 'Weak';
        _passwordStrengthColor = AppColors.error;
      } else if (strength <= 4) {
        _passwordStrength = lang == 'ar' ? 'متوسطة' : 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else {
        _passwordStrength = lang == 'ar' ? 'قوية' : 'Strong';
        _passwordStrengthColor = AppColors.success;
      }
    });
  }

  bool _isPasswordStrong() {
    final password = _passwordController.text;
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password);
  }

  void _login() async {
    final lang = LocalizationService.instance.currentLanguage;

    if (!_isValidEmail) {
      _showError(
        lang == 'ar'
            ? 'يرجى إدخال بريد إلكتروني صحيح'
            : 'Please enter a valid email',
      );
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showError(
        lang == 'ar' ? 'يرجى إدخال كلمة المرور' : 'Please enter your password',
      );
      return;
    }

    if (!_isPasswordStrong()) {
      _showError(
        lang == 'ar'
            ? 'كلمة المرور يجب أن تحتوي على 8 أحرف على الأقل، حرف كبير، حرف صغير، ورقم'
            : 'Password must be at least 8 characters with uppercase, lowercase, and a number',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await Dio().post(
        "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap({
          "action": "login_with_email",
          "email": _emailController.text.trim(),
          "password": _passwordController.text,
        }),
      );

      if (!mounted) return;

      final data = response.data;
      final success = data["success"] == true;
      final message = data["message"]?.toString() ?? "";

      if (success) {
        _navigateToOtp();
        return;
      }

      if (message == "المستخدم غير موجود") {
        _navigateToOtp();
        return;
      }

      if (message == "كلمة المرور غير صحيحة") {
        _showError(
          lang == 'ar' ? 'كلمة المرور غير صحيحة' : 'Incorrect password',
        );
        return;
      }

      if (message.contains("جوجل")) {
        _showError(
          lang == 'ar'
              ? 'هذا الحساب مسجل بجوجل، يرجى تسجيل الدخول عبر جوجل'
              : 'This account is registered with Google, please sign in with Google',
        );
        return;
      }

      _showError(
        message.isNotEmpty
            ? message
            : (lang == 'ar'
                  ? 'حدث خطأ، يرجى المحاولة مرة أخرى'
                  : 'An error occurred, please try again'),
      );
    } catch (e) {
      if (mounted) {
        _showError(
          lang == 'ar'
              ? 'حدث خطأ في الاتصال، يرجى المحاولة مرة أخرى'
              : 'Connection error, please try again',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _navigateToOtp() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EmailOTPScreen(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        ),
      ),
    );
  }

  void _showError(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    final canSubmit =
        _isValidEmail && _passwordController.text.isNotEmpty && !_isLoading;

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: SafeArea(
            child: Column(
              children: [
                AuthVisuals.backButton(
                  context,
                  onRootBack: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (_) => false,
                    );
                  },
                ),
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        child: ConstrainedBox(
                          constraints:
                              BoxConstraints(minHeight: constraints.maxHeight),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              AuthVisuals.logoMark(),
                              const SizedBox(height: 18),
                              AuthVisuals.brandTitle(
                                title: lang == 'ar'
                                    ? 'تسجيل الدخول بالبريد'
                                    : 'Email Login',
                              ),
                              const SizedBox(height: 10),
                              Text(
                                lang == 'ar'
                                    ? 'أدخل بريدك الإلكتروني وكلمة المرور'
                                    : 'Enter your email and password',
                                textAlign: TextAlign.center,
                                style: AuthVisuals.bodyStyle(size: 15),
                              ),
                              const SizedBox(height: 36),
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AuthVisuals.text,
                                ),
                                decoration: AuthVisuals.softInputDecoration(
                                  hint: 'example@email.com',
                                  prefixIcon: const Icon(
                                    Iconsax.sms,
                                    color: AuthVisuals.brand,
                                  ),
                                  suffixIcon: _emailController.text.isNotEmpty
                                      ? Icon(
                                          _isValidEmail
                                              ? Iconsax.tick_circle5
                                              : Iconsax.close_circle5,
                                          color: _isValidEmail
                                              ? AppColors.success
                                              : AppColors.error,
                                        )
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 14),
                              TextField(
                                controller: _passwordController,
                                obscureText: !_isPasswordVisible,
                                style: GoogleFonts.cairo(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AuthVisuals.text,
                                ),
                                decoration: AuthVisuals.softInputDecoration(
                                  hint: lang == 'ar'
                                      ? 'كلمة المرور'
                                      : 'Password',
                                  prefixIcon: const Icon(
                                    Iconsax.lock,
                                    color: AuthVisuals.brand,
                                  ),
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _isPasswordVisible
                                          ? Iconsax.eye
                                          : Iconsax.eye_slash,
                                      color: AuthVisuals.muted,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        _isPasswordVisible =
                                            !_isPasswordVisible;
                                      });
                                    },
                                  ),
                                ),
                              ),
                              if (_passwordController.text.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    lang == 'ar'
                                        ? 'قوة كلمة المرور: $_passwordStrength'
                                        : 'Password strength: $_passwordStrength',
                                    style: AuthVisuals.bodyStyle(
                                      size: 13,
                                      color: _passwordStrengthColor,
                                      weight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 22),
                              AuthVisuals.primaryButton(
                                label: lang == 'ar'
                                    ? 'إرسال رمز التحقق'
                                    : 'Send verification code',
                                onPressed: canSubmit ? _login : null,
                                loading: _isLoading,
                                icon: Iconsax.sms,
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
                  child: AuthVisuals.footerText(
                    lang == 'ar'
                        ? 'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية'
                        : 'By continuing, you agree to our Terms and Privacy Policy',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
