import 'package:GlobalFarm/features/orders/invoice_webview.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class MyOrdersScreen extends StatefulWidget {
  const MyOrdersScreen({super.key});

  @override
  State<MyOrdersScreen> createState() => _MyOrdersScreenState();
}

class _MyOrdersScreenState extends State<MyOrdersScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final uid = await AuthService.getCurrentUID();
      print('🔍 DEBUG MyOrders - UID from AuthService: $uid');

      if (uid == null) {
        print('❌ DEBUG MyOrders - UID is null, user not logged in');
        throw Exception('User not logged in');
      }

      print('📡 DEBUG MyOrders - Calling API with custId: $uid');
      final result = await ApiService.getMyOrders(custId: uid);
      print('📦 DEBUG MyOrders - API Response: $result');

      if (result['success'] == true) {
        final orders = result['data'] ?? [];
        print('✅ DEBUG MyOrders - Orders count: ${orders.length}');
        setState(() {
          _orders = orders;
          _isLoading = false;
        });
      } else {
        print(
          '❌ DEBUG MyOrders - API returned success=false: ${result['error']}',
        );
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ DEBUG MyOrders - Exception: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openInvoice(
    String orderId, {
    bool isCustomerView = false,
  }) async {
    final url = InvoiceWebView.buildUrl(
      orderId: orderId,
      view: isCustomerView ? 'customer' : null,
    );

    if (!context.mounted) return;

    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => InvoiceWebView(url: url)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            tr('orders.my_orders_title'),
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              )
            : _hasError
            ? _buildErrorWidget()
            : _orders.isEmpty
            ? _buildEmptyWidget()
            : RefreshIndicator(
                onRefresh: _loadOrders,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    return _buildOrderCard(_orders[index]);
                  },
                ),
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
            tr('orders.load_error'),
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('orders.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
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
              Iconsax.shopping_bag,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            tr('orders.no_orders'),
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('orders.no_orders_hint'),
            style: TextStyle(color: context.appTextSecondary, fontSize: 16),
          ),
        ],
      ),
    );
  }

  int _sellerCount(dynamic order) {
    if (order is! Map) return 1;

    final value = order["seller_count"];
    if (value == null) return 1;

    final count = switch (value) {
      int v => v,
      num v => v.toInt(),
      _ => int.tryParse(value.toString().trim()),
    };

    if (count == null || count < 1) return 1;
    return count;
  }

  Widget _buildOrderCard(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Order Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Iconsax.receipt_text,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('orders.order_number'),
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '#${order['oid']}',
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _getStatusColor(order['status']),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    _getStatusText(order['status']),
                    style: TextStyle(
                      color: _getStatusColor(order['status']),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Divider
            Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.3),
                    Colors.transparent,
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Order Details
            _buildDetailRow(
              Iconsax.shop,
              tr('orders.sellers_count'),
              '${_sellerCount(order)} ${tr('orders.seller_unit')}',
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Iconsax.calendar,
              tr('orders.order_date'),
              _formatDate(order['created_at']),
            ),
            const SizedBox(height: 12),
            _buildDetailRow(
              Iconsax.money,
              tr('orders.total_amount'),
              '${order['total_amount']} ${tr('orders.currency')}',
            ),
            const SizedBox(height: 8),
            Text(
              tr('orders.tap_for_items_hint'),
              style: TextStyle(
                color: context.appTextSecondary.withOpacity(0.8),
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),

            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _openInvoice(order['oid'].toString(), isCustomerView: true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                icon: const Icon(Iconsax.document_text, size: 20),
                label: Text(
                  tr('orders.view_invoice'),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(color: context.appTextSecondary, fontSize: 14),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
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

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// Maps the raw API status value to its localized label.
  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return tr('orders.status_processing');
      case 'completed':
        return tr('orders.status_completed');
      case 'cancelled':
        return tr('orders.status_cancelled');
      default:
        return status;
    }
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateStr;
    }
  }
}
