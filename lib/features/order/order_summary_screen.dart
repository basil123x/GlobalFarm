import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/models/cart_model.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/widgets/item_thumbnail_widget.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/shipping/shipping_address_screen.dart';

class OrderSummaryScreen extends StatefulWidget {
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;

  const OrderSummaryScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
  });

  @override
  State<OrderSummaryScreen> createState() => _OrderSummaryScreenState();
}

class _OrderSummaryScreenState extends State<OrderSummaryScreen> {
  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: context.appBackground,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            tr('orders.summary_title'),
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Items Section
                    _buildSectionTitle(
                      tr('orders.order_items'),
                      Iconsax.shopping_bag,
                    ),
                    const SizedBox(height: 16),
                    ...widget.cartItems.map((item) => _buildOrderItem(item)),

                    const SizedBox(height: 24),

                    // Order Summary Section
                    _buildSectionTitle(
                      tr('orders.cost_summary'),
                      Iconsax.receipt,
                    ),
                    const SizedBox(height: 16),
                    _buildOrderSummary(),
                  ],
                ),
              ),
            ),

            // Continue Button
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary.withOpacity(0.2), Colors.transparent],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 20),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderItem(CartItemModel cartItem) {
    final itemTotal = double.parse(cartItem.item.price) * cartItem.cartQuantity;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: Row(
        children: [
          // Product Image
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: ItemThumbnailWidget(
              itemId: cartItem.item.id,
              itemIdx: cartItem.item.idx,
              storeId: cartItem.item.store_id,
              mediaValue:
                  cartItem.item.media.isNotEmpty ? cartItem.item.media : null,
              thumbnailUrl: cartItem.item.thumbnail.isNotEmpty
                  ? cartItem.item.thumbnail
                  : null,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(11),
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
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${tr('orders.seller')}: ${cartItem.seller.name}',
                  style: TextStyle(
                    // color: Colors.white.withOpacity(0.6),
                    color: context.appTextSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: context.isDarkMode
                            ? AppColors.darkElevated.withOpacity(0.5)
                            : Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${tr('orders.quantity')}: ${cartItem.cartQuantity}',
                        style: TextStyle(
                          // color: Colors.white,
                          color: context.appTextPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${itemTotal.toStringAsFixed(2)} ${tr('orders.currency')}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSummary() {
    final subtotal = widget.totalAmount;
    const shipping = 0.0; // Free shipping for now
    const tax = 0.0; // No tax for now
    final total = subtotal + shipping + tax;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            '${tr('orders.subtotal')}:',
            '${subtotal.toStringAsFixed(2)} ${tr('orders.currency')}',
          ),
          const SizedBox(height: 12),
          _buildSummaryRow(
            '${tr('orders.shipping')}:',
            shipping == 0
                ? tr('orders.free')
                : '${shipping.toStringAsFixed(2)} ${tr('orders.currency')}',
          ),

          // const SizedBox(height: 12),
          // _buildSummaryRow(
          //   'الضريبة:',
          //   tax == 0 ? 'غير مطبقة' : '${tax.toStringAsFixed(2)} ريال',
          // ),
          const SizedBox(height: 16),

          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppColors.primary.withOpacity(0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${tr('orders.grand_total')}:',
                style: TextStyle(
                  // color: Colors.white,
                  color: context.appTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
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
                  '${total.toStringAsFixed(2)} ${tr('orders.currency')}',
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
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            // color: Colors.white.withOpacity(0.8),
            color: context.appTextSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            // color: Colors.white,
            color: context.appTextPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
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
            onPressed: () async {
              final currentUid = await AuthService.getCurrentUID();
              if (currentUid != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ShippingAddressScreen(
                      userId: widget.userId,
                      uid: currentUid,
                      cartItems: widget.cartItems,
                      totalAmount: widget.totalAmount,
                    ),
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              elevation: 8,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  tr('orders.continue_to_shipping'),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 8),
                Transform.flip(
                  flipX: true,
                  child: const Icon(Iconsax.truck, size: 20),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
