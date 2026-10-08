import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/services/wishlist_service.dart';
import 'package:GlobalFarm/core/utils/app_responsive.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/core/widgets/product_grid_card.dart';
import 'package:GlobalFarm/features/auth/login.dart';
import 'package:GlobalFarm/features/add_product/add_product_screen.dart';
import 'package:GlobalFarm/features/camera/camera_screen.dart';
import 'package:GlobalFarm/features/product/product_detail_screen.dart';
import 'package:GlobalFarm/features/search/search_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:GlobalFarm/core/services/s3_upload_service.dart';

/// Traditional e-commerce home: sticky header + scrollable product grid.
class HomeScreen extends StatefulWidget {
  final VoidCallback? onOpenCategories;
  final VoidCallback? onOpenCart;
  final void Function(VoidCallback openAddProduct)? onRegisterAddProduct;

  const HomeScreen({
    super.key,
    this.onOpenCategories,
    this.onOpenCart,
    this.onRegisterAddProduct,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final PageController _bannerController = PageController();

  List<ItemModel> _items = [];
  List<String> _categories = [];
  String? _selectedCategory;
  String? _userId;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _isOpeningCamera = false;
  int _page = 0;
  bool _hasMore = true;
  int _bannerIndex = 0;
  Timer? _bannerTimer;
  List<String> _bannerUrls = [];
  bool _bannersLoading = true;
  final Map<String, int> _cartQuantities = {};

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  int get _bannerCount =>
      _bannerUrls.isNotEmpty ? _bannerUrls.length : _fallbackSlides.length;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _bootstrap();
    _startBannerAutoScroll();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onRegisterAddProduct?.call(_handleAddProduct);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _scrollController.dispose();
    _bannerController.dispose();
    super.dispose();
  }

  void _startBannerAutoScroll() {
    _bannerTimer?.cancel();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_bannerController.hasClients || _bannerCount == 0) return;
      final next = (_bannerIndex + 1) % _bannerCount;
      _bannerController.animateToPage(
        next,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  List<_BannerSlide> get _fallbackSlides => [
        _BannerSlide(
          title: tr('home.banner_welcome_title'),
          subtitle: tr('home.banner_welcome_subtitle'),
          colors: const [Color(0xFF4A7C3F), Color(0xFF2D5A28)],
          icon: Iconsax.tree,
          openCategories: true,
        ),
        _BannerSlide(
          title: tr('home.banner_offers_title'),
          subtitle: tr('home.banner_offers_subtitle'),
          colors: const [Color(0xFF2D6A4F), Color(0xFF52B788)],
          icon: Iconsax.tag,
          openCategories: true,
        ),
      ];

  Future<void> _loadBanners() async {
    setState(() => _bannersLoading = true);
    try {
      final urls = await ApiService.getBanners(storeId: AppConfig.storeId);
      if (!mounted) return;
      setState(() {
        _bannerUrls = urls;
        _bannerIndex = 0;
        _bannersLoading = false;
      });
      if (_bannerController.hasClients) {
        _bannerController.jumpToPage(0);
      }
      _startBannerAutoScroll();
    } catch (e) {
      debugPrint('Home banners error: $e');
      if (!mounted) return;
      setState(() {
        _bannerUrls = [];
        _bannersLoading = false;
      });
      _startBannerAutoScroll();
    }
  }

  Future<void> _bootstrap() async {
    final loggedIn = await AuthService.isLoggedIn();
    final uid = await AuthService.getCurrentUserId();
    final admin =
        loggedIn ? await AuthService.refreshRoleFromApi() : false;
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _userId = uid;
      _isAdmin = admin;
    });
    await Future.wait([
      _loadBanners(),
      _loadCategories(),
      _loadItems(refresh: true),
    ]);
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await ApiService.getCategories(storeId: AppConfig.storeId);
      if (!mounted) return;
      setState(() {
        _categories = cats
            .where((c) => !_isProjectsCategory(c))
            .toList();
      });
    } catch (e) {
      debugPrint('Home categories error: $e');
    }
  }

  bool _isProjectsCategory(String name) {
    final n = name.toLowerCase();
    return n.contains('مشروع') ||
        n.contains('استشار') ||
        n.contains('project') ||
        n.contains('consult');
  }

  Future<void> _loadItems({bool refresh = false}) async {
    if (refresh) {
      if (_isLoading) return;
      setState(() {
        _isLoading = true;
        _page = 0;
        _hasMore = true;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      setState(() => _isLoadingMore = true);
    }

    try {
      final offset = refresh ? 0 : _items.length;
      final List<ItemModel> fetched;
      if (_isLoggedIn && _userId != null) {
        fetched = await ApiService.fetchItemsWithLikes(
          userId: _userId!,
          limit: 10,
          offset: offset,
          category: _selectedCategory,
        );
      } else {
        fetched = await ApiService.fetchItems(
          page: refresh ? 0 : _page,
          userId: _userId,
          category: _selectedCategory,
        );
      }

      if (!mounted) return;
      setState(() {
        if (refresh) {
          _items = fetched;
          _cartQuantities.clear();
          _page = 1;
        } else {
          _items.addAll(fetched);
          _page += 1;
        }
        for (final item in fetched) {
          _cartQuantities[item.id] = item.interactions.cartQuantity;
        }
        _hasMore = fetched.length >= 10;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      debugPrint('Home load items error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _isLoadingMore || !_hasMore) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 240) {
      _loadItems();
    }
  }

  Future<void> _selectCategory(String? category) async {
    if (_selectedCategory == category) return;
    setState(() => _selectedCategory = category);
    await _loadItems(refresh: true);
  }

  Map<String, dynamic> _detailMap(ItemModel item) {
    return {
      'id': item.id,
      'idx': item.idx,
      'storeid': item.storeid,
      'name': item.name,
      'eng': item.nameEn,
      'price': item.price,
      'qtt': item.quantity,
      'description': item.description,
      'description_arb': item.descriptionArb,
      'seller_name': item.seller.name,
      'seller_id': item.seller.id,
    };
  }

  Future<String?> _requireLogin() async {
    if (_isLoggedIn && _userId != null && _userId!.isNotEmpty) {
      return _userId;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
    final loggedIn = await AuthService.isLoggedIn();
    final uid = await AuthService.getCurrentUserId();
    final admin =
        loggedIn ? await AuthService.refreshRoleFromApi() : false;
    if (!mounted) return null;
    setState(() {
      _isLoggedIn = loggedIn;
      _userId = uid;
      _isAdmin = admin;
    });
    return loggedIn ? uid : null;
  }

  void _setCartQty(String itemId, int quantity) {
    setState(() {
      _cartQuantities[itemId] = quantity;
      final i = _items.indexWhere((e) => e.id == itemId);
      if (i != -1) {
        _items[i].interactions.cartQuantity = quantity;
      }
    });
  }

  Future<void> _addToCart(ItemModel item) async {
    if (_isAdmin) return;
    final userId = await _requireLogin();
    if (userId == null || !mounted) return;

    final current = _cartQuantities[item.id] ?? 0;
    if (item.quantity > 0 && current >= item.quantity) {
      showAppSnackbar(
        context,
        message: '${tr('cart.available_quantity')}: ${item.quantity}',
        type: SnackType.warning,
      );
      return;
    }

    final previous = current;
    _setCartQty(item.id, current + 1);
    try {
      await ApiService.addToCart(itemId: item.id, userId: userId, quantity: 1);
    } catch (_) {
      if (!mounted) return;
      _setCartQty(item.id, previous);
      showAppSnackbar(
        context,
        message: tr('cart.add_error'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _removeFromCart(ItemModel item) async {
    final userId = await _requireLogin();
    if (userId == null || !mounted) return;

    final current = _cartQuantities[item.id] ?? 0;
    if (current <= 0) return;

    final previous = current;
    _setCartQty(item.id, current - 1);
    try {
      final result = await ApiService.removeFromCart(
        itemId: item.id,
        userId: userId,
      );
      if (result['success'] == true && result['quantity'] != null) {
        final serverQty = result['quantity'];
        final parsed = serverQty is int
            ? serverQty
            : int.tryParse(serverQty.toString()) ?? previous - 1;
        _setCartQty(item.id, parsed);
      }
    } catch (_) {
      if (!mounted) return;
      _setCartQty(item.id, previous);
      showAppSnackbar(
        context,
        message: tr('cart.update_error'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _toggleLike(ItemModel item) async {
    final userId = await _requireLogin();
    if (userId == null) return;

    final wasLiked = item.interactions.isLiked;
    setState(() {
      item.interactions.isLiked = !wasLiked;
      item.interactions.likes += wasLiked ? -1 : 1;
    });
    WishlistService.instance.setLiked(item, !wasLiked);

    try {
      await ApiService.toggleLike(itemId: item.id, userId: userId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item.interactions.isLiked = wasLiked;
        item.interactions.likes += wasLiked ? 1 : -1;
      });
      WishlistService.instance.setLiked(item, wasLiked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          children: [
            // ── Sticky header (app bar → categories) ──
            _buildAppBar(),
            _buildBanner(),
            _buildCategoriesRow(),
            const SizedBox(height: 4),
            // ── Scrollable products only ──
            Expanded(child: _buildProductsArea()),
          ],
        ),
      ),
    );
  }

  Widget _buildProductsArea() {
    if (_isLoading && _items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_items.isEmpty) {
      return _buildEmpty();
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () async {
            await Future.wait([
              _loadBanners(),
              _loadCategories(),
              _loadItems(refresh: true),
            ]);
      },
      child: GridView.builder(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: AppResponsive.productGridPadding(context),
        gridDelegate: AppResponsive.productGridDelegate(context),
        itemCount: _items.length + (_isLoadingMore ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 2,
              ),
            );
          }
          return ProductGridCard(
            item: _items[index],
            quantity: _cartQuantities[_items[index].id] ?? 0,
            isOwn: _userId != null && _userId == _items[index].seller.id,
            isAdmin: _isAdmin,
            isArabic: _ar,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      ProductDetailScreen(item: _detailMap(_items[index])),
                ),
              );
            },
            onLike: () => _toggleLike(_items[index]),
            onAddToCart: () => _addToCart(_items[index]),
            onRemoveFromCart: () => _removeFromCart(_items[index]),
          );
        },
      ),
    );
  }

  Widget _buildAppBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      color: context.appBackground,
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: context.appBorder),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/images/Logo.png',
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Global Farm',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tr('home.app_tagline'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.25,
                    color: context.appTextSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(
            icon: Iconsax.search_normal_1,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SearchScreen()),
              );
            },
          ),
          const SizedBox(width: 8),
          // Admin: add product (+). Buyers: support headset OR cart.
          if (_isAdmin) ...[
            _HeaderIconButton(
              icon: Iconsax.add,
              onTap: _handleAddProduct,
            ),
          ] else ...[
            _HeaderIconButton(
              icon: Iconsax.shopping_bag,
              onTap: () => widget.onOpenCart?.call(),
            ),
            const SizedBox(width: 8),
            _HeaderIconButton(
              icon: Iconsax.headphone,
              onTap: _showSupportSheet,
            ),
          ],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Banner Manager (Admin only)
  // ─────────────────────────────────────────────────────────────────

  void _showBannerManagerSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _BannerManagerSheet(
        storeId: AppConfig.storeId,
        onChanged: () => _loadBanners(),
      ),
    );
  }

  void _handleAddProduct() {
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    _showAddProductBottomSheet();
  }

  void _showAddProductBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.appBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  tr('home.add_new_product'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Iconsax.camera, color: AppColors.primary),
                  title: Text(tr('home.add_photo')),
                  subtitle: Text(
                    tr('home.add_photo_hint'),
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showImageSourceBottomSheet();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Iconsax.video_play,
                    color: AppColors.primary,
                  ),
                  title: Text(tr('home.add_video')),
                  subtitle: Text(
                    tr('home.add_video_hint'),
                    style: TextStyle(color: context.appTextSecondary),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showVideoSourceBottomSheet();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('home.add_photo'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(Iconsax.camera, color: AppColors.primary),
                  title: Text(tr('home.take_photo')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCameraAndAddProduct(isVideo: false);
                  },
                ),
                ListTile(
                  leading: const Icon(Iconsax.gallery, color: AppColors.primary),
                  title: Text(tr('home.choose_from_gallery')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickImageFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showVideoSourceBottomSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  tr('home.add_video'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: context.appTextPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: const Icon(
                    Iconsax.video_circle,
                    color: AppColors.primary,
                  ),
                  title: Text(tr('home.record_video')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _openCameraAndAddProduct(isVideo: true);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Iconsax.video_play,
                    color: AppColors.primary,
                  ),
                  title: Text(tr('home.choose_from_gallery')),
                  onTap: () {
                    Navigator.pop(ctx);
                    _pickVideoFromGallery();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _openAddProductScreen(List<String> mediaFiles) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddProductScreen(mediaFiles: mediaFiles),
      ),
    );
    if (result != null && mounted) {
      await _loadItems(refresh: true);
    }
  }

  Future<void> _openCameraAndAddProduct({required bool isVideo}) async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => CameraScreen(isVideo: isVideo)),
      );
      if (result is List<String> && result.isNotEmpty) {
        await _openAddProductScreen(result);
      }
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _pickImageFromGallery() async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      final picker = ImagePicker();
      final result = await picker.pickMultiImage();
      final imagePaths = result.map((image) => image.path).toList();
      if (imagePaths.isEmpty) return;
      await _openAddProductScreen(imagePaths);
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _pickVideoFromGallery() async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video != null) {
        await _openAddProductScreen([video.path]);
      }
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _callNumber(String localNumber) async {
    final uri = Uri(scheme: 'tel', path: '+974$localNumber');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        showAppSnackbar(
          context,
          message: tr('home.dialer_error'),
          type: SnackType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr('home.dialer_error'),
        type: SnackType.error,
      );
    }
  }

  void _showSupportSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.appSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Iconsax.headphone,
                        color: AppColors.primary,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr('home.support_title'),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: context.appTextPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tr('home.support_subtitle'),
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.appTextSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _SupportPhoneTile(
                  icon: Iconsax.headphone5,
                  iconColor: AppColors.primary,
                  title: tr('home.support_title'),
                  subtitle: tr('home.support_phone_subtitle'),
                  displayNumber: '3338 0011',
                  onCall: () {
                    Navigator.pop(ctx);
                    _callNumber('33380011');
                  },
                ),
                const SizedBox(height: 10),
                _SupportPhoneTile(
                  icon: Iconsax.user,
                  iconColor: AppColors.primary,
                  title: tr('home.customer_service'),
                  subtitle: tr('home.customer_service_subtitle'),
                  displayNumber: '7799 1225',
                  onCall: () {
                    Navigator.pop(ctx);
                    _callNumber('77991225');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildBanner() {
    final useImages = _bannerUrls.isNotEmpty;
    final count = _bannerCount;

    return Column(
      children: [
        Stack(
          children: [
            SizedBox(
          height: AppResponsive.homeBannerHeight(context),
          child: _bannersLoading && !useImages
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8EFE4),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
                )
              : PageView.builder(
                  controller: _bannerController,
                  onPageChanged: (i) => setState(() => _bannerIndex = i),
                  itemCount: count,
                  itemBuilder: (context, index) {
                    if (useImages) {
                      return _buildImageBanner(_bannerUrls[index]);
                    }
                    return _buildFallbackBanner(_fallbackSlides[index]);
                  },
                ),
            ),
            // Admin: زر إدارة البانر لازق فوق السلايدر في أقصى اليمين
            if (_isAdmin)
              Positioned(
                top: 10,
                right: 24,
                child: GestureDetector(
                  onTap: _showBannerManagerSheet,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Iconsax.gallery_edit,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (count > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(count, (i) {
              final active = i == _bannerIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: active
                      ? AppColors.primary
                      : AppColors.primary.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            }),
          ),
        const SizedBox(height: 6),
      ],
    );
  }

  Widget _buildImageBanner(String url) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: CachedNetworkImage(
        imageUrl: url,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        placeholder: (_, __) => Container(
          color: const Color(0xFFE8EFE4),
          child: const Center(
            child: SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.primary,
              ),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFFE8EFE4),
          child: const Icon(Iconsax.image, color: AppColors.grey, size: 36),
        ),
      ),
    );
  }

  Widget _buildFallbackBanner(_BannerSlide slide) {
    return GestureDetector(
      onTap: () {
        if (slide.openCategories) widget.onOpenCategories?.call();
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: slide.colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: slide.colors.first.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: _ar ? null : -20,
              right: _ar ? -20 : null,
              bottom: -20,
              child: Icon(
                slide.icon,
                size: 120,
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(slide.icon, color: Colors.white, size: 18),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    slide.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slide.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesRow() {
    final chips = <String?>[null, ..._categories];
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = chips[index];
          final selected = _selectedCategory == cat;
          final label = cat ?? tr('home.all');
          return GestureDetector(
            onTap: () => _selectCategory(cat),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : context.appSurface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected
                      ? AppColors.primary
                      : context.appBorder,
                ),
                boxShadow: selected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.28),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (selected) ...[
                    const Icon(Iconsax.tick_circle5, size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                  ] else if (cat == null) ...[
                    Icon(
                      Iconsax.category_2,
                      size: 14,
                      color: context.appTextSecondary,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : context.appTextPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Iconsax.box_1,
              size: 48,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            tr('home.no_products'),
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () => _loadItems(refresh: true),
            icon: const Icon(Iconsax.refresh, size: 18),
            label: Text(tr('home.retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _HeaderIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(12),
      elevation: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.appBorder),
          ),
          child: Icon(icon, size: 20, color: context.appTextPrimary),
        ),
      ),
    );
  }
}

class _SupportPhoneTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String displayNumber;
  final VoidCallback onCall;

  const _SupportPhoneTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.displayNumber,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayNumber,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: iconColor,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.call, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BannerSlide {
  final String title;
  final String subtitle;
  final List<Color> colors;
  final IconData icon;
  final bool openCategories;

  const _BannerSlide({
    required this.title,
    required this.subtitle,
    required this.colors,
    required this.icon,
    required this.openCategories,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Banner Manager Sheet — Admin only
// ─────────────────────────────────────────────────────────────────────────────

class _BannerManagerSheet extends StatefulWidget {
  final String storeId;
  final VoidCallback onChanged;

  const _BannerManagerSheet({
    required this.storeId,
    required this.onChanged,
  });

  @override
  State<_BannerManagerSheet> createState() => _BannerManagerSheetState();
}

class _BannerManagerSheetState extends State<_BannerManagerSheet> {
  List<String> _urls = [];
  bool _loading = true;
  bool _uploading = false;
  double _uploadProgress = 0;
  final Set<String> _deleting = {};

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    final urls = await S3UploadService.listBannerUrls(storeId: widget.storeId);
    if (!mounted) return;
    setState(() {
      _urls = urls;
      _loading = false;
    });
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final List<XFile> picked = await picker.pickMultiImage(imageQuality: 90);
    if (picked.isEmpty || !mounted) return;

    setState(() {
      _uploading = true;
      _uploadProgress = 0;
    });

    int done = 0;
    for (final file in picked) {
      await S3UploadService.uploadBannerImage(
        filePath: file.path,
        storeId: widget.storeId,
        onProgress: (p) {
          if (!mounted) return;
          setState(() {
            _uploadProgress = (done + p) / picked.length;
          });
        },
      );
      done++;
    }

    if (!mounted) return;
    setState(() {
      _uploading = false;
      _uploadProgress = 0;
    });
    await _refresh();
    widget.onChanged();
    if (mounted) {
      showAppSnackbar(
        context,
        message: _ar
            ? 'تم رفع ${picked.length} صورة بنجاح 🎉'
            : '${picked.length} banner(s) uploaded ✅',
        type: SnackType.success,
      );
    }
  }

  Future<void> _delete(String url) async {
    setState(() => _deleting.add(url));
    final ok = await S3UploadService.deleteBannerImage(url);
    if (!mounted) return;
    if (ok) {
      setState(() => _urls.remove(url));
      widget.onChanged();
      showAppSnackbar(
        context,
        message: _ar ? 'تم حذف الصورة' : 'Banner deleted',
        type: SnackType.success,
      );
    } else {
      showAppSnackbar(
        context,
        message: _ar ? 'فشل الحذف، حاول مجدداً' : 'Delete failed, try again',
        type: SnackType.error,
      );
    }
    setState(() => _deleting.remove(url));
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (ctx, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 4),
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[350],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    const Icon(
                      Iconsax.gallery_edit,
                      color: AppColors.primary,
                      size: 22,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      _ar ? 'إدارة البانرات الترويجية' : 'Manage Promo Banners',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Iconsax.close_circle),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              // Upload progress
              if (_uploading)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _ar
                            ? 'جاري الرفع... ${(_uploadProgress * 100).toInt()}%'
                            : 'Uploading... ${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _uploadProgress,
                          color: AppColors.primary,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                          minHeight: 6,
                        ),
                      ),
                    ],
                  ),
                ),
              // Upload button
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _uploading ? null : _pickAndUpload,
                    icon: const Icon(Iconsax.gallery_add, size: 20),
                    label: Text(
                      _ar ? 'رفع صور جديدة من المعرض' : 'Upload from Gallery',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),
              // Banner list
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _urls.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Iconsax.gallery_slash,
                                  size: 52,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _ar
                                      ? 'لا توجد بانرات حتى الآن\nارفع صوراً ترويجية من المعرض'
                                      : 'No banners yet\nUpload promo images from your gallery',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.grey[500],
                                    fontSize: 14,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            controller: scrollController,
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 16 / 9,
                            ),
                            itemCount: _urls.length,
                            itemBuilder: (_, i) {
                              final url = _urls[i];
                              final isDeleting = _deleting.contains(url);
                              return Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: CachedNetworkImage(
                                      imageUrl: url,
                                      fit: BoxFit.cover,
                                      placeholder: (_, __) => Container(
                                        color: const Color(0xFFE8EFE4),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: AppColors.primary,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Gradient overlay
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topCenter,
                                          end: Alignment.bottomCenter,
                                          colors: [
                                            Colors.transparent,
                                            Colors.black.withValues(alpha: 0.45),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Delete button
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: GestureDetector(
                                      onTap: isDeleting
                                          ? null
                                          : () => _confirmDelete(url),
                                      child: Container(
                                        width: 30,
                                        height: 30,
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          shape: BoxShape.circle,
                                        ),
                                        child: isDeleting
                                            ? const Padding(
                                                padding: EdgeInsets.all(6),
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  color: Colors.white,
                                                ),
                                              )
                                            : const Icon(
                                                Iconsax.trash,
                                                color: Colors.white,
                                                size: 15,
                                              ),
                                      ),
                                    ),
                                  ),
                                  // Sequence badge
                                  Positioned(
                                    bottom: 6,
                                    left: 6,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.black.withValues(alpha: 0.5),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${i + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDelete(String url) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          _ar ? 'حذف البانر؟' : 'Delete Banner?',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          _ar
              ? 'هل أنت متأكد من حذف هذه الصورة الترويجية؟ لا يمكن التراجع.'
              : 'Are you sure you want to delete this promo image? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              _ar ? 'إلغاء' : 'Cancel',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _delete(url);
            },
            child: Text(_ar ? 'حذف' : 'Delete'),
          ),
        ],
      ),
    );
  }
}
