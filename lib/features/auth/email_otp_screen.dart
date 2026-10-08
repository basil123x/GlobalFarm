import 'package:GlobalFarm/features/auth/login.dart';
import 'package:GlobalFarm/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'auth_visuals.dart';
import 'email_signup_screen.dart';

class EmailOTPScreen extends StatefulWidget {
  final String email;
  final String password;

  const EmailOTPScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailOTPScreen> createState() => _EmailOTPScreenState();
}

class _EmailOTPScreenState extends State<EmailOTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String _enteredOTP = '';
  late String _generatedOTP;

  @override
  void initState() {
    super.initState();
    _generatedOTP = AuthService.generateOTP();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      sendOTPEmail();
    });
  }

  void _onOTPChanged(int index, String value) {
    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }

    _enteredOTP = _controllers.map((controller) => controller.text).join();

    if (_enteredOTP.length == 6) {
      _verifyOTP();
    }
  }

  void _verifyOTP() async {
    final lang = LocalizationService.instance.currentLanguage;
    if (_enteredOTP.length != 6) {
      _showError(
        lang == 'ar'
            ? 'يرجى إدخال الكود المكون من 6 أرقام'
            : 'Please enter 6 digit code',
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    await Future.delayed(const Duration(seconds: 1));

    if (_enteredOTP == _generatedOTP) {
      try {
        final cacheBust =
            "${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}";
        final checkResponse = await Dio().post(
          cacheBust,
          data: FormData.fromMap({
            "action": "get_user_by_email",
            "email": widget.email,
          }),
        );

        if (checkResponse.data["success"] == true &&
            checkResponse.data["data"] != null) {
          // ✅ مستخدم موجود → دخّله
          final userData = checkResponse.data["data"] as Map<String, dynamic>;
          await _saveUserSession(
            uid: userData["id"]?.toString() ?? "",
            oid: userData["oid"]?.toString() ?? "",
            email: userData["email"]?.toString() ?? widget.email,
            name: userData["name"]?.toString() ?? "",
            role: userData["role"]?.toString(),
            storeId:
                userData["store_id"]?.toString() ??
                userData["storeid"]?.toString(),
          );
          await _updateFcmToken();
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const SplashScreen()),
            );
          }
        } else {
          // ✅ مستخدم جديد → روح صفحة إنشاء الحساب
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => EmailSignupScreen(
                  email: widget.email,
                  password: widget.password,
                ),
              ),
            );
          }
        }
      } catch (e) {
        setState(() {
          _isLoading = false;
        });
        _showError(
          lang == 'ar'
              ? 'حدث خطأ أثناء التحقق، يرجى المحاولة مرة أخرى'
              : 'Verification error, please try again',
        );
      }
    } else {
      setState(() {
        _isLoading = false;
      });
      _showError(
        lang == 'ar'
            ? 'كود التحقق غير صحيح، يرجى المحاولة مرة أخرى'
            : 'Wrong code, please try again',
      );
      _clearOTP();
    }
  }

  Future<void> _saveUserSession({
    required String uid,
    required String oid,
    required String email,
    required String name,
    String? role,
    String? storeId,
  }) async {
    const storage = FlutterSecureStorage();
    await storage.write(key: "user_uid", value: uid);
    await storage.write(key: "user_oid", value: oid);
    await storage.write(key: "user_email", value: email);
    await storage.write(key: "user_name", value: name);
    await storage.write(key: "login_type", value: "Email");
    await AuthService.saveUserRoleAndStore(role, storeId);
  }

  Future<void> _updateFcmToken() async {
    final String? userId = OneSignal.User.pushSubscription.id;
    await Dio().post(
      "${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
      data: FormData.fromMap({
        "action": "update_fcm_token",
        "email": widget.email,
        "fcm_token": userId,
      }),
    );
  }

  void _clearOTP() {
    for (var controller in _controllers) {
      controller.clear();
    }
    _enteredOTP = '';
    _focusNodes[0].requestFocus();
  }

  void _showError(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
  }

  void _resendOTP() {
    final lang = LocalizationService.instance.currentLanguage;
    _generatedOTP = AuthService.generateOTP();
    sendOTPEmail();
    _clearOTP();

    showAppSnackbar(
      context,
      message: lang == 'ar' ? 'تم إرسال كود جديد' : 'New code sent',
      type: SnackType.success,
    );
  }

  sendOTPEmail() async {
    var result = await Dio().post(
      "${AppConfig.apiBaseUrl}/send_email.php?k=${DateTime.now().millisecondsSinceEpoch}",
      data: FormData.fromMap({"email": widget.email, "otp": _generatedOTP}),
    );
    print(result);
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
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
                                    ? 'تحقق من بريدك الإلكتروني'
                                    : 'Verify your Email',
                              ),
                              const SizedBox(height: 12),
                              Text.rich(
                                TextSpan(
                                  style: AuthVisuals.bodyStyle(size: 15),
                                  children: [
                                    TextSpan(
                                      text: lang == 'ar'
                                          ? 'أدخل الكود المرسل إلى\n'
                                          : 'Enter the code sent to\n',
                                    ),
                                    TextSpan(
                                      text: widget.email,
                                      style: GoogleFonts.cairo(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: AuthVisuals.brand,
                                      ),
                                    ),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 36),
                              AuthVisuals.otpRow(
                                controllers: _controllers,
                                focusNodes: _focusNodes,
                                onChanged: _onOTPChanged,
                              ),
                              const SizedBox(height: 28),
                              if (_isLoading)
                                const CircularProgressIndicator(
                                  color: AuthVisuals.brand,
                                  strokeWidth: 2.4,
                                )
                              else
                                AuthVisuals.primaryButton(
                                  label: lang == 'ar'
                                      ? 'تأكيد الرمز'
                                      : 'Verify code',
                                  onPressed: _enteredOTP.length == 6
                                      ? _verifyOTP
                                      : null,
                                  icon: Iconsax.tick_circle,
                                ),
                              const SizedBox(height: 18),
                              TextButton(
                                onPressed: _resendOTP,
                                child: Text(
                                  lang == 'ar'
                                      ? 'إعادة إرسال الكود'
                                      : 'Resend Code',
                                  style: AuthVisuals.bodyStyle(
                                    size: 15,
                                    color: AuthVisuals.brand,
                                    weight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    lang == 'ar'
                                        ? 'ألم يصلك الكود؟ '
                                        : "Didn't receive the code? ",
                                    style: AuthVisuals.bodyStyle(size: 13.5),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const LoginScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      lang == 'ar'
                                          ? 'جرب طريقة أخرى'
                                          : 'Try another way',
                                      style: AuthVisuals.bodyStyle(
                                        size: 13.5,
                                        color: AppColors.primaryLight,
                                        weight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      );
                    },
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
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }
}
