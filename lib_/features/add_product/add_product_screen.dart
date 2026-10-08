import 'dart:io';
import 'dart:math' as math;
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/services/onesignal_service.dart';
import 'package:GlobalFarm/core/services/s3_upload_service.dart';
import 'package:GlobalFarm/features/home/tiktok_feed_screen.dart';
import 'package:GlobalFarm/shared/providers/app_provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/widgets/video_player_widget.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/database_service.dart';
import 'package:GlobalFarm/features/camera/camera_screen.dart';

// ══════════════════════════════════════════════════════════════════════════════
// LOGO THEME COLORS - MATCHING APP LOGO
// ══════════════════════════════════════════════════════════════════════════════
class _LuxuryColors {
  // Light theme backgrounds
  static const Color bgLight = Color(0xFFF5F5F5);
  static const Color bgCard = Color(0xFFFFFFFF);
  static const Color cardBorder = Color(0xFFE0E0E0);
  
  // Deep Navy/Indigo (from logo)
  static const Color navyPrimary = Color(0xFF2D2B6B);
  static const Color navyDark = Color(0xFF1E1B5E);
  
  // Orange accents (from logo)
  static const Color orangePrimary = Color(0xFFFF8C00);
  static const Color orangeLight = Color(0xFFFFB347);
  static const Color orangeDark = Color(0xFFFF6B00);
  
  // Toggle/Card tint
  static const Color orangeTint = Color(0xFFFFF4E6);
  
  // Text colors for light theme
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  
  // Input field colors
  static const Color inputBg = Color(0xFFFFFFFF);
  static const Color inputBorder = Color(0xFFD1D5DB);
  
  // Toggle colors
  static const Color toggleOff = Color(0xFFD1D5DB);
  static const Color toggleTrackOff = Color(0xFFE5E7EB);

