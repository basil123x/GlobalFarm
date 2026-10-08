import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/auth/login.dart';
import 'package:GlobalFarm/features/barcode/barcode_lookup_screen.dart';
import 'package:GlobalFarm/features/cart/shopping_cart_screen.dart';
import 'package:GlobalFarm/features/categories/categories_screen.dart';
import 'package:GlobalFarm/features/chat/conversations_screen.dart';
import 'package:GlobalFarm/features/home/home_screen.dart';
import 'package:GlobalFarm/features/profile/profile_screen.dart';
import 'package:GlobalFarm/features/wishlist/wishlist_screen.dart';

/// Root shell: Noon/Amazon-style bottom navigation for GlobalFarm.
class MainShell extends StatefulWidget {
  final int initialIndex;

  const MainShell({super.key, this.initialIndex = 0});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  late int _currentIndex;
  String? _userId;
  bool _loginChecked = false;
  bool _isAdmin = false;
  VoidCallback? _openAddProduct;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, 4);
    _loadUser();
  }

  Future<void> _loadUser() async {
    final uid = await AuthService.getCurrentUserId();
    // Refresh role from DB so Admin flag set in SQL takes effect immediately.
    final admin = (uid != null && uid.isNotEmpty)
        ? await AuthService.refreshRoleFromApi()
        : false;
    if (!mounted) return;
    setState(() {
      _userId = uid;
      _isAdmin = admin;
      _loginChecked = true;
    });
  }

  Future<void> _onTabSelected(int index) async {
    if (index == 2 || index == 3 || index == 4) {
      final loggedIn = await AuthService.isLoggedIn();
      final uid = await AuthService.getCurrentUserId();
      if (!loggedIn || uid == null || uid.isEmpty) {
        if (!mounted) return;
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        await _loadUser();
        final stillLoggedIn = await AuthService.isLoggedIn();
        if (!stillLoggedIn) return;
      } else {
        _userId = uid;
        _isAdmin = await AuthService.refreshRoleFromApi();
      }
    }

    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  Future<void> _onCenterAdd() async {
    if (_isAdmin) {
      _openAddProduct?.call();
      return;
    }
    // Buyers: open cart (old middle-tab behavior).
    await _onTabSelected(2);
  }

  void openCategoriesTab() => _onTabSelected(1);

  @override
  Widget build(BuildContext context) {
    // نستمع للـ LocalizationService حتى يُعاد بناء الـ shell فور تغيير اللغة
    final localization = context.watch<LocalizationService>();
    final ar = localization.currentLanguage == 'ar';

    final Widget middleTab;
    if (_isAdmin) {
      middleTab = const BarcodeLookupScreen();
    } else if (_loginChecked && _userId != null && _userId!.isNotEmpty) {
      middleTab = ShoppingCartScreen(
        userId: _userId!,
        isActive: _currentIndex == 2,
        showBackButton: false,
        onBrowseProducts: () => setState(() => _currentIndex = 0),
      );
    } else {
      middleTab = _LoginPlaceholder(
        message: ar ? 'سجّل دخولك لعرض السلة' : 'Sign in to view your cart',
      );
    }

    final tabs = <Widget>[
      HomeScreen(
        onOpenCategories: openCategoriesTab,
        onOpenCart: () => _onTabSelected(2),
        onRegisterAddProduct: (openAdd) => _openAddProduct = openAdd,
      ),
      const CategoriesScreen(),
      middleTab,
      _loginChecked && _userId != null && _userId!.isNotEmpty
          ? ConversationsScreen(userId: _userId!)
          : _LoginPlaceholder(
              message: ar ? 'سجّل دخولك لعرض المحادثات' : 'Sign in to view chats',
            ),
      _loginChecked && _userId != null && _userId!.isNotEmpty
          ? ProfileScreen(
              userId: _userId!,
              onOpenWishlist: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const WishlistScreen()),
                );
              },
              onOpenHome: () => setState(() => _currentIndex = 0),
              onOpenAddProduct: () => _openAddProduct?.call(),
            )
          : _LoginPlaceholder(
              message: ar
                  ? 'سجّل دخولك لعرض الملف الشخصي'
                  : 'Sign in to view your profile',
            ),
    ];

    return Directionality(
      textDirection: localization.textDirection,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark.copyWith(
          systemNavigationBarColor: Colors.white,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        child: Scaffold(
          backgroundColor: context.appBackground,
          body: IndexedStack(index: _currentIndex, children: tabs),
          bottomNavigationBar: _FarmBottomBar(
            currentIndex: _currentIndex,
            ar: ar,
            isAdmin: _isAdmin,
            onTap: _onTabSelected,
            onAdd: _onCenterAdd,
          ),
        ),
      ),
    );
  }
}

class _FarmBottomBar extends StatelessWidget {
  static const Color _active = AppColors.primary;
  static const Color _idle = Color(0xFF9AA89A);

  final int currentIndex;
  final bool ar;
  final bool isAdmin;
  final ValueChanged<int> onTap;
  final VoidCallback onAdd;

  const _FarmBottomBar({
    required this.currentIndex,
    required this.ar,
    required this.isAdmin,
    required this.onTap,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return SizedBox(
      height: 92 + bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 64 + bottom,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(
                    color: AppColors.softGreenBorder.withValues(alpha: 0.9),
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 14,
                    offset: const Offset(0, -3),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: Row(
                    children: [
                      _item(
                        index: 0,
                        label: ar ? 'الرئيسية' : 'Home',
                        icon: Iconsax.home_2,
                        activeIcon: Iconsax.home_25,
                      ),
                      _item(
                        index: 1,
                        label: ar ? 'استكشف' : 'Explore',
                        icon: Iconsax.search_normal_1,
                        activeIcon: Iconsax.search_status5,
                      ),
                      const SizedBox(width: 76),
                      _item(
                        index: 3,
                        label: ar ? 'المحادثات' : 'Chats',
                        icon: Iconsax.message,
                        activeIcon: Iconsax.message5,
                      ),
                      _item(
                        index: 4,
                        label: ar ? 'حسابي' : 'Account',
                        icon: Iconsax.user,
                        activeIcon: Iconsax.profile_circle5,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: onAdd,
                child: Container(
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white, width: 4),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.35),
                        blurRadius: 18,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    isAdmin ? Iconsax.add : Iconsax.shopping_cart,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _item({
    required int index,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final selected = currentIndex == index;
    final color = selected ? _active : _idle;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(index),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? activeIcon : icon, color: color, size: 26),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoginPlaceholder extends StatelessWidget {
  final String message;

  const _LoginPlaceholder({required this.message});

  @override
  Widget build(BuildContext context) {
    final ar = context.watch<LocalizationService>().currentLanguage == 'ar';
    return SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.lock_1, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                icon: const Icon(Iconsax.login, size: 18),
                label: Text(ar ? 'تسجيل الدخول' : 'Sign in'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 22,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
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
