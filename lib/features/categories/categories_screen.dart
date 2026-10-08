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
import 'package:GlobalFarm/features/product/product_detail_screen.dart';

/// Categories tab — same product cards as Home (heart + animated cart).
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<String> _categories = [];
  String? _selectedCategory;
  List<ItemModel> _items = [];
  bool _isLoadingCats = true;
  bool _isLoadingItems = false;
  String? _userId;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  final Map<String, int> _cartQuantities = {};

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  bool _isProjectsCategory(String name) {
    final n = name.toLowerCase();
    return n.contains('مشروع') ||
        n.contains('استشار') ||
        n.contains('project') ||
        n.contains('consult');
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final loggedIn = await AuthService.isLoggedIn();
    final uid = await AuthService.getCurrentUserId();
    final admin = await AuthService.isAdmin();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = loggedIn;
      _userId = uid;
      _isAdmin = admin;
    });
    await _loadCategories();
  }

  Future<void> _loadCategories() async {
    setState(() => _isLoadingCats = true);
    try {
      final cats = await ApiService.getCategories(storeId: AppConfig.storeId);
      if (!mounted) return;
      setState(() {
        _categories = cats.where((c) => !_isProjectsCategory(c)).toList();
        _isLoadingCats = false;
      });

      if (_categories.isNotEmpty) {
        await _selectCategory(_categories.first);
      }
    } catch (e) {
      debugPrint('Categories load error: $e');
      if (!mounted) return;
      setState(() => _isLoadingCats = false);
    }
  }

  Future<void> _selectCategory(String category) async {
    setState(() {
      _selectedCategory = category;
      _isLoadingItems = true;
      _items = [];
    });

    try {
      final List<ItemModel> fetched;
      if (_isLoggedIn && _userId != null) {
        fetched = await ApiService.fetchItemsWithLikes(
          userId: _userId!,
          limit: 40,
          offset: 0,
          category: category,
        );
      } else {
        fetched = await ApiService.fetchItems(
          page: 0,
          userId: _userId,
          category: category,
        );
      }

      if (!mounted) return;
      setState(() {
        _items = fetched;
        for (final item in fetched) {
          _cartQuantities[item.id] = item.interactions.cartQuantity;
        }
        _isLoadingItems = false;
      });
    } catch (e) {
      debugPrint('Category items error: $e');
      if (!mounted) return;
      setState(() => _isLoadingItems = false);
    }
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
    if (!mounted) return null;
    final admin = await AuthService.isAdmin();
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
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                tr('home.categories_title'),
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
            ),
            if (_isLoadingCats)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else ...[
              _buildCategoryChips(),
              const SizedBox(height: 8),
              Expanded(child: _buildProducts()),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: _categories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final selected = _selectedCategory == cat;
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
                    const Icon(
                      Iconsax.tick_circle5,
                      size: 14,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    cat,
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

  Widget _buildProducts() {
    if (_selectedCategory == null) {
      return Center(
        child: Text(
          tr('home.select_category_hint'),
          style: TextStyle(color: context.appTextSecondary),
        ),
      );
    }

    if (_isLoadingItems) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.box_1, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              tr('home.no_products_in_category'),
              style: TextStyle(color: context.appTextSecondary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      physics: const BouncingScrollPhysics(),
      padding: AppResponsive.productGridPadding(context),
      gridDelegate: AppResponsive.productGridDelegate(context),
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ProductGridCard(
          item: item,
          quantity: _cartQuantities[item.id] ?? 0,
          isOwn: _userId != null && _userId == item.seller.id,
          isAdmin: _isAdmin,
          isArabic: _ar,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ProductDetailScreen(item: _detailMap(item)),
              ),
            );
          },
          onLike: () => _toggleLike(item),
          onAddToCart: () => _addToCart(item),
          onRemoveFromCart: () => _removeFromCart(item),
        );
      },
    );
  }
}
