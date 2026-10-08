import 'dart:math';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/models/cart_model.dart';
import 'package:GlobalFarm/core/models/shipping_address_model.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/features/sellers/sellers_contact_screen.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/orders/invoice_webview.dart';

class PaymentSuccessScreen extends StatefulWidget {
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;
  final ShippingAddressModel shippingAddress;

  const PaymentSuccessScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
    required this.shippingAddress,
  });

  @override
  State<PaymentSuccessScreen> createState() => _PaymentSuccessScreenState();
}

class _PaymentSuccessScreenState extends State<PaymentSuccessScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  String? _createdOrderOid;

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

    // Create orders for each seller
    _createOrders();
  }

  Future<void> _createOrders() async {
    try {
      final currentOid = await AuthService.getCurrentOID();

      final Map<String, List<CartItemModel>> itemsBySeller = {};
      for (var item in widget.cartItems) {
        final sellerId = item.seller.id;
        itemsBySeller.putIfAbsent(sellerId, () => []);
        itemsBySeller[sellerId]!.add(item);
      }

      for (final entry in itemsBySeller.entries) {
        final sellerId = entry.key;
        final sellerItems = entry.value;

        double sellerTotal = 0.0;
        for (var item in sellerItems) {
          sellerTotal += double.parse(item.item.price) * item.cartQuantity;
        }

        final itemsJson =
            '[${sellerItems.map((item) => '{"id":"${item.item.id}","name":"${item.item.name}","price":"${item.item.price}","quantity":${item.cartQuantity}}').join(',')}]';

        final result = await ApiService.createOrder(
          uid: sellerId,
          custId: widget.userId,
          oid: currentOid ?? '',
          shipId: widget.shippingAddress.id.toString(),
          items: itemsJson,
          totalAmount: sellerTotal.toStringAsFixed(2),
        );

        print('Order API response: $result');
        print('✅ Order created for seller $sellerId: $result');
      }

      if (mounted) {
        setState(() {
          _createdOrderOid = currentOid;
        });
      }
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
      // Don't show error to user as payment was successful
    }
  }

  Future<void> _openInvoice(String orderId) async {
    print("My Bill Order Id ---> $orderId");
    final Uri url = Uri.parse(
      InvoiceWebView.buildUrl(orderId: orderId, view: 'customer'),
    );

    if (!await launchUrl(
      url,
      mode: LaunchMode.inAppWebView, // يفتح داخل الأب
      webViewConfiguration: const WebViewConfiguration(enableJavaScript: true),
    )) {
      if (context.mounted) {
        showAppSnackbar(
          context,
          message: 'فشل فتح الفاتورة',
          type: SnackType.error,
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
    return Scaffold(
      // backgroundColor: const Color(0xFF0A0E27),
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
                    // Success Animation
                    AnimatedBuilder(
                      animation: _animationController,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _scaleAnimation.value,
                          child: Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              gradient: RadialGradient(
                                colors: [
                                  Colors.green.withOpacity(0.3),
                                  Colors.green.withOpacity(0.1),
                                  Colors.transparent,
                                ],
                              ),
                              borderRadius: BorderRadius.circular(60),
                            ),
                            child: Container(
                              margin: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(40),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.green.withOpacity(0.3),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Iconsax.tick_circle,
                                color: Colors.white,
                                size: 50,
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
                            'تم الدفع بنجاح!',
                            style: TextStyle(
                              // color: Colors.white,
                              color: context.appTextPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'شكراً لك، تم تأكيد طلبك بنجاح',
                            style: TextStyle(
                              // color: Colors.white.withOpacity(0.8),
                              color: context.appTextSecondary,
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // Order Summary Card
                    FadeTransition(
                      opacity: _fadeAnimation,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: context.surfaceGradient(),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: context.appBorder,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Iconsax.receipt_2,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'ملخص الطلب',
                                  style: TextStyle(
                                    // color: Colors.white,
                                    color: context.appTextPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 20),

                            _buildSummaryRow(
                              'عدد العناصر:',
                              '${widget.cartItems.length} عنصر',
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'المبلغ الإجمالي:',
                              '${widget.totalAmount.toStringAsFixed(2)} ريال',
                            ),
                            const SizedBox(height: 12),
                            _buildSummaryRow(
                              'العنوان:',
                              widget.shippingAddress.formattedAddress,
                            ),

                            const SizedBox(height: 20),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Iconsax.info_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'سيتم التواصل معك قريباً لتأكيد التسليم',
                                      style: TextStyle(
                                        // color: Colors.green.shade300,
                                        color: Colors.green.shade700,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ],
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
                    // Contact Sellers Button
                    SizedBox(
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
                        label: const Text(
                          'تواصل مع البائعين',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Back to Home Button
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                _clearCartAndUpdateOID();
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const MainShell(),
                                  ),
                                );
                              },
                              // 31665646
                              style: OutlinedButton.styleFrom(
                                // foregroundColor: Colors.white,
                                foregroundColor: context.appTextPrimary,
                                side: BorderSide(
                                  color: const Color(
                                    0xFF1A1A2E,
                                  ).withOpacity(0.3),
                                  // color: Colors.white.withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Iconsax.home),
                              label: const Text(
                                'الرئيسية',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 20),
                        Expanded(
                          child: SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                final oid =
                                    _createdOrderOid ??
                                    (widget.cartItems.isNotEmpty
                                        ? widget.cartItems.first.orderId
                                        : '');
                                _openInvoice(oid);
                              },
                              style: OutlinedButton.styleFrom(
                                // foregroundColor: Colors.white,
                                foregroundColor: context.appTextPrimary,
                                side: BorderSide(
                                  color: const Color(
                                    0xFF1A1A2E,
                                  ).withOpacity(0.3),
                                  // color: Colors.white.withOpacity(0.3),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(25),
                                ),
                              ),
                              icon: const Icon(Iconsax.bill),
                              label: const Text(
                                'عرض فاتورتك',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
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
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            // color: Colors.white.withOpacity(0.7),
            color: context.appTextSecondary,
            fontSize: 14,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.end,
          ),
        ),
      ],
    );
  }
}
