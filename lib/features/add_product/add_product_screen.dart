import 'dart:io';
import 'dart:math' as math;
import 'package:GlobalFarm/shared/providers/app_provider.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/utils/country_code_util.dart';
import 'package:GlobalFarm/core/widgets/video_player_widget.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/database_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/services/s3_upload_service.dart';
import 'package:GlobalFarm/features/camera/camera_screen.dart';
import 'package:GlobalFarm/core/utils/app_responsive.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

// ══════════════════════════════════════════════════════════════════════════════
// THEME COLORS — aligned with GlobalFarm green (AppColors.primary)
// ══════════════════════════════════════════════════════════════════════════════
class _LuxuryColors {
  static const Color cardBorder = Color(0xFFE0E0E0);

  // Green accents (app theme)
  static const Color orangePrimary = AppColors.primary;
  static const Color orangeLight = AppColors.primaryLight;
  static const Color orangeDark = AppColors.primaryDark;

  // Soft green tint for cards / add tile
  static const Color orangeTint = Color(0xFFEAF3E8);

  // Input field colors
  static const Color inputBorder = Color(0xFFD1D5DB);

  // Toggle colors
  static const Color toggleOff = Color(0xFFD1D5DB);
  static const Color toggleTrackOff = Color(0xFFE5E7EB);

  // Green gradient (primary accent)
  static const LinearGradient orangeGradient = LinearGradient(
    colors: [orangeLight, orangePrimary, orangeDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark green gradient (secondary accents / scanner btn)
  static const LinearGradient navyGradient = LinearGradient(
    colors: [AppColors.primaryDark, AppColors.secondaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const Color navyPrimary = AppColors.primaryDark;
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
  static const _storage = FlutterSecureStorage();
  static const _draftItemIdKey = 'add_product_draft_item_id';
  static const _draftClientIdKey = 'add_product_draft_client_id';
  static const _draftMediaKey = 'add_product_draft_media';

  final PageController _mediaController = PageController();

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
  final List<String> _pendingUploadPaths = [];
  /// Local path → upload progress 0..1 while actively uploading.
  final Map<String, double> _uploadProgressByPath = {};
  /// Local paths waiting in the upload queue (dimmed).
  final Set<String> _queuedUploadPaths = {};
  int _currentMediaIndex = 0;
  bool _isPublic = true;
  bool _commentsEnabled = true;
  bool _isUploading = false;
  bool _isMediaUploading = false;
  bool _initialMediaUploaded = false;
  String? _currentItemId;
  String? _globalFarmClientId;
  String _savedMediaString = '';
  int _uploadedMediaCount = 0;
  Future<void>? _initRecordFuture;

  // Categories for autocomplete
  List<String> _categories = [];
  bool _isLoadingCategories = true;

  String get _lang => LocalizationService.instance.currentLanguage;

  Color get _onSurface => Theme.of(context).colorScheme.onSurface;

  Color get _onSurfaceSecondary => AppColors.textSecondaryColor(context);

  Color get _outline => Theme.of(context).colorScheme.outline;

  // Animation controllers
  late AnimationController _glowController;
  late AnimationController _pulseController;
  late Animation<double> _glowAnimation;
  late Animation<double> _pulseAnimation;

  // Focus nodes for glow effect
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, bool> _fieldFocused = {};

  int _maxMediaIndexFromString(String media) {
    var maxIndex = 0;
    for (final part in media.split(',')) {
      final trimmed = part.trim();
      if (trimmed.isEmpty) continue;
      final match = RegExp(r'^(\d+)').firstMatch(trimmed);
      if (match != null) {
        maxIndex = math.max(maxIndex, int.parse(match.group(1)!));
      }
    }
    return maxIndex;
  }

  int get _nextUploadStartIndex => _maxMediaIndexFromString(_savedMediaString);

  void _syncUploadedMediaCount() {
    _uploadedMediaCount = _nextUploadStartIndex;
  }

  Future<void> _clearDraft() async {
    await _storage.delete(key: _draftItemIdKey);
    await _storage.delete(key: _draftClientIdKey);
    await _storage.delete(key: _draftMediaKey);
  }

  Future<void> _loadExistingItemState() async {
    if (_currentItemId == null || _currentItemId!.isEmpty) return;

    final item = await ApiService.fetchItemById(itemId: _currentItemId!);
    if (!mounted) return;

    final existingNames = <String>[];
    if (item != null) {
      for (final url in item.media) {
        final name = url.split('/').last.split('?').first.trim();
        if (name.isNotEmpty && RegExp(r'^\d+\.').hasMatch(name)) {
          existingNames.add(name);
        }
      }
      if (item.idx.isNotEmpty) {
        _globalFarmClientId = item.idx;
      }
      for (final url in item.media) {
        if (url.startsWith('http') && !_mediaFiles.contains(url)) {
          _mediaFiles.insert(0, url);
        }
      }
    }

    if (existingNames.isNotEmpty) {
      _savedMediaString = existingNames.join(', ');
      _syncUploadedMediaCount();
    }

    if (mounted) setState(() {});
  }

  bool _isNetworkMediaPath(String path) => path.startsWith('http');

  bool _isVideoMediaPath(String path) {
    final lower = path.toLowerCase();
    return lower.contains('.mp4') ||
        lower.contains('.mov') ||
        lower.contains('.avi');
  }

  Widget _buildMediaImage(
    String path, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
  }) {
    if (_isVideoMediaPath(path)) {
      return ColoredBox(
        color: _LuxuryColors.navyPrimary,
        child: const Center(
          child: Icon(Iconsax.video_play, color: Colors.white, size: 28),
        ),
      );
    }
    if (_isNetworkMediaPath(path)) {
      return Image.network(
        path,
        fit: fit,
        width: width,
        height: height,
        errorBuilder: (context, error, stackTrace) => ColoredBox(
          color: _LuxuryColors.navyPrimary,
          child: const Center(
            child: Icon(Iconsax.image, color: Colors.white54, size: 28),
          ),
        ),
      );
    }
    return Image.file(
      File(path),
      fit: fit,
      width: width,
      height: height,
    );
  }

  Future<void> insertOneRecord() async {
    try {
      // 1) سجل فاضي جديد على Gfnursery — UPDATE عند النشر
      final emptyId = await ApiService.insertEmptyGlobalFarmItem();
      if (emptyId == null || emptyId <= 0) {
        print('insert_empty failed — no Gfnursery client id');
        return;
      }
      final clientId = emptyId.toString();
      print('✅ insert_empty Gfnursery id: $clientId');

      final country = getCountryCode();
      final uid = await _storage.read(key: 'user_uid');
      final request = await Dio().post(
        '${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'insertNewOne',
          'country': country,
          'store_id': AppConfig.storeId,
          if (uid != null && uid.isNotEmpty) 'uid': uid,
        }),
      );

      final data = request.data;
      if (data is! Map || data['item_id'] == null) {
        print('insertNewOne failed: $data');
        return;
      }

      final martitItemId = data['item_id'].toString();
      print('✅ insertNewOne Martit item_id: $martitItemId');

      await DatabaseService.updateItemIdx(itemId: martitItemId, idx: clientId);

      if (!mounted) return;

      _savedMediaString = '';
      _uploadedMediaCount = 0;
      _initialMediaUploaded = false;

      setState(() {
        _currentItemId = martitItemId;
        _globalFarmClientId = clientId;
      });

      await _uploadInitialMediaIfNeeded();
    } catch (e) {
      print('insertOneRecord error: $e');
    }
  }

  Future<void> _initProductRecord() async {
    if (widget.itemId != null && widget.itemId!.isNotEmpty) {
      _currentItemId = widget.itemId;
      await _loadExistingItemState();
      await _uploadInitialMediaIfNeeded();
      return;
    }

    await _clearDraft();
    await insertOneRecord();
  }

  Future<void> _ensureProductRecordReady() async {
    if (_currentItemId != null &&
        _globalFarmClientId != null &&
        _globalFarmClientId!.isNotEmpty) {
      return;
    }
    _initRecordFuture ??= _initProductRecord();
    await _initRecordFuture;
  }

  Future<void> _fetchCategories() async {
    try {
      final response = await Dio().post(
        '${AppConfig.apiBaseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_categories',
          'store_id': AppConfig.storeId,
        }),
      );

      if (response.data['status'] == 'success' &&
          response.data['categories'] != null) {
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
    _initRecordFuture = _initProductRecord();
    _fetchCategories();
    _initAnimations();
    _initFocusNodes();
    _categoryController.addListener(() {
      if (mounted) setState(() {});
    });
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );
  }

