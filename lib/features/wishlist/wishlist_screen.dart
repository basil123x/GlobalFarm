import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
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

/// Wishlist tab — updates instantly when liking from Home/Categories.
class WishlistScreen extends StatefulWidget {
  final bool isActive;

  const WishlistScreen({super.key, this.isActive = true});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  String? _userId;
  final Map<String, int> _cartQuantities = {};

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  @override
  void initState() {
    super.initState();
    WishlistService.instance.addListener(_onWishlistChanged);
    _bootstrap();
  }

  @override
  void dispose() {
    WishlistService.instance.removeListener(_onWishlistChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant WishlistScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !oldWidget.isActive) {
      _syncFromServer(silent: true);
    }
  }

  void _onWishlistChanged() {
    if (mounted) setState(() {});
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
    if (loggedIn && uid != null && uid.isNotEmpty) {
      await _syncFromServer();
    } else {
      WishlistService.instance.clear();
    }
  }

  Future<void> _syncFromServer({bool silent = false}) async {
    final loggedIn = await AuthService.isLoggedIn();
    final uid = await AuthService.getCurrentUserId();

    if (!loggedIn || uid == null || uid.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isLoggedIn = false;
        _userId = null;
        _isAdmin = false;
        _isLoading = false;
      });
      WishlistService.instance.clear();
      return;
    }

    if (!silent || WishlistService.instance.items.isEmpty) {
      if (mounted) setState(() => _isLoading = true);
    }

    try {
      final liked = <ItemModel>[];
      var offset = 0;
      const pageSize = 40;
      for (var i = 0; i < 8; i++) {
        final batch = await ApiService.fetchItemsWithLikes(
          userId: uid,
          limit: pageSize,
          offset: offset,
        );
        liked.addAll(batch.where((e) => e.interactions.isLiked));
        offset += batch.length;
        if (batch.length < pageSize) break;
      }

      // Merge: keep locally liked items that may not be in the first pages yet.
      final merged = <String, ItemModel>{
        for (final e in WishlistService.instance.items) e.id: e,
        for (final e in liked) e.id: e,
      };

      WishlistService.instance.replaceAll(merged.values.toList());

      final admin = await AuthService.isAdmin();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _userId = uid;
        _isAdmin = admin;
        for (final item in merged.values) {
          _cartQuantities[item.id] = item.interactions.cartQuantity;
        }
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Wishlist sync error: $e');
      final admin = await AuthService.isAdmin();
      if (!mounted) return;
      setState(() {
        _isLoggedIn = true;
        _userId = uid;
        _isAdmin = admin;
        _isLoading = false;
      });
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

  Future<void> _toggleLike(ItemModel item) async {
    if (_userId == null) return;
    final wasLiked = item.interactions.isLiked;
    setState(() {
      item.interactions.isLiked = !wasLiked;
      item.interactions.likes += wasLiked ? -1 : 1;
    });
    WishlistService.instance.setLiked(item, !wasLiked);

    try {
      await ApiService.toggleLike(itemId: item.id, userId: _userId!);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        item.interactions.isLiked = wasLiked;
        item.interactions.likes += wasLiked ? 1 : -1;
      });
      WishlistService.instance.setLiked(item, wasLiked);
      showAppSnackbar(
        context,
        message: tr('wishlist.update_error'),
        type: SnackType.error,
      );
    }
  }

  void _setCartQty(String itemId, int quantity) {
    setState(() {
      _cartQuantities[itemId] = quantity;
      final cached = WishlistService.instance.items
          .where((e) => e.id == itemId)
          .toList();
      if (cached.isNotEmpty) {
        cached.first.interactions.cartQuantity = quantity;
      }
    });
  }

  Future<void> _addToCart(ItemModel item) async {
    if (_isAdmin) return;
    if (_userId == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      await _bootstrap();
      if (!mounted || _userId == null) return;
    }

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
      await ApiService.addToCart(
        itemId: item.id,
        userId: _userId!,
        quantity: 1,
      );
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
    if (_userId == null) return;
    final current = _cartQuantities[item.id] ?? 0;
    if (current <= 0) return;

    final previous = current;
    _setCartQty(item.id, current - 1);
    try {
      final result = await ApiService.removeFromCart(
        itemId: item.id,
        userId: _userId!,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = WishlistService.instance.items;

    return Scaffold(
      backgroundColor: context.appBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tr('wishlist.title'),
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: context.appTextPrimary,
                      ),
                    ),
                  ),
                  Material(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      onTap: () => _syncFromServer(),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.appBorder),
                        ),
                        child: Icon(
                          Iconsax.refresh,
                          size: 20,
                          color: context.appTextPrimary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _buildBody(items)),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(List<ItemModel> items) {
    if (_isLoading && items.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (!_isLoggedIn) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.heart, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                tr('wishlist.login_prompt'),
                textAlign: TextAlign.center,
                style: TextStyle(color: context.appTextSecondary, fontSize: 16),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                  await _bootstrap();
                },
                icon: const Icon(Iconsax.login, size: 18),
                label: Text(tr('wishlist.sign_in')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.heart, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              tr('wishlist.empty'),
              style: TextStyle(color: context.appTextSecondary, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: () => _syncFromServer(),
      child: GridView.builder(
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        padding: AppResponsive.productGridPadding(context),
        gridDelegate: AppResponsive.productGridDelegate(context),
        itemCount: items.length,
        itemBuilder: (context, index) {
          final item = items[index];
          return ProductGridCard(
            item: item,
            quantity: _cartQuantities[item.id] ??
                item.interactions.cartQuantity,
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
      ),
    );
  }
}
