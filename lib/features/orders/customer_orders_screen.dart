import 'package:GlobalFarm/core/services/onesignal_service.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/orders/invoice_webview.dart';

class CustomerOrdersScreen extends StatefulWidget {
  const CustomerOrdersScreen({super.key});

  @override
  State<CustomerOrdersScreen> createState() => _CustomerOrdersScreenState();
}

class _CustomerOrdersScreenState extends State<CustomerOrdersScreen> {
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
      if (uid == null) {
        throw Exception('User not logged in');
      }

      final isAdmin = await AuthService.isAdmin();
      final result = await ApiService.getCustomerOrders(
        uid: uid,
        storeId: isAdmin ? AppConfig.storeId : null,
      );

      if (result['success'] == true) {
        setState(() {
          _orders = result['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading customer orders: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _openInvoice(String orderId, String visitorUid) async {
    // Seller view: pass user_id to filter by seller's uid
    final uid = await AuthService.getCurrentUID();
    final url = InvoiceWebView.buildUrl(
      orderId: orderId,
      view: 'seller',
      userId: uid,
    );
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } else {
      showAppSnackbar(
        context,
        message: tr('orders.invoice_open_failed'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _showStatusBottomSheet(dynamic order) async {
    final statuses = [
      {
        'value': 'Pending',
        'label': tr('orders.status_pending'),
        'icon': Iconsax.clock,
        // Sent as the push-notification body to the customer, not shown here.
        'desc': 'الطلب تم استلامه لكن لم يبدأ معالجته بعد.',
      },
      {
        'value': 'Preparing',
        'label': tr('orders.status_preparing'),
        'icon': Iconsax.box,
        'desc': 'الطلب جاري تجهيزه، مثل تجميع المنتجات أو تجهيزها للشحن.',
      },
      {
        'value': 'ReadyToShip',
        'label': tr('orders.status_ready_to_ship'),
        'icon': Iconsax.box_tick,
        'desc': 'الطلب تم تحضيره بالكامل ومستعد للخروج من المخزن للشحن.',
      },
      {
        'value': 'Shipping',
        'label': tr('orders.status_shipping'),
        'icon': Iconsax.truck_fast,
        'desc': 'الطلب في طريقه للعميل، تم تسليمه لشركة الشحن.',
      },
      {
        'value': 'Delivered',
        'label': tr('orders.status_delivered'),
        'icon': Iconsax.tick_circle,
        'desc': 'الطلب وصل للعميل وتم استلامه بنجاح.',
      },
    ];

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('orders.change_status_title'),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: context.appTextPrimary,
              ),
            ),
            const SizedBox(height: 20),
            ...statuses.map(
              (status) => _buildStatusOption(
                order,
                status['value'] as String,
                status['label'] as String,
                status['icon'] as IconData,
                status['desc'] as String,
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusOption(
    dynamic order,
    String statusValue,
    String statusLabel,
    IconData icon,
    String desc,
  ) {
    final isCurrentStatus = order['status'] == statusValue;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isCurrentStatus
              ? null
              : () => _updateOrderStatus(order, statusValue, desc),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isCurrentStatus
                  ? AppColors.primary.withOpacity(0.1)
                  : context.appSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCurrentStatus ? AppColors.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isCurrentStatus
                        ? AppColors.primary
                        : Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: isCurrentStatus ? Colors.white : Colors.grey[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isCurrentStatus
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isCurrentStatus
                          ? AppColors.primary
                          : context.appTextPrimary,
                    ),
                  ),
                ),
                if (isCurrentStatus)
                  const Icon(
                    Iconsax.tick_circle,
                    color: AppColors.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateOrderStatus(
    dynamic order,
    String newStatus,
    String desc,
  ) async {
    Navigator.pop(context);

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );

    try {
      final uid = await AuthService.getCurrentUID();
      if (uid == null) {
        throw Exception('User not logged in');
      }

      final result = await ApiService.updateOrderStatus(
        orderId: order['oid'].toString(),
        status: newStatus,
        uid: uid,
      );

      if (!mounted) return;
      Navigator.pop(context); // Close loading

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: tr('orders.status_updated'),
          type: SnackType.success,
        );
        List<String> tokens = [];
        for (var i = 0; i < result['client_token'].length; i++) {
          tokens.add(result['client_token'][i]['player_id']);
        }
        OneSignalService.sendNotificationToMultipleUsers(
          playerIds: tokens,
          title: newStatus,
          message: desc,
        );
        _loadOrders();
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? tr('orders.status_update_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading
      showAppSnackbar(
        context,
        message: '${tr('common.error')}: $e',
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
        appBar: AppBar(
          forceMaterialTransparency: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            tr('orders.customer_orders_title'),
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
              Iconsax.people,
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
            tr('orders.no_customer_orders_hint'),
            style: TextStyle(color: context.appTextSecondary, fontSize: 16),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(dynamic order) {
    final shippingInfo = order['shipping_info'];

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
                InkWell(
                  onTap: () => _showStatusBottomSheet(order),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _getStatusText(order['status']),
                          style: TextStyle(
                            color: _getStatusColor(order['status']),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Iconsax.arrow_down_1,
                          color: _getStatusColor(order['status']),
                          size: 14,
                        ),
                      ],
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

            // Customer Info Section
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Iconsax.user,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        tr('orders.customer_info'),
                        style: TextStyle(
                          color: context.appTextPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildDetailRow(
                    Iconsax.personalcard,
                    tr('orders.name'),
                    order['customer_name'] ?? tr('orders.not_available'),
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(
                    Iconsax.call,
                    tr('orders.phone'),
                    order['customer_phone'] ?? tr('orders.not_available'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Shipping Info Section
            if (shippingInfo != null && shippingInfo['fullname'] != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Iconsax.location,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          tr('orders.shipping_info'),
                          style: TextStyle(
                            color: context.appTextPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildDetailRow(
                      Iconsax.personalcard,
                      tr('orders.name'),
                      shippingInfo['fullname'] ?? tr('orders.not_available'),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Iconsax.call,
                      tr('orders.phone'),
                      shippingInfo['mobile'] ?? tr('orders.not_available'),
                    ),
                    const SizedBox(height: 8),
                    _buildDetailRow(
                      Iconsax.global,
                      tr('orders.address'),
                      '${shippingInfo['city'] ?? ''}, ${shippingInfo['country'] ?? ''}',
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 12),

            // Order Details
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

            const SizedBox(height: 20),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _openInvoice(
                  order['oid'].toString(),
                  order['uid'].toString(),
                ),
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
        Icon(icon, color: AppColors.primary, size: 16),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: TextStyle(color: context.appTextSecondary, fontSize: 13),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 13,
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
      case 'preparing':
        return Colors.blue;
      case 'readytoship':
        return Colors.purple;
      case 'shipping':
        return Colors.indigo;
      case 'delivered':
        return Colors.green;
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
        return tr('orders.status_pending');
      case 'preparing':
        return tr('orders.status_preparing');
      case 'readytoship':
        return tr('orders.status_ready_to_ship');
      case 'shipping':
        return tr('orders.status_shipping');
      case 'delivered':
        return tr('orders.status_delivered');
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
