import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:sadad_qa_payments/sadad_qa_payments.dart';
import '../../core/constants/app_colors.dart';
import '../../core/models/cart_model.dart';
import '../../core/models/shipping_address_model.dart';
import '../../core/utils/theme_extensions.dart';
import 'order_success_screen.dart';

class PaymentMethodsScreen extends StatefulWidget {
  final String userId;
  final List<CartItemModel> cartItems;
  final double totalAmount;
  final ShippingAddressModel shippingAddress;

  const PaymentMethodsScreen({
    super.key,
    required this.userId,
    required this.cartItems,
    required this.totalAmount,
    required this.shippingAddress,
  });

  @override
  State<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends State<PaymentMethodsScreen> {
  int? _selectedPaymentMethod;
  String name = "";
  String mobile = "";

  Future loadProfile() async {
    String? uid = await AuthService.getCurrentUID();
    var result = await Dio().post(
      "${AppConfig.apiBaseUrl}/profile.php?user_id=$uid&k=${DateTime.now().millisecondsSinceEpoch}",
    );
    setState(() {
      name = result.data['data']['name'];
      mobile = result.data['data']['phone'];
    });
  }

  @override
  void initState() {
    loadProfile();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            'طريقة الدفع',
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const SizedBox(height: 20),
              _buildPaymentOptionCard(
                index: 0,
                icon: Iconsax.card,
                title: 'الدفع الإلكتروني',
                subtitle: 'الدفع عبر سداد',
                isEnabled: true,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 0;
                  });
                },
              ),
              const SizedBox(height: 16),
              _buildPaymentOptionCard(
                index: 1,
                icon: Iconsax.money,
                title: 'الدفع عند الاستلام',
                subtitle: 'ادفع عند استلام طلبك',
                isEnabled: true,
                onTap: () {
                  setState(() {
                    _selectedPaymentMethod = 1;
                  });
                },
              ),
              const Spacer(),
              _buildContinueButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentOptionCard({
    required int index,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isEnabled,
    required VoidCallback onTap,
  }) {
    final isSelected = _selectedPaymentMethod == index;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.12)
              : context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.appBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isEnabled
                    ? (isSelected
                        ? AppColors.primary
                        : AppColors.primary.withValues(alpha: 0.12))
                    : Colors.grey.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                color: isEnabled
                    ? (isSelected ? Colors.white : AppColors.primary)
                    : Colors.grey,
                size: 28,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: isEnabled
                          ? context.appTextPrimary
                          : Colors.grey,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: isEnabled
                          ? context.appTextSecondary
                          : Colors.grey.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            if (isEnabled)
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : context.appTextSecondary,
                    width: 2,
                  ),
                  color: isSelected ? AppColors.primary : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(Icons.check, color: Colors.white, size: 16)
                    : null,
              )
            else
              Icon(
                Iconsax.arrow_left_2,
                color: context.appTextSecondary,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      padding: const EdgeInsets.only(bottom: 20),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (_selectedPaymentMethod == 0) {
                final oid = await AuthService.getCurrentOID();
                // TODO: قبل الـ production - انقل الـ secret key للسيرفر
                final result = await Dio().post(
                  "https://api.sadadqatar.com/api-v5/userbusinesses/getsdktoken",
                  data: {
                    "sadadId": "1672510",
                    "secretKey": "SoXaZoomMjjo9i1i",
                    "domain": "globalfarmnursery.com",
                    "isTest": true,
                  },
                );

                if (!mounted) return;

                final paymentResult =
                    await Navigator.push<Map<String, dynamic>>(
                      context,
                      MaterialPageRoute(
                        builder: (context) {
                          return PaymentScreen(
                            orderId: oid ?? "",
                            productDetail: [],
                            customerName: name,
                            amount: widget.totalAmount,
                            email: "info@gfnursery.com",
                            mobile: mobile,
                            token: result.data['accessToken'],
                            packageMode: PackageMode.debug,
                            isWalletEnabled: true,
                            paymentTypes: [
                              PaymentType.creditCard,
                              PaymentType.debitCard,
                              PaymentType.sadadPay,
                            ],
                            image: Image.asset("assets/images/Logo.png"),
                            titleText: "GlobalFarm",
                            paymentButtonColor: AppColors.primary,
                            paymentButtonTextColor: Colors.white,
                            themeColor: AppColors.primary,
                            googleMerchantID: 'BCR2DN6TR6Y7Z2CJ',
                            googleMerchantName: 'Sadad Payment Solutions', merchantSadadId: '1672510',
                          );
                        },
                      ),
                    );

                if (!mounted || paymentResult == null) return;

                final transOid = paymentResult['orderid']?.toString() ?? '';
                final transId =
                    paymentResult['transaction_id']?.toString() ?? '';
                final transStatus = paymentResult['status']?.toString() ?? '';
                final transAmount =
                    paymentResult['amount']?.toString() ??
                    widget.totalAmount.toString();
                final transPaymentMode =
                    paymentResult['payment_mode']?.toString() ?? '';

                try {
                  await Dio().post(
                    "${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}",
                    data: FormData.fromMap({
                      "action": "add_new_transactions",
                      "oid": transOid,
                      "name": name,
                      "mobile": mobile,
                      "trans_id": transId,
                      "status": transStatus,
                      "amount": transAmount,
                      "pay_mode": transPaymentMode,
                      "store_id": AppConfig.storeId,
                    }),
                  );
                } catch (e) {
                  debugPrint('Failed to save transaction: $e');
                }

                if (!mounted) return;

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderSuccessScreen(
                      userId: widget.userId,
                      cartItems: widget.cartItems,
                      totalAmount: widget.totalAmount,
                      shippingAddress: widget.shippingAddress,
                      transStatus: transStatus,
                      paymentMode: 'visa',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => OrderSuccessScreen(
                      userId: widget.userId,
                      cartItems: widget.cartItems,
                      totalAmount: widget.totalAmount,
                      shippingAddress: widget.shippingAddress,
                      transStatus: "3",
                      paymentMode: 'credit',
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
              children: const [
                Text(
                  'تأكيد الطلب',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(width: 8),
                Icon(Iconsax.tick_circle, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
