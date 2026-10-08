import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/features/chat/chat_screen.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/profile/seller_profile_screen.dart';

class SellersContactScreen extends StatefulWidget {
  final String userId;

  const SellersContactScreen({super.key, required this.userId});

  @override
  State<SellersContactScreen> createState() => _SellersContactScreenState();
}

class _SellersContactScreenState extends State<SellersContactScreen> {
  List<SellerContactModel> _sellers = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadSellers();
  }

  Future<void> _loadSellers() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await ApiService.getUserSellers(userId: widget.userId);

      if (result['success'] == true) {
        final List<dynamic> data = result['data'] ?? [];
        setState(() {
          _sellers = data
              .map((item) => SellerContactModel.fromJson(item))
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading sellers: $e');
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Widget _buildSellerAvatar(SellerContactModel seller, {double size = 60}) {
    return SmartAvatarWidget(
      userId: seller.id,
      name: seller.name,
      size: size,
      fallbackUrl: seller.avatar,
      backgroundColor: AppColors.primary,
      initialsStyle: TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: size * 0.35,
      ),
    );
  }

  void _showContactOptions(SellerContactModel seller) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: context.appTextDirection,
        child: Container(
          decoration: BoxDecoration(
            gradient: context.bottomBarGradient(),
            borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  // color: Colors.white.withOpacity(0.3),
                  color: context.appTextPrimary.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              const SizedBox(height: 20),

              // Seller Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildSellerAvatar(seller),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seller.name,
                            style: TextStyle(
                              // color: Colors.white,
                              color: context.appTextPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'البائع',
                            style: TextStyle(
                              // color: Colors.white.withOpacity(0.7),
                              color: context.appTextSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Contact Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _buildContactOption(
                      icon: Iconsax.message,
                      title: 'دردشة مباشرة',
                      subtitle: 'تواصل مع البائع عبر الدردشة',
                      onTap: () {
                        Navigator.pop(context);
                        // Create new conversation (no conversationId = new conversation)
                        print(seller.convId);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(
                              receiverId: seller.id,
                              receiverName: seller.name,
                              receiverAvatar: seller.avatar,
                              receiverToken: seller.token,
                              conversationId: seller.convId,
                              isOnline: false,
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildContactOption(
                      icon: Iconsax.call,
                      title: 'مكالمة هاتفية',
                      subtitle: 'اتصل بالبائع مباشرة',
                      onTap: () {
                        Navigator.pop(context);
                        showAppSnackbar(
                          context,
                          message: 'ميزة المكالمات ستكون متاحة قريباً',
                          type: SnackType.info,
                        );
                      },
                    ),

                    const SizedBox(height: 12),

                    _buildContactOption(
                      icon: Iconsax.user,
                      title: 'عرض الملف الشخصي',
                      subtitle: 'اطلع على منتجات البائع الأخرى',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                SellerProfileScreen(userId: seller.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          // color: Colors.white.withOpacity(0.1),
          color: context.appSurface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            // color: Colors.white.withOpacity(0.2),
            color: AppColors.primary.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                // color: Colors.white,
                color: AppColors.primary,
                size: 24,
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
                      // color: Colors.white,
                      color: context.appTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      // color: Colors.white.withOpacity(0.7),
                      color: context.appTextSecondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Iconsax.arrow_square_left,
              // color: Colors.white.withOpacity(0.5),
              color: context.appTextSecondary.withOpacity(0.8),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: context.appTextDirection,
      child: Scaffold(
        // backgroundColor: const Color(0xFF0A0E27),
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            // icon: const Icon(Iconsax.arrow_right_3, color: Colors.white),
            icon: Icon(Iconsax.arrow_right, color: context.appTextPrimary),
          ),
          title: Text(
            'تواصل مع البائعين',
            style: TextStyle(
              // color: Colors.white,
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
            : _sellers.isEmpty
            ? _buildEmptyWidget()
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _sellers.length,
                itemBuilder: (context, index) {
                  return _buildSellerCard(_sellers[index]);
                },
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
            'حدث خطأ في تحميل البائعين',
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _loadSellers,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('إعادة المحاولة'),
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
              Iconsax.user_octagon,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'لا توجد مشتريات سابقة',
            style: TextStyle(
              // color: Colors.white,
              color: context.appTextPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'لم تقم بشراء أي منتجات بعد',
            style: TextStyle(
              // color: Colors.white.withOpacity(0.7),
              color: context.appTextSecondary,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(25),
              ),
            ),
            child: const Text(
              'تصفح المنتجات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSellerCard(SellerContactModel seller) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: context.surfaceGradient(),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(20),
        leading: _buildSellerAvatar(seller),
        title: Text(
          seller.name,
          style: TextStyle(
            // color: Colors.white,
            color: context.appTextPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              Icon(
                Iconsax.shop,
                // color: Colors.white.withOpacity(0.6),
                color: context.appTextSecondary,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                'البائع',
                style: TextStyle(
                  // color: Colors.white.withOpacity(0.6),
                  color: context.appTextSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: const Icon(
            Iconsax.message,
            color: AppColors.primary,
            size: 20,
          ),
        ),
        onTap: () => _showContactOptions(seller),
      ),
    );
  }
}

class SellerContactModel {
  final String id;
  final String name;
  final String avatar;
  final String token;
  final String convId;

  SellerContactModel({
    required this.id,
    required this.name,
    required this.avatar,
    required this.token,
    required this.convId,
  });

  factory SellerContactModel.fromJson(Map<String, dynamic> json) {
    return SellerContactModel(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      avatar: json['avatar']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      convId: json['convId']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'avatar': avatar,
      'token': token,
      'convId': convId,
    };
  }
}
