import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/widgets/media_viewer_widget.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/features/auth/login.dart';
import 'package:GlobalFarm/features/profile/seller_profile_screen.dart';
import 'package:GlobalFarm/core/utils/app_responsive.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class ProductDetailScreen extends StatefulWidget {
  final Map<String, dynamic> item;
  const ProductDetailScreen({super.key, required this.item});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  bool _isLoading = false;
  int _cartQuantity = 0;
  String? _currentUserId;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isSubscribed = false;

  bool get _isOwnProduct =>
      _currentUserId != null &&
      _currentUserId ==
          (widget.item['seller_id'] ?? widget.item['uid'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    final isLoggedIn = await AuthService.isLoggedIn();
    final userId = await AuthService.getCurrentUserId();
    final isAdmin = await AuthService.isAdmin();
    final sellerId = (widget.item['seller_id'] ?? widget.item['uid'] ?? '')
        .toString();
    final isOwnProduct = userId != null && userId == sellerId;
    setState(() {
      _isLoggedIn = isLoggedIn;
      _currentUserId = userId;
      _isAdmin = isAdmin;
    });
    if (isLoggedIn && userId != null) {
      if (!isOwnProduct && !isAdmin) {
        _loadCartQuantity(userId);
      }
      _checkNotifyStatus();
    }
  }

  Future<void> _checkNotifyStatus() async {
    if (_currentUserId == null) return;
    try {
      final result = await ApiService.checkNotifyStatus(
        itemId: widget.item['id'].toString(),
        userId: _currentUserId!,
      );
      if (result['success'] == true && mounted) {
        setState(() => _isSubscribed = result['is_subscribed'] == true);
      }
    } catch (e) {}
  }

  Future<void> _addNotifyRequest() async {
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    if (_currentUserId == null) return;
    try {
      final result = await ApiService.addNotifyRequest(
        itemId: widget.item['id'].toString(),
        userId: _currentUserId!,
        storeId:
            widget.item['storeid']?.toString() ??
            widget.item['store_id']?.toString() ??
            AppConfig.storeId,
      );
      if (result['success'] == true && mounted) {
        setState(() => _isSubscribed = true);
        showAppSnackbar(
          context,
          message: tr('product.notify_success'),
          type: SnackType.success,
        );
      }
    } catch (e) {}
  }

  Future<void> _loadCartQuantity(String userId) async {
    try {
      final result = await ApiService.getCartQuantity(
        itemId: widget.item['id'].toString(),
        userId: userId,
      );
      if (result['success'] == true && mounted) {
        setState(() => _cartQuantity = result['quantity'] ?? 0);
      }
    } catch (e) {}
  }

  Future<void> _addToCart() async {
    if (_isOwnProduct || _isAdmin) return;
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
      return;
    }
    if (_currentUserId == null) return;

    final stockQty =
        int.tryParse(
          widget.item['qtt']?.toString() ??
              widget.item['quantity']?.toString() ??
              '0',
        ) ??
        0;
    if (stockQty > 0 && _cartQuantity >= stockQty) {
      showAppSnackbar(
        context,
        message: '${tr('cart.available_quantity')}: $stockQty',
        type: SnackType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await ApiService.addToCart(
        itemId: widget.item['id'].toString(),
        userId: _currentUserId!,
        quantity: 1,
      );
      if (result['success'] == true) {
        setState(() => _cartQuantity = result['quantity'] ?? _cartQuantity + 1);
        if (!mounted) return;
        showAppSnackbar(
          context,
          message: tr('product.added_to_cart'),
          type: SnackType.success,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: tr('common.error'), type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _removeFromCart() async {
    if (_isOwnProduct || _isAdmin) return;
    if (_currentUserId == null) return;
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.removeFromCart(
        itemId: widget.item['id'].toString(),
        userId: _currentUserId!,
      );
      if (result['success'] == true && mounted) {
        final serverQty = result['quantity'];
        setState(() {
          _cartQuantity = serverQty is int
              ? serverQty
              : int.tryParse(serverQty?.toString() ?? '') ??
                    (_cartQuantity - 1).clamp(0, 999);
        });
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(context, message: tr('common.error'), type: SnackType.error);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final itemId = item['id']?.toString() ?? '';
    final itemIdx = item['idx']?.toString() ?? '';
    final storeId =
        item['storeid']?.toString() ?? item['store_id']?.toString() ?? AppConfig.storeId;
    final lang = LocalizationService.instance.currentLanguage;
    final name = lang == 'ar'
        ? (item['name']?.toString() ?? '')
        : (item['eng']?.toString().isNotEmpty == true
              ? item['eng'].toString()
              : item['name']?.toString() ?? '');
    final price = item['price']?.toString() ?? '0';
    final description = lang == 'ar'
        ? (item['description_arb']?.toString().isNotEmpty == true
              ? item['description_arb'].toString()
              : item['description']?.toString() ?? '')
        : (item['description']?.toString() ?? '');
    final sellerName = item['seller_name']?.toString() ?? '';
    final sellerId =
        item['seller_id']?.toString() ?? item['uid']?.toString() ?? '';
    final stockQty =
        int.tryParse(
          item['qtt']?.toString() ?? item['quantity']?.toString() ?? '0',
        ) ??
        0;
    final isOutOfStock = stockQty == 0;

    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: context.appSurface,
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: AppResponsive.isTablet(context) ? 480 : 400,
              pinned: true,
              backgroundColor: context.appSurface,
              leading: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Iconsax.arrow_right_3,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
              ),
              flexibleSpace: FlexibleSpaceBar(
                stretchModes: const [StretchMode.zoomBackground],
                background: SizedBox.expand(
                  child: MediaViewerWidget(
                    mediaUrls: const [],
                    itmId: itemId,
                    itmIdx: itemIdx,
                    storeid: storeId,
                    autoPlayVideo: false,
                    showControls: true,
                    showIndicators: true,
                  ),
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // Title — full width so the name breathes
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                        color: context.appTextPrimary,
                      ),
                      textAlign: TextAlign.right,
                    ),

                    const SizedBox(height: 14),

                    // Price + stock on a calmer secondary row
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: isOutOfStock
                                ? Colors.red.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            isOutOfStock
                                ? tr('product.out_of_stock')
                                : '${tr('product.available')} ($stockQty)',
                            style: TextStyle(
                              color: isOutOfStock
                                  ? Colors.red
                                  : AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            '$price ${tr('common.currency')}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    const Divider(),
                    const SizedBox(height: 12),

                    if (sellerName.isNotEmpty) ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                sellerName,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                  color: context.appTextPrimary,
                                ),
                              ),
                              Text(
                                tr('product.seller'),
                                style: const TextStyle(
                                  color: Colors.grey,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 12),
                          GestureDetector(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    SellerProfileScreen(userId: sellerId),
                              ),
                            ),
                            child: SmartAvatarWidget(
                              userId: sellerId,
                              name: sellerName,
                              size: 48,
                              backgroundColor: AppColors.secondary,
                              initialsStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                    ],

                    if (description.isNotEmpty) ...[
                      Text(
                        tr('product.description'),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurface,
                          height: 1.6,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 100),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),

        bottomNavigationBar: Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          decoration: BoxDecoration(
            color: context.appSurface,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: _isAdmin
              ? Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.box_1, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        '${tr('product.stock_quantity')}: $stockQty',
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : _isOwnProduct
              ? Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.box, color: AppColors.primary, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        tr('product.your_product'),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                )
              : isOutOfStock
              ? ElevatedButton.icon(
                  onPressed: _isSubscribed ? null : _addNotifyRequest,
                  icon: Icon(
                    _isSubscribed
                        ? Iconsax.notification5
                        : Iconsax.notification,
                  ),
                  label: Text(
                    _isSubscribed
                        ? tr('product.notify_registered')
                        : tr('product.notify_me'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSubscribed
                        ? Colors.grey[400]
                        : AppColors.secondary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                )
              : _cartQuantity == 0
              ? GestureDetector(
                  onTap: _isLoading ? null : _addToCart,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                    height: 56,
                    decoration: BoxDecoration(
                      color: _isLoading
                          ? AppColors.primary.withOpacity(0.7)
                          : AppColors.primary,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.4),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Iconsax.shopping_cart,
                                  color: Colors.white,
                                  size: 22,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  tr('product.add_to_cart'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                )
              : Row(
                  children: [
                    GestureDetector(
                      onTap: _isLoading ? null : _removeFromCart,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _cartQuantity == 1
                              ? Colors.red.withOpacity(0.1)
                              : AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _cartQuantity == 1
                                ? Colors.red.withOpacity(0.3)
                                : AppColors.primary.withOpacity(0.3),
                          ),
                        ),
                        child: Icon(
                          _cartQuantity == 1 ? Iconsax.trash : Iconsax.minus,
                          color: _cartQuantity == 1
                              ? Colors.red
                              : AppColors.primary,
                          size: 22,
                        ),
                      ),
                    ),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) =>
                            ScaleTransition(scale: animation, child: child),
                        child: Column(
                          key: ValueKey<int>(_cartQuantity),
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$_cartQuantity',
                              style: TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                                color: context.appTextPrimary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            Text(
                              tr('product.in_cart'),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: _isLoading || _cartQuantity >= stockQty
                          ? null
                          : _addToCart,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: _cartQuantity >= stockQty
                              ? Colors.grey.withOpacity(0.1)
                              : AppColors.primary,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _cartQuantity >= stockQty
                              ? []
                              : [
                                  BoxShadow(
                                    color: AppColors.primary.withOpacity(0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
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
                            : Icon(
                                Iconsax.add,
                                color: _cartQuantity >= stockQty
                                    ? Colors.grey
                                    : Colors.white,
                                size: 22,
                              ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
