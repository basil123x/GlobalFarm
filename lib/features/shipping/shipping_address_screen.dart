import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/models/cart_model.dart';
import 'package:GlobalFarm/core/models/shipping_address_model.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/features/payment/payment_methods_screen.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class ShippingAddressScreen extends StatefulWidget {
  final String userId;
  final String uid;
  final List<CartItemModel> cartItems;
  final double totalAmount;

  const ShippingAddressScreen({
    super.key,
    required this.userId,
    required this.uid,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<ShippingAddressScreen> createState() => _ShippingAddressScreenState();
}

class _ShippingAddressScreenState extends State<ShippingAddressScreen> {
  List<ShippingAddressModel> _addresses = [];
  bool _isLoading = true;
  bool _isLocating = false;
  bool _showAddForm = false;
  int? _selectedAddressIndex;

  // Form controllers
  final _fullnameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryController = TextEditingController();
  final _cityController = TextEditingController();
  final _zoneController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _prefillUserData();
    _loadAddresses();
  }

  Future<void> _prefillUserData() async {
    const storage = FlutterSecureStorage();

    final name = await AuthService.getCurrentName() ?? '';
    final phone = await AuthService.getCurrentPhone() ?? '';
    final email =
        await storage.read(key: 'user_email') ??
        await storage.read(key: 'social_email') ??
        '';

    if (!mounted) return;

    setState(() {
      if (name.isNotEmpty) _fullnameController.text = name;
      if (phone.isNotEmpty) _mobileController.text = phone;
      if (email.isNotEmpty) _emailController.text = email;
      if (_countryController.text.isEmpty) _countryController.text = 'Qatar';
    });
  }

  @override
  void dispose() {
    _fullnameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _cityController.dispose();
    _zoneController.dispose();
    _streetController.dispose();
    _buildingController.dispose();
    super.dispose();
  }

  Future<void> _loadAddresses() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final result = await ApiService.getShippingAddresses(uid: widget.uid);

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _addresses = data
              .map((item) => ShippingAddressModel.fromJson(item))
              .toList();
          _isLoading = false;
          if (_addresses.isNotEmpty) {
            _selectedAddressIndex = 0;
            _showAddForm = false;
          } else {
            _selectedAddressIndex = null;
            _showAddForm = true;
          }
        });
      } else {
        setState(() {
          _isLoading = false;
          if (_addresses.isEmpty) _showAddForm = true;
        });
      }
    } catch (e) {
      print('Error loading addresses: $e');
      setState(() {
        _isLoading = false;
        if (_addresses.isEmpty) _showAddForm = true;
      });
    }
  }

  Future<void> _getLocationAndFill() async {
    setState(() => _isLocating = true);

    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (!mounted) return;
          showAppSnackbar(
            context,
            message: 'يجب السماح بالوصول للموقع',
            type: SnackType.warning,
          );
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        showAppSnackbar(
          context,
          message: 'يجب السماح بالوصول للموقع من الإعدادات',
          type: SnackType.warning,
        );
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      final url =
          'https://nominatim.openstreetmap.org/reverse'
          '?lat=${position.latitude}'
          '&lon=${position.longitude}'
          '&format=json'
          '&accept-language=ar';

      final response = await Dio().get(
        url,
        options: Options(headers: {'User-Agent': 'MartItApp/1.0'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final address = data['address'] ?? {};

        if (!mounted) return;
        setState(() {
          final city =
              address['city'] ??
              address['town'] ??
              address['village'] ??
              address['municipality'] ??
              '';
          if (city.isNotEmpty) _cityController.text = city.toString();

          final country = address['country'] ?? 'Qatar';
          _countryController.text = country.toString();

          final zone =
              address['suburb'] ??
              address['neighbourhood'] ??
              address['quarter'] ??
              address['district'] ??
              '';
          if (zone.isNotEmpty) _zoneController.text = zone.toString();

          final street = address['road'] ?? address['street'] ?? '';
          if (street.isNotEmpty) _streetController.text = street.toString();

          final building = address['house_number'] ?? '';
          if (building.isNotEmpty) {
            _buildingController.text = building.toString();
          }
        });

        if (!mounted) return;
        showAppSnackbar(
          context,
          message: 'تم تحديد موقعك بنجاح ✓',
          type: SnackType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: 'تعذر تحديد الموقع، أدخل العنوان يدوياً',
        type: SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  bool _validateForm() {
    final required = [
      (_fullnameController, 'الاسم الكامل'),
      (_mobileController, 'رقم الهاتف'),
      (_countryController, 'الدولة'),
      (_cityController, 'المدينة'),
      (_zoneController, 'رقم المنطقة'),
      (_streetController, 'رقم الشارع'),
      (_buildingController, 'رقم المبنى'),
    ];

    for (final (controller, name) in required) {
      if (controller.text.trim().isEmpty) {
        showAppSnackbar(
          context,
          message: '$name مطلوب',
          type: SnackType.warning,
        );
        return false;
      }
    }
    return true;
  }

  Future<void> _addAddress() async {
    if (!_validateForm()) return;
    if (!_formKey.currentState!.validate()) return;

    try {
      final oid = await AuthService.getCurrentOID();

      final result = await ApiService.addShippingAddress(
        fullname: _fullnameController.text,
        mobile: _mobileController.text,
        email: _emailController.text,
        country: _countryController.text,
        city: _cityController.text,
        zoneNumber: _zoneController.text,
        streetNumber: _streetController.text,
        buildingNumber: _buildingController.text,
        uid: widget.uid,
        oid: oid ?? '',
      );

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: 'تم إضافة العنوان بنجاح',
          type: SnackType.success,
        );

        _clearForm();
        setState(() {
          _showAddForm = false;
        });
        _loadAddresses();
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? 'فشل في إضافة العنوان',
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: 'حدث خطأ أثناء إضافة العنوان',
        type: SnackType.error,
      );
    }
  }

  void _clearForm() {
    _fullnameController.clear();
    _mobileController.clear();
    _emailController.clear();
    _countryController.clear();
    _cityController.clear();
    _zoneController.clear();
    _streetController.clear();
    _buildingController.clear();
    _prefillUserData();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            'عناوين الشحن',
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Add New Address Button
                          if (!_showAddForm)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 20),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _showAddForm = true;
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                icon: const Icon(Iconsax.add_circle),
                                label: const Text(
                                  'إضافة عنوان جديد',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),

                          // Add Address Form
                          if (_showAddForm) _buildAddressForm(),

                          // Existing Addresses
                          if (_addresses.isNotEmpty && !_showAddForm) ...[
                            Text(
                              'العناوين المحفوظة:',
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ..._addresses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final address = entry.value;
                              return _buildAddressCard(address, index);
                            }),
                            if (_addresses.length > 1)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 0,
                                  vertical: 8,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Iconsax.info_circle,
                                      size: 14,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'لديك ${_addresses.length - 1} عنوان آخر، اضغط لتغيير العنوان',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  // Continue Button
                  if (!_showAddForm) _buildContinueButton(),
                ],
              ),
      ),
    );
  }

  Widget _buildAddressForm() {
    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'إضافة عنوان جديد',
                  style: TextStyle(
                    // color: Colors.white,
                    color: context.appTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  onPressed: _addresses.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _showAddForm = false;
                            _clearForm();
                          });
                        },
                  icon: Icon(
                    Iconsax.close_circle,
                    color: _addresses.isEmpty ? Colors.grey : Colors.red,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            ElevatedButton.icon(
              onPressed: _isLocating ? null : _getLocationAndFill,
              icon: _isLocating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.my_location),
              label: Text(
                _isLocating ? 'جاري تحديد الموقع...' : 'استخدم موقعي الحالي',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),

            const SizedBox(height: 20),

            _buildTextField(
              'الاسم الكامل',
              _fullnameController,
              Iconsax.user,
              true,
            ),
            _buildTextField(
              'رقم الهاتف',
              _mobileController,
              Iconsax.call,
              true,
            ),
            _buildTextField(
              'البريد الإلكتروني',
              _emailController,
              Iconsax.sms,
              false,
            ),
            _buildTextField('الدولة', _countryController, Iconsax.global, true),
            _buildTextField('المدينة', _cityController, Iconsax.location, true),
            _buildTextField('رقم المنطقة', _zoneController, Iconsax.map, true),
            _buildTextField(
              'رقم الشارع',
              _streetController,
              Iconsax.routing,
              true,
            ),
            _buildTextField(
              'رقم المبنى',
              _buildingController,
              Iconsax.building,
              true,
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                if (_addresses.isNotEmpty) ...[
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _showAddForm = false;
                          _clearForm();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[700],
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text('إلغاء'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: _addAddress,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('حفظ العنوان'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller,
    IconData icon,
    bool required,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        // style: const TextStyle(color: Colors.white),
        style: TextStyle(color: context.appTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          // labelStyle: TextStyle(color: Colors.white.withOpacity(0.7)),
          labelStyle: TextStyle(color: context.appTextSecondary),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          // fillColor: context.appSurface.withOpacity(0.1),
          fillColor: context.appSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.appBorder),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: context.appBorder),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary),
          ),
        ),
        validator: required
            ? (value) {
                if (value == null || value.isEmpty) {
                  return 'هذا الحقل مطلوب';
                }
                return null;
              }
            : null,
      ),
    );
  }

  Widget _buildAddressCard(ShippingAddressModel address, int index) {
    final isSelected = _selectedAddressIndex == index;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedAddressIndex = index;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appCardBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Iconsax.location,
                      color: isSelected
                          ? AppColors.primary
                          : context.appTextPrimary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        address.fullname,
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 16,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isSelected) const SizedBox(width: 28),
                  ],
                ),
                const SizedBox(height: 12),
                _buildAddressDetail(Iconsax.call, address.mobile),
                if (address.email.isNotEmpty)
                  _buildAddressDetail(Iconsax.sms, address.email),
                _buildAddressDetail(
                  Iconsax.global,
                  '${address.city}, ${address.country}',
                ),
                if (address.streetNumber.isNotEmpty ||
                    address.buildingNumber.isNotEmpty)
                  _buildAddressDetail(
                    Iconsax.location,
                    '${address.streetNumber.isNotEmpty ? "شارع ${address.streetNumber}" : ""}'
                    '${address.buildingNumber.isNotEmpty ? " - مبنى ${address.buildingNumber}" : ""}',
                  ),
              ],
            ),
            if (isSelected)
              Positioned(
                top: 0,
                left: 0,
                child: Icon(
                  Iconsax.tick_circle5,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressDetail(IconData icon, String text) {
    if (text.isEmpty) return const SizedBox();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          // Icon(icon, color: Colors.white.withOpacity(0.6), size: 16),
          Icon(icon, color: context.appTextSecondary, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                // color: Colors.white.withOpacity(0.8),
                color: context.appTextSecondary,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueButton() {
    final hasSelection =
        _selectedAddressIndex != null &&
        _selectedAddressIndex! < _addresses.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.bottomBarGradient(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: hasSelection
                ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PaymentMethodsScreen(
                          userId: widget.userId,
                          cartItems: widget.cartItems,
                          totalAmount: widget.totalAmount,
                          shippingAddress: _addresses[_selectedAddressIndex!],
                        ),
                      ),
                    );
                  }
                : () {
                    showAppSnackbar(
                      context,
                      message: 'اختر أو أضف عنوان شحن أولاً',
                      type: SnackType.warning,
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: hasSelection
                  ? AppColors.primary
                  : Colors.grey.shade400,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: hasSelection ? 8 : 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'إكمال الدفع',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                const Icon(Iconsax.card, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
