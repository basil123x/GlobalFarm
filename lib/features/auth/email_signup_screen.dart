import 'dart:io';
import 'package:GlobalFarm/features/splash/splash_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/services/s3_upload_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class EmailSignupScreen extends StatefulWidget {
  final String email;
  final String password;

  const EmailSignupScreen({
    super.key,
    required this.email,
    required this.password,
  });

  @override
  State<EmailSignupScreen> createState() => _EmailSignupScreenState();
}

class _EmailSignupScreenState extends State<EmailSignupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedImage;
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
    _passwordController.text = widget.password;
  }

  Future<void> _pickImage() async {
    final lang = LocalizationService.instance.currentLanguage;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError(
        lang == 'ar' ? 'حدث خطأ أثناء اختيار الصورة' : 'Error selecting image',
      );
    }
  }

  Future<void> _takePhoto() async {
    final lang = LocalizationService.instance.currentLanguage;
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      _showError(
        lang == 'ar' ? 'حدث خطأ أثناء التقاط الصورة' : 'Error taking photo',
      );
    }
  }

  void _showImagePickerOptions() {
    final lang = LocalizationService.instance.currentLanguage;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.lightGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              lang == 'ar' ? 'اختر صورة الملف الشخصي' : 'Choose profile photo',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.camera, color: Color(0xFF6366F1)),
              ),
              title: Text(lang == 'ar' ? 'التقاط صورة' : 'Take photo'),
              subtitle: Text(lang == 'ar' ? 'استخدم الكاميرا' : 'Use camera'),
              onTap: () {
                Navigator.pop(context);
                _takePhoto();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.gallery, color: Color(0xFF8B5CF6)),
              ),
              title: Text(
                lang == 'ar' ? 'اختيار من المعرض' : 'Choose from gallery',
              ),
              subtitle: Text(
                lang == 'ar' ? 'اختر صورة موجودة' : 'Choose existing photo',
              ),
              onTap: () {
                Navigator.pop(context);
                _pickImage();
              },
            ),
            if (_selectedImage != null)
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Iconsax.trash, color: AppColors.error),
                ),
                title: Text(lang == 'ar' ? 'حذف الصورة' : 'Remove photo'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _selectedImage = null;
                  });
                },
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  String _hashPassword(String password) {
    var bytes = utf8.encode(password);
    var digest = sha256.convert(bytes);
    return digest.toString();
  }

  bool _validateInputs() {
    final lang = LocalizationService.instance.currentLanguage;

    if (_nameController.text.trim().isEmpty) {
      _showError(
        lang == 'ar'
            ? 'يرجى إدخال الاسم الكامل'
            : 'Please enter your full name',
      );
      return false;
    }

    if (_nameController.text.trim().length < 3) {
      _showError(
        lang == 'ar'
            ? 'الاسم يجب أن يكون 3 أحرف على الأقل'
            : 'Name must be at least 3 characters',
      );
      return false;
    }

    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(_emailController.text)) {
      _showError(
        lang == 'ar'
            ? 'يرجى إدخال بريد إلكتروني صحيح'
            : 'Please enter a valid email',
      );
      return false;
    }

    if (_passwordController.text.length < 8) {
      _showError(
        lang == 'ar'
            ? 'كلمة المرور يجب أن تكون 8 أحرف على الأقل'
            : 'Password must be at least 8 characters',
      );
      return false;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError(
        lang == 'ar'
            ? 'كلمة المرور وتأكيد كلمة المرور غير متطابقين'
            : 'Passwords do not match',
      );
      return false;
    }

    return true;
  }

  Future<void> _createAccount() async {
    final lang = LocalizationService.instance.currentLanguage;
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final String? playerId = OneSignal.User.pushSubscription.id;

      final response = await Dio().post(
        "${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap({
          "action": "create_email_account",
          "name": _nameController.text.trim(),
          "email": _emailController.text,
          "password": _passwordController.text,
          "player_id": playerId,
          "avatar_url": "",
          "login_type": "Email",
          "store_id": AppConfig.storeId,
        }),
      );

      if (response.data["success"] == true) {
        const storage = FlutterSecureStorage();
        final uid = response.data["data"]["id"]?.toString() ?? "";

        await storage.write(key: "user_uid", value: uid);
        await storage.write(
          key: "user_oid",
          value: response.data["data"]["oid"]?.toString() ?? "",
        );
        await storage.write(
          key: "user_email",
          value: response.data["data"]["email"]?.toString() ?? "",
        );
        await storage.write(
          key: "user_name",
          value: response.data["data"]["name"]?.toString() ?? "",
        );
        await storage.write(key: "login_type", value: "Email");

        if (_selectedImage != null && uid.isNotEmpty) {
          final storedUid = await storage.read(key: "user_uid");
          final avatarUrl = await S3UploadService.uploadProfileImage(
            userId: storedUid ?? uid,
            filePath: _selectedImage!.path,
          );

          if (avatarUrl != null) {
            await AuthService.updateUserAvatarUrl(
              uid: storedUid ?? uid,
              avatarUrl: avatarUrl,
            );
            await AuthService.updateProfileImage(avatarUrl);
          }
        }

        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => SplashScreen()),
            (route) => false,
          );
        }
      } else {
        setState(() {
          _isLoading = false;
        });
        _showError(
          response.data['message'] ??
              (lang == 'ar'
                  ? 'حدث خطأ أثناء إنشاء الحساب'
                  : 'Error creating account'),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showError(
        lang == 'ar' ? 'حدث خطأ أثناء إنشاء الحساب' : 'Error creating account',
      );
    }
  }

  void _showError(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
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
            title: Text(
              lang == 'ar' ? 'إنشاء حساب جديد' : 'Create Account',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  GestureDetector(
                    onTap: _showImagePickerOptions,
                    child: Stack(
                      children: [
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: _selectedImage == null
                                ? const LinearGradient(
                                    colors: [
                                      Color(0xFF6366F1),
                                      Color(0xFF8B5CF6),
                                    ],
                                  )
                                : null,
                            image: _selectedImage != null
                                ? DecorationImage(
                                    image: FileImage(_selectedImage!),
                                    fit: BoxFit.cover,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: _selectedImage == null
                              ? const Icon(
                                  Iconsax.user,
                                  size: 50,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 3),
                            ),
                            child: const Icon(
                              Iconsax.camera,
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    lang == 'ar' ? 'اضغط لإضافة صورة' : 'Tap to add photo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondaryColor(context),
                    ),
                  ),
                  const SizedBox(height: 40),
                  _buildTextField(
                    controller: _nameController,
                    label: lang == 'ar' ? 'الاسم الكامل' : 'Full Name',
                    icon: Iconsax.user,
                    hint: lang == 'ar'
                        ? 'أدخل اسمك الكامل'
                        : 'Enter your full name',
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _emailController,
                    label: lang == 'ar' ? 'البريد الإلكتروني' : 'Email',
                    icon: Iconsax.sms,
                    hint: 'example@email.com',
                    keyboardType: TextInputType.emailAddress,
                    readOnly: true,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _passwordController,
                    label: lang == 'ar' ? 'كلمة المرور' : 'Password',
                    icon: Iconsax.lock,
                    hint: '••••••••',
                    obscureText: !_isPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Iconsax.eye : Iconsax.eye_slash,
                        color: AppColors.textSecondaryColor(context),
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    readOnly: true,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _confirmPasswordController,
                    label: lang == 'ar'
                        ? 'تأكيد كلمة المرور'
                        : 'Confirm Password',
                    icon: Iconsax.lock_1,
                    hint: '••••••••',
                    obscureText: !_isConfirmPasswordVisible,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isConfirmPasswordVisible
                            ? Iconsax.eye
                            : Iconsax.eye_slash,
                        color: AppColors.textSecondaryColor(context),
                      ),
                      onPressed: () {
                        setState(() {
                          _isConfirmPasswordVisible =
                              !_isConfirmPasswordVisible;
                        });
                      },
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _createAccount,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: const Color(
                          0xFF6366F1,
                        ).withValues(alpha: 0.3),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Iconsax.tick_circle, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  lang == 'ar'
                                      ? 'إنشاء الحساب'
                                      : 'Create Account',
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    lang == 'ar'
                        ? 'بالمتابعة، أنت توافق على شروط الاستخدام وسياسة الخصوصية'
                        : 'By continuing, you agree to our Terms and Privacy Policy',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String hint,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            obscureText: obscureText,
            readOnly: readOnly,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: AppColors.textHint),
              prefixIcon: Icon(icon, color: const Color(0xFF6366F1)),
              suffixIcon: suffixIcon,
              filled: true,
              fillColor: readOnly
                  ? AppColors.lightGrey.withValues(alpha: 0.3)
                  : Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.lightGrey, width: 1),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: AppColors.lightGrey, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF6366F1),
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