  // Orange gradient (primary accent)
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [orangeLight, orangePrimary, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Navy gradient
  static const LinearGradient navyGradient = LinearGradient(
    colors: [navyPrimary, navyDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x55FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment(-1.0, -0.3),
    end: Alignment(1.0, 0.3),
  );
}

class AddProductScreen extends StatefulWidget {
  final List<String> mediaFiles;
  final String? itemId;

  const AddProductScreen({super.key, required this.mediaFiles, this.itemId});

  @override
  State<AddProductScreen> createState() => _AddProductScreenState();
}

class _AddProductScreenState extends State<AddProductScreen>
    with TickerProviderStateMixin {
  final PageController _mediaController = PageController();
  final ScrollController _scrollController = ScrollController();

  final TextEditingController _barcodeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _engnameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _description_arb_Controller =
      TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();

  List<String> _mediaFiles = [];
  int _currentMediaIndex = 0;
  bool _isPublic = true;
  bool _commentsEnabled = true;
  bool _isUploading = false;
  String? _currentItemId;
  int _clientItemId = 0;

  // Categories for autocomplete
  List<String> _categories = [];
  bool _isLoadingCategories = true;

  // Animation controllers
  late AnimationController _glowController;
  late AnimationController _shimmerController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _shimmerAnimation;
  late Animation<double> _pulseAnimation;

  // Focus nodes for glow effect
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _fieldFocused = {};
  
  Future<String> getUserCountry() async {
    try {
      // 1. اطلب permission
      LocationPermission permission = await Geolocator.requestPermission();
      
      // 2. جيب الموقع
      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      
      // 3. حوّل لاسم دولة
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      
      return placemarks.first.country ?? 'Unknown'; // "EG"
    } catch (e) {
      return 'Unknown';
    }
  }

  Future insertOneRecord() async {
    var request = await Dio().post(
      'https://Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      data: FormData.fromMap({'action': 'insertNewOne', 'country': 'QA', 'store_id': AppConfig.storeId}),
    );
    setState(() {
      _currentItemId = request.data['item_id'].toString();
      _clientItemId =
          int.tryParse(request.data['client_id']?.toString() ?? '') ?? 0;
    });
    print('insertNewOne — item_id: $_currentItemId, client_id: $_clientItemId');
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Dio().post(
        'https://Globee-Trading.com/app2026/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({'action': 'get_categories', 'store_id': AppConfig.storeId}),
      );
      
      if (response.data['status'] == 'success' && response.data['categories'] != null) {
        setState(() {
          _categories = List<String>.from(response.data['categories']);
          _isLoadingCategories = false;
        });
      } else {
        setState(() => _isLoadingCategories = false);
      }
    } catch (e) {
      setState(() => _isLoadingCategories = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _mediaFiles = List.from(widget.mediaFiles);
    insertOneRecord();
    _fetchCategories();
    _initAnimations();
    _initFocusNodes();
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  void _initAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    )..repeat();

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _shimmerAnimation = Tween<double>(begin: -1.0, end: 2.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.linear),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initFocusNodes() {
    final fields = [
      'barcode', 'nameAr', 'nameEn', 'descAr', 'descEn', 'category', 'price', 'quantity'
    ];
    for (final field in fields) {
      _focusNodes[field] = FocusNode();
      _fieldFocused[field] = false;
      _focusNodes[field]!.addListener(() {
        setState(() => _fieldFocused[field] = _focusNodes[field]!.hasFocus);
      });
    }
  }

  @override
  void dispose() {
    _mediaController.dispose();
    _scrollController.dispose();
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _glowController.dispose();
    _shimmerController.dispose();
    _pulseController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _isUploading = false;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: _LuxuryColors.bgLight,
        appBar: _buildLuxuryAppBar(),
        body: SafeArea(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCinematicMediaPreview(),
                    const SizedBox(height: 28),
                    _buildAnimatedSection(
                      delay: 0,
                      child: _buildGlassSection(
                        title: 'معلومات المنتج',
                        icon: Iconsax.box,
                        children: [
                          _buildBarcodeField(),
                          const SizedBox(height: 20),
                          _buildLuxuryTextField(
                            controller: _nameController,
                            label: 'اسم المنتج بالعربي',
                            hint: 'أدخل اسم المنتج',
                            icon: Iconsax.text,
                            focusKey: 'nameAr',
                            textDirection: TextDirection.rtl,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s0-9٠-٩]')),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildLuxuryTextField(
                            controller: _engnameController,
                            label: 'اسم المنتج بالإنجليزي',
                            hint: 'Enter product name',
                            icon: Iconsax.text,
                            focusKey: 'nameEn',
                            textDirection: TextDirection.ltr,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,!?"-]')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedSection(
                      delay: 100,
                      child: _buildGlassSection(
                        title: 'الوصف',
                        icon: Iconsax.document_text,
                        children: [
                          _buildLuxuryTextField(
                            controller: _description_arb_Controller,
                            label: 'الوصف بالعربي',
                            hint: 'أدخل وصف المنتج بالعربي',
                            icon: Iconsax.edit_2,
                            maxLines: 3,
                            focusKey: 'descAr',
                            textDirection: TextDirection.rtl,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[\u0600-\u06FF\s0-9٠-٩]')),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildLuxuryTextField(
                            controller: _descriptionController,
                            label: 'الوصف بالإنجليزي',
                            hint: 'Enter product description',
                            icon: Iconsax.edit_2,
                            maxLines: 3,
                            focusKey: 'descEn',
                            textDirection: TextDirection.ltr,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9\s.,!?"-]')),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedSection(
                      delay: 200,
                      child: _buildGlassSection(
                        title: 'التصنيف',
                        icon: Iconsax.category,
                        children: [
                          _buildCategoryAutocomplete(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedSection(
                      delay: 300,
                      child: _buildGlassSection(
                        title: 'السعر والكمية',
                        icon: Iconsax.money,
                        children: [
                          _buildPriceQuantityRow(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildAnimatedSection(
                      delay: 400,
                      child: _buildGlassSection(
                        title: 'إعدادات الخصوصية',
                        icon: Iconsax.shield_tick,
                        children: [
                          _buildPremiumToggle(
                            title: 'منتج عام',
                            subtitle: 'يمكن لجميع المستخدمين رؤية هذا المنتج',
                            value: _isPublic,
                            onChanged: (v) => setState(() => _isPublic = v),
                            activeIcon: Iconsax.global,
                            inactiveIcon: Iconsax.lock,
                          ),
                          const SizedBox(height: 16),
                          _buildPremiumToggle(
                            title: 'تفعيل التعليقات',
                            subtitle: 'السماح للمستخدمين بالتعليق على المنتج',
                            value: _commentsEnabled,
                            onChanged: (v) => setState(() => _commentsEnabled = v),
                            activeIcon: Iconsax.message,
                            inactiveIcon: Iconsax.message_minus,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 36),
                    _buildAnimatedSection(
                      delay: 500,
                      child: _buildShimmerButton(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
      ),
    );
  }

  PreferredSizeWidget _buildLuxuryAppBar() {
    return AppBar(
      backgroundColor: _LuxuryColors.bgLight,
      elevation: 0,
      centerTitle: true,
      leading: Container(),
      actions: [
        Container(
          margin: const EdgeInsets.only(left: 8),
          child: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _LuxuryColors.bgCard,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LuxuryColors.cardBorder),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 2))],
              ),
              child: const Icon(Iconsax.arrow_right_3, color: _LuxuryColors.textPrimary, size: 20),
            ),
          ),
        ),
      ],
      title: ShaderMask(
        shaderCallback: (bounds) => _LuxuryColors.orangeGradient.createShader(bounds),
        child: const Text(
          'إضافة منتج جديد',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildAnimatedSection({required int delay, required Widget child}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        return Transform.translate(
          offset: Offset(0, 30 * (1 - value)),
          child: Opacity(opacity: value, child: child),
        );
      },
    );
  }

  Widget _buildCinematicMediaPreview() {
    return Consumer<AppProvider>(
      builder: (context, appProvider, child) {
        return AnimatedBuilder(
          animation: _glowAnimation,
          builder: (context, child) {
            return Container(
              height: 380,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: _LuxuryColors.orangePrimary.withOpacity(0.2 * _glowAnimation.value),
                    blurRadius: 25,
                    spreadRadius: 0,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: LinearGradient(
                          colors: [
                            _LuxuryColors.orangeLight.withOpacity(0.9 + 0.1 * _glowAnimation.value),
                            _LuxuryColors.orangePrimary.withOpacity(0.85 + 0.15 * _glowAnimation.value),
                            _LuxuryColors.orangeDark.withOpacity(0.9 + 0.1 * _glowAnimation.value),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      padding: const EdgeInsets.all(3),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(21),
                          color: _LuxuryColors.bgCard,
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(21),
                          child: appProvider.allMedia.isEmpty
                              ? _buildEmptyMediaState()
                              : PageView.builder(
                                  controller: _mediaController,
                                  onPageChanged: (index) => setState(() => _currentMediaIndex = index),
                                  itemCount: appProvider.allMedia.length,
                                  itemBuilder: (context, index) {
                                    final file = File(appProvider.allMedia[index]);
                                    final isVideo = appProvider.allMedia[index].toLowerCase().contains('.mp4');
                                    return isVideo
                                        ? VideoPlayerWidget(filePath: appProvider.allMedia[index], autoPlay: false, showControls: true)
                                        : Image.file(file, fit: BoxFit.cover);
                                  },
                                ),
                        ),
                      ),
                    ),
                    Positioned(top: 16, left: 16, child: _buildGlowingAddButton()),
                    if (appProvider.allMedia.length > 1)
                      Positioned(
                        bottom: 20,
                        left: 0,
                        right: 0,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: List.generate(
                            appProvider.allMedia.length,
                            (index) => AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: _currentMediaIndex == index ? 24 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                gradient: _currentMediaIndex == index ? _LuxuryColors.orangeGradient : null,
                                color: _currentMediaIndex == index ? null : Colors.white.withOpacity(0.5),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyMediaState() {
    return Container(
      decoration: BoxDecoration(
        color: _LuxuryColors.bgLight,
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _LuxuryColors.orangeGradient,
                      boxShadow: [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.3), blurRadius: 20, spreadRadius: 2)],
                    ),
                    child: const Icon(Iconsax.camera, color: Colors.white, size: 40),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) => _LuxuryColors.orangeGradient.createShader(bounds),
              child: const Text('أضف صور أو فيديو للمنتج', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 8),
            Text('اضغط على زر الإضافة للبدء', style: TextStyle(color: _LuxuryColors.textSecondary, fontSize: 14)),
          ],
        ),
      ),
    );
  }

  Widget _buildGlowingAddButton() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _showAddMoreMediaBottomSheet,
          child: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: _LuxuryColors.orangeGradient,
              boxShadow: [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.5 * _pulseAnimation.value), blurRadius: 15, spreadRadius: 1)],
            ),
            child: const Icon(Iconsax.add, color: Colors.white, size: 26),
          ),
        );
      },
    );
  }

  Widget _buildGlassSection({required String title, required IconData icon, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _LuxuryColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ShaderMask(shaderCallback: (bounds) => _LuxuryColors.orangeGradient.createShader(bounds), child: Icon(icon, color: Colors.white, size: 22)),
              const SizedBox(width: 10),
              ShaderMask(
                shaderCallback: (bounds) => _LuxuryColors.orangeGradient.createShader(bounds),
                child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.3)),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  // Generate random 12-digit EAN barcode
  String _generateRandomBarcode() {
    final random = math.Random();
    String barcode = '';
    for (int i = 0; i < 12; i++) {
      barcode += random.nextInt(10).toString();
    }
    return barcode;
  }

  Widget _buildBarcodeField() {
    final isFocused = _fieldFocused['barcode'] ?? false;
    return Row(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              boxShadow: isFocused ? [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.2), blurRadius: 12)] : [],
            ),
            child: TextField(
              controller: _barcodeController,
              focusNode: _focusNodes['barcode'],
              keyboardType: TextInputType.number,
              style: const TextStyle(color: _LuxuryColors.textPrimary, fontSize: 16),
              decoration: InputDecoration(
                labelText: 'الباركود',
                hintText: 'أدخل باركود المنتج',
                hintStyle: const TextStyle(color: _LuxuryColors.textHint),
                labelStyle: TextStyle(color: isFocused ? _LuxuryColors.orangePrimary : _LuxuryColors.textSecondary, fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal),
                prefixIcon: GestureDetector(
                  onTap: () {
                    setState(() {
                      _barcodeController.text = _generateRandomBarcode();
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: _LuxuryColors.orangeGradient,
                    ),
                    child: const Icon(Iconsax.refresh, color: Colors.white, size: 20),
                  ),
                ),
                filled: true,
                fillColor: _LuxuryColors.inputBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1)),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _LuxuryColors.orangePrimary, width: 2)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<String>(
              context: context,
              backgroundColor: Colors.transparent,
              builder: (context) => Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('مسح الباركود', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                          TextButton(
                            onPressed: () => Navigator.pop(context, '-1'),
                            child: Text('إلغاء', style: TextStyle(color: Color(0xFFD4AF37))),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: MobileScanner(
                        onDetect: (capture) {
                          final barcode = capture.barcodes.firstOrNull;
                          if (barcode?.rawValue != null) {
                            Navigator.pop(context, barcode!.rawValue);
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );

            if (result != null && result != '-1') {
              setState(() => _barcodeController.text = result);
            }
          },
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: _LuxuryColors.navyGradient,
                  boxShadow: [BoxShadow(color: _LuxuryColors.navyPrimary.withOpacity(0.4), blurRadius: 12)],
                ),
                child: const Icon(Iconsax.scan_barcode, color: Colors.white, size: 24),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildLuxuryTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String focusKey,
    int maxLines = 1,
    TextInputType? keyboardType,
    TextDirection? textDirection,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isFocused = _fieldFocused[focusKey] ?? false;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused ? [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.2), blurRadius: 12)] : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: _focusNodes[focusKey],
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: textDirection,
        inputFormatters: inputFormatters,
        style: const TextStyle(color: _LuxuryColors.textPrimary, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: const TextStyle(color: _LuxuryColors.textHint),
          labelStyle: TextStyle(color: isFocused ? _LuxuryColors.orangePrimary : _LuxuryColors.textSecondary, fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal),
          prefixIcon: ShaderMask(
            shaderCallback: (bounds) => isFocused ? _LuxuryColors.orangeGradient.createShader(bounds) : LinearGradient(colors: [_LuxuryColors.textSecondary, _LuxuryColors.textSecondary]).createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          filled: true,
          fillColor: _LuxuryColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _LuxuryColors.orangePrimary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildCategoryAutocomplete() {
    final isFocused = _fieldFocused['category'] ?? false;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: isFocused ? [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.2), blurRadius: 12)] : [],
      ),
      child: Autocomplete<String>(
        optionsBuilder: (TextEditingValue textEditingValue) {
          if (_isLoadingCategories) return const Iterable<String>.empty();
          if (textEditingValue.text.isEmpty) return _categories;
          
          final query = textEditingValue.text.toLowerCase();
          return _categories.where((category) => 
            category.toLowerCase().contains(query)
          );
        },
        onSelected: (String selection) {
          _categoryController.text = selection;
        },
        fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
          // Sync with our controller
          if (_categoryController.text.isNotEmpty && textEditingController.text.isEmpty) {
            textEditingController.text = _categoryController.text;
          }
          textEditingController.addListener(() {
            _categoryController.text = textEditingController.text;
          });
          
          // Track focus for styling
          focusNode.addListener(() {
            setState(() => _fieldFocused['category'] = focusNode.hasFocus);
          });
          
          return TextField(
            controller: textEditingController,
            focusNode: focusNode,
            style: const TextStyle(color: _LuxuryColors.textPrimary, fontSize: 16),
            decoration: InputDecoration(
              labelText: 'التصنيف',
              hintText: 'أدخل تصنيف المنتج',
              hintStyle: const TextStyle(color: _LuxuryColors.textHint),
              labelStyle: TextStyle(
                color: isFocused ? _LuxuryColors.orangePrimary : _LuxuryColors.textSecondary,
                fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
              ),
              prefixIcon: ShaderMask(
                shaderCallback: (bounds) => isFocused 
                  ? _LuxuryColors.orangeGradient.createShader(bounds) 
                  : LinearGradient(colors: [_LuxuryColors.textSecondary, _LuxuryColors.textSecondary]).createShader(bounds),
                child: const Icon(Iconsax.tag, color: Colors.white, size: 22),
              ),
              suffixIcon: _isLoadingCategories 
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_LuxuryColors.orangePrimary),
                      ),
                    ),
                  )
                : null,
              filled: true,
              fillColor: _LuxuryColors.inputBg,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _LuxuryColors.orangePrimary, width: 2)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            ),
          );
        },
        optionsViewBuilder: (context, onSelected, options) {
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              elevation: 4,
              borderRadius: BorderRadius.circular(12),
              color: _LuxuryColors.bgCard,
              child: Container(
                constraints: const BoxConstraints(maxHeight: 200),
                width: MediaQuery.of(context).size.width - 72,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _LuxuryColors.inputBorder),
                ),
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  shrinkWrap: true,
                  itemCount: options.length,
                  itemBuilder: (context, index) {
                    final option = options.elementAt(index);
                    return InkWell(
                      onTap: () => onSelected(option),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          border: index < options.length - 1 
                            ? Border(bottom: BorderSide(color: _LuxuryColors.inputBorder.withOpacity(0.5)))
                            : null,
                        ),
                        child: Row(
                          children: [
                            ShaderMask(
                              shaderCallback: (bounds) => _LuxuryColors.orangeGradient.createShader(bounds),
                              child: const Icon(Iconsax.tag, color: Colors.white, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                option,
                                style: const TextStyle(
                                  color: _LuxuryColors.textPrimary,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPriceQuantityRow() {
    return Row(
      children: [
        Expanded(child: _buildNumericField(controller: _priceController, label: 'السعر', icon: Iconsax.money_4, focusKey: 'price', suffix: 'ر.ق')),
        const SizedBox(width: 16),
        Expanded(child: _buildQuantityField()),
      ],
    );
  }

  Widget _buildNumericField({required TextEditingController controller, required String label, required IconData icon, required String focusKey, String? suffix}) {
    final isFocused = _fieldFocused[focusKey] ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: isFocused ? [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.2), blurRadius: 12)] : []),
      child: TextField(
        controller: controller,
        focusNode: _focusNodes[focusKey],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: const TextStyle(color: _LuxuryColors.textPrimary, fontSize: 18, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: isFocused ? _LuxuryColors.orangePrimary : _LuxuryColors.textSecondary),
          suffixText: suffix,
          suffixStyle: TextStyle(color: _LuxuryColors.orangePrimary, fontWeight: FontWeight.w600),
          prefixIcon: ShaderMask(
            shaderCallback: (bounds) => isFocused ? _LuxuryColors.orangeGradient.createShader(bounds) : LinearGradient(colors: [_LuxuryColors.textSecondary, _LuxuryColors.textSecondary]).createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          filled: true,
          fillColor: _LuxuryColors.inputBg,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: _LuxuryColors.orangePrimary, width: 2)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        ),
      ),
    );
  }

  Widget _buildQuantityField() {
    final isFocused = _fieldFocused['quantity'] ?? false;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: _LuxuryColors.inputBg,
        border: Border.all(color: isFocused ? _LuxuryColors.orangePrimary : _LuxuryColors.inputBorder, width: isFocused ? 2 : 1),
        boxShadow: isFocused ? [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.2), blurRadius: 12)] : [],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildQuantityButton(icon: Iconsax.minus, onTap: () {
                final current = int.tryParse(_quantityController.text) ?? 1;
                if (current > 1) { _quantityController.text = (current - 1).toString(); setState(() {}); }
              }),
              SizedBox(
                width: 40,
                height: 40,
                child: Center(
                  child: TextField(
                    controller: _quantityController,
                    focusNode: _focusNodes['quantity'],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    decoration: const InputDecoration(fillColor: Colors.transparent,border: InputBorder.none, contentPadding: EdgeInsets.zero, isDense: true, focusedBorder: OutlineInputBorder(borderSide: BorderSide.none)),

                  ),
                ),
              ),
              _buildQuantityButton(icon: Iconsax.add, onTap: () {
                final current = int.tryParse(_quantityController.text) ?? 0;
                _quantityController.text = (current + 1).toString();
                setState(() {});
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityButton({required IconData icon, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), gradient: _LuxuryColors.navyGradient),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }

  Widget _buildPremiumToggle({required String title, required String subtitle, required bool value, required ValueChanged<bool> onChanged, required IconData activeIcon, required IconData inactiveIcon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: value ? _LuxuryColors.orangeTint : _LuxuryColors.inputBg,
        border: Border.all(color: value ? _LuxuryColors.orangePrimary.withOpacity(0.3) : _LuxuryColors.inputBorder, width: 1),
      ),
      child: Row(
        children: [
         
          // Icon
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: value ? _LuxuryColors.orangeGradient : null,
              color: value ? null : _LuxuryColors.bgLight,
              border: value ? null : Border.all(color: _LuxuryColors.inputBorder),
            ),
            child: Icon(value ? activeIcon : inactiveIcon, color: value ? Colors.white : _LuxuryColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: value ? _LuxuryColors.orangePrimary : _LuxuryColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: _LuxuryColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
           // Toggle switch on the LEFT (RTL layout)
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _LuxuryColors.orangePrimary,
              activeTrackColor: _LuxuryColors.orangePrimary.withOpacity(0.4),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: _LuxuryColors.toggleTrackOff,
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.transparent;
                }
                return _LuxuryColors.toggleOff;
              }),
            ),
          ),
          
        ],
      ),
    );
  }

  Widget _buildShimmerButton() {
    return AnimatedBuilder(
      animation: _shimmerAnimation,
      builder: (context, child) {
        return GestureDetector(
          onTap: _isUploading ? null : _submitProduct,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: _LuxuryColors.orangeGradient,
              boxShadow: [BoxShadow(color: _LuxuryColors.orangePrimary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Transform.translate(
                    offset: Offset(MediaQuery.of(context).size.width * _shimmerAnimation.value, 0),
                    child: Container(width: 100, decoration: BoxDecoration(gradient: _LuxuryColors.shimmerGradient)),
                  ),
                ),
                Center(
                  child: _isUploading
                      ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)),
                          const SizedBox(width: 12),
                          const Text('جاري الرفع...', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                        ])
                      : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const Icon(Iconsax.send_1, color: Colors.white, size: 24),
                          const SizedBox(width: 10),
                          const Text('نشر المنتج', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        ]),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAddMoreMediaBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text('إضافة وسائط', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Iconsax.camera, color: AppColors.primary),
              title: const Text('التقاط صورة'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(isVideo: false),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.video_circle,
                color: AppColors.secondary,
              ),
              title: const Text('تسجيل فيديو'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CameraScreen(isVideo: true),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Iconsax.gallery, color: Colors.green),
              title: const Text('اختيار من المعرض'),
              onTap: () {
                Navigator.pop(context);
                _pickFromGallery();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختيار نوع الوسائط'),
        content: Consumer<AppProvider>(
          builder: (context, appProvider, child) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Iconsax.image),
                  title: const Text('صور'),
                  onTap: () async {
                    Navigator.pop(context);
                    final List<XFile> images = await picker.pickMultiImage();
                    if (images.isNotEmpty) {
                      setState(() {
                        appProvider.allMedia.addAll(
                          images.map((image) => image.path),
                        );
                      });
                    }
                  },
                ),
                ListTile(
                  leading: const Icon(Iconsax.video_play),
                  title: const Text('فيديو'),
                  onTap: () async {
                    Navigator.pop(context);
                    final XFile? video = await picker.pickVideo(
                      source: ImageSource.gallery,
                    );
                    if (video != null) {
                      setState(() {
                        appProvider.allMedia.add(video.path);
                      });
                    }
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _submitProduct() async {
    // Validate fields
    if (_nameController.text.trim().isEmpty) {
      _showError('يرجى إدخال اسم المنتج');
      return;
    }

    if (_descriptionController.text.trim().isEmpty) {
      _showError('يرجى إدخال وصف المنتج');
      return;
    }

    if (_priceController.text.trim().isEmpty) {
      _showError('يرجى إدخال سعر المنتج');
      return;
    }

    if (_quantityController.text.trim().isEmpty) {
      _showError('يرجى إدخال كمية المنتج');
      return;
    }

    if (_categoryController.text.trim().isEmpty) {
      _showError('يرجى إدخال تصنيف المنتج');
      return;
    }

    // if (_currentItemId == null) {
    //   _showError('خطأ في إنشاء المنتج');
    //   return;
    // }

    setState(() {
      _isUploading = true;
    });

    final appProvider = Provider.of<AppProvider>(context, listen: false);
    String? uid = await FlutterSecureStorage().read(key: "user_uid");
    String? userName = await AuthService.getCurrentName();
    // Prepare data for background upload
    Map<String, dynamic> data = {
      'itemId': _currentItemId,
      'clientItemId': _clientItemId,
      'uid': uid,
      'userName': userName,
      'barcode': _barcodeController.text.trim(),
      'name': _nameController.text.trim(),
      'eng': _engnameController.text.trim(),
      'description': _descriptionController.text.trim(),
      '_description_arb_Controller': _description_arb_Controller.text.trim(),
      'price': _priceController.text.trim(),
      'quantity': _quantityController.text.trim(),
      'category': _categoryController.text.trim(),
      'visibility': _isPublic ? 'public' : 'private',
      'comments': _commentsEnabled ? 'on' : 'off',
      'mediaFiles': appProvider.allMedia,
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    // Start background upload
    _startBackgroundUpload(data);

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => TikTokFeedScreen()),
    );
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم بدء رفع المنتج في الخلفية'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _startBackgroundUpload(Map<String, dynamic> data) async {
    try {
      final appProvider = Provider.of<AppProvider>(context, listen: false);
      _runBackgroundUpload(data);
      appProvider.allMedia.clear();
    } catch (e) {
      print('Error starting background upload: $e');
    }
  }

  void _runBackgroundUpload(Map<String, dynamic> data) async {
    try {
      print("🚀 Starting product upload: ${data['name']}");

      final itemId = data['itemId'];
      final mediaFiles = List<String>.from(data['mediaFiles']);

      // Step 1: Upload media files to Bunny.net
      print("📤 Uploading ${mediaFiles.length} media files...");

      final int clientItemId =
          (data['clientItemId'] is int)
              ? data['clientItemId'] as int
              : int.tryParse(data['clientItemId']?.toString() ?? '') ?? 0;

      final uploadedUrls = await S3UploadService.uploadMediaFiles(
        filePaths: mediaFiles,
        itemId: itemId.toString(),
        onProgress: (current, total, progress) {
          final overallProgress =
              ((current - 1) / total * 100 + progress * 100 / total).toInt();
          print(
            "Upload progress: file $current/$total — $overallProgress%",
          );
        },
      );

      if (uploadedUrls.isEmpty) {
        print("❌ No media files uploaded");
        return;
      }

      if (clientItemId <= 0) {
        print("❌ No client_id from insertNewOne — skipping client thumbnail");
      }

      print("📁 S3 upload complete for item: $itemId");
      print("📁 Client items id for thumbnail: $clientItemId");

      // Step 2: Create media string for database
      final mediaString = uploadedUrls
          .map((url) {
            final fileName = url.split('/').last;
            return fileName;
          })
          .join(', ');

      print("📝 Media string: $mediaString");

      // Step 3: Update item in database
      final updateResult = await DatabaseService.updateItem(
        itemId: itemId,
        uid: data['uid'],
        barcode: data['barcode'],
        name: data['name'],
        eng: data['eng'],
        description: data['description'],
        description_arb: data['_description_arb_Controller'],
        category: data['category'],
        price: data['price'],
        quantity: data['quantity'],
        visibility: data['visibility'],
        comments: data['comments'],
        media: mediaString,
      );

      if (updateResult['success'] == true) {
        print("✅ Product uploaded successfully: ${data['name']}");

        final request = await Dio().post(
          "https://www.Globee-Trading.com/app2026/sql.php",
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List playerIds = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in playerIds) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalService.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "المستخدم: ${data['userName']} رفع منتج جديد",
            message:
                "تم رفع منتج جديد بواسطة ${data['userName']} في النظام. اضغط هنا لعرض التفاصيل أو متابعة النشاط.",
          );
        }
      } else {
        print("❌ Failed to update database: ${updateResult['error']}");
      }

      data.clear();
      mediaFiles.clear();
    } catch (e) {
      print("❌ Error uploading product: $e");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}
