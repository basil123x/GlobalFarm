import 'dart:io';
// TODO: Phone update feature - requires OTP service subscription
// import 'dart:math';
//
// import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
// TODO: Phone update feature - requires OTP service subscription
// import 'package:pinput/pinput.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/s3_upload_service.dart';
import 'package:GlobalFarm/core/utils/avatar_url_util.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class EditProfileScreen extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentType;
  final String currentAvatar;
  final String currentUid;

  const EditProfileScreen({
    super.key,
    required this.currentName,
    required this.currentPhone,
    required this.currentType,
    required this.currentAvatar,
    required this.currentUid,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  static const _storage = FlutterSecureStorage();

  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  // TODO: Phone update feature - requires OTP service subscription
  // final _phoneController = TextEditingController();
  // final _otpController = TextEditingController();

  File? _selectedImage;
  String? _uploadedImageUrl;
  String? _userUid;
  String? _avatarBaseUrl;
  int _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  // TODO: Phone update feature - requires OTP service subscription
  // bool _showOtpField = false;
  // bool _otpVerified = false;
  // String _generatedOtp = '';
  // String? _otpPhoneNumber;
  String _originalName = '';
  String _originalPhone = '';
  bool _nameChanged = false;
  // bool _phoneChanged = false;
  bool _imageChanged = false;
  // String _loginType = '';

  bool get _hasAnyChanges => _nameChanged || _imageChanged;

  // TODO: Phone update feature - requires OTP service subscription
  /*
  void _resetOtpState() {
    _showOtpField = false;
    _otpVerified = false;
    _generatedOtp = '';
    _otpPhoneNumber = null;
    _otpController.clear();
  }

  bool get _phoneRequiresOtp {
    final phone = _phoneController.text.trim();
    return phone.isNotEmpty && phone != _originalPhone.trim();
  }
  */

  static const _avatarPlaceholder = Icon(
    Iconsax.user,
    size: 48,
    color: Colors.grey,
  );

  @override
  void initState() {
    super.initState();
    _loadUserProfileFromApi();
    // TODO: Phone update feature - requires OTP service subscription
    // _loadLoginType();

    _nameController.addListener(_onFieldsChanged);
    // _phoneController.addListener(_onFieldsChanged);
  }

  // TODO: Phone update feature - requires OTP service subscription
  /*
  Future<void> _loadLoginType() async {
    final loginType = await _storage.read(key: "login_type") ?? "";
    if (!mounted) return;
    setState(() => _loginType = loginType);
  }
  */

  void _applyProfileFields(String name, String phone) {
    if (!mounted) return;
    setState(() {
      _originalName = name;
      _originalPhone = phone;
      _nameController.text = name;
      // _phoneController.text = phone;
      _nameChanged = false;
      // _phoneChanged = false;
    });
  }

  void _applyUserIdentity({
    required String uid,
    String? oid,
    required String name,
    required String phone,
  }) {
    if (!mounted) return;
    setState(() {
      _userUid = uid.isNotEmpty ? uid : null;
      _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;
      _originalName = name;
      _originalPhone = phone;
      _nameController.text = name;
      // _phoneController.text = phone;
      _nameChanged = false;
      // _phoneChanged = false;
      if (_userUid != null && _userUid!.isNotEmpty) {
        _avatarBaseUrl = AvatarUrlUtil.displayUrl(
          _userUid!,
          timestamp: _avatarCacheTimestamp,
        );
      }
    });
  }

  Future<void> _loadUserProfileFromApi() async {
    final email =
        await _storage.read(key: "user_email") ??
        await _storage.read(key: "social_email");
    final fallbackPhone = widget.currentPhone.isNotEmpty
        ? widget.currentPhone
        : (await AuthService.getCurrentPhone() ?? "");

    try {
      final requestData = <String, dynamic>{"action": "get_user_details"};
      if (email != null && email.isNotEmpty) {
        requestData["email"] = email;
      } else if (fallbackPhone.isNotEmpty) {
        requestData["phone"] = fallbackPhone;
      } else {
        _applyProfileFields(widget.currentName, widget.currentPhone);
        return;
      }

      final response = await Dio().post(
        "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap(requestData),
      );

      if (response.data["success"] == true && response.data["data"] != null) {
        final data = response.data["data"] as Map<String, dynamic>;
        final uid = data["id"]?.toString() ?? "";
        final oid = data["oid"]?.toString() ?? "";
        final name = data["name"]?.toString() ?? widget.currentName;
        final phone = data["phone"]?.toString() ?? "";

        await AuthService.syncSessionFromApi(
          uid: uid,
          oid: oid,
          name: name,
          phone: phone,
        );

        _applyUserIdentity(uid: uid, oid: oid, name: name, phone: phone);
      } else {
        _applyProfileFields(
          widget.currentName,
          fallbackPhone.isNotEmpty ? fallbackPhone : widget.currentPhone,
        );
      }
    } catch (e) {
      print("Failed to load user profile: $e");
      _applyProfileFields(
        widget.currentName,
        fallbackPhone.isNotEmpty ? fallbackPhone : widget.currentPhone,
      );
    }
  }

  void _onFieldsChanged() {
    setState(() {
      _nameChanged = _nameController.text.trim() != _originalName.trim();
    });
  }

  // TODO: Phone update feature - requires OTP service subscription
  /*
  void _onFieldsChanged() {
    final phone = _phoneController.text.trim();
    final phoneChanged = phone != _originalPhone.trim();

    if (_otpPhoneNumber != null && phone != _otpPhoneNumber) {
      _resetOtpState();
    } else if (!phoneChanged) {
      _resetOtpState();
    }

    setState(() {
      _nameChanged = _nameController.text.trim() != _originalName.trim();
      _phoneChanged = phoneChanged;
    });
  }
  */

  @override
  void dispose() {
    _nameController.dispose();
    // TODO: Phone update feature - requires OTP service subscription
    // _phoneController.dispose();
    // _otpController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              "اختر مصدر الصورة",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            _buildImageSourceTile(
              icon: Iconsax.camera,
              title: "الكاميرا",
              subtitle: "استخدم الكاميرا",
              onTap: () async {
                Navigator.pop(context);
                await _selectImage(ImageSource.camera);
              },
            ),
            _buildImageSourceTile(
              icon: Iconsax.gallery,
              title: "المعرض",
              subtitle: "اختر صورة موجودة",
              onTap: () async {
                Navigator.pop(context);
                await _selectImage(ImageSource.gallery);
              },
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
          ],
        ),
      ),
    );
  }

  Widget _buildImageSourceTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: AppColors.primary, size: 24),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: context.appTextPrimary,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }

  Future<void> _selectImage(ImageSource source) async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
          _isUploadingImage = true;
        });

        await _uploadAvatarToS3(File(image.path));
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'فشل في اختيار الصورة: $e',
        type: SnackType.error,
      );
    }
  }

  Future<void> _uploadAvatarToS3(File imageFile) async {
    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final userId = _userUid;
      if (userId == null || userId.isEmpty) {
        throw Exception('تعذر تحديد المستخدم');
      }

      final avatarUrl = await S3UploadService.uploadProfileImage(
        userId: userId,
        filePath: imageFile.path,
        onProgress: (progress) {
          print(
            "Uploading profile image: ${(progress * 100).toStringAsFixed(1)}%",
          );
        },
      );

      if (avatarUrl != null) {
        await AuthService.updateUserAvatarUrl(
          uid: userId,
          avatarUrl: avatarUrl,
        );
        await AuthService.updateProfileImage(avatarUrl);

        setState(() {
          _avatarCacheTimestamp = timestamp;
          _uploadedImageUrl = AvatarUrlUtil.withCacheBust(
            avatarUrl,
            timestamp: timestamp,
          );
          _isUploadingImage = false;
          _imageChanged = true;
        });

        if (mounted) {
          showAppSnackbar(
            context,
            message: 'تم رفع الصورة بنجاح',
            type: SnackType.success,
          );
        }
      } else {
        setState(() {
          _isUploadingImage = false;
          _selectedImage = null;
          _imageChanged = false;
        });
        throw Exception('فشل في رفع الصورة');
      }
    } catch (e) {
      setState(() {
        _isUploadingImage = false;
        _selectedImage = null;
        _imageChanged = false;
      });

      if (mounted) {
        showAppSnackbar(
          context,
          message: 'فشل في رفع الصورة: $e',
          type: SnackType.error,
        );
      }
    }
  }

  Widget _buildAvatarImage() {
    const size = 114.0;

    if (_selectedImage != null) {
      return ClipOval(
        child: Image.file(
          _selectedImage!,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    }

    final url = _uploadedImageUrl;
    if (url != null) {
      return ClipOval(
        child: Image.network(
          url,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildSmartAvatar(size),
        ),
      );
    }

    return _buildSmartAvatar(size);
  }

  Widget _buildSmartAvatar(double size) {
    final userId = _userUid ?? "";
    if (userId.isEmpty) {
      return Container(
        width: size,
        height: size,
        color: Colors.grey[300],
        alignment: Alignment.center,
        child: const CircularProgressIndicator(strokeWidth: 2),
      );
    }

    return SmartAvatarWidget(
      userId: userId,
      name: _nameController.text.isNotEmpty
          ? _nameController.text
          : widget.currentName,
      size: size,
      cacheTimestamp: _avatarCacheTimestamp,
      loadSocialFromStorage: true,
      fallbackUrl: widget.currentAvatar.isNotEmpty
          ? widget.currentAvatar
          : null,
    );
  }

  // TODO: Phone update feature - requires OTP service subscription
  /*
  Future<bool> _checkPhoneUniqueness(String phone) async {
    try {
      final currentUid = _userUid;
      if (currentUid == null || currentUid.isEmpty) {
        throw Exception("تعذر تحديد المستخدم");
      }

      final response = await Dio().post(
        "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap({
          "action": "get_user_details",
          "phone": phone,
        }),
      );

      if (response.data["success"] == true && response.data["data"] != null) {
        final returnedUid =
            response.data["data"]["id"]?.toString() ?? "";
        if (returnedUid != currentUid) {
          _showErrorSnack("رقم الهاتف مستخدم بالفعل");
          return false;
        }
      }

      return true;
    } catch (e) {
      _showErrorSnack("حدث خطأ أثناء التحقق من رقم الهاتف");
      return false;
    }
  }

  void _showPhoneEmptyDialog() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: "خطأ",
      desc: "رقم الهاتف لا يمكن أن يكون فارغاً",
      btnOkText: "حسناً",
      btnOkOnPress: () {},
    ).show();
  }

  void _generateLocalOtp(String phone) {
    final otp = (Random().nextInt(900000) + 100000).toString();
    setState(() {
      _generatedOtp = otp;
      _otpPhoneNumber = phone;
      _showOtpField = true;
      _otpVerified = false;
      _otpController.clear();
    });

    showAppSnackbar(
      context,
      message: "كود التحقق: $otp",
      type: SnackType.info,
    );
  }

  bool _verifyLocalOtp() {
    if (_otpController.text.trim() != _generatedOtp) {
      _showErrorSnack("الكود غير صحيح");
      return false;
    }
    setState(() => _otpVerified = true);
    return true;
  }

  Widget _buildOtpPinPut() {
    const defaultPinTheme = PinTheme(
      width: 45,
      height: 55,
      textStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.primary,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFFE0E0E0)),
        ),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyDecorationWith(
      border: Border.all(color: AppColors.primary, width: 2),
      borderRadius: BorderRadius.circular(12),
    );

    return Directionality(
      textDirection: TextDirection.ltr,
      child: Pinput(
        length: 6,
        controller: _otpController,
        keyboardType: TextInputType.number,
        defaultPinTheme: defaultPinTheme,
        focusedPinTheme: focusedPinTheme,
        submittedPinTheme: focusedPinTheme,
        onCompleted: (_) => setState(() {}),
      ),
    );
  }
  */

  void _showErrorSnack(String message) {
    showAppSnackbar(context, message: message, type: SnackType.error);
  }

  Map<String, dynamic> _buildPopResult() {
    final name = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : _originalName;

    return {
      'success': true,
      'name': name,
      'phone': _originalPhone,
      'avatar':
          _uploadedImageUrl ??
          (_userUid != null
              ? AvatarUrlUtil.displayUrl(
                  _userUid!,
                  timestamp: _avatarCacheTimestamp,
                )
              : widget.currentAvatar),
    };
  }

  Future<void> _saveProfile() async {
    if (!_hasAnyChanges) return;

    if (_isUploadingImage) {
      showAppSnackbar(
        context,
        message: 'يرجى الانتظار حتى يتم رفع الصورة',
        type: SnackType.warning,
      );
      return;
    }

    if (_imageChanged && !_nameChanged) {
      Navigator.pop(context, _buildPopResult());
      return;
    }

    final name = _nameController.text.trim();

    // TODO: Phone update feature - requires OTP service subscription
    /*
    final phone = _phoneController.text.trim();

    final loginType =
        _loginType.isNotEmpty
            ? _loginType
            : (await _storage.read(key: "login_type") ?? "");

    if (loginType == "Phone" && phone.isEmpty) {
      _showPhoneEmptyDialog();
      return;
    }

    if (_phoneChanged && phone.isEmpty) {
      _showErrorSnack("رقم الهاتف مطلوب");
      return;
    }

    if (_phoneChanged) {
      if (!AuthService.isValidQatarPhone(phone)) {
        _showErrorSnack("رقم الهاتف غير صحيح. يجب أن يكون 8 أرقام");
        return;
      }

      if (_generatedOtp.isEmpty || _otpPhoneNumber != phone) {
        setState(() => _isLoading = true);
        final isUnique = await _checkPhoneUniqueness(phone);
        if (mounted) setState(() => _isLoading = false);
        if (!isUnique) return;

        _generateLocalOtp(phone);
        return;
      }

      if (!_otpVerified) {
        if (_otpController.text.trim().length != 6) {
          _showErrorSnack("يرجى إدخال كود التحقق المكون من 6 أرقام");
          return;
        }
        if (!_verifyLocalOtp()) return;
      }
    } else if (phone.isNotEmpty && !AuthService.isValidQatarPhone(phone)) {
      _showErrorSnack("رقم الهاتف غير صحيح. يجب أن يكون 8 أرقام");
      return;
    }
    */

    setState(() => _isLoading = true);

    try {
      final currentUid = _userUid;
      if (currentUid == null || currentUid.isEmpty) {
        throw Exception('تعذر تحديد المستخدم');
      }

      final nameToSend = name.isNotEmpty ? name : null;

      final result = await ApiService.updateUserProfile(
        uid: currentUid,
        name: nameToSend,
        phone: null,
      );

      if (result['success'] == true) {
        if (name.isNotEmpty) {
          await AuthService.updateUserName(name);
        }

        if (mounted) {
          setState(() {
            if (name.isNotEmpty) _originalName = name;
            _nameChanged = false;
            // _phoneChanged = false;
            // _resetOtpState();
          });

          showAppSnackbar(
            context,
            message: result['message'] ?? 'تم حفظ التغييرات بنجاح',
            type: SnackType.success,
          );

          Navigator.pop(context, _buildPopResult());
        }
      } else {
        if (mounted) {
          showAppSnackbar(
            context,
            message: result['error'] ?? 'فشل في التحديث',
            type: SnackType.error,
          );
        }
      }
    } catch (e) {
      if (mounted) {
        showAppSnackbar(context, message: 'خطأ: $e', type: SnackType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appBackground,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Iconsax.arrow_square_left, color: context.appTextPrimary),
        ),
        title: Text(
          'تعديل الملف الشخصي',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile Picture Section
              GestureDetector(
                onTap: _isUploadingImage ? null : _pickImage,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.primary, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      _buildAvatarImage(),
                      // Loading overlay while uploading
                      if (_isUploadingImage)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 3,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _isUploadingImage
                                ? Colors.grey
                                : AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: context.appSurface, width: 2),
                          ),
                          child: Icon(
                            _isUploadingImage
                                ? Iconsax.refresh
                                : Iconsax.camera,
                            color: AppColors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // Name Field
              _buildTextField(
                controller: _nameController,
                label: 'الاسم',
                icon: Iconsax.user,
              ),

              // TODO: Phone update feature - requires OTP service subscription
              /*
              const SizedBox(height: 20),

              // Phone Field
              _buildTextField(
                controller: _phoneController,
                label: 'رقم الهاتف',
                icon: Iconsax.call,
                keyboardType: TextInputType.phone,
              ),

              AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: _showOtpField
                    ? Column(
                        children: [
                          const SizedBox(height: 24),
                          const Text(
                            "رمز التحقق",
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildOtpPinPut(),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
              */
              const SizedBox(height: 40),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _hasAnyChanges && !_isLoading && !_isUploadingImage
                      ? _saveProfile
                      : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: context.isDarkMode
                        ? AppColors.darkElevated
                        : Colors.grey.shade300,
                    disabledForegroundColor: context.appTextSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'حفظ التغييرات',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(color: context.appTextPrimary),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: AppColors.primary.withValues(alpha: 0.85),
        ),
        prefixIcon: Icon(icon, color: AppColors.primary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.isDarkMode
            ? AppColors.darkElevated
            : AppColors.primary.withValues(alpha: 0.08),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: context.appBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: context.appBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }
}
