import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/features/chat/conversations_screen.dart';
import 'package:GlobalFarm/features/orders/customer_orders_screen.dart';
import 'package:GlobalFarm/features/orders/my_orders_screen.dart';
import 'package:GlobalFarm/features/profile/edit_profile_screen.dart';
import 'package:GlobalFarm/features/profile/profile_avatar_preview_screen.dart';
import 'package:GlobalFarm/features/settings/settings_screen.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';

enum _ProfileSection { orders, addresses, support }

/// Metrash-style account hub — solid header, icon grid, white content body.
class ProfileScreen extends StatefulWidget {
  final String userId;
  final VoidCallback? onOpenWishlist;
  final VoidCallback? onOpenHome;
  final VoidCallback? onOpenAddProduct;

  const ProfileScreen({
    super.key,
    required this.userId,
    this.onOpenWishlist,
    this.onOpenHome,
    this.onOpenAddProduct,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserProfileModel? _profile;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isAdmin = false;
  int _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;

  _ProfileSection _selected = _ProfileSection.orders;

  List<dynamic> _recentOrders = [];
  bool _ordersLoading = false;
  List<dynamic> _addresses = [];
  bool _addressesLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final admin = await AuthService.refreshRoleFromApi();
      final response = await ApiService.getUserProfile(widget.userId);
      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _profile = UserProfileModel.fromJson(response['data']);
          _isAdmin = admin;
          _isLoading = false;
          _avatarCacheTimestamp = DateTime.now().millisecondsSinceEpoch;
          if (admin) _selected = _ProfileSection.orders;
        });
        await _loadFreshUserDetails();
        _loadRecentOrders();
        _loadAddresses();
      } else {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadFreshUserDetails() async {
    final currentUid = await AuthService.getCurrentUID();
    if (currentUid == null || currentUid != widget.userId) return;

    const storage = FlutterSecureStorage();
    final email =
        await storage.read(key: 'user_email') ??
        await storage.read(key: 'social_email');
    if (email == null || email.isEmpty) return;

    try {
      final response = await Dio().post(
        '${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({'action': 'get_user_details', 'email': email}),
      );

      if (response.data['success'] != true || response.data['data'] == null) {
        return;
      }

      final data = response.data['data'] as Map<String, dynamic>;
      final name = data['name']?.toString() ?? '';
      if (name.isEmpty) return;

      await AuthService.updateUserName(name);
      if (!mounted || _profile == null) return;

      setState(() {
        _profile = UserProfileModel(
          id: _profile!.id,
          uid: _profile!.uid,
          name: name,
          phone: data['phone']?.toString() ?? _profile!.phone,
          avatar: _profile!.avatar,
          type: _profile!.type,
          itemsCount: _profile!.itemsCount,
        );
      });
    } catch (_) {}
  }

  Future<void> _loadRecentOrders() async {
    setState(() => _ordersLoading = true);
    try {
      final uid = await AuthService.getCurrentUID();
      if (uid == null) {
        if (mounted) setState(() => _ordersLoading = false);
        return;
      }

      final result = _isAdmin
          ? await ApiService.getCustomerOrders(
              uid: uid,
              storeId: AppConfig.storeId,
            )
          : await ApiService.getMyOrders(custId: uid);

      if (!mounted) return;
      if (result['success'] == true) {
        final list = (result['data'] as List?) ?? [];
        setState(() {
          _recentOrders = list.take(5).toList();
          _ordersLoading = false;
        });
      } else {
        setState(() {
          _recentOrders = [];
          _ordersLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recentOrders = [];
        _ordersLoading = false;
      });
    }
  }

  Future<void> _loadAddresses() async {
    setState(() => _addressesLoading = true);
    try {
      if (_isAdmin) {
        final uid = await AuthService.getCurrentUID() ?? widget.userId;
        final result = await ApiService.getCustomerOrders(
          uid: uid,
          storeId: AppConfig.storeId,
        );
        if (!mounted) return;
        final list = (result['success'] == true)
            ? ((result['data'] as List?) ?? [])
            : <dynamic>[];
        final seen = <String>{};
        final addresses = <Map<String, dynamic>>[];
        for (final order in list) {
          if (order is! Map) continue;
          final shipping = order['shipping_info'];
          if (shipping is! Map) continue;
          final name = shipping['fullname']?.toString() ?? '';
          final phone = shipping['mobile']?.toString() ??
              shipping['phone']?.toString() ??
              '';
          final city = shipping['city']?.toString() ?? '';
          final country = shipping['country']?.toString() ?? '';
          final key = '$name|$phone|$city|$country';
          if (key.trim() == '|||' || !seen.add(key)) continue;
          addresses.add({
            'fullname': name,
            'mobile': phone,
            'city': city,
            'country': country,
          });
        }
        setState(() {
          _addresses = addresses;
          _addressesLoading = false;
        });
        return;
      }

      final uid = await AuthService.getCurrentUID() ?? widget.userId;
      final result = await ApiService.getShippingAddresses(uid: uid);
      if (!mounted) return;
      if (result['success'] == true) {
        setState(() {
          _addresses = (result['data'] as List?) ?? [];
          _addressesLoading = false;
        });
      } else {
        setState(() {
          _addresses = [];
          _addressesLoading = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _addresses = [];
        _addressesLoading = false;
      });
    }
  }

  Future<void> _openEditProfile() async {
    final profile = _profile;
    if (profile == null) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditProfileScreen(
          currentName: profile.name,
          currentPhone: profile.phone,
          currentType: profile.type,
          currentAvatar: profile.avatar,
          currentUid: profile.uid.isNotEmpty ? profile.uid : widget.userId,
        ),
      ),
    );

    if (result != null && mounted) {
      await _loadProfile();
    }
  }

  Future<void> _openSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SettingsScreen(profile: _profile),
      ),
    );
    if (result != null && mounted) {
      await _loadProfile();
    }
  }

  void _openMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConversationsScreen(userId: widget.userId),
      ),
    );
  }

  void _openAllOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _isAdmin
            ? const CustomerOrdersScreen()
            : const MyOrdersScreen(),
      ),
    ).then((_) => _loadRecentOrders());
  }

  void _logout() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: tr('profile.logout'),
      desc: tr('profile.logout_confirm'),
      btnCancelText: tr('common.cancel'),
      btnOkText: tr('profile.logout'),
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        await AuthService.logout();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainShell()),
          (_) => false,
        );
      },
    ).show();
  }

  void _deleteAccount() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: tr('settings.delete_account'),
      desc: tr('settings.delete_account_confirm'),
      btnCancelText: tr('common.cancel'),
      btnOkText: tr('settings.delete_permanently'),
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () async {
        final uid = await AuthService.getCurrentUID();
        if (uid == null || uid.isEmpty) {
          if (!mounted) return;
          showAppSnackbar(
            context,
            message: tr('settings.user_not_identified'),
            type: SnackType.error,
          );
          return;
        }
        try {
          final response = await Dio().post(
            '${AuthService.baseUrl}/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
            data: FormData.fromMap({
              'action': 'delete_account_permit',
              'uid': uid,
            }),
          );
          if (response.data['success'] == true) {
            await AuthService.logout();
            if (!mounted) return;
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const MainShell()),
              (_) => false,
            );
          } else if (mounted) {
            showAppSnackbar(
              context,
              message: response.data['error']?.toString() ??
                  tr('settings.delete_failed'),
              type: SnackType.error,
            );
          }
        } catch (_) {
          if (!mounted) return;
          showAppSnackbar(
            context,
            message: tr('settings.delete_error'),
            type: SnackType.error,
          );
        }
      },
    ).show();
  }

  Future<void> _callNumber(String localNumber) async {
    final uri = Uri(scheme: 'tel', path: '+974$localNumber');
    try {
      final ok = await launchUrl(uri);
      if (!ok && mounted) {
        showAppSnackbar(
          context,
          message: tr('profile.dialer_error'),
          type: SnackType.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr('profile.dialer_error'),
        type: SnackType.error,
      );
    }
  }

  void _onGridTap(_ProfileMenuItem item) {
    switch (item.id) {
      case 'orders':
        setState(() => _selected = _ProfileSection.orders);
        _loadRecentOrders();
        break;
      case 'addresses':
        setState(() => _selected = _ProfileSection.addresses);
        _loadAddresses();
        break;
      case 'wishlist':
        widget.onOpenWishlist?.call();
        break;
      case 'messages':
        _openMessages();
        break;
      case 'add_product':
        widget.onOpenAddProduct?.call();
        break;
      case 'edit':
        _openEditProfile();
        break;
      case 'settings':
        _openSettings();
        break;
      case 'support':
        setState(() => _selected = _ProfileSection.support);
        break;
      case 'logout':
        _logout();
        break;
      case 'delete':
        _deleteAccount();
        break;
    }
  }

  List<_ProfileMenuItem> get _menuItems {
    if (_isAdmin) {
      // Exactly 8 tiles — no empty gaps in the 4×2 grid.
      return [
        _ProfileMenuItem(
          id: 'orders',
          icon: Iconsax.box,
          label: tr('profile.customer_orders'),
          section: _ProfileSection.orders,
        ),
        _ProfileMenuItem(
          id: 'addresses',
          icon: Iconsax.location,
          label: tr('profile.customer_addresses'),
          section: _ProfileSection.addresses,
        ),
        _ProfileMenuItem(
          id: 'messages',
          icon: Iconsax.message,
          label: tr('profile.messages'),
        ),
        _ProfileMenuItem(
          id: 'add_product',
          icon: Iconsax.add_circle,
          label: tr('profile.add_product'),
        ),
        _ProfileMenuItem(
          id: 'edit',
          icon: Iconsax.user_edit,
          label: tr('profile.edit_account'),
        ),
        _ProfileMenuItem(
          id: 'settings',
          icon: Iconsax.setting_2,
          label: tr('profile.settings'),
        ),
        _ProfileMenuItem(
          id: 'logout',
          icon: Iconsax.logout,
          label: tr('profile.logout'),
        ),
        _ProfileMenuItem(
          id: 'delete',
          icon: Iconsax.trash,
          label: tr('settings.delete_account'),
        ),
      ];
    }

    return [
      _ProfileMenuItem(
        id: 'orders',
        icon: Iconsax.box,
        label: tr('profile.my_orders'),
        section: _ProfileSection.orders,
      ),
      _ProfileMenuItem(
        id: 'addresses',
        icon: Iconsax.location,
        label: tr('profile.my_addresses'),
        section: _ProfileSection.addresses,
      ),
      _ProfileMenuItem(
        id: 'wishlist',
        icon: Iconsax.heart,
        label: tr('profile.wishlist'),
      ),
      _ProfileMenuItem(
        id: 'messages',
        icon: Iconsax.message,
        label: tr('profile.messages'),
      ),
      _ProfileMenuItem(
        id: 'edit',
        icon: Iconsax.user_edit,
        label: tr('profile.edit_account'),
      ),
      _ProfileMenuItem(
        id: 'settings',
        icon: Iconsax.setting_2,
        label: tr('profile.settings'),
      ),
      _ProfileMenuItem(
        id: 'support',
        icon: Iconsax.headphone,
        label: tr('profile.support'),
        section: _ProfileSection.support,
      ),
      _ProfileMenuItem(
        id: 'logout',
        icon: Iconsax.logout,
        label: tr('profile.logout'),
      ),
    ];
  }

  String get _sectionTitle {
    switch (_selected) {
      case _ProfileSection.orders:
        return _isAdmin
            ? tr('profile.customer_orders')
            : tr('profile.my_orders');
      case _ProfileSection.addresses:
        return _isAdmin
            ? tr('profile.customer_addresses')
            : tr('profile.my_addresses');
      case _ProfileSection.support:
        return tr('profile.support');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.appBackground,
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_hasError || _profile == null) {
      return Scaffold(
        backgroundColor: context.appBackground,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Iconsax.warning_2, size: 56, color: Colors.grey[400]),
              const SizedBox(height: 12),
              Text(
                tr('profile.profile_error'),
                style: TextStyle(color: context.appTextSecondary),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: Text(tr('profile.retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      // One body color under the green header (matches curved sheet).
      backgroundColor: context.appSurface,
      body: Column(
        children: [
          // Header + avatar + name + icon grid stay fixed.
          _buildCompactHeader(),
          // Only the section under the buttons scrolls.
          Expanded(
            child: ColoredBox(
              color: context.appSurface,
              child: RefreshIndicator(
                color: AppColors.primary,
                onRefresh: _loadProfile,
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: EdgeInsets.zero,
                  children: [
                    _buildSectionContent(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Straight green header + white body with top corner curves.
  Widget _buildCompactHeader() {
    final topPad = MediaQuery.of(context).padding.top;
    const avatarSize = 96.0;
    const headerBodyHeight = 188.0;
    const bodyTopRadius = 36.0;
    const bodyOverlap = 36.0;

    final greenHeight = topPad + headerBodyHeight;
    final sheetTop = greenHeight - bodyOverlap;
    final profile = _profile!;
    final displayName = profile.name.isNotEmpty
        ? profile.name
        : tr('profile.user');

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Straight green header.
        Container(
          height: greenHeight,
          width: double.infinity,
          color: AppColors.primary,
          padding: EdgeInsets.only(top: topPad + 20),
          alignment: Alignment.topCenter,
          child: Text(
            tr('profile.title'),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        // White body (rounded top) + name + icon grid.
        Padding(
          padding: EdgeInsets.only(top: sheetTop),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: context.appSurface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(bodyTopRadius),
                topRight: Radius.circular(bodyTopRadius),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              children: [
                SizedBox(height: avatarSize / 2 + 8),
                Text(
                  displayName,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: context.appTextPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 22),
                _buildIconGrid(),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        // Avatar on the seam.
        Positioned(
          top: sheetTop - (avatarSize / 2),
          left: 0,
          right: 0,
          child: Center(
            child: GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileAvatarPreviewScreen(
                      userId: widget.userId,
                      name: profile.name,
                      fallbackUrl: profile.avatar,
                      cacheTimestamp: _avatarCacheTimestamp,
                    ),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SmartAvatarWidget(
                  userId: widget.userId,
                  name: profile.name,
                  size: avatarSize - 6,
                  fallbackUrl: profile.avatar,
                  cacheTimestamp: _avatarCacheTimestamp,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconGrid() {
    final items = _menuItems;
    final row1 = items.take(4).toList();
    final row2 = items.skip(4).take(4).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in row1) Expanded(child: _buildGridItem(item)),
          ],
        ),
        const SizedBox(height: 18),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in row2) Expanded(child: _buildGridItem(item)),
          ],
        ),
      ],
    );
  }

  Widget _buildGridItem(_ProfileMenuItem item) {
    final selected = item.section != null && item.section == _selected;
    return GestureDetector(
      onTap: () => _onGridTap(item),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected
                  ? AppColors.primary
                  : AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Icon(
              item.icon,
              size: 21,
              color: selected ? Colors.white : AppColors.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: context.appTextPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionContent() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _sectionTitle,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 12),
          if (_selected == _ProfileSection.orders) _buildOrdersSection(),
          if (_selected == _ProfileSection.addresses) _buildAddressesSection(),
          if (_selected == _ProfileSection.support) _buildSupportSection(),
        ],
      ),
    );
  }

  Widget _buildOrdersSection() {
    if (_ordersLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_recentOrders.isEmpty) {
      return _EmptyCard(
        icon: Iconsax.box_1,
        title: _isAdmin
            ? tr('profile.no_customer_orders')
            : tr('profile.no_orders_yet'),
        subtitle: _isAdmin
            ? tr('profile.customer_orders_empty_hint')
            : tr('profile.orders_empty_hint'),
        actionLabel: _isAdmin ? null : tr('profile.browse_products'),
        onAction: _isAdmin ? null : () => widget.onOpenHome?.call(),
      );
    }

    return Column(
      children: [
        ..._recentOrders.map((order) {
          final id = order['oid']?.toString() ??
              order['order_id']?.toString() ??
              order['id']?.toString() ??
              '';
          final status = order['status']?.toString() ?? '';
          final total = order['total_amount']?.toString() ??
              order['total']?.toString() ??
              order['amount']?.toString() ??
              '';
          final date = order['created_at']?.toString() ??
              order['date']?.toString() ??
              '';
          final customerName = order['customer_name']?.toString() ?? '';

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.appSurfaceVariant,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.appBorder),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.box,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        id.isEmpty
                            ? tr('profile.order')
                            : '${tr('profile.order')} #$id',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: context.appTextPrimary,
                        ),
                      ),
                      if (_isAdmin && customerName.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          customerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (status.isNotEmpty) status,
                          if (date.isNotEmpty) date,
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (total.isNotEmpty)
                  Text(
                    total,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary,
                    ),
                  ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openAllOrders,
            icon: const Icon(Iconsax.arrow_left_2, size: 18),
            label: Text(
              _isAdmin
                  ? tr('profile.view_all_customer_orders')
                  : tr('profile.view_all_orders'),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressesSection() {
    if (_addressesLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_addresses.isEmpty) {
      return _EmptyCard(
        icon: Iconsax.location,
        title: _isAdmin
            ? tr('profile.no_customer_addresses')
            : tr('profile.no_saved_addresses'),
        subtitle: _isAdmin
            ? tr('profile.customer_addresses_empty_hint')
            : tr('profile.addresses_empty_hint'),
      );
    }

    return Column(
      children: _addresses.map((addr) {
        final name = addr['fullname']?.toString() ??
            addr['full_name']?.toString() ??
            '';
        final phone = addr['mobile']?.toString() ??
            addr['phone']?.toString() ??
            '';
        final city = addr['city']?.toString() ?? '';
        final country = addr['country']?.toString() ?? '';
        final line = [
          if (city.isNotEmpty) city,
          if (country.isNotEmpty) country,
        ].join(', ');

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: context.appSurfaceVariant,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.appBorder),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Iconsax.location,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name.isNotEmpty ? name : tr('profile.shipping_address'),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: context.appTextPrimary,
                      ),
                    ),
                    if (line.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        line,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                    if (phone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        phone,
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appTextSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSupportSection() {
    return Column(
      children: [
        Text(
          tr('profile.support_intro'),
          style: TextStyle(
            fontSize: 13,
            color: context.appTextSecondary,
          ),
        ),
        const SizedBox(height: 14),
        _SupportTile(
          icon: Iconsax.headphone5,
          color: AppColors.primary,
          title: tr('profile.support'),
          subtitle: tr('profile.support_desc'),
          displayNumber: '3338 0011',
          onCall: () => _callNumber('33380011'),
        ),
        const SizedBox(height: 10),
        _SupportTile(
          icon: Iconsax.user,
          color: AppColors.primary,
          title: tr('profile.customer_service'),
          subtitle: tr('profile.customer_service_desc'),
          displayNumber: '7799 1225',
          onCall: () => _callNumber('77991225'),
        ),
      ],
    );
  }
}

class _ProfileMenuItem {
  final String id;
  final IconData icon;
  final String label;
  final _ProfileSection? section;

  const _ProfileMenuItem({
    required this.id,
    required this.icon,
    required this.label,
    this.section,
  });
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: context.appSurfaceVariant,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.appBorder),
      ),
      child: Column(
        children: [
          Icon(icon, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: context.appTextPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              color: context.appTextSecondary,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}

class _SupportTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String displayNumber;
  final VoidCallback onCall;

  const _SupportTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.displayNumber,
    required this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurfaceVariant,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onCall,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.appTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      displayNumber,
                      textDirection: TextDirection.ltr,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: color,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Iconsax.call, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
