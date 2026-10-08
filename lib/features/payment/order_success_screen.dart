import 'dart:math';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_config.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/services/api_service.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/localization_service.dart';
import '../sellers/sellers_contact_screen.dart';
import '../../core/utils/theme_extensions.dart';
import '../orders/invoice_webview.dart';

class OrderSuccessScreen extends StatefulWidget {
  final String? transStatus;
  /// `visa` = Sadad/card, `credit` = cash on delivery
  final String paymentMode;
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;
  final ShippingAddressModel shippingAddress;

  const OrderSuccessScreen({
    super.key,
    this.transStatus,
    this.paymentMode = 'visa',
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
    required this.shippingAddress,
  });

  @override
  State<OrderSuccessScreen> createState() => _OrderSuccessScreenState();
}

class _OrderSuccessScreenState extends State<OrderSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    if (widget.transStatus == '3') {
      _createOrders();
    }
  }

  Future<void> _createOrders() async {
    try {
      // Group cart items by seller
      Map<String, List<CartItemModel>> itemsBySeller = {};
      for (var cartItem in widget.cartItems) {
        String sellerId = cartItem.seller.id;
        if (!itemsBySeller.containsKey(sellerId)) {
          itemsBySeller[sellerId] = [];
        }
        itemsBySeller[sellerId]!.add(cartItem);
      }

      // Get current OID
      final currentOid = await AuthService.getCurrentOID();

      // Create order for each seller
      for (var entry in itemsBySeller.entries) {
        String sellerId = entry.key;
        List<CartItemModel> sellerItems = entry.value;

        // Calculate total for this seller
        double sellerTotal = 0.0;
        for (var item in sellerItems) {
          sellerTotal += (double.parse(item.item.price) * item.cartQuantity);
        }

        // Prepare items JSON
        String itemsJson = sellerItems
            .map(
              (item) =>
                  '{"id":"${item.item.id}","name":"${item.item.name}","price":"${item.item.price}","quantity":${item.cartQuantity}}',
            )
            .join(',');
        itemsJson = '[$itemsJson]';

        // Create order on Martit
        final orderResult = await ApiService.createOrder(
          uid: sellerId,
          custId: widget.userId,
          oid: currentOid ?? '',
          shipId: widget.shippingAddress.id.toString(),
          items: itemsJson,
          totalAmount: sellerTotal.toStringAsFixed(2),
        );

        final martitOrderId = orderResult['order_id']?.toString() ?? '';
        final address = widget.shippingAddress;
        final notes =
            'App order OID: ${currentOid ?? ''} | '
            '${address.city}, ${address.country} | '
            '${address.streetNumber} - ${address.buildingNumber}';

        final syncItems = sellerItems.map((cartItem) {
          final itemId = cartItem.item.idx.isNotEmpty
              ? cartItem.item.idx
              : cartItem.item.id;
          return {
            'itemid': int.tryParse(itemId) ?? itemId,
            'qtt': cartItem.cartQuantity,
            'price': double.tryParse(cartItem.item.price) ?? 0,
            'discx': 0,
            'cost': 0,
            'invtype': 'a14',
            'branch': int.tryParse(AppConfig.storeId) ?? 2,
            'notes': cartItem.item.name,
          };
        }).toList();

        // Sync invoice to Gfnursery (inv + inv_det)
        await ApiService.syncOrderToGlobalFarm(
          oid: currentOid ?? '',
          customerName: address.fullname,
          customerPhone: address.mobile,
          customerUid: widget.userId,
          notes: notes,
          total: sellerTotal,
          paymentMode: widget.paymentMode,
          items: syncItems,
          martitOrderId: martitOrderId,
        );
      }

      print('✅ Orders created successfully');
    } catch (e) {
      print('❌ Error creating orders: $e');
    }
  }

  Future<void> _clearCartAndUpdateOID() async {
    try {
      // Generate new 4-digit OID
      final newOid = (1000 + Random().nextInt(9000)).toString();

      // Clear cart and update OID in database
      await ApiService.clearCartAndUpdateOID(
        userId: widget.userId,
        newOid: newOid,
      );

      // Update OID in local storage
      const storage = FlutterSecureStorage();
      await storage.write(key: 'user_oid', value: newOid);

      print('✅ Cart cleared and OID updated to: $newOid');
    } catch (e) {
      print('❌ Error clearing cart and updating OID: $e');
    }
  }

  Future<void> _openInvoice(String orderId) async {
    print("My Bill Order Id ---> $orderId");
    final Uri url = Uri.parse(
      InvoiceWebView.buildUrl(orderId: orderId, view: 'customer'),
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppWebView,
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    )) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(content: Text(tr('orders.invoice_open_failed'))),
        );
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    print(widget.transStatus);
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Success Animation with Green Glow
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  colors: [
                                    Colors.green.withOpacity(0.4),
                                    Colors.green.withOpacity(0.2),
                                    Colors.green.withOpacity(0.05),
                                    Colors.transparent,
                                  ],
                                ),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    color: widget.transStatus != '3' ? Colors.red : Colors.green,
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: widget.transStatus != '3' ? Colors.red :Colors.green.withOpacity(0.35),
                                        blurRadius: 40,
                                        spreadRadius: widget.transStatus != '3' ? 1 : 15,
                                      ),
                                      BoxShadow(
                                        color: widget.transStatus != '3' ? Colors.red : Colors.green.withOpacity(0.15),
                                        blurRadius: 70,
                                        spreadRadius: widget.transStatus != '3' ? 1 : 30,
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    widget.transStatus != '3' ? Icons.close_rounded : Icons.check_rounded,
                                    color: Colors.white,
                                    size: 55,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 32),

                      // Success Message
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          children: [
                            Text(
                              widget.transStatus != '3'
                                  ? tr('orders.payment_failed_title')
                                  : tr('orders.payment_success_title'),
                              style: TextStyle(
                                color: context.appTextPrimary,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              widget.transStatus != '3'
                                  ? tr('orders.payment_failed_subtitle')
                                  : tr('orders.payment_success_subtitle'),
                              style: TextStyle(
                                color: context.appTextSecondary,
                                fontSize: 16,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 40),

                      // Order Summary Card with Purple/Lavender Background
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: context.appSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: context.appBorder,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              // Header with Receipt Icon
                              Row(
                                children: [
                                  Icon(
                                    Iconsax.receipt_2,
                                    color: AppColors.primary,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    tr('orders.summary_title'),
                                    style: TextStyle(
                                      color: context.appTextPrimary,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Number of Items
                              _buildSummaryRow(
                                tr('orders.items_count'),
                                '${widget.cartItems.length} ${tr('orders.item_unit')}',
                              ),
                              const SizedBox(height: 12),
                              
                              // Total Amount
                              _buildSummaryRow(
                                tr('orders.total_amount'),
                                '${widget.totalAmount.toStringAsFixed(2)} ${tr('orders.currency')}',
                              ),
                              const SizedBox(height: 12),
                              
                              // Address
                              _buildSummaryRow(
                                tr('orders.address'),
                                '${widget.shippingAddress.city}, ${widget.shippingAddress.country}, ${tr('orders.street')} ${widget.shippingAddress.streetNumber}, ${tr('orders.building')} ${widget.shippingAddress.buildingNumber}, ${tr('orders.zone')} ${widget.shippingAddress.zoneNumber}',
                              ),


                              // Info Box
                                Visibility(
                                  visible: widget.transStatus != '3' ? false : true,
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.35),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Iconsax.info_circle,
                                        color: AppColors.primary,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          tr('orders.contact_soon_note'),
                                          style: TextStyle(
                                            color: AppColors.primary,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Buttons
                FadeTransition(
                  opacity: _fadeAnimation,
                  child: Column(
                    children: [
                      // Contact Sellers Button (Primary - Olive Green)
                      Visibility(
                        visible: widget.transStatus != '3' ? false : true,
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      SellersContactScreen(userId: widget.userId),
                                ),
                              );
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
                            icon: const Icon(Iconsax.message),
                            label: Text(
                              tr('orders.contact_sellers'),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Secondary Row: Home and Invoice Buttons
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                if (widget.transStatus == '3') {
                                  _clearCartAndUpdateOID();
                                }
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MainShell(),
                                  ),
                                );
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.appTextPrimary,
                                side: BorderSide(color: context.appBorder),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Iconsax.home),
                              label: Text(
                                tr('orders.home'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          if (widget.transStatus == '3')
                          const SizedBox(width: 16),
                          if (widget.transStatus == '3')
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                String orderId = "";
                                for (var carto in widget.cartItems) {
                                  orderId = carto.orderId;
                                }
                                _openInvoice(orderId);
                              },
                              style: OutlinedButton.styleFrom(
                                foregroundColor: context.appTextPrimary,
                                side: BorderSide(color: context.appBorder),
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Iconsax.bill),
                              label: Text(
                                tr('orders.view_your_invoice'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: context.appTextSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '→',
          style: TextStyle(
            color: context.appTextPrimary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.start,
          ),
        ),
      ],
    );
  }
}