  Future<void> _uploadInitialMediaIfNeeded() async {
    if (_currentItemId == null || _initialMediaUploaded) return;

    final paths = widget.mediaFiles.isNotEmpty
        ? List<String>.from(widget.mediaFiles)
        : List<String>.from(_mediaFiles);
    if (paths.isEmpty) return;

    _initialMediaUploaded = true;
    await _ensureProductRecordReady();
    await _uploadMediaImmediately(paths);
  }

  Future<void> _addMediaPaths(List<String> paths) async {
    if (paths.isEmpty) return;
    final newPaths = paths.where((path) => !_mediaFiles.contains(path)).toList();
    if (newPaths.isEmpty) return;
    setState(() {
      _mediaFiles.addAll(newPaths);
      _queuedUploadPaths.addAll(newPaths);
    });
    await _ensureProductRecordReady();
    await _uploadMediaImmediately(newPaths);
  }

  Future<void> _uploadMediaImmediately(List<String> filePaths) async {
    if (filePaths.isEmpty) return;

    await _ensureProductRecordReady();

    if (_currentItemId == null ||
        _globalFarmClientId == null ||
        _globalFarmClientId!.isEmpty) {
      _pendingUploadPaths.addAll(filePaths);
      if (mounted) {
        setState(() => _queuedUploadPaths.addAll(filePaths));
      } else {
        _queuedUploadPaths.addAll(filePaths);
      }
      return;
    }

    if (_isMediaUploading) {
      _pendingUploadPaths.addAll(filePaths);
      if (mounted) {
        setState(() => _queuedUploadPaths.addAll(filePaths));
      } else {
        _queuedUploadPaths.addAll(filePaths);
      }
      return;
    }

    setState(() {
      _isMediaUploading = true;
      _queuedUploadPaths.addAll(filePaths);
    });
    try {
      await _performMediaUpload(filePaths);

      while (_pendingUploadPaths.isNotEmpty) {
        final batch = List<String>.from(_pendingUploadPaths);
        _pendingUploadPaths.clear();
        if (mounted) {
          setState(() => _queuedUploadPaths.addAll(batch));
        }
        await _performMediaUpload(batch);
      }
    } catch (e) {
      print('Media upload error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isMediaUploading = false;
          _uploadProgressByPath.clear();
          _queuedUploadPaths.clear();
        });
      }
    }
  }

  Future<void> _performMediaUpload(List<String> filePaths) async {
    if (filePaths.isEmpty ||
        _currentItemId == null ||
        _globalFarmClientId == null ||
        _globalFarmClientId!.isEmpty) {
      return;
    }

    final uploadedUrls = <String>[];

    for (var i = 0; i < filePaths.length; i++) {
      final path = filePaths[i];
      if (mounted) {
        setState(() {
          _queuedUploadPaths.remove(path);
          _uploadProgressByPath[path] = 0.0;
        });
      } else {
        _queuedUploadPaths.remove(path);
        _uploadProgressByPath[path] = 0.0;
      }

      final startIndex = _nextUploadStartIndex;
      final urls = await S3UploadService.uploadMediaFiles(
        filePaths: [path],
        clientItemId: _globalFarmClientId!,
        startIndex: startIndex,
        uploadToGlobalFarmNursery: true,
        onProgress: (current, total, progress) {
          if (!mounted) return;
          setState(() {
            _uploadProgressByPath[path] = progress.clamp(0.0, 1.0);
          });
        },
      );

      if (urls.isNotEmpty) {
        uploadedUrls.addAll(urls);
        final newNames = urls.map((url) => url.split('/').last).toList();
        final newMediaChunk = newNames.join(', ');
        _savedMediaString = _savedMediaString.isEmpty
            ? newMediaChunk
            : '$_savedMediaString, $newMediaChunk';
        _syncUploadedMediaCount();

        await ApiService.updateItemMedia(
          itemId: _currentItemId!,
          media: _savedMediaString,
        );
      }

      if (mounted) {
        setState(() => _uploadProgressByPath.remove(path));
      } else {
        _uploadProgressByPath.remove(path);
      }
    }

    if (uploadedUrls.isNotEmpty) {
      await _ensureGlobalFarmPrimaryImage();
    }

    if (mounted) setState(() {});
  }

  Future<void> _ensureGlobalFarmPrimaryImage() async {
    if (_globalFarmClientId == null || _globalFarmClientId!.isEmpty) return;

    String? localPath;
    for (final path in _mediaFiles) {
      if (!_isNetworkMediaPath(path) && !_isVideoMediaPath(path)) {
        localPath = path;
        break;
      }
    }
    if (localPath == null) return;

    await S3UploadService.uploadGlobalFarmPrimaryImage(
      clientItemId: _globalFarmClientId!,
      filePath: localPath,
    );
  }

  void _initAnimations() {
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  void _initFocusNodes() {
    final fields = [
      'barcode',
      'nameAr',
      'nameEn',
      'descAr',
      'descEn',
      'category',
      'price',
      'quantity',
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
    _barcodeController.dispose();
    _nameController.dispose();
    _engnameController.dispose();
    _descriptionController.dispose();
    _description_arb_Controller.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _categoryController.dispose();
    _glowController.dispose();
    _pulseController.dispose();
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    super.dispose();
  }

  void _selectCategory(String category) {
    setState(() => _categoryController.text = category);
  }

  void _removeMediaAt(int index) {
    if (index < 0 || index >= _mediaFiles.length) return;

    final removedPath = _mediaFiles[index];
    setState(() {
      _mediaFiles.removeAt(index);
      _uploadProgressByPath.remove(removedPath);
      _queuedUploadPaths.remove(removedPath);
      _pendingUploadPaths.remove(removedPath);

      if (_currentMediaIndex >= _mediaFiles.length) {
        _currentMediaIndex = _mediaFiles.isEmpty ? 0 : _mediaFiles.length - 1;
      }

      if (index < _uploadedMediaCount && _savedMediaString.isNotEmpty) {
        final parts = _savedMediaString
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
        if (index < parts.length) {
          parts.removeAt(index);
          _savedMediaString = parts.join(', ');
          _syncUploadedMediaCount();
          if (_currentItemId != null) {
            ApiService.updateItemMedia(
              itemId: _currentItemId!,
              media: _savedMediaString,
            );
          }
        }
      } else if (index < _uploadedMediaCount) {
        _uploadedMediaCount = math.max(0, _uploadedMediaCount - 1);
      }
    });

    if (_mediaFiles.isNotEmpty && _mediaController.hasClients) {
      _mediaController.jumpToPage(
        _currentMediaIndex.clamp(0, _mediaFiles.length - 1),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: _buildLuxuryAppBar(),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: AppResponsive.formMaxWidth(context),
                    ),
                    child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionTitle(
                        _lang == 'ar' ? 'صور المنتج' : 'Product photos',
                      ),
                      const SizedBox(height: 12),
                      _buildCinematicMediaPreview(fullHeight: false),
                      const SizedBox(height: 12),
                      _buildMediaThumbnailsRow(),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        _lang == 'ar'
                            ? 'الباركود (اختياري)'
                            : 'Barcode (optional)',
                      ),
                      const SizedBox(height: 12),
                      _buildBarcodeField(),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        _lang == 'ar' ? 'اسم المنتج' : 'Product name',
                      ),
                      const SizedBox(height: 12),
                      _buildLuxuryTextField(
                        controller: _nameController,
                        label: _lang == 'ar'
                            ? 'اسم المنتج بالعربي'
                            : 'Product Name (Arabic)',
                        hint: _lang == 'ar'
                            ? 'أدخل اسم المنتج'
                            : 'Enter product name',
                        icon: Iconsax.text,
                        focusKey: 'nameAr',
                        // مقصود: هذا حقل الاسم العربي، يبقى RTL دائماً
                        // مهما كانت لغة الواجهة
                        textDirection: TextDirection.rtl,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\u0600-\u06FF\s0-9٠-٩]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLuxuryTextField(
                        controller: _engnameController,
                        label: _lang == 'ar'
                            ? 'اسم المنتج بالإنجليزي'
                            : 'Product Name (English)',
                        hint: 'Enter product name',
                        icon: Iconsax.text,
                        focusKey: 'nameEn',
                        textDirection: TextDirection.ltr,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,!?"-]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        _lang == 'ar' ? 'الوصف' : 'Description',
                      ),
                      const SizedBox(height: 12),
                      _buildLuxuryTextField(
                        controller: _description_arb_Controller,
                        label: _lang == 'ar'
                            ? 'الوصف بالعربي'
                            : 'Description (Arabic)',
                        hint: _lang == 'ar'
                            ? 'أدخل وصف المنتج بالعربي'
                            : 'Enter Arabic description',
                        icon: Iconsax.edit_2,
                        maxLines: 4,
                        focusKey: 'descAr',
                        // مقصود: هذا حقل الوصف العربي، يبقى RTL دائماً
                        textDirection: TextDirection.rtl,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[\u0600-\u06FF\s0-9٠-٩]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      _buildLuxuryTextField(
                        controller: _descriptionController,
                        label: _lang == 'ar'
                            ? 'الوصف بالإنجليزي'
                            : 'Description (English)',
                        hint: 'Enter product description',
                        icon: Iconsax.edit_2,
                        maxLines: 4,
                        focusKey: 'descEn',
                        textDirection: TextDirection.ltr,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[a-zA-Z0-9\s.,!?"-]'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        _lang == 'ar' ? 'التصنيف' : 'Category',
                      ),
                      const SizedBox(height: 12),
                      _buildCategoryAutocomplete(),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        _lang == 'ar' ? 'السعر والكمية' : 'Price & quantity',
                      ),
                      const SizedBox(height: 12),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            flex: 5,
                            child: _buildPriceQuantityInput(
                              controller: _priceController,
                              focusKey: 'price',
                              label: _lang == 'ar' ? 'السعر' : 'Price',
                              icon: Iconsax.money_4,
                              suffixText: 'ر.ق',
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 3,
                            child: _buildPriceQuantityInput(
                              controller: _quantityController,
                              focusKey: 'quantity',
                              label: _lang == 'ar' ? 'الكمية' : 'Qty',
                              icon: Iconsax.box_1,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              showStepper: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      _buildSectionTitle(
                        _lang == 'ar' ? 'الإعدادات' : 'Settings',
                      ),
                      const SizedBox(height: 12),
                      _buildPremiumToggle(
                        title: _lang == 'ar' ? 'منتج عام' : 'Public Product',
                        subtitle: _lang == 'ar'
                            ? 'يمكن لجميع المستخدمين رؤية هذا المنتج'
                            : 'All users can see this product',
                        value: _isPublic,
                        onChanged: (v) {
                          setState(() => _isPublic = v);
                        },
                        activeIcon: Iconsax.global,
                        inactiveIcon: Iconsax.lock,
                      ),
                      const SizedBox(height: 16),
                      _buildPremiumToggle(
                        title: _lang == 'ar'
                            ? 'تفعيل التعليقات'
                            : 'Enable Comments',
                        subtitle: _lang == 'ar'
                            ? 'السماح للمستخدمين بالتعليق على المنتج'
                            : 'Allow users to comment on product',
                        value: _commentsEnabled,
                        onChanged: (v) {
                          setState(() => _commentsEnabled = v);
                        },
                        activeIcon: Iconsax.message,
                        inactiveIcon: Iconsax.message_minus,
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                  ),
                ),
              ),
              _buildBottomPublishBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: _onSurface,
        fontSize: 17,
        fontWeight: FontWeight.w800,
      ),
    );
  }

  PreferredSizeWidget _buildLuxuryAppBar() {
    return AppBar(
      backgroundColor: context.appBackground,
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
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _LuxuryColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Iconsax.arrow_right_3, color: _onSurface, size: 20),
            ),
          ),
        ),
      ],
      title: ShaderMask(
        shaderCallback: (bounds) =>
            _LuxuryColors.orangeGradient.createShader(bounds),
        child: Text(
          _lang == 'ar' ? 'إضافة منتج' : 'Add Product',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }

  Widget _buildBottomPublishBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
      decoration: BoxDecoration(
        color: context.appBackground,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: _buildNavButton(
          label: _lang == 'ar' ? 'نشر المنتج' : 'Publish product',
          onPressed: _isUploading ? null : _submitProduct,
          outlined: false,
        ),
      ),
    );
  }

  Widget _buildNavButton({
    required String label,
    required VoidCallback? onPressed,
    required bool outlined,
  }) {
    final enabled = onPressed != null;
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: outlined || !enabled
                  ? null
                  : _LuxuryColors.orangeGradient,
              color: outlined ? context.appSurface : null,
              border: outlined
                  ? Border.all(
                      color: enabled
                          ? _LuxuryColors.orangePrimary
                          : _LuxuryColors.inputBorder,
                    )
                  : null,
              boxShadow: !outlined && enabled
                  ? [
                      BoxShadow(
                        color: _LuxuryColors.orangePrimary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            child: _isUploading && !outlined
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: outlined
                          ? (enabled
                                ? _LuxuryColors.orangePrimary
                                : _onSurfaceSecondary)
                          : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  bool _isMediaDone(String path, int index) {
    if (_isNetworkMediaPath(path)) return true;
    if (_uploadProgressByPath.containsKey(path)) return false;
    if (_queuedUploadPaths.contains(path)) return false;
    if (_pendingUploadPaths.contains(path)) return false;
    return index < _uploadedMediaCount;
  }

  Widget _buildMediaThumbnailsRow() {
    const gap = 10.0;
    const size = 80.0;

    return SizedBox(
      height: size,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          ...List.generate(_mediaFiles.length, (index) {
            final path = _mediaFiles[index];
            final isSelected = index == _currentMediaIndex;
            final progress = _uploadProgressByPath[path];
            final isUploading = progress != null;
            final isQueued = !isUploading &&
                (_queuedUploadPaths.contains(path) ||
                    _pendingUploadPaths.contains(path));
            final isDone = _isMediaDone(path, index);
            final opacity = isQueued ? 0.45 : 1.0;

            return Padding(
              padding: const EdgeInsetsDirectional.only(end: gap),
              child: GestureDetector(
                onTap: () {
                  setState(() => _currentMediaIndex = index);
                  if (_mediaController.hasClients) {
                    _mediaController.animateToPage(
                      index,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Opacity(
                        opacity: opacity,
                        child: Container(
                          width: size,
                          height: size,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? _LuxuryColors.orangePrimary
                                  : _LuxuryColors.inputBorder,
                              width: isSelected ? 2.5 : 1,
                            ),
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: _LuxuryColors.orangePrimary
                                          .withOpacity(0.25),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: _buildMediaImage(
                              path,
                              width: size,
                              height: size,
                            ),
                          ),
                        ),
                      ),
                      if (isUploading || isQueued)
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ColoredBox(
                              color: Colors.black.withValues(
                                alpha: isUploading ? 0.45 : 0.25,
                              ),
                              child: isUploading
                                  ? Center(
                                      child: SizedBox(
                                        width: 34,
                                        height: 34,
                                        child: CustomPaint(
                                          painter: _ApplePieProgressPainter(
                                            progress: progress.clamp(0.02, 1.0),
                                            color: AppColors.primary,
                                          ),
                                        ),
                                      ),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                      if (isDone || (!isUploading && !isQueued))
                        Positioned(
                          top: -2,
                          right: -2,
                          child: GestureDetector(
                            onTap: () => _removeMediaAt(index),
                            child: Container(
                              width: 22,
                              height: 22,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.close,
                                color: Colors.white,
                                size: 13,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: gap),
            child: GestureDetector(
              onTap: _showAddMoreMediaBottomSheet,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _LuxuryColors.orangePrimary,
                    width: 1.5,
                  ),
                  color: _LuxuryColors.orangeTint,
                ),
                child: const Icon(
                  Iconsax.add,
                  color: _LuxuryColors.orangePrimary,
                  size: 28,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryAutocomplete() {
    final focusNode = _focusNodes['category']!;
    final isFocused = _fieldFocused['category'] ?? false;

    if (_isLoadingCategories) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _LuxuryColors.inputBorder),
        ),
        child: const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              _LuxuryColors.orangePrimary,
            ),
          ),
        ),
      );
    }

    return RawAutocomplete<String>(
      textEditingController: _categoryController,
      focusNode: focusNode,
      optionsBuilder: (TextEditingValue value) {
        final q = value.text.trim().toLowerCase();
        if (q.isEmpty) {
          return _categories.take(12);
        }
        return _categories.where(
          (c) => c.toLowerCase().contains(q),
        );
      },
      onSelected: (String selection) {
        _selectCategory(selection);
      },
      fieldViewBuilder: (
        context,
        textEditingController,
        fieldFocusNode,
        onFieldSubmitted,
      ) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                      blurRadius: 12,
                    ),
                  ]
                : [],
          ),
          child: TextField(
            controller: textEditingController,
            focusNode: fieldFocusNode,
            onSubmitted: (_) => onFieldSubmitted(),
            style: TextStyle(color: _onSurface, fontSize: 16),
            decoration: InputDecoration(
              labelText: _lang == 'ar' ? 'التصنيف' : 'Category',
              hintText: _lang == 'ar'
                  ? 'ابحث أو اكتب تصنيفاً جديداً'
                  : 'Search or type a new category',
              hintStyle: TextStyle(color: _onSurfaceSecondary),
              labelStyle: TextStyle(
                color: isFocused
                    ? _LuxuryColors.orangePrimary
                    : _onSurfaceSecondary,
                fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
              ),
              prefixIcon: Icon(
                Iconsax.tag,
                color: isFocused
                    ? _LuxuryColors.orangePrimary
                    : _onSurfaceSecondary,
                size: 22,
              ),
              suffixIcon: _isLoadingCategories
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : Icon(
                      Iconsax.arrow_down_1,
                      size: 18,
                      color: _onSurfaceSecondary,
                    ),
              filled: true,
              fillColor: context.appSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: _LuxuryColors.inputBorder,
                  width: 1,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: _LuxuryColors.orangePrimary,
                  width: 2,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 18,
              ),
            ),
          ),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final opts = options.toList();
        if (opts.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: AlignmentDirectional.topStart,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(14),
            color: context.appSurface,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220, minWidth: 280),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 6),
                shrinkWrap: true,
                itemCount: opts.length,
                separatorBuilder: (_, __) => Divider(
                  height: 1,
                  color: context.appBorder,
                ),
                itemBuilder: (context, index) {
                  final option = opts[index];
                  return InkWell(
                    onTap: () => onSelected(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Iconsax.tag,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              option,
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
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
    );
  }

  Widget _buildCinematicMediaPreview({bool fullHeight = false}) {
    return AnimatedBuilder(
      animation: _glowAnimation,
      builder: (context, child) {
        final preview = Container(
          height: fullHeight ? null : (AppResponsive.isTablet(context) ? 420 : 380),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: _LuxuryColors.orangePrimary.withOpacity(
                  0.2 * _glowAnimation.value,
                ),
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
                        _LuxuryColors.orangeLight.withOpacity(
                          0.9 + 0.1 * _glowAnimation.value,
                        ),
                        _LuxuryColors.orangePrimary.withOpacity(
                          0.85 + 0.15 * _glowAnimation.value,
                        ),
                        _LuxuryColors.orangeDark.withOpacity(
                          0.9 + 0.1 * _glowAnimation.value,
                        ),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(21),
                      color: context.appSurface,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(21),
                      child: _mediaFiles.isEmpty
                          ? _buildEmptyMediaState()
                          : PageView.builder(
                              controller: _mediaController,
                              onPageChanged: (index) =>
                                  setState(() => _currentMediaIndex = index),
                              itemCount: _mediaFiles.length,
                              itemBuilder: (context, index) {
                                final path = _mediaFiles[index];
                                if (_isVideoMediaPath(path)) {
                                  return VideoPlayerWidget(
                                    filePath: _isNetworkMediaPath(path)
                                        ? null
                                        : path,
                                    networkUrl: _isNetworkMediaPath(path)
                                        ? path
                                        : null,
                                    autoPlay: false,
                                    showControls: true,
                                  );
                                }
                                return _buildMediaImage(path, fit: BoxFit.cover);
                              },
                            ),
                    ),
                  ),
                ),
                Positioned(top: 16, left: 16, child: _buildGlowingAddButton()),
                if (_mediaFiles.length > 1)
                  Positioned(
                    bottom: 20,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _mediaFiles.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentMediaIndex == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(4),
                            gradient: _currentMediaIndex == index
                                ? _LuxuryColors.orangeGradient
                                : null,
                            color: _currentMediaIndex == index
                                ? null
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
        if (fullHeight) {
          return SizedBox.expand(child: preview);
        }
        return preview;
      },
    );
  }

  Widget _buildEmptyMediaState() {
    return Container(
      decoration: BoxDecoration(color: context.appBackground),
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
                      boxShadow: [
                        BoxShadow(
                          color: _LuxuryColors.orangePrimary.withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Iconsax.camera,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            ShaderMask(
              shaderCallback: (bounds) =>
                  _LuxuryColors.orangeGradient.createShader(bounds),
              child: Text(
                _lang == 'ar'
                    ? 'أضف صور أو فيديو للمنتج'
                    : 'Add photos or video',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _lang == 'ar'
                  ? 'اضغط على زر الإضافة للبدء'
                  : 'Tap the add button to start',
              style: TextStyle(color: _onSurfaceSecondary, fontSize: 14),
            ),
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
              boxShadow: [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(
                    0.5 * _pulseAnimation.value,
                  ),
                  blurRadius: 15,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: const Icon(Iconsax.add, color: Colors.white, size: 26),
          ),
        );
      },
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
              boxShadow: isFocused
                  ? [
                      BoxShadow(
                        color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                        blurRadius: 12,
                      ),
                    ]
                  : [],
            ),
            child: TextField(
              controller: _barcodeController,
              focusNode: _focusNodes['barcode'],
              keyboardType: TextInputType.number,
              style: TextStyle(color: _onSurface, fontSize: 16),
              decoration: InputDecoration(
                labelText: _lang == 'ar' ? 'الباركود' : 'Barcode',
                hintText: _lang == 'ar'
                    ? 'أدخل باركود المنتج'
                    : 'Enter product barcode',
                hintStyle: TextStyle(color: _onSurfaceSecondary),
                labelStyle: TextStyle(
                  color: isFocused
                      ? _LuxuryColors.orangePrimary
                      : _onSurfaceSecondary,
                  fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
                ),
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
                    child: const Icon(
                      Iconsax.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
                filled: true,
                fillColor: context.appSurface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: _LuxuryColors.inputBorder,
                    width: 1,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: _LuxuryColors.orangePrimary,
                    width: 2,
                  ),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 18,
                ),
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
                          Text(
                            _lang == 'ar' ? 'مسح الباركود' : 'Scan Barcode',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, '-1'),
                            child: Text(
                              _lang == 'ar' ? 'إلغاء' : 'Cancel',
                              style: const TextStyle(color: AppColors.primary),
                            ),
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
                  boxShadow: [
                    BoxShadow(
                      color: _LuxuryColors.navyPrimary.withOpacity(0.4),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: const Icon(
                  Iconsax.scan_barcode,
                  color: Colors.white,
                  size: 24,
                ),
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
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: _LuxuryColors.orangePrimary.withOpacity(0.2),
                  blurRadius: 12,
                ),
              ]
            : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: _focusNodes[focusKey],
        maxLines: maxLines,
        keyboardType: keyboardType,
        textDirection: textDirection,
        inputFormatters: inputFormatters,
        style: TextStyle(color: _onSurface, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          hintStyle: TextStyle(color: _onSurfaceSecondary),
          labelStyle: TextStyle(
            color: isFocused
                ? _LuxuryColors.orangePrimary
                : _onSurfaceSecondary,
            fontWeight: isFocused ? FontWeight.w600 : FontWeight.normal,
          ),
          prefixIcon: ShaderMask(
            shaderCallback: (bounds) => isFocused
                ? _LuxuryColors.orangeGradient.createShader(bounds)
                : LinearGradient(
                    colors: [_onSurfaceSecondary, _onSurfaceSecondary],
                  ).createShader(bounds),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          filled: true,
          fillColor: context.appSurface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide(color: _LuxuryColors.inputBorder, width: 1),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(
              color: _LuxuryColors.orangePrimary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 18,
          ),
        ),
      ),
    );
  }

  /// Shared style for price + quantity so they sit flush in one row.
  Widget _buildPriceQuantityInput({
    required TextEditingController controller,
    required String focusKey,
    required String label,
    required IconData icon,
    required TextInputType keyboardType,
    String? suffixText,
    List<TextInputFormatter>? inputFormatters,
    bool showStepper = false,
  }) {
    final isFocused = _fieldFocused[focusKey] ?? false;
    const fieldHeight = 58.0;

    Widget stepperBtn({
      required IconData iconData,
      required VoidCallback onTap,
      required bool accent,
    }) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 28,
          height: 28,
          child: Icon(
            iconData,
            size: 15,
            color: accent ? AppColors.primary : _onSurfaceSecondary,
          ),
        ),
      );
    }

    return SizedBox(
      height: fieldHeight,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: isFocused
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.18),
                    blurRadius: 10,
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: controller,
          focusNode: _focusNodes[focusKey],
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _onSurface,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
          decoration: InputDecoration(
            labelText: label,
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            labelStyle: TextStyle(
              color: isFocused ? AppColors.primary : _onSurfaceSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
            floatingLabelStyle: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            prefixIcon: showStepper
                ? stepperBtn(
                    iconData: Iconsax.minus,
                    accent: false,
                    onTap: () {
                      final current =
                          int.tryParse(_quantityController.text) ?? 1;
                      if (current > 0) {
                        _quantityController.text = (current - 1).toString();
                        setState(() {});
                      }
                    },
                  )
                : Icon(
                    icon,
                    size: 20,
                    color: isFocused ? AppColors.primary : _onSurfaceSecondary,
                  ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            suffixIcon: showStepper
                ? stepperBtn(
                    iconData: Iconsax.add,
                    accent: true,
                    onTap: () {
                      final current =
                          int.tryParse(_quantityController.text) ?? 0;
                      _quantityController.text = (current + 1).toString();
                      setState(() {});
                    },
                  )
                : (suffixText != null
                    ? Padding(
                        padding: const EdgeInsetsDirectional.only(end: 12),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            suffixText,
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      )
                    : null),
            suffixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 40,
            ),
            filled: true,
            fillColor: context.appSurface,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: _LuxuryColors.inputBorder,
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumericField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required String focusKey,
    String? suffix,
  }) {
    return _buildPriceQuantityInput(
      controller: controller,
      focusKey: focusKey,
      label: label,
      icon: icon,
      suffixText: suffix,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
    );
  }

  Widget _buildPremiumToggle({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData activeIcon,
    required IconData inactiveIcon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = Theme.of(context).colorScheme.surface;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: value
            ? (isDark ? AppColors.darkElevated : _LuxuryColors.orangeTint)
            : surface,
        border: Border.all(
          color: value
              ? _LuxuryColors.orangePrimary.withOpacity(0.3)
              : _outline,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: value ? _LuxuryColors.orangeGradient : null,
              color: value ? null : surface,
              border: value ? null : Border.all(color: _outline),
            ),
            child: Icon(
              value ? activeIcon : inactiveIcon,
              color: value ? Colors.white : _onSurfaceSecondary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: value
                        ? (isDark ? Colors.white : _LuxuryColors.orangePrimary)
                        : _onSurface,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(color: _onSurfaceSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Transform.scale(
            scale: 1.1,
            child: Switch(
              value: value,
              onChanged: onChanged,
              activeThumbColor: _LuxuryColors.orangePrimary,
              activeTrackColor: _LuxuryColors.orangePrimary.withOpacity(0.4),
              inactiveThumbColor: surface,
              inactiveTrackColor: isDark
                  ? AppColors.darkElevated
                  : _LuxuryColors.toggleTrackOff,
              trackOutlineColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return Colors.transparent;
                }
                return isDark ? AppColors.darkBorder : _LuxuryColors.toggleOff;
              }),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddMoreMediaBottomSheet() {
    final lang = _lang;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            Text(
              lang == 'ar' ? 'إضافة منتج جديد' : 'Add New Product',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Iconsax.camera, color: AppColors.primary),
              title: Text(lang == 'ar' ? 'إضافة صورة' : 'Add Photo'),
              subtitle: Text(
                lang == 'ar' ? 'التقط صورة للمنتج' : 'Take a product photo',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showImageSourceBottomSheet();
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.video_play,
                color: AppColors.secondary,
              ),
              title: Text(lang == 'ar' ? 'إضافة فيديو' : 'Add Video'),
              subtitle: Text(
                lang == 'ar' ? 'سجل فيديو للمنتج' : 'Record a product video',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _showVideoSourceBottomSheet();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showImageSourceBottomSheet() {
    final lang = _lang;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            Text(
              lang == 'ar' ? 'إضافة صورة' : 'Add Photo',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Iconsax.camera, color: AppColors.primary),
              title: Text(lang == 'ar' ? 'التقاط صورة' : 'Take Photo'),
              subtitle: Text(
                lang == 'ar'
                    ? 'استخدم الكاميرا لالتقاط صورة جديدة'
                    : 'Use camera to take a new photo',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _openCameraForAppend(isVideo: false);
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.gallery,
                color: AppColors.secondary,
              ),
              title: Text(
                lang == 'ar' ? 'اختيار من المعرض' : 'Choose from Gallery',
              ),
              subtitle: Text(
                lang == 'ar'
                    ? 'اختر صورة من معرض الصور'
                    : 'Choose from photo gallery',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickImagesFromGallery();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showVideoSourceBottomSheet() {
    final lang = _lang;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
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
            Text(
              lang == 'ar' ? 'إضافة فيديو' : 'Add Video',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(
                Iconsax.video_circle,
                color: AppColors.primary,
              ),
              title: Text(lang == 'ar' ? 'تسجيل فيديو' : 'Record Video'),
              subtitle: Text(
                lang == 'ar'
                    ? 'استخدم الكاميرا لتسجيل فيديو جديد'
                    : 'Use camera to record a new video',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _openCameraForAppend(isVideo: true);
              },
            ),
            ListTile(
              leading: const Icon(
                Iconsax.video_play,
                color: AppColors.secondary,
              ),
              title: Text(
                lang == 'ar' ? 'اختيار من المعرض' : 'Choose from Gallery',
              ),
              subtitle: Text(
                lang == 'ar'
                    ? 'اختر فيديو من معرض الفيديوهات'
                    : 'Choose from video gallery',
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickVideoFromGallery();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _openCameraForAppend({required bool isVideo}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CameraScreen(
          isVideo: isVideo,
        ),
      ),
    ).then((result) async {
      if (result != null && result is List<String> && result.isNotEmpty) {
        await _addMediaPaths(result);
      }
    });
  }

  Future<void> _pickImagesFromGallery() async {
    final picker = ImagePicker();
    final result = await picker.pickMultiImage();
    final paths = result.map((image) => image.path).toList();
    if (paths.isNotEmpty) {
      await _addMediaPaths(paths);
    }
  }

  Future<void> _pickVideoFromGallery() async {
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      await _addMediaPaths([video.path]);
    }
  }

  void _showValidationError(String message) {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: _lang == 'ar' ? 'خطأ' : 'Error',
      desc: message,
      btnOkOnPress: () {},
      btnOkText: _lang == 'ar' ? 'حسناً' : 'OK',
    ).show();
  }

  bool _validateProductForm() {
    if (_mediaFiles.isEmpty) {
      _showValidationError(
        _lang == 'ar'
            ? 'يجب إضافة صورة واحدة على الأقل للمنتج'
            : 'Add at least one photo',
      );
      return false;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty || name.length < 3) {
      _showValidationError(
        _lang == 'ar' ? 'يجب إدخال اسم المنتج' : 'Product name is required',
      );
      return false;
    }

    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText);
    if (priceText.isEmpty || price == null || price <= 0) {
      _showValidationError(
        _lang == 'ar' ? 'يجب إدخال سعر صحيح للمنتج' : 'Enter a valid price',
      );
      return false;
    }

    final quantityText = _quantityController.text.trim();
    final quantity = int.tryParse(quantityText);
    if (quantityText.isEmpty || quantity == null || quantity <= 0) {
      _showValidationError(
        _lang == 'ar'
            ? 'يجب إدخال كمية صحيحة للمنتج'
            : 'Enter a valid quantity',
      );
      return false;
    }

    if (_categoryController.text.trim().isEmpty) {
      _showValidationError(
        _lang == 'ar' ? 'يجب اختيار تصنيف للمنتج' : 'Select a category',
      );
      return false;
    }

    return true;
  }

  void _submitProduct() async {
    if (!_validateProductForm()) {
      return;
    }

    setState(() {
      _isUploading = true;
    });

    final uid = await FlutterSecureStorage().read(key: 'user_uid');
    if (uid != null && uid.isNotEmpty && _currentItemId != null) {
      await DatabaseService.updateItem(
        itemId: _currentItemId!,
        clientId: _globalFarmClientId,
        idx: _globalFarmClientId,
        uid: uid,
        barcode: _barcodeController.text.trim(),
        name: _nameController.text.trim(),
        eng: _engnameController.text.trim(),
        description: _descriptionController.text.trim(),
        description_arb: _description_arb_Controller.text.trim(),
        category: _categoryController.text.trim(),
        price: _priceController.text.trim(),
        quantity: _quantityController.text.trim().isEmpty
            ? '0'
            : _quantityController.text.trim(),
        visibility: _isPublic ? 'Public' : 'Private',
        comments: _commentsEnabled ? 'on' : 'off',
        media: _savedMediaString,
      );
    }

    // تحديث نفس صف Gfnursery (client_id) — id يمنع INSERT مكرر
    if (_globalFarmClientId != null && _globalFarmClientId!.isNotEmpty) {
      await _ensureGlobalFarmPrimaryImage();
      await ApiService.syncItemToGlobalFarm(
        clientId: _globalFarmClientId!,
        martitItemId: _currentItemId,
        itemName: _nameController.text.trim(),
        itemNameEn: _engnameController.text.trim(),
        category: _categoryController.text.trim(),
        description: _descriptionController.text.trim(),
        price: _priceController.text.trim(),
        barcode: _barcodeController.text.trim(),
        descriptionArb: _description_arb_Controller.text.trim(),
        quantity: _quantityController.text.trim().isEmpty
            ? '0'
            : _quantityController.text.trim(),
      );
    }

    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });

    showAppSnackbar(
      context,
      message: _lang == 'ar'
          ? 'تم حفظ المنتج بنجاح'
          : 'Product saved successfully',
      type: SnackType.success,
    );
    await _clearDraft();
    final appProvider = Provider.of<AppProvider>(context, listen: false);
    appProvider.allMedia.clear();
    Navigator.pop(context, _currentItemId);
  }
}

/// Apple Photos–style circular pie progress for media uploads.
class _ApplePieProgressPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _ApplePieProgressPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;

    // Dim track ring
    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(center, radius - 1.25, trackPaint);

    // Bright ring
    final ringPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - 1.25),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      ringPaint,
    );

    // Solid pie wedge (Apple sync style)
    final piePaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final pieRadius = radius - 5.5;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: pieRadius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0.0, 1.0),
      true,
      piePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ApplePieProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
