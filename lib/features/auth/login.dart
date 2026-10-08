import 'dart:async';
import 'dart:math';
import 'package:GlobalFarm/core/services/apple_auth_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/avatar_service.dart';
import 'package:GlobalFarm/core/services/google_auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:GlobalFarm/features/settings/legal_document_screen.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'package:GlobalFarm/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:iconsax/iconsax.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/constants/app_strings.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'email_login_screen.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String _qatarDialCode = '+974';
  static const int _qatarMaxLength = 8;
  static const String _qatarFlagUrl = 'https://flagcdn.com/w80/qa.png';

  static const Color _brand = AppColors.primary;
  static const Color _button = AppColors.primaryLight;
  static const Color _fieldFill = AppColors.softGreen;
  static const Color _fieldBorder = AppColors.softGreenBorder;
  static const Color _muted = Color(0xFF8D8D92);
  static const Color _footer = Color(0xFFB0B0B4);

  final GoogleAuthService googleAuthService = GoogleAuthService();
  final TextEditingController _phoneController = TextEditingController();
  bool _isAppleLoading = false;
  bool _isGoogleLoading = false;
  bool _isSendingOtp = false;
  late final TapGestureRecognizer _termsTap;
  late final TapGestureRecognizer _privacyTap;

  @override
  void initState() {
    super.initState();
    _termsTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(LegalDocumentType.termsOfUse);
    _privacyTap = TapGestureRecognizer()
      ..onTap = () => _openLegal(LegalDocumentType.privacyPolicy);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _termsTap.dispose();
    _privacyTap.dispose();
    super.dispose();
  }

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  void _openLegal(LegalDocumentType type) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LegalDocumentScreen(type: type)),
    );
  }

  Future<void> _sendOtp() async {
    if (_isSendingOtp) return;
    final phone = _phoneController.text.trim();
    if (!AuthService.isValidQatarPhone(phone)) {
      showAppSnackbar(
        context,
        message: _ar
            ? 'أدخل رقم هاتف قطري مكوّن من $_qatarMaxLength أرقام'
            : 'Enter a valid $_qatarMaxLength-digit Qatar phone number',
        type: SnackType.error,
      );
      return;
    }

    setState(() => _isSendingOtp = true);
    final otp = AuthService.generateOTP();
    if (!mounted) return;
    setState(() => _isSendingOtp = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => OTPScreen(
          countryCode: _qatarDialCode,
          phoneNumber: phone,
          generatedOTP: otp,
        ),
      ),
    );
  }

  Future<void> _googleSignIn() async {
    if (_isGoogleLoading) return;
    setState(() => _isGoogleLoading = true);
    try {
      User? user = await GoogleAuthService().signInWithGoogle();
      if (user != null) {
        int uid = 1000 + Random().nextInt(9000);
        int oid = 1000 + Random().nextInt(9000);

        await FlutterSecureStorage().write(
          key: "user_uid",
          value: uid.toString(),
        );
        await FlutterSecureStorage().write(
          key: "user_oid",
          value: oid.toString(),
        );
        await FlutterSecureStorage().write(
          key: 'social_name',
          value: user.displayName,
        );
        await FlutterSecureStorage().write(
          key: 'social_email',
          value: user.email,
        );
        await FlutterSecureStorage().write(
          key: 'social_avatar',
          value: user.photoURL,
        );
        await FlutterSecureStorage().write(key: "login_type", value: "Google");

        final String? playerId = OneSignal.User.pushSubscription.id;

        var result = await Dio().post(
          "${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecond}",
          data: FormData.fromMap({
            "action": "create_account",
            "uid": uid,
            "oid": oid,
            "name": user.displayName,
            "email": user.email,
            "phone": "",
            "player_id": playerId,
            "store_id": AppConfig.storeId,
            "login_type": "Google",
          }),
        );

        // ← أضف الـ print دي
        print('🔥 API Response: ${result.data}');

        if (result.data['success'] == true) {
          final data = result.data['data'];
          if (data is Map) {
            await AuthService.saveUserRoleAndStore(
              data['role']?.toString(),
              data['store_id']?.toString() ?? data['storeid']?.toString(),
            );
          }

          final userId = await FlutterSecureStorage().read(key: "user_uid");
          await AvatarService.uploadSocialPhotoIfNeeded(
            userId: userId ?? "",
            photoUrl: user.photoURL,
          );

          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => SplashScreen()),
            );
          }
        } else {
          if (result.data['success'] == false) {
            final existingUid = result.data['uid']['uid'].toString();
            final uidData = result.data['uid'];
            if (uidData is Map) {
              await AuthService.saveUserRoleAndStore(
                uidData['role']?.toString(),
                uidData['store_id']?.toString() ??
                    uidData['storeid']?.toString(),
              );
            }

            await FlutterSecureStorage().write(
              key: "user_uid",
              value: existingUid,
            );
            await FlutterSecureStorage().write(
              key: "user_oid",
              value: result.data['uid']['oid'].toString(),
            );
            await FlutterSecureStorage().write(
              key: 'social_name',
              value: user.displayName,
            );
            await FlutterSecureStorage().write(
              key: 'social_email',
              value: user.email,
            );
            await FlutterSecureStorage().write(
              key: 'social_avatar',
              value: user.photoURL,
            );
            await FlutterSecureStorage().write(
              key: "login_type",
              value: "Google",
            );

            final userId = await FlutterSecureStorage().read(key: "user_uid");
            await AvatarService.uploadSocialPhotoIfNeeded(
              userId: userId ?? "",
              photoUrl: user.photoURL,
            );

            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => SplashScreen()),
              );
            }
          } else {
            if (mounted) {
              showAppSnackbar(
                context,
                message: 'API Error: ${result.data}',
                type: SnackType.error,
              );
            }
          }
        }
      }
    } catch (e) {
      print('❌ Error: $e');
      showAppSnackbar(context, message: "Error: $e", type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  // ignore: unused_element
  Future<void> _appleSignIn() async {
    if (_isAppleLoading) return;

    setState(() {
      _isAppleLoading = true;
    });

    try {
      final result = await AppleAuthService.signIn();
      if (result == null) {
        return;
      }

      await AppleAuthService.saveSession(result);

      // Apple Sign In does not provide a profile photo URL — skip upload.
      final userId = await FlutterSecureStorage().read(key: "user_uid");
      await AvatarService.uploadSocialPhotoIfNeeded(
        userId: userId ?? "",
        photoUrl: null,
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SplashScreen()),
        );
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code != AuthorizationErrorCode.canceled && mounted) {
        showAppSnackbar(context, message: "Error: $e", type: SnackType.error);
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, message: "Error: $e", type: SnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isAppleLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  onPressed: () {
                    if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                      return;
                    }
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const MainShell()),
                      (_) => false,
                    );
                  },
                  icon: const Icon(
                    Iconsax.arrow_right_3,
                    color: Color(0xFF1C1C1E),
                    size: 28,
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minHeight: constraints.maxHeight),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(28),
                                boxShadow: [
                                  BoxShadow(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.18),
                                    blurRadius: 28,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: AppColors.softGreen
                                        .withValues(alpha: 0.95),
                                    blurRadius: 36,
                                    spreadRadius: 10,
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.all(14),
                              child: Image.asset(
                                'assets/images/Logo.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 18),
                            Text(
                              AppStrings.appName,
                              style: GoogleFonts.cairo(
                                fontSize: 32,
                                height: 1,
                                fontWeight: FontWeight.w800,
                                color: _brand,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              _ar
                                  ? 'مرحباً بك في عالم التسوق الذكي'
                                  : 'Welcome to the smart shopping world',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 16,
                                color: _muted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 36),
                            _buildPhoneField(),
                            const SizedBox(height: 12),
                            Text(
                              _ar
                                  ? 'أدخل رقم هاتفك لاستلام رمز التحقق'
                                  : 'Enter your phone number to receive a code',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.cairo(
                                fontSize: 13.5,
                                color: const Color(0xFF9A9AA0),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 18),
                            _buildSendButton(),
                            const SizedBox(height: 28),
                            _buildOrDivider(),
                            const SizedBox(height: 22),
                            _buildSocialRow(),
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
                child: _buildFooter(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: _fieldFill,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _fieldBorder),
      ),
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: Image.network(
                _qatarFlagUrl,
                width: 30,
                height: 20,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox(width: 30, height: 20),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '974+',
              textDirection: TextDirection.ltr,
              style: GoogleFonts.cairo(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF3A3A3C),
              ),
            ),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: Color(0xFF3A3A3C),
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              height: 22,
              color: AppColors.softGreenBorder,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _phoneController,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: GoogleFonts.cairo(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF2C2C2E),
                  letterSpacing: 1,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(_qatarMaxLength),
                ],
                decoration: InputDecoration(
                  isCollapsed: true,
                  border: InputBorder.none,
                  hintText: _ar ? 'رقم الجوال' : 'Mobile number',
                  hintStyle: GoogleFonts.cairo(
                    fontSize: 15,
                    color: const Color(0xFFB4B4BA),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _isSendingOtp ? null : _sendOtp,
        style: ElevatedButton.styleFrom(
          backgroundColor: _button,
          disabledBackgroundColor: _button,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        child: _isSendingOtp
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
                    _ar ? 'إرسال رمز التحقق' : 'Send verification code',
                    style: GoogleFonts.cairo(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Iconsax.sms, size: 22, color: Colors.white),
                ],
              ),
      ),
    );
  }

  Widget _buildOrDivider() {
    return Row(
      children: [
        const Expanded(child: Divider(color: Color(0xFFE6E6EA), thickness: 1)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            _ar ? 'أو' : 'or',
            style: GoogleFonts.cairo(
              fontSize: 14,
              color: _footer,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const Expanded(child: Divider(color: Color(0xFFE6E6EA), thickness: 1)),
      ],
    );
  }

  Widget _buildSocialRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      textDirection: TextDirection.ltr,
      children: [
        _CircleAction(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmailLoginScreen()),
            );
          },
          child: const Icon(
            Iconsax.sms,
            color: _brand,
            size: 26,
          ),
        ),
        const SizedBox(width: 18),
        _CircleAction(
          onTap: _isGoogleLoading ? null : _googleSignIn,
          child: _isGoogleLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: _brand),
                )
              : Image.asset(
                  'assets/images/social/google.png',
                  width: 26,
                  height: 26,
                ),
        ),
      ],
    );
  }

  Widget _buildFooter() {
    final style = GoogleFonts.cairo(
      fontSize: 12,
      height: 1.7,
      color: _footer,
      fontWeight: FontWeight.w500,
    );
    return Text.rich(
      TextSpan(
        style: style,
        children: _ar
            ? [
                const TextSpan(text: 'بالمتابعة، أنت توافق على '),
                TextSpan(text: 'شروط الاستخدام', recognizer: _termsTap),
                const TextSpan(text: ' و'),
                TextSpan(text: 'سياسة الخصوصية', recognizer: _privacyTap),
              ]
            : [
                const TextSpan(text: 'By continuing, you agree to the '),
                TextSpan(text: 'Terms of Use', recognizer: _termsTap),
                const TextSpan(text: ' and '),
                TextSpan(text: 'Privacy Policy', recognizer: _privacyTap),
              ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

class _CircleAction extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;

  const _CircleAction({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.softGreen,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 58, height: 58, child: Center(child: child)),
      ),
    );
  }
}
