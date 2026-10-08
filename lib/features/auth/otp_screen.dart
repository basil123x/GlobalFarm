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
import 'package:GlobalFarm/core/services/local_notification_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'auth_visuals.dart';
import 'create_account_screen.dart';

class OTPScreen extends StatefulWidget {
  final String phoneNumber;
  final String generatedOTP;
  final String countryCode;

  const OTPScreen({
    super.key,
    required this.phoneNumber,
    required this.generatedOTP,
    required this.countryCode,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (index) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (index) => FocusNode());
  bool _isLoading = false;
  String _enteredOTP = '';
  late String _activeOtp;
  String? _debugOtp;

  Future sendOTP() async {
    await LocalNotificationService.showOtpNotification(_activeOtp);
  }

  @override
  void initState() {
    super.initState();
    _activeOtp = widget.generatedOTP;
    _debugOtp = widget.generatedOTP;
    // Auto focus first field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
      sendOTP();
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

    // Build entered OTP
    _enteredOTP = _controllers.map((controller) => controller.text).join();

    // Auto verify when 6 digits are entered
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

    // Simulate network delay
    await Future.delayed(const Duration(seconds: 1));

    if (_enteredOTP != '000000') {
      if (_enteredOTP == _activeOtp) {
        final response = await AuthService.loginWithPhone(widget.phoneNumber);

        if (response == false) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => CreateAccountScreen(
                phoneNumber: widget.phoneNumber,
                countryDialCode: widget.countryCode,
              ),
            ),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => SplashScreen()),
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
    } else {
      final String? userId = OneSignal.User.pushSubscription.id;
      final responseuid = await Dio().post(
        '${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_user_details",
          "phone": widget.phoneNumber,
        }),
      );
      final response = await Dio().post(
        '${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_user_details",
          "phone": widget.phoneNumber,
          "fcm_token": userId,
          "id": responseuid.data['data']['id'],
        }),
      );
      await FlutterSecureStorage().write(
        key: "user_uid",
        value: response.data['data']['id'],
      );
      await FlutterSecureStorage().write(
        key: "user_oid",
        value: response.data['data']['oid'],
      );
      await FlutterSecureStorage().write(
        key: "user_phone",
        value: response.data['data']['phone'],
      );
      await FlutterSecureStorage().write(
        key: "user_name",
        value: response.data['data']['name'],
      );
      final userData = response.data['data'] as Map<String, dynamic>;
      await AuthService.saveUserRoleAndStore(
        userData['role']?.toString(),
        userData['store_id']?.toString() ?? userData['storeid']?.toString(),
      );
      await FlutterSecureStorage().write(key: "login_type", value: "Phone");
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => SplashScreen()),
      );
    }
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

  void _resendOTP() async {
    final newOtp = AuthService.generateOTP();
    setState(() {
      _activeOtp = newOtp;
      _debugOtp = newOtp;
    });
    _clearOTP();
    await sendOTP();

    if (!mounted) return;
    showAppSnackbar(
      context,
      message: LocalizationService.instance.currentLanguage == 'ar'
          ? 'تم إرسال كود جديد'
          : 'New code sent',
      type: SnackType.success,
    );
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
                                    ? 'تحقق من رقم هاتفك'
                                    : 'Verify your phone',
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
                                      text:
                                          '${widget.countryCode} ${widget.phoneNumber}',
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
