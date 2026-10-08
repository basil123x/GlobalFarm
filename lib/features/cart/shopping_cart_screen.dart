import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/models/cart_model.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/widgets/item_thumbnail_widget.dart';
import 'package:GlobalFarm/core/utils/app_responsive.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/order/order_summary_screen.dart';

class ShoppingCartScreen extends StatefulWidget {
  final String userId;
  /// When true (tab selected), cart reloads so new adds appear immediately.
  final bool isActive;
  /// Switch to Home/products inside the shell — avoids black screen from pop.
  final VoidCallback? onBrowseProducts;
  final bool showBackButton;

  const ShoppingCartScreen({
    super.key,
    required this.userId,
    this.isActive = true,
    this.onBrowseProducts,
    this.showBackButton = true,
  });

  @override
  State<ShoppingCartScreen> createState() => _ShoppingCartScreenState();
}

class _ShoppingCartScreenState extends State<ShoppingCartScreen> {
  List<CartItemModel> _cartItems = [];
  bool _isLoading = true;
  bool _hasError = false;
  double _totalAmount = 0.0;

  @override
  void initState() {
    super.initState();
    _loadCartItems();
  }

  @override
  void didUpdateWidget(covariant ShoppingCartScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.userId != oldWidget.userId) {
      _loadCartItems();
      return;
    }
    // Reload whenever the cart tab becomes visible again
    if (widget.isActive && !oldWidget.isActive) {
      _loadCartItems(silent: true);
    }
  }

  void _goBrowseProducts() {
    if (widget.onBrowseProducts != null) {
      widget.onBrowseProducts!();
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _loadCartItems({bool silent = false}) async {
    if (!silent || _cartItems.isEmpty) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      print('Loading cart for userId: ${widget.userId}');
      final result = await ApiService.getCartItems(userId: widget.userId);
      print('Cart result: $result');

      if (!mounted) return;

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _cartItems = data.map((item) {
            print('Parsing cart item: $item');
            final map = item is Map<String, dynamic>
                ? item
                : Map<String, dynamic>.from(item as Map);
            return CartItemModel.fromJson(map);
          }).toList();
          _calculateTotal();
          _isLoading = false;
          _hasError = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading cart items: $e');
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _calculateTotal() {
    _totalAmount = 0.0;
    for (var item in _cartItems) {
      _totalAmount += (double.parse(item.item.price) * item.cartQuantity);
    }
  }

  Future<void> _updateQuantity(String cartId, int newQuantity) async {
    try {
      final result = await ApiService.updateCartQuantity(
        cartId: cartId,
        quantity: newQuantity,
      );

      if (result['success'] == true) {
        if (newQuantity == 0) {
          // Remove item from list
          setState(() {
            _cartItems.removeWhere((item) => item.cartId == cartId);
            _calculateTotal();
          });
        } else {
          // Update quantity
          setState(() {
            final index = _cartItems.indexWhere(
              (item) => item.cartId == cartId,
            );
            if (index != -1) {
              _cartItems[index].cartQuantity = newQuantity;
              _calculateTotal();
            }
          });
        }

        if (newQuantity == 0) {
          showAppSnackbar(
            context,
            message: tr('cart.item_removed'),
            type: SnackType.success,
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? tr('cart.update_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: tr('cart.update_error'),
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        // backgroundColor: const Color(0xFF0A0E27),
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          leading: widget.showBackButton
              ? IconButton(
                  onPressed: _goBrowseProducts,
                  icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
                )
              : null,
          title: Text(
            tr('cart.title'),
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 12),
              child: Material(
                color: context.appSurface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: _loadCartItems,
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
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _hasError
            ? _buildErrorWidget()
            : _cartItems.isEmpty
            ? _buildEmptyCartWidget()
            : Column(
                children: [
                  Expanded(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: AppResponsive.isTablet(context)
                              ? 720
                              : double.infinity,
                        ),
                        child: RefreshIndicator(
                          color: AppColors.primary,
                          onRefresh: _loadCartItems,
                          child: ListView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.all(16),
                            itemCount: _cartItems.length,
                            itemBuilder: (context, index) {
                              return _buildCartItem(_cartItems[index]);
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: AppResponsive.isTablet(context)
                            ? 720
                            : double.infinity,
                      ),
                      child: _buildBottomSummary(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Iconsax.warning_2, size: 80, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            tr('cart.load_error'),
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadCartItems,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('cart.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCartWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(60),
            ),
            child: const Icon(
              Iconsax.shopping_cart,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('cart.empty'),
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('cart.empty_message'),
            style: TextStyle(
              // color: Colors.white.withOpacity(0.7),
              color: context.appTextSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: _goBrowseProducts,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: Text(
              tr('cart.browse_products'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCartItem(CartItemModel cartItem) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Product Image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: ItemThumbnailWidget(
                itemId: cartItem.item.id,
                itemIdx: cartItem.item.idx,
                storeId: cartItem.item.store_id,
                mediaValue: cartItem.item.media.isNotEmpty
                    ? cartItem.item.media
                    : null,
                thumbnailUrl: cartItem.item.thumbnail.isNotEmpty
                    ? cartItem.item.thumbnail
                    : null,
                width: 80,
                height: 80,
                fit: BoxFit.cover,
                borderRadius: BorderRadius.circular(13),
                placeholderColor: Colors.grey[800],
              ),
            ),

            const SizedBox(width: 16),

            // Product Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    cartItem.item.name,
                    style: TextStyle(
                      // color: Colors.white,
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${tr('product.seller')}: ${cartItem.seller.name}',
                    style: TextStyle(
                      // color: Colors.white.withOpacity(0.7),
                      color: context.appTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.5),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '${cartItem.item.price} ${tr('common.currency')}',
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 16),

            // Quantity Controls
            Column(
              children: [
                // Increase Button
                GestureDetector(
                  onTap: cartItem.cartQuantity < cartItem.item.availableQuantity
                      ? () => _updateQuantity(
                          cartItem.cartId,
                          cartItem.cartQuantity + 1,
                        )
                      : null,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color:
                          cartItem.cartQuantity <
                              cartItem.item.availableQuantity
                          ? AppColors.primary
                          : Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(
                      Iconsax.add,
                      color:
                          cartItem.cartQuantity <
                              cartItem.item.availableQuantity
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Quantity Display
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      // color: Colors.white.withOpacity(0.2),
                      color: AppColors.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    cartItem.cartQuantity.toString(),
                    style: TextStyle(
                      // color: Colors.white,
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Decrease Button
                GestureDetector(
                  onTap: () => _updateQuantity(
                    cartItem.cartId,
                    cartItem.cartQuantity - 1,
                  ),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Iconsax.minus,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.bottomBarGradient(),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: SafeArea(
        child: Column(
          children: [
            // Total Amount
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${tr('cart.grand_total')}:',
                  style: TextStyle(
                    // color: Colors.white,
                    color: context.appTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    '${_totalAmount.toStringAsFixed(2)} ${tr('common.currency')}',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Continue Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _cartItems.isNotEmpty
                    ? () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => OrderSummaryScreen(
                              userId: widget.userId,
                              cartItems: _cartItems,
                              totalAmount: _totalAmount,
                            ),
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      tr('cart.order_summary'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Iconsax.arrow_left_2, size: 20),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
