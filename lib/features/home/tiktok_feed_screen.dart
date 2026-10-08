import 'dart:io';

import 'package:GlobalFarm/core/services/onesignal_service.dart';
import 'package:GlobalFarm/core/services/onesignal_service_web.dart';
import 'package:GlobalFarm/features/add_product/add_product_screen.dart';
import 'package:GlobalFarm/features/auth/login.dart';
import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:iconsax/iconsax.dart';
import 'package:image_picker/image_picker.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/database_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/core/widgets/media_viewer_widget.dart';
import 'package:GlobalFarm/core/widgets/item_thumbnail_widget.dart';
import 'package:GlobalFarm/core/widgets/app_coach_tutorial.dart';
import 'package:GlobalFarm/core/utils/item_media_url_util.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/product/product_detail_screen.dart';
import 'package:GlobalFarm/features/search/search_screen.dart';
import 'package:GlobalFarm/features/profile/profile_screen.dart';
import 'package:GlobalFarm/features/comments/comments_modal.dart';
import 'package:GlobalFarm/features/camera/camera_screen.dart';
import 'package:GlobalFarm/features/cart/shopping_cart_screen.dart';
import 'package:GlobalFarm/features/chat/conversations_screen.dart';
import 'package:GlobalFarm/features/orders/my_orders_screen.dart';
import 'package:GlobalFarm/features/orders/customer_orders_screen.dart';
import 'package:http/http.dart' as http;

class TikTokFeedScreen extends StatefulWidget {
  final String? initialItemId;

  const TikTokFeedScreen({super.key, this.initialItemId});

  @override
  State<TikTokFeedScreen> createState() => _TikTokFeedScreenState();
}

class _TikTokFeedScreenState extends State<TikTokFeedScreen>
    with TickerProviderStateMixin {
  static const String _prefViewMode = 'view_mode';
  static const String _viewModeTiktok = 'tiktok';
  static const String _viewModeGrid = 'grid';

  PageController _pageController = PageController();
  int _itemsLoadGeneration = 0;
  int _feedViewKey = 0;
  final ScrollController _gridScrollController = ScrollController();
  int _currentIndex = 0;
  DateTime? _itemViewStartTime;
  bool _isLoggedIn = false;
  bool _isAdmin = false;
  bool _isOpeningCamera = false;
  List<ItemModel> _items = [];
  bool _isLoading = false;
  bool _hasError = false;
  int _currentPage = 0;
  String? _currentItemId;
  String? _currentUserId;
  List<String> _categories = [];
  String?
  _selectedCategory; // ✅ الفلتر الحالي - null = الكل، غير null = تصنيف محدد
  bool _isLoadingCategories = false;
  String? _currentStoreId; // ✅ المتجر الحالي للمنتج المعروض
  String _viewMode = _viewModeTiktok;
  bool _showScrollToTop = false;
  final Map<String, int> _cartQuantities = {};
  Set<String> _notifySubscribed = {};
  bool _showHeartAnimation = false;
  bool _heartIsLiked = true;
  AnimationController? _heartAnimController;
  Animation<double>? _heartScaleAnim;
  Animation<double>? _heartOpacityAnim;
  Color _heartColor = Colors.red;
  bool _showCoachTutorial = false;
  bool _coachTutorialChecked = false;

  final GlobalKey _coachLoginKey = GlobalKey();
  final GlobalKey _coachSearchKey = GlobalKey();
  final GlobalKey _coachViewModeKey = GlobalKey();
  final GlobalKey _coachMoreKey = GlobalKey();
  final GlobalKey _coachSellerKey = GlobalKey();
  final GlobalKey _coachLikeKey = GlobalKey();
  final GlobalKey _coachCommentKey = GlobalKey();
  final GlobalKey _coachShareKey = GlobalKey();
  final GlobalKey _coachCartKey = GlobalKey();
  final GlobalKey _coachProductInfoKey = GlobalKey();

  Future<String> getUserCountry() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return 'Qatar'; // default
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low, // ✅ low بدل high أسرع
        timeLimit: Duration(seconds: 5), // ✅ timeout
      );

      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return placemarks.first.country ?? 'Unknown';
    } catch (e) {
      return 'Qatar'; // ✅ default بدل Unknown
    }
  }

  @override
  void initState() {
    super.initState();
    _loadViewMode();
    _checkLoginStatus();
    _gridScrollController.addListener(_onGridScroll);

    _heartAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    _heartScaleAnim =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 0.0, end: 1.3), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.3, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 20),
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 20),
        ]).animate(
          CurvedAnimation(parent: _heartAnimController!, curve: Curves.easeOut),
        );

    _heartOpacityAnim = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.0), weight: 60),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 40),
    ]).animate(_heartAnimController!);

    _heartAnimController!.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() => _showHeartAnimation = false);
        _heartAnimController!.reset();
      }
    });
  }

  void _triggerHeartAnimation(bool isLiking) {
    _heartIsLiked = isLiking;

    if (isLiking) {
      setState(() {
        _showHeartAnimation = true;
        _heartColor = Colors.red;
      });
      _heartAnimController!.forward(from: 0);
    } else {
      setState(() {
        _showHeartAnimation = true;
        _heartColor = Colors.red;
      });
      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _heartColor = Colors.white);
      });
      _heartAnimController!.forward(from: 0);
    }
  }

  Future<void> _loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefViewMode) ?? _viewModeTiktok;
    if (!mounted) return;
    setState(() {
      _viewMode = saved == _viewModeGrid ? _viewModeGrid : _viewModeTiktok;
    });
  }

  Future<void> _setViewMode(String mode) async {
    if (_viewMode == mode) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefViewMode, mode);
    if (!mounted) return;
    setState(() {
      _viewMode = mode;
      if (mode == _viewModeTiktok) {
        _showScrollToTop = false;
      }
    });
  }

  bool get _isTikTokMode => _viewMode == _viewModeTiktok;

  Future<void> _maybeStartCoachTutorial() async {
    if (_coachTutorialChecked || _showCoachTutorial || !_isTikTokMode) return;
    _coachTutorialChecked = true;

    final prefs = await SharedPreferences.getInstance();
    final done = prefs.getBool('tutorial_done') ?? false;
    if (done || !mounted) return;

    // Wait for side actions / top bar to layout with GlobalKeys.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 450), () {
        if (!mounted || _items.isEmpty) return;
        setState(() => _showCoachTutorial = true);
      });
    });
  }

  Future<void> _finishCoachTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_done', true);
    if (!mounted) return;
    setState(() => _showCoachTutorial = false);
  }

  List<CoachTutorialStep> _buildCoachSteps() {
    final steps = <CoachTutorialStep>[
      CoachTutorialStep(
        targetKey: _coachLoginKey,
        title: !_isLoggedIn
            ? tr('feed.login')
            : (_isAdmin ? tr('feed.add_product') : tr('feed.logout')),
        description: !_isLoggedIn
            ? tr('feed.coach_login_desc')
            : (_isAdmin
                  ? tr('feed.coach_add_product_desc')
                  : tr('feed.coach_logout_desc')),
      ),
      CoachTutorialStep(
        targetKey: _coachSearchKey,
        title: tr('feed.search'),
        description: tr('feed.coach_search_desc'),
      ),
      CoachTutorialStep(
        targetKey: _coachViewModeKey,
        title: tr('feed.coach_view_mode_title'),
        description: tr('feed.coach_view_mode_desc'),
      ),
      if (_isLoggedIn)
        CoachTutorialStep(
          targetKey: _coachMoreKey,
          title: tr('feed.coach_more_title'),
          description: tr('feed.coach_more_desc'),
        ),
      CoachTutorialStep(
        title: tr('feed.coach_browse_title'),
        description: tr('feed.coach_browse_desc'),
        showSwipeHint: true,
        fallbackRect: (s) =>
            Rect.fromCenter(center: Offset(s.width / 2, s.height * 0.4), width: 140, height: 140),
      ),
      CoachTutorialStep(
        targetKey: _coachSellerKey,
        title: tr('feed.coach_seller_title'),
        description: tr('feed.coach_seller_desc'),
      ),
      CoachTutorialStep(
        targetKey: _coachLikeKey,
        title: tr('feed.coach_like_title'),
        description: tr('feed.coach_like_desc'),
      ),
      CoachTutorialStep(
        targetKey: _coachCommentKey,
        title: tr('feed.coach_comments_title'),
        description: tr('feed.coach_comments_desc'),
      ),
      CoachTutorialStep(
        targetKey: _coachShareKey,
        title: tr('feed.coach_share_title'),
        description: tr('feed.coach_share_desc'),
      ),
      CoachTutorialStep(
        targetKey: _coachCartKey,
        title: tr('feed.add_to_cart'),
        description: tr('feed.coach_cart_desc'),
      ),
      CoachTutorialStep(
        targetKey: _coachProductInfoKey,
        title: tr('feed.coach_product_info_title'),
        description: tr('feed.coach_product_info_desc'),
      ),
    ];
    return steps;
  }

  void _onGridScroll() {
    if (_isTikTokMode || !_gridScrollController.hasClients) return;

    final offset = _gridScrollController.offset;
    final showScrollToTop = offset > 300;
    if (showScrollToTop != _showScrollToTop) {
      setState(() => _showScrollToTop = showScrollToTop);
    }

    if (_isLoading || _items.isEmpty) return;

    final position = _gridScrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      _loadItems(
        uid: _currentUserId,
        initiItem: '',
        category: _selectedCategory,
      );
    }
  }

  void _scrollGridToTop() {
    if (!_gridScrollController.hasClients) return;
    _gridScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOut,
    );
  }

  double _gridHeaderHeight(BuildContext context) {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    return statusBarHeight + 126;
  }

  int _gridCartQuantity(ItemModel item) {
    return _cartQuantities[item.id] ?? item.interactions.cartQuantity;
  }

  void _syncCartQuantitiesFromItems(Iterable<ItemModel> items) {
    for (final item in items) {
      _cartQuantities[item.id] = item.interactions.cartQuantity;
    }
  }

  Future<String?> _requireLoginForGridCart(ItemModel item) async {
    if (!_isLoggedIn) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
      return null;
    }

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      if (!mounted) return null;
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return null;
    }

    if (currentUserId == item.seller.id) {
      if (!mounted) return null;
      showAppSnackbar(
        context,
        message: tr('feed.cannot_add_own_product'),
        type: SnackType.warning,
      );
      return null;
    }

    return currentUserId;
  }

  void _setGridCartQuantity(String itemId, int quantity) {
    setState(() {
      _cartQuantities[itemId] = quantity;
      final itemIndex = _items.indexWhere((i) => i.id == itemId);
      if (itemIndex != -1) {
        _items[itemIndex].interactions.cartQuantity = quantity;
      }
    });
  }

  Future<void> _onGridCartAdd(ItemModel item) async {
    final userId = await _requireLoginForGridCart(item);
    if (userId == null) return;

    final current = _gridCartQuantity(item);
    if (item.quantity > 0 && current >= item.quantity) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr('feed.available_quantity_only', {'n': item.quantity}),
        type: SnackType.warning,
      );
      return;
    }

    final previous = current;
    _setGridCartQuantity(item.id, current + 1);

    try {
      await ApiService.addToCart(itemId: item.id, userId: userId, quantity: 1);
    } catch (e) {
      if (!mounted) return;
      _setGridCartQuantity(item.id, previous);
      showAppSnackbar(
        context,
        message: tr('feed.cart_add_error'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _onGridCartRemove(ItemModel item) async {
    final userId = await _requireLoginForGridCart(item);
    if (userId == null) return;

    final current = _gridCartQuantity(item);
    if (current <= 0) return;

    final previous = current;
    _setGridCartQuantity(item.id, current - 1);

    try {
      final result = await ApiService.removeFromCart(
        itemId: item.id,
        userId: userId,
      );
      if (result['success'] == true && result['quantity'] != null) {
        final serverQty = result['quantity'];
        final parsed = serverQty is int
            ? serverQty
            : int.tryParse(serverQty.toString()) ?? previous - 1;
        _setGridCartQuantity(item.id, parsed);
      }
    } catch (e) {
      if (!mounted) return;
      _setGridCartQuantity(item.id, previous);
      showAppSnackbar(
        context,
        message: tr('feed.cart_update_error'),
        type: SnackType.error,
      );
    }
  }

  Future<void> _addNotifyRequest(ItemModel item) async {
    if (!_isLoggedIn || _currentUserId == null) {
      Navigator.of(
        context,
      ).push(MaterialPageRoute(builder: (context) => const LoginScreen()));
      return;
    }

    if (_currentUserId == item.seller.id) {
      return;
    }

    try {
      final result = await ApiService.addNotifyRequest(
        itemId: item.id,
        userId: _currentUserId!,
        storeId: item.storeid,
      );

      if (!mounted) return;

      if (result['success'] == true) {
        final alreadySubscribed = result['already_subscribed'] == true;
        setState(() {
          _notifySubscribed.add(item.id.toString());
        });

        if (alreadySubscribed) {
          showAppSnackbar(
            context,
            message: tr('feed.already_subscribed_alert'),
            type: SnackType.warning,
          );
        } else {
          showAppSnackbar(
            context,
            message: tr('feed.notify_success'),
            type: SnackType.success,
          );
        }
      } else {
        showAppSnackbar(
          context,
          message:
              result['error']?.toString() ?? tr('feed.notify_register_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: tr('feed.notify_register_error'),
        type: SnackType.error,
      );
    }
  }

  void _onGridNotifyWhenAvailable(ItemModel item) {
    _addNotifyRequest(item);
  }

  String? _itemShareImageUrl(ItemModel item) {
    return ItemMediaUrlUtil.resolveShareImageUrl(
      mediaUrls: item.media,
      storeId: item.storeid,
      itemId: item.id,
      itemIdx: item.idx,
    );
  }

  void _openItemFromGrid(ItemModel item) {
    final index = _items.indexWhere((i) => i.id == item.id);
    if (index < 0) return;

    setState(() {
      _currentIndex = index;
      _currentItemId = item.id;
    });

    if (!_isTikTokMode) {
      _setViewMode(_viewModeTiktok);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pageController.hasClients) {
        _pageController.jumpToPage(index);
      }
    });
  }

  void _trackLeavingItem(int itemIndex) {
    if (_itemViewStartTime == null ||
        itemIndex < 0 ||
        itemIndex >= _items.length) {
      return;
    }
    final item = _items[itemIndex];
    final seconds = DateTime.now().difference(_itemViewStartTime!).inSeconds;
    ApiService.trackInteraction(
      _currentUserId,
      item.id,
      'view',
      watchSeconds: seconds,
    );
    if (seconds < 2) {
      ApiService.trackInteraction(_currentUserId, item.id, 'skip');
    }
  }

  void _onPageChanged(int newIndex) {
    if (_items.isEmpty || newIndex >= _items.length) return;

    if (newIndex != _currentIndex && _currentIndex < _items.length) {
      _trackLeavingItem(_currentIndex);
    }

    final newStoreId = _items[newIndex].storeid;

    setState(() {
      _currentIndex = newIndex;
      _currentItemId = _items[newIndex].id;
    });

    _itemViewStartTime = DateTime.now();

    if (newStoreId != _currentStoreId) {
      _loadCategoriesForStore(newStoreId);
    }
  }

  Future<void> _loadNotifySubscriptions() async {
    if (!_isLoggedIn || _currentUserId == null) return;
    try {
      final ids = await ApiService.getUserNotifySubscriptions(_currentUserId!);
      if (!mounted) return;
      setState(() {
        _notifySubscribed = ids.map((e) => e.toString()).toSet();
      });
    } catch (e) {
      print('Error loading notify subscriptions: $e');
    }
  }

  String _sellerUserId(SellerModel seller) {
    return seller.uid.isNotEmpty ? seller.uid : seller.id;
  }

  bool _isOwnProduct(ItemModel item) {
    if (_currentUserId == null || _currentUserId!.isEmpty) return false;
    return _currentUserId == item.seller.uid ||
        _currentUserId == item.seller.id ||
        _currentUserId == _sellerUserId(item.seller);
  }

  bool _sheetIsDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  Color _sheetBackground(BuildContext context) =>
      _sheetIsDark(context) ? AppColors.darkBackground : Colors.white;

  Color _sheetTileBackground(BuildContext context) =>
      _sheetIsDark(context) ? AppColors.darkSurface : const Color(0xFFF5F5F5);

  Color _sheetOnSurface(BuildContext context) =>
      Theme.of(context).colorScheme.onSurface;

  bool _sameSeller(SellerModel a, SellerModel b) {
    return _sellerUserId(a) == _sellerUserId(b);
  }

  void _setFollowStateForSeller(SellerModel targetSeller, bool isFollowing) {
    for (var i = 0; i < _items.length; i++) {
      print(
        'Comparing: ${_items[i].seller.id} == ${targetSeller.id} '
        '(uid: ${_items[i].seller.uid} vs ${targetSeller.uid})',
      );
      if (!_sameSeller(_items[i].seller, targetSeller)) continue;

      _items[i] = ItemModel(
        id: _items[i].id,
        idx: _items[i].idx,
        storeid: _items[i].storeid,
        name: _items[i].name,
        nameEn: _items[i].nameEn,
        price: _items[i].price,
        quantity: _items[i].quantity,
        description: _items[i].description,
        descriptionArb: _items[i].descriptionArb,
        views: _items[i].views,
        media: _items[i].media,
        seller: SellerModel(
          id: _items[i].seller.id,
          uid: _items[i].seller.uid.isNotEmpty
              ? _items[i].seller.uid
              : _items[i].seller.id,
          name: _items[i].seller.name,
          avatar: _items[i].seller.avatar,
          token: _items[i].seller.token,
          isFollowing: isFollowing,
        ),
        interactions: _items[i].interactions,
      );
    }
  }

  Future<void> _checkLoginStatus() async {
    final currentUserIdx = await AuthService.getCurrentUserId();

    final isLoggedIn = await AuthService.isLoggedIn();
    final isAdmin = isLoggedIn ? await AuthService.isAdmin() : false;
    setState(() {
      _isLoggedIn = isLoggedIn;
      _currentUserId = currentUserIdx;
      _isAdmin = isAdmin;
    });

    print('🔔 Loaded notify subscriptions: $_notifySubscribed');
    print('🔔 Current item ids: ${_items.map((e) => e.id).toList()}');

    if (isLoggedIn) {
      _loadNotifySubscriptions();
    }

    if (isLoggedIn && currentUserIdx != null) {
      final scores = await ApiService.getUserScores(currentUserIdx);
      print('🎯 User category scores: ${scores['top_categories']}');
    }

    // ✅ تحميل المنتجات أولاً، ثم التصنيفات ستُحمّل تلقائياً
    if (widget.initialItemId != null && widget.initialItemId!.isNotEmpty) {
      await _pinFeedToItem(widget.initialItemId!);
    } else {
      _loadItems(uid: _currentUserId, isRefresh: true);
    }
  }

  Future<void> _pinFeedToItem(String itemId) async {
    final pinnedId = itemId.trim();
    if (pinnedId.isEmpty) return;

    print('📌 Pinning feed to item: $pinnedId');

    if (!_isTikTokMode) {
      await _setViewMode(_viewModeTiktok);
    }

    _resetFeedPageController();

    setState(() {
      _currentIndex = 0;
      _currentItemId = pinnedId;
      _selectedCategory = null;
    });

    await _loadItems(
      isRefresh: true,
      uid: _currentUserId,
      category: null,
      pinnedItemId: pinnedId,
    );
  }

  Future<void> _loadCategoriesForStore(String storeId) async {
    // ✅ تجنب إعادة التحميل إذا كان نفس المتجر
    if (storeId == _currentStoreId && _categories.isNotEmpty) return;
    if (_isLoadingCategories) return;

    setState(() {
      _isLoadingCategories = true;
    });

    try {
      final categories = await ApiService.getCategories(storeId: storeId);
      setState(() {
        _categories = categories;
        _currentStoreId = storeId;
        _isLoadingCategories = false;

        // ✅ إذا التصنيف المختار غير موجود في المتجر الجديد، نرجع لـ "الكل"
        if (_selectedCategory != null &&
            !categories.contains(_selectedCategory)) {
          _selectedCategory = null;
        }
      });

      print('📦 Loaded ${categories.length} categories for store: $storeId');
    } catch (e) {
      print('Error loading categories for store $storeId: $e');
      setState(() {
        _isLoadingCategories = false;
      });
    }
  }

  void _resetFeedPageController() {
    final oldController = _pageController;
    _pageController = PageController();
    oldController.dispose();
    _feedViewKey++;
  }

  Future<void> _loadItems({
    bool isRefresh = false,
    String? uid,
    String? initiItem,
    String? category,
    String? pinnedItemId,
  }) async {
    final hasPinnedRefresh =
        isRefresh && pinnedItemId != null && pinnedItemId.isNotEmpty;
    if (_isLoading && !hasPinnedRefresh) return;

    final generation = ++_itemsLoadGeneration;
    print("SSSSSS $uid");
    print("Category Filter: $category");

    setState(() {
      _isLoading = true;
      _hasError = false;
      if (isRefresh) {
        _currentPage = 0;
        _items.clear();
      }
    });

    try {
      List<ItemModel> items;

      // ✅ نجيب الـ user_id سواء مسجل دخول أو لأ
      final currentUserId = _isLoggedIn
          ? await AuthService.getCurrentUserId()
          : null;

      final prefs = await SharedPreferences.getInstance();
      String simCountry = prefs.getString('selected_country') ?? 'QA';
      print('🌍 Selected country: $simCountry');
      print(
        '🗣️ Selected language: ${LocalizationService.instance.currentLanguage}',
      );

      // pinnedItemId يتعارض مع itemSrchId على السيرفر — لا تبعت الاثنين معاً
      final String? searchItemId = hasPinnedRefresh
          ? null
          : (initiItem == "" ? initiItem : widget.initialItemId);

      if (_isLoggedIn && currentUserId != null) {
        items = await ApiService.fetchItemsWithLikes(
          userId: currentUserId,
          limit: 10,
          offset: isRefresh ? 0 : _items.length,
          initialItemId: searchItemId,
          category: category,
          country: simCountry,
          pinnedItemId: isRefresh ? pinnedItemId : null,
        );
      } else {
        items = await ApiService.fetchItems(
          page: isRefresh ? 0 : _currentPage,
          userId: uid,
          initialItemId: searchItemId,
          category: category,
          country: simCountry,
          pinnedItemId: isRefresh ? pinnedItemId : null,
        );
      }

      if (hasPinnedRefresh) {
        final pinnedIndex = items.indexWhere((item) => item.id == pinnedItemId);
        if (pinnedIndex > 0) {
          final pinnedItem = items.removeAt(pinnedIndex);
          items.insert(0, pinnedItem);
        } else if (pinnedIndex == -1) {
          final fetchedItem = await ApiService.fetchItemById(
            itemId: pinnedItemId,
            userId: currentUserId,
            country: simCountry,
          );
          if (fetchedItem != null) {
            items.insert(0, fetchedItem);
          }
        }
      } else if (items.isEmpty &&
          searchItemId != null &&
          searchItemId.isNotEmpty &&
          isRefresh) {
        print('🔎 Direct item lookup fallback: $searchItemId');
        final fetchedItem = await ApiService.fetchItemById(
          itemId: searchItemId,
          userId: currentUserId,
          country: simCountry,
        );
        if (fetchedItem != null) {
          items = [fetchedItem];
        }
      }

      if (generation != _itemsLoadGeneration) return;

      setState(() {
        if (isRefresh) {
          _items = items;
          _cartQuantities.clear();
        } else {
          _items.addAll(items);
        }
        _syncCartQuantitiesFromItems(items);
        _isLoading = false;
        _currentPage++;
        if (hasPinnedRefresh && _items.isNotEmpty) {
          _currentIndex = 0;
          _currentItemId = pinnedItemId;
          _itemViewStartTime = DateTime.now();
        } else if (_itemViewStartTime == null && _items.isNotEmpty) {
          _itemViewStartTime = DateTime.now();
        }
      });

      if (isRefresh && items.isNotEmpty) {
        _maybeStartCoachTutorial();
      }

      if (hasPinnedRefresh && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_pageController.hasClients && _items.isNotEmpty) {
            _pageController.jumpToPage(0);
          }
        });
      }

      // ✅ تحميل التصنيفات للمتجر الأول بعد تحميل المنتجات
      if (items.isNotEmpty && isRefresh) {
        _loadCategoriesForStore(items[0].storeid);
      }
    } catch (e) {
      print('API Error: $e');
      if (generation != _itemsLoadGeneration) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });

      showAppSnackbar(
        context,
        message: '${tr('feed.server_connection_error')}: $e',
        type: SnackType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        bool exitApp =
            await showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(tr('common.exit_app')),
                content: Text(tr('common.exit_app_msg')),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: Text(tr('common.no')),
                  ),
                  TextButton(
                    onPressed: () => SystemNavigator.pop(),
                    child: Text(tr('common.yes')),
                  ),
                ],
              ),
            ) ??
            false;

        return exitApp;
      },
      child: Directionality(
        textDirection: LocalizationService.instance.textDirection,
        child: Scaffold(
          backgroundColor: _isTikTokMode ? Colors.black : context.appBackground,
          body: _isLoading && _items.isEmpty
              ? const Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              : Stack(
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      switchInCurve: Curves.easeInOut,
                      switchOutCurve: Curves.easeInOut,
                      child: _isTikTokMode
                          ? _buildTikTokFeed(
                              key: ValueKey('tiktok_feed_$_feedViewKey'),
                            )
                          : _buildGridFeed(key: const ValueKey('grid_feed')),
                    ),
                    if (_isTikTokMode && _showHeartAnimation)
                      Positioned.fill(
                        child: IgnorePointer(
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _heartAnimController!,
                              builder: (context, child) {
                                return Opacity(
                                  opacity: _heartOpacityAnim!.value,
                                  child: Transform.scale(
                                    scale: _heartScaleAnim!.value,
                                    child: Icon(
                                      Icons.favorite,
                                      color: _heartColor,
                                      size: 120,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black.withOpacity(0.3),
                                          blurRadius: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    if (_isTikTokMode) ...[
                      _buildTopBar(),
                      _buildCategoriesBar(),
                      _buildSideActions(),
                      _buildBottomInfo(),
                    ] else ...[
                      _buildGridHeader(),
                      if (_showScrollToTop)
                        Positioned(
                          right: 16,
                          bottom: 16,
                          child: FloatingActionButton.small(
                            onPressed: _scrollGridToTop,
                            backgroundColor: AppColors.primary,
                            child: const Icon(
                              Iconsax.arrow_up,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    ],
                    if (_items.isEmpty) _buildEmptyFeedState(),
                    if (_showCoachTutorial && _isTikTokMode && _items.isNotEmpty)
                      Positioned.fill(
                        child: AppCoachTutorial(
                          steps: _buildCoachSteps(),
                          isArabic:
                              LocalizationService.instance.currentLanguage ==
                              'ar',
                          onFinish: _finishCoachTutorial,
                          onSkip: _finishCoachTutorial,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildTikTokFeed({Key? key}) {
    return PageView.builder(
      key: key,
      controller: _pageController,
      scrollDirection: Axis.vertical,
      onPageChanged: (index) {
        final actualIndex = index % _items.length;
        _onPageChanged(actualIndex);

        if (actualIndex >= _items.length - 3 && !_isLoading) {
          _loadItems(
            uid: _items[actualIndex].seller.id,
            initiItem: '',
            category: _selectedCategory,
          );
        }
      },
      itemCount: _items.isEmpty ? 0 : null,
      itemBuilder: (context, index) {
        if (_items.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        final actualIndex = index % _items.length;
        return _buildVideoItem(_items[actualIndex], actualIndex);
      },
    );
  }

  Widget _buildGridFeed({Key? key}) {
    final topPadding = _gridHeaderHeight(context);

    return RefreshIndicator(
      key: key,
      color: AppColors.primary,
      onRefresh: () => _loadItems(
        isRefresh: true,
        uid: _currentUserId,
        category: _selectedCategory,
      ),
      child: GridView.builder(
        controller: _gridScrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(12, topPadding, 12, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.62,
        ),
        itemCount: _items.length + (_isLoading ? 2 : 0),
        itemBuilder: (context, index) {
          if (index >= _items.length) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                  color: AppColors.primary,
                  strokeWidth: 2,
                ),
              ),
            );
          }
          return _buildGridProductCard(_items[index]);
        },
      ),
    );
  }

  Map<String, dynamic> _productDetailItemMap(ItemModel item) {
    return {
      'id': item.id,
      'idx': item.idx,
      'storeid': item.storeid,
      'name': item.name,
      'eng': item.nameEn,
      'price': item.price,
      'qtt': item.quantity,
      'description': item.description,
      'description_arb': item.descriptionArb,
      'seller_name': item.seller.name,
      'seller_id': item.seller.id,
    };
  }

  Widget _buildGridProductCard(ItemModel item) {
    final showCart = !_isLoggedIn || !_isOwnProduct(item);

    return Material(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                ProductDetailScreen(item: _productDetailItemMap(item)),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: ItemThumbnailWidget.fromItem(
                  itemId: item.id,
                  itemIdx: item.idx,
                  storeId: item.storeid,
                  media: item.media,
                  height: 160,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(16),
                  ),
                  placeholderColor: context.appSurfaceVariant,
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.localizedName(
                        LocalizationService.instance.currentLanguage,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textDirection: context.appTextDirection,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(Iconsax.shop, size: 12, color: Colors.grey[500]),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            item.seller.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textDirection: context.appTextDirection,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${item.price} ${tr('feed.price')}',
                            style: const TextStyle(
                              color: AppColors.secondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        if (showCart)
                          _GridCartButton(
                            cartQuantity: _gridCartQuantity(item),
                            stockQuantity: item.quantity,
                            onAdd: () => _onGridCartAdd(item),
                            onRemove: () => _onGridCartRemove(item),
                            onNotify: () => _onGridNotifyWhenAvailable(item),
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

  Widget _buildEmptyFeedState() {
    final textColor = _isTikTokMode ? Colors.white : context.appTextPrimary;
    final iconColor = _isTikTokMode ? Colors.white : Colors.grey;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.box, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text(
            tr('feed.no_products'),
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () =>
                _loadItems(isRefresh: true, category: _selectedCategory),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('feed.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBarIconButton({
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    if (_isTikTokMode) {
      return Stack(
        children: [
          Positioned(
            left: 1,
            top: 1,
            child: IconButton(
              onPressed: onPressed,
              icon: Icon(icon, color: Colors.black45, size: 28),
            ),
          ),
          IconButton(
            onPressed: onPressed,
            icon: Icon(icon, color: Colors.white, size: 28),
          ),
        ],
      );
    }

    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, color: context.appTextPrimary, size: 28),
    );
  }

  Widget _buildViewModeSwitchButton() {
    final switchToGrid = _isTikTokMode;
    return IconButton(
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
      onPressed: () =>
          _setViewMode(switchToGrid ? _viewModeGrid : _viewModeTiktok),
      icon: Icon(
        switchToGrid ? Iconsax.grid_2 : Iconsax.play_circle,
        size: 24,
        color: AppColors.primary,
      ),
    );
  }

  Widget _buildTopBarRow() {
    final lang = LocalizationService.instance.currentLanguage;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      children: [
        !_isLoggedIn
            ? IconButton(
                key: _coachLoginKey,
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => const LoginScreen(),
                    ),
                  );
                },
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.secondary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Iconsax.login_1,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              )
            : (_isAdmin
                  ? IconButton(
                      key: _coachLoginKey,
                      onPressed: () async {
                        String? uid = await AuthService.getCurrentUID();
                        AuthService.getUserStatus(uid).then((val) {
                          if (val['status'] == '2') {
                            showAppSnackbar(
                              context,
                              message: tr('feed.account_banned'),
                              type: SnackType.error,
                            );
                          } else {
                            _handleAddProduct();
                          }
                        });
                      },
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Iconsax.add,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    )
                  : IconButton(
                      key: _coachLoginKey,
                      onPressed: _confirmLogout,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.secondary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Iconsax.logout,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    )),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            KeyedSubtree(
              key: _coachSearchKey,
              child: _buildTopBarIconButton(
                icon: Iconsax.search_normal,
                onPressed: () async {
                  final itemId = await Navigator.push<String>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SearchScreen(),
                    ),
                  );
                  if (itemId != null && itemId.isNotEmpty && mounted) {
                    await _pinFeedToItem(itemId);
                  }
                },
              ),
            ),
            KeyedSubtree(
              key: _coachViewModeKey,
              child: _buildViewModeSwitchButton(),
            ),
            if (_isLoggedIn)
              KeyedSubtree(
                key: _coachMoreKey,
                child: _buildTopBarIconButton(
                  icon: Iconsax.more,
                  onPressed: _showMoreOptions,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: _buildTopBarRow(),
      ),
    );
  }

  Widget _buildGridHeader() {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: _buildTopBarRow(),
                ),
                SizedBox(height: 50, child: _buildCategoriesContent()),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoriesContent() {
    if (_isLoadingCategories) {
      return const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: AppColors.primary,
            strokeWidth: 2,
          ),
        ),
      );
    }

    if (_categories.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _categories.length + 1,
      itemBuilder: (context, index) => _buildCategoryItemAt(index),
    );
  }

  Widget _buildCategoryItemAt(int index) {
    if (index == 0) {
      return _buildCategoryChip(
        label: tr('feed.all'),
        isSelected: _selectedCategory == null,
        onTap: () {
          if (_selectedCategory == null) return;

          setState(() {
            _selectedCategory = null;
          });
          _loadItems(isRefresh: true, uid: _currentUserId, category: null);
        },
      );
    }

    final category = _categories[index - 1];
    return _buildCategoryChip(
      label: category,
      isSelected: _selectedCategory == category,
      onTap: () {
        if (_selectedCategory == category) return;

        setState(() {
          _selectedCategory = category;
        });
        _loadItems(isRefresh: true, uid: _currentUserId, category: category);
      },
    );
  }

  Widget _buildCategoriesBar() {
    final statusBarHeight = MediaQuery.of(context).padding.top;
    final topPosition = statusBarHeight + 60;

    if (_isLoadingCategories) {
      return Positioned(
        top: topPosition,
        left: 0,
        right: 0,
        child: SizedBox(
          height: 50,
          child: Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
      );
    }

    if (_categories.isEmpty) return const SizedBox();

    return Positioned(
      top: topPosition,
      left: 0,
      right: 0,
      child: SizedBox(
        height: 50,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _categories.length + 1,
          itemBuilder: (context, index) => _buildCategoryItemAt(index),
        ),
      ),
    );
  }

  Widget _buildCategoryChip({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final unselectedBg = _isTikTokMode
        ? Colors.white.withOpacity(0.2)
        : Colors.white;
    final unselectedBorder = _isTikTokMode
        ? Colors.white.withOpacity(0.3)
        : Colors.grey.shade300;
    final labelColor = isSelected
        ? Colors.white
        : (_isTikTokMode ? Colors.white : context.appTextPrimary);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : unselectedBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : unselectedBorder,
            width: 1.5,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 14,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              shadows: _isTikTokMode && !isSelected
                  ? const [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 2,
                        color: Colors.black45,
                      ),
                    ]
                  : null,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSideActions() {
    if (_items.isEmpty || _currentIndex >= _items.length) {
      return const SizedBox();
    }

    final item = _items[_currentIndex];
    final sellerUserId = item.seller.uid;
    return Positioned(
      right: LocalizationService.instance.currentLanguage == 'ar' ? null : 9,
      left: LocalizationService.instance.currentLanguage == 'ar' ? 9 : null,
      bottom: 140,
      child: Column(
        children: [
          _buildActionButton(
            key: _coachSellerKey,
            child: SmartAvatarWidget(
              userId: sellerUserId,
              name: item.seller.name,
              size: 48,
              fallbackUrl: item.seller.avatar,
              backgroundColor: AppColors.secondary,
              initialsStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(userId: item.seller.id),
                ),
              );
            },
          ),

          // Follow Button
          if (_isLoggedIn && !_isOwnProduct(item))
            _buildActionButton(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: item.seller.isFollowing
                      ? const Color(0xFF6B7280)
                      : AppColors.primary,
                  borderRadius: BorderRadius.circular(20),
                  border: item.seller.isFollowing
                      ? Border.all(color: const Color(0xFF4B5563), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (item.seller.isFollowing)
                      const Icon(Icons.check, color: Colors.white, size: 14),
                    if (item.seller.isFollowing) const SizedBox(width: 4),
                    Text(
                      item.seller.isFollowing
                          ? tr('feed.following')
                          : tr('feed.follow'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              onTap: () {
                _followUser(item);
              },
            ),

          // Like Button
          _buildActionButton(
            key: _coachLikeKey,
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 0,
                      top: 1,
                      child: Icon(
                        Iconsax.heart,
                        color: item.interactions.isLiked
                            ? Colors.red
                            : Colors.black45,
                        size: 33,
                      ),
                    ),
                    Icon(
                      item.interactions.isLiked
                          ? Iconsax.heart5
                          : Iconsax.heart,
                      color: item.interactions.isLiked
                          ? Colors.red
                          : Colors.white,
                      size: 32,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.likes),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 1,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _handleLike(item),
          ),

          // Comment Button
          _buildActionButton(
            key: _coachCommentKey,
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 1,
                      top: 1,
                      child: Icon(
                        Iconsax.message,
                        color: Colors.black45,
                        size: 32,
                      ),
                    ),
                    const Icon(Iconsax.message, color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.comments),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 1,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => CommentsModal(
                  itemId: item.id,
                  isLoggedIn: _isLoggedIn,
                  items: item,
                ),
              );
            },
          ),

          // Share Button
          _buildActionButton(
            key: _coachShareKey,
            child: Column(
              children: [
                Stack(
                  children: [
                    Positioned(
                      left: 1,
                      top: 1,
                      child: Icon(
                        Iconsax.share,
                        size: 32,
                        color: Colors.black45,
                      ),
                    ),
                    const Icon(Iconsax.share, color: Colors.white, size: 32),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  _formatCount(item.interactions.shares),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    shadows: [
                      Shadow(
                        offset: Offset(2, 2),
                        blurRadius: 1,
                        color: Colors.black,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            onTap: () => _handleShare(item),
          ),

          // Shopping Cart / Notify When Available
          if (!_isOwnProduct(item))
            item.quantity == 0
                ? _buildActionButton(
                    key: _coachCartKey,
                    child: Builder(
                      builder: (context) {
                        final isSubscribed = _notifySubscribed.contains(
                          item.id.toString(),
                        );

                        return Column(
                          children: [
                            isSubscribed
                                ? const Icon(
                                    Iconsax.notification5,
                                    color: Colors.white,
                                    size: 32,
                                  )
                                : Stack(
                                    children: [
                                      const Positioned(
                                        left: 1,
                                        top: 1,
                                        child: Icon(
                                          Iconsax.notification,
                                          size: 32,
                                          color: Colors.black45,
                                        ),
                                      ),
                                      const Icon(
                                        Iconsax.notification,
                                        color: Colors.white,
                                        size: 32,
                                      ),
                                    ],
                                  ),
                            const SizedBox(height: 4),
                            Text(
                              isSubscribed
                                  ? tr('feed.notify_subscribed')
                                  : tr('feed.notify_me'),
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                shadows: isSubscribed
                                    ? null
                                    : const [
                                        Shadow(
                                          offset: Offset(2, 2),
                                          blurRadius: 1,
                                          color: Colors.black,
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    onTap: () => _addNotifyRequest(item),
                  )
                : _buildActionButton(
                    key: _coachCartKey,
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Positioned(
                              left: 1,
                              top: 1,
                              child: Icon(
                                Iconsax.shopping_cart,
                                size: 32,
                                color: Colors.black45,
                              ),
                            ),
                            const Icon(
                              Iconsax.shopping_cart,
                              color: Colors.white,
                              size: 32,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatCount(item.interactions.cartQuantity),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                offset: Offset(2, 2),
                                blurRadius: 1,
                                color: Colors.black,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    onTap: () => _showCartBottomSheet(item),
                  ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    Key? key,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(padding: const EdgeInsets.all(8), child: child),
    );
  }

  Widget _buildBottomInfo() {
    if (_items.isEmpty || _currentIndex >= _items.length) {
      return const SizedBox();
    }

    final item = _items[_currentIndex];

    return Positioned(
      left: LocalizationService.instance.currentLanguage == 'ar' ? 80 : 16,
      right: LocalizationService.instance.currentLanguage == 'ar' ? 16 : 80,
      bottom: 10,
      child: Container(
        key: _coachProductInfoKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Iconsax.user, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  item.seller.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    shadows: [
                      Shadow(
                        offset: Offset(1, 1),
                        blurRadius: 3,
                        color: Colors.black26,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            // Product Title
            Text(
              item.localizedName(LocalizationService.instance.currentLanguage),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    offset: Offset(1, 1),
                    blurRadius: 3,
                    color: Colors.black26,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // Price
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Iconsax.tag, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${item.price} ${tr('feed.price')}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 10),
                item.quantity == 0
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tr('feed.out_of_stock'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      )
                    : Text(
                        "${item.quantity} ${item.quantity >= 3 && item.quantity <= 9 ? tr('feed.pieces') : tr('feed.piece')}",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          shadows: [
                            Shadow(
                              offset: Offset(1, 1),
                              blurRadius: 3,
                              color: Colors.black26,
                            ),
                          ],
                        ),
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoItem(ItemModel item, int actualIndex) {
    return GestureDetector(
      key: ValueKey('feed_item_${item.id}'),
      onDoubleTap: () {
        if (_items.isEmpty || actualIndex >= _items.length) return;
        final tappedItem = _items[actualIndex];
        if (_currentUserId == tappedItem.seller.id) return;

        final wasLiked = tappedItem.interactions.isLiked;
        _handleLike(tappedItem);
        _triggerHeartAnimation(!wasLiked);
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: MediaViewerWidget(
          mediaUrls: item.media,
          itmId: item.id,
          itmIdx: item.idx,
          storeid: item.storeid,
          autoPlayVideo: true,
          showControls: false,
          showIndicators: item.media.length > 1,
        ),
      ),
    );
  }

  Future<void> _openAddProductScreen(List<String> mediaFiles) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddProductScreen(mediaFiles: mediaFiles),
      ),
    );
    await _onReturnFromAddProductScreen(result);
  }

  Future<void> _openCameraAndAddProduct({required bool isVideo}) async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => CameraScreen(isVideo: isVideo)),
      );
      if (result is List<String> && result.isNotEmpty) {
        await _openAddProductScreen(result);
      }
    } finally {
      _isOpeningCamera = false;
    }
  }

  Future<void> _onReturnFromAddProductScreen(dynamic newItemId) async {
    if (newItemId == null) return;
    final pinnedId = newItemId.toString().trim();
    if (pinnedId.isEmpty) return;
    await _pinFeedToItem(pinnedId);
  }

  void _handleAddProduct() async {
    _showAddProductBottomSheet();
  }

  void _showAddProductBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = _sheetIsDark(context);
        return Container(
          decoration: BoxDecoration(
            color: _sheetBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('feed.add_new_product'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _sheetOnSurface(context),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Iconsax.camera, color: AppColors.primary),
                title: Text(tr('feed.add_photo')),
                subtitle: Text(tr('feed.take_product_photo')),
                onTap: () {
                  Navigator.pop(context);
                  _showImageSourceBottomSheet();
                },
              ),
              ListTile(
                leading: const Icon(
                  Iconsax.video_play,
                  color: AppColors.secondary,
                ),
                title: Text(tr('feed.add_video')),
                subtitle: Text(tr('feed.record_product_video')),
                onTap: () {
                  Navigator.pop(context);
                  _showVideoSourceBottomSheet();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptions() async {
    final item = (_items.isNotEmpty && _currentIndex < _items.length)
        ? _items[_currentIndex]
        : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = _sheetIsDark(sheetContext);
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.45,
          maxChildSize: 0.75,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: _sheetBackground(sheetContext),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  offset: const Offset(0, -6),
                ),
              ],
            ),
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                if (item != null) _buildMoreSheetHeader(item),
                const Divider(height: 32, thickness: 0.5),
                Row(
                  children: [
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.user,
                        label: tr('feed.profile'),
                        backgroundColor: const Color(0xFFE3F2FD),
                        iconColor: const Color(0xFF1565C0),
                        onTap: _showCurrentUserProfile,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.shopping_cart,
                        label: tr('feed.shopping_cart'),
                        backgroundColor: const Color(0xFFE8F5E9),
                        iconColor: const Color(0xFF2E7D32),
                        onTap: _showShoppingCart,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.bag_tick,
                        label: tr('feed.customer_orders'),
                        backgroundColor: const Color(0xFFF3E5F5),
                        iconColor: const Color(0xFF7B1FA2),
                        onTap: _showCustomerOrders,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.bag,
                        label: tr('feed.my_orders'),
                        backgroundColor: const Color(0xFFFFF3E0),
                        iconColor: AppColors.secondary,
                        onTap: _showMyOrders,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.message,
                        label: tr('feed.conversations'),
                        backgroundColor: const Color(0xFFE0F2F1),
                        iconColor: const Color(0xFF00695C),
                        onTap: _showConversations,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildMoreGridCard(
                        icon: Iconsax.document_text,
                        label: tr('feed.description'),
                        backgroundColor: const Color(0xFFFFFDE7),
                        iconColor: const Color(0xFFF9A825),
                        onTap: _showItemDescription,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildMoreGridCard(
                  icon: Iconsax.warning_2,
                  label: tr('feed.report_content'),
                  backgroundColor: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                  onTap: _showReportOptions,
                  fullWidth: true,
                ),
                const SizedBox(height: 12),
                _buildMoreGridCard(
                  icon: Iconsax.user_remove,
                  label: tr('feed.block_user'),
                  backgroundColor: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFC62828),
                  onTap: _showBlockUserOptions,
                  fullWidth: true,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      tr('common.close'),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  height: MediaQuery.of(sheetContext).padding.bottom + 16,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildMoreSheetHeader(ItemModel item) {
    return Row(
      children: [
        ItemThumbnailWidget.fromItem(
          itemId: item.id,
          itemIdx: item.idx,
          storeId: item.storeid,
          media: item.media,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(30),
          placeholderColor: context.appSurfaceVariant,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.name,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                '${item.price} ${tr('feed.price')}',
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMoreGridCard({
    required IconData icon,
    required String label,
    required Color backgroundColor,
    required Color iconColor,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? AppColors.darkSurface : backgroundColor;
    final resolvedIconColor = isDark ? Colors.white70 : iconColor;
    final labelColor = isDark
        ? Colors.white70
        : iconColor.withValues(alpha: 0.9);

    return Material(
      color: cardColor,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
            vertical: fullWidth ? 14 : 18,
            horizontal: fullWidth ? 16 : 8,
          ),
          child: fullWidth
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 28, color: resolvedIconColor),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 28, color: resolvedIconColor),
                    const SizedBox(height: 10),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: labelColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  void _showShoppingCart() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ShoppingCartScreen(userId: currentUserId),
      ),
    );
  }

  void _showConversations() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConversationsScreen(userId: currentUserId),
      ),
    );
  }

  void _showCustomerOrders() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CustomerOrdersScreen()),
    );
  }

  void _showMyOrders() async {
    Navigator.pop(context); // Close bottom sheet

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const MyOrdersScreen()),
    );
  }

  void _confirmLogout() {
    AwesomeDialog(
      context: context,
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: tr('feed.logout'),
      desc: tr('feed.logout_confirm'),
      btnCancelText: tr('common.cancel'),
      btnOkText: tr('feed.logout'),
      btnOkColor: Colors.red,
      btnCancelOnPress: () {},
      btnOkOnPress: () => _performLogout(),
    ).show();
  }

  Future<void> _performLogout() async {
    await AuthService.logout();
    if (!mounted) return;
    setState(() {
      _isLoggedIn = false;
      _isAdmin = false;
      _currentUserId = null;
    });
    showAppSnackbar(
      context,
      message: tr('feed.logout_success'),
      type: SnackType.success,
    );
    _loadItems(isRefresh: true, uid: null);
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    }
    return count.toString();
  }

  void _showCurrentUserProfile() async {
    Navigator.pop(context); // Close bottom sheet

    // Get current user ID from AuthService
    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ProfileScreen(userId: currentUserId),
        ),
      );
    } else {
      showAppSnackbar(
        context,
        message: tr('feed.user_data_not_found'),
        type: SnackType.error,
      );
    }
  }

  void _showImageSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = _sheetIsDark(context);
        return Container(
          decoration: BoxDecoration(
            color: _sheetBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('feed.add_photo'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _sheetOnSurface(context),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Iconsax.camera, color: AppColors.primary),
                title: Text(tr('feed.take_photo')),
                subtitle: Text(tr('feed.take_photo_desc')),
                onTap: () {
                  Navigator.pop(context);
                  _openCameraAndAddProduct(isVideo: false);
                },
              ),
              ListTile(
                leading: const Icon(
                  Iconsax.gallery,
                  color: AppColors.secondary,
                ),
                title: Text(tr('feed.choose_from_gallery')),
                subtitle: Text(tr('feed.choose_photo_desc')),
                onTap: () {
                  Navigator.pop(context);
                  _pickImageFromGallery();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _showVideoSourceBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = _sheetIsDark(context);
        return Container(
          decoration: BoxDecoration(
            color: _sheetBackground(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 50,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white30 : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                tr('feed.add_video'),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: _sheetOnSurface(context),
                ),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Iconsax.video_circle,
                  color: AppColors.primary,
                ),
                title: Text(tr('feed.record_video')),
                subtitle: Text(tr('feed.record_video_desc')),
                onTap: () {
                  Navigator.pop(context);
                  _openCameraAndAddProduct(isVideo: true);
                },
              ),
              ListTile(
                leading: const Icon(
                  Iconsax.video_play,
                  color: AppColors.secondary,
                ),
                title: Text(tr('feed.choose_from_gallery')),
                subtitle: Text(tr('feed.choose_video_desc')),
                onTap: () {
                  Navigator.pop(context);
                  _pickVideoFromGallery();
                },
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  void _pickImageFromGallery() async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      final ImagePicker picker = ImagePicker();
      final result = await picker.pickMultiImage();
      final imagePaths = result.map((image) => image.path).toList();
      if (imagePaths.isEmpty) return;

      await _openAddProductScreen(imagePaths);
    } finally {
      _isOpeningCamera = false;
    }
  }

  void _pickVideoFromGallery() async {
    if (_isOpeningCamera) return;
    _isOpeningCamera = true;
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? video = await picker.pickVideo(source: ImageSource.gallery);

      if (video != null) {
        await _openAddProductScreen([video.path]);
      }
    } finally {
      _isOpeningCamera = false;
    }
  }

  void _followUser(ItemModel item) async {
    bool? previousFollowing;
    try {
      final currentUserId = await AuthService.getCurrentUserId();
      if (currentUserId == null) {
        showAppSnackbar(
          context,
          message: tr('common.login_required'),
          type: SnackType.error,
        );
        return;
      }

      if (currentUserId == _sellerUserId(item.seller)) {
        showAppSnackbar(
          context,
          message: tr('feed.cannot_follow_self'),
          type: SnackType.warning,
        );
        return;
      }

      final wasFollowing = item.seller.isFollowing;
      previousFollowing = wasFollowing;
      final targetFollowing = !wasFollowing;

      setState(() {
        _setFollowStateForSeller(item.seller, targetFollowing);
      });

      String? userToken;
      try {
        userToken = OneSignal.User.pushSubscription.id;
      } catch (e) {
        print('Error getting OneSignal token: $e');
      }

      final result = await DatabaseService.followUser(
        buyerId: currentUserId,
        userId: _sellerUserId(item.seller),
        userToken: userToken,
      );

      if (result['success'] == true) {
        final confirmedFollowing = result['action'] == 'followed';
        setState(() {
          _setFollowStateForSeller(item.seller, confirmedFollowing);
        });

        String message = tr('feed.updated_successfully');
        if (result['action'] == 'followed') {
          message = tr('feed.followed_successfully');
          ApiService.trackInteraction(currentUserId, item.id, 'follow');
        } else if (result['action'] == 'unfollowed') {
          message = tr('feed.unfollowed');
        }

        showAppSnackbar(context, message: message, type: SnackType.success);

        final user = await FlutterSecureStorage().read(key: 'user_name');
        OneSignalService.sendNotificationToUser(
          playerId: item.seller.token,
          title: "متابعة مشتري",
          message: "$message من قبل $user",
        );
      } else {
        setState(() {
          _setFollowStateForSeller(item.seller, wasFollowing);
        });

        showAppSnackbar(
          context,
          message: result['error'] ?? tr('feed.follow_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      print('Error following user: $e');

      if (previousFollowing != null) {
        setState(() {
          _setFollowStateForSeller(item.seller, previousFollowing!);
        });
      }

      showAppSnackbar(
        context,
        message: tr('feed.follow_error'),
        type: SnackType.error,
      );
    }
  }

  // Show item description with statistics
  void _showItemDescription() async {
    Navigator.pop(context); // Close more options bottom sheet

    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final isDark = _sheetIsDark(sheetContext);
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.35,
          maxChildSize: 0.6,
          builder: (context, scrollController) => Container(
            decoration: BoxDecoration(
              color: _sheetBackground(sheetContext),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: FutureBuilder<Map<String, dynamic>>(
              future: ApiService.getItemStats(item.id),
              builder: (context, snapshot) {
                final bottomInset =
                    MediaQuery.of(sheetContext).padding.bottom + 16;

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }

                if (snapshot.hasError ||
                    !snapshot.hasData ||
                    snapshot.data!['success'] != true) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        tr('feed.load_data_failed'),
                        style: TextStyle(
                          color: _sheetOnSurface(context),
                          fontSize: 16,
                        ),
                      ),
                    ),
                  );
                }

                final stats = snapshot.data!['data'];
                final description = (stats['description'] ?? '')
                    .toString()
                    .trim();
                final hasDescription = description.isNotEmpty;
                final createdAt = stats['created_at']?.toString() ?? '';
                final dateValue = createdAt.isNotEmpty
                    ? createdAt.split(' ').first
                    : '—';

                return ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(bottom: bottomInset),
                  children: [
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white30 : Colors.grey[400],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Text(
                            tr('feed.product_description'),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: _sheetOnSurface(context),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => Navigator.pop(sheetContext),
                            icon: Icon(
                              Iconsax.close_circle,
                              color: isDark ? Colors.white70 : Colors.grey[500],
                              size: 28,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                    Divider(
                      height: 24,
                      thickness: 0.5,
                      color: Theme.of(context).dividerColor,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      child: Text(
                        hasDescription
                            ? description
                            : tr('feed.no_description'),
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.6,
                          color: hasDescription
                              ? _sheetOnSurface(context)
                              : (isDark ? Colors.white54 : Colors.grey),
                          fontStyle: hasDescription
                              ? FontStyle.normal
                              : FontStyle.italic,
                        ),
                        textDirection: context.appTextDirection,
                        textAlign: TextAlign.right,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildDescriptionStatCard(
                              icon: Iconsax.heart,
                              label: tr('feed.likes'),
                              value: _formatCount(stats['likes'] ?? 0),
                              gradientColors: const [
                                Color(0xFFFF8A80),
                                Color(0xFFE57373),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDescriptionStatCard(
                              icon: Iconsax.eye,
                              label: tr('feed.views'),
                              value: _formatCount(stats['views'] ?? 0),
                              gradientColors: const [
                                Color(0xFF81D4FA),
                                Color(0xFF4FC3F7),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildDescriptionStatCard(
                              icon: Iconsax.calendar,
                              label: tr('feed.published_date'),
                              value: dateValue,
                              gradientColors: const [
                                Color(0xFFA5D6A7),
                                Color(0xFF66BB6A),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildDescriptionStatCard({
    required IconData icon,
    required String label,
    required String value,
    required List<Color> gradientColors,
  }) {
    return Container(
      height: 90,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 11,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    if (dateString.isEmpty) return tr('feed.not_specified');

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} ${tr('feed.day')}';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} ${tr('feed.hour')}';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} ${tr('feed.minute')}';
      } else {
        return tr('feed.now');
      }
    } catch (e) {
      return dateString;
    }
  }

  // Show report options
  void _showReportOptions() async {
    Navigator.pop(context); // Close more options bottom sheet

    _showReasonSelectionSheet(
      title: tr('feed.report_content'),
      subtitle: tr('feed.report_reason_subtitle'),
      confirmLabel: tr('feed.confirm_report'),
      accentColor: Colors.red,
      headerIcon: Iconsax.warning_2,
      reasons: _reasonOptions(const {
        'محتوى غير لائق': 'feed.reason_inappropriate_content',
        'محتوى مضلل': 'feed.reason_misleading_content',
        'انتهاك حقوق الطبع والنشر': 'feed.reason_copyright_violation',
        'محتوى عنيف': 'feed.reason_violent_content',
        'محتوى إباحي': 'feed.reason_explicit_content',
        'بريد عشوائي': 'feed.reason_spam',
        'محتوى مخالف للقوانين': 'feed.reason_illegal_content',
        'تحرش أو تنمر': 'feed.reason_harassment_or_bullying',
        'معلومات شخصية': 'feed.reason_personal_information',
        'محتوى مزيف': 'feed.reason_fake_content',
        'أخرى': 'feed.reason_other',
      }),
      onConfirm: _submitReport,
    );
  }

  /// أسباب البلاغ/الحظر تُخزَّن في السيرفر، فالقيمة تبقى ثابتة بالعربي دائماً
  /// ولا تتغير مع لغة المستخدم؛ المترجَم هو النص المعروض فقط. لولا ذلك
  /// لاختلفت البيانات المحفوظة بين مستخدم عربي ومستخدم إنجليزي.
  List<({String value, String label})> _reasonOptions(
    Map<String, String> valueToKey,
  ) {
    return valueToKey.entries
        .map((entry) => (value: entry.key, label: tr(entry.value)))
        .toList();
  }

  void _showReasonSelectionSheet({
    required String title,
    required String subtitle,
    required String confirmLabel,
    required Color accentColor,
    required IconData headerIcon,
    required List<({String value, String label})> reasons,
    required Future<void> Function(String reason) onConfirm,
  }) {
    String? selectedReason;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final isDark = _sheetIsDark(context);
            final maxHeight = MediaQuery.of(context).size.height * 0.75;
            final bottomInset = MediaQuery.of(context).padding.bottom;

            return Container(
              constraints: BoxConstraints(maxHeight: maxHeight),
              decoration: BoxDecoration(
                color: _sheetBackground(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white30 : Colors.grey[400],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(headerIcon, color: accentColor, size: 26),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _sheetOnSurface(context),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 15,
                      color: isDark ? Colors.white70 : Colors.grey[600],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: reasons.length,
                      separatorBuilder: (_, __) => Divider(
                        height: 1,
                        thickness: 1,
                        color: Theme.of(context).dividerColor,
                        indent: 20,
                        endIndent: 20,
                      ),
                      itemBuilder: (context, index) {
                        final reason = reasons[index];
                        final isSelected = selectedReason == reason.value;
                        return _buildReasonListItem(
                          label: reason.label,
                          accentColor: accentColor,
                          isSelected: isSelected,
                          onTap: () {
                            setSheetState(() => selectedReason = reason.value);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: selectedReason == null
                            ? null
                            : () async {
                                final reason = selectedReason!;
                                Navigator.pop(sheetContext);
                                await onConfirm(reason);
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: isDark
                              ? AppColors.darkElevated
                              : Colors.grey[300],
                          disabledForegroundColor: isDark
                              ? Colors.white54
                              : Colors.grey[500],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          confirmLabel,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildReasonListItem({
    required String label,
    required Color accentColor,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final isDark = _sheetIsDark(context);
    return Material(
      color: isSelected
          ? AppColors.primary.withValues(alpha: 0.08)
          : _sheetTileBackground(context),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkElevated
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Iconsax.info_circle,
                  size: 20,
                  color: accentColor.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  label,
                  textAlign: TextAlign.start,
                  textDirection: context.appTextDirection,
                  style: TextStyle(
                    fontSize: 16,
                    color: _sheetOnSurface(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Iconsax.tick_circle5,
                  color: AppColors.primary,
                  size: 22,
                )
              else
                const SizedBox(width: 22),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitReport(String reason) async {
    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    final currentUserId = await AuthService.getCurrentUserId();
    final currentUserName = await AuthService.getCurrentName();

    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    try {
      final result = await ApiService.addReport(
        itemId: item.id,
        userId: currentUserId,
        reason: reason,
      );

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: tr('feed.report_sent'),
          type: SnackType.success,
        );
        final request = await Dio().post(
          "${AppConfig.apiBaseUrl}/sql.php",
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List playerIds = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in playerIds) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "ابلاغ جديد",
            message: "لديكم إبلاغ جديد من المستخدم $currentUserName",
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? tr('feed.report_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: tr('feed.report_error'),
        type: SnackType.error,
      );
    }
  }

  // Show block user options
  void _showBlockUserOptions() async {
    Navigator.pop(context); // Close more options bottom sheet

    _showReasonSelectionSheet(
      title: tr('feed.block_user'),
      subtitle: tr('feed.block_reason_subtitle'),
      confirmLabel: tr('feed.confirm_block'),
      accentColor: Colors.orange,
      headerIcon: Iconsax.user_remove,
      reasons: _reasonOptions(const {
        'محتوى مسيء': 'feed.reason_abusive_content',
        'تحرش': 'feed.reason_harassment',
        'بريد عشوائي': 'feed.reason_spam',
        'محتوى مزعج': 'feed.reason_annoying_content',
        'انتهاك الخصوصية': 'feed.reason_privacy_violation',
        'محتوى مخالف': 'feed.reason_violating_content',
        'سلوك غير لائق': 'feed.reason_inappropriate_behavior',
        'أخرى': 'feed.reason_other',
      }),
      onConfirm: _submitBlockUser,
    );
  }

  Future<void> _submitBlockUser(String reason) async {
    if (_currentIndex >= _items.length) return;

    final item = _items[_currentIndex];
    final currentUserId = await AuthService.getCurrentUserId();

    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    try {
      // Use the same report system but with a different reason format
      final result = await ApiService.addReport(
        itemId: item.id,
        userId: currentUserId,
        reason: 'حظر المستخدم: $reason',
      );

      if (result['success'] == true) {
        showAppSnackbar(
          context,
          message: tr('feed.block_request_sent'),
          type: SnackType.success,
        );
        final request = await Dio().post(
          "${AppConfig.apiBaseUrl}/sql.php",
          data: FormData.fromMap({"action": "get_tokens"}),
        );
        List playerIds = request.data['player_ids'];
        List<String> setPlayers = [];
        for (var player_id in playerIds) {
          setPlayers.add(player_id['player_id'].toString());
          await OneSignalServiceWebSys.sendNotificationToMultipleUsers(
            playerIds: setPlayers,
            title: "حظر مستخدم جديد",
            message: "حظر المستخدم: $reason",
          );
        }
      } else {
        showAppSnackbar(
          context,
          message: result['error'] ?? tr('feed.block_request_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      showAppSnackbar(
        context,
        message: tr('feed.block_request_error'),
        type: SnackType.error,
      );
    }
  }

  void _handleLike(ItemModel item) async {
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    try {
      final user = await FlutterSecureStorage().read(key: 'user_name');
      setState(() {
        item.interactions.isLiked = !item.interactions.isLiked;
        if (item.interactions.isLiked) {
          item.interactions.likes++;
          OneSignalService.sendNotificationToUser(
            playerId: item.seller.token,
            title: "إعجاب على المنتج ${item.name}",
            message: "تم الإعجاب من قبل $user",
          );
        } else {
          item.interactions.likes--;
          OneSignalService.sendNotificationToUser(
            playerId: item.seller.token,
            title: "إعجاب على المنتج ${item.name}",
            message: "تم إلغاء الإعجاب من قبل $user",
          );
        }
      });

      _triggerHeartAnimation(item.interactions.isLiked);

      if (item.interactions.isLiked) {
        ApiService.trackInteraction(currentUserId, item.id, 'like');
      }

      // Send request to server
      final result = await ApiService.toggleLike(
        itemId: item.id,
        userId: currentUserId,
      );

      if (result['success'] != true) {
        // Revert changes if server request failed
        setState(() {
          item.interactions.isLiked = !item.interactions.isLiked;
          if (item.interactions.isLiked) {
            item.interactions.likes++;
          } else {
            item.interactions.likes--;
          }
        });

        showAppSnackbar(
          context,
          message: result['error'] ?? tr('feed.like_update_failed'),
          type: SnackType.error,
        );
      }
    } catch (e) {
      // Revert changes if error occurred
      setState(() {
        item.interactions.isLiked = !item.interactions.isLiked;
        if (item.interactions.isLiked) {
          item.interactions.likes++;
        } else {
          item.interactions.likes--;
        }
      });

      showAppSnackbar(
        context,
        message: tr('feed.like_update_error'),
        type: SnackType.error,
      );
    }
  }

  void _handleShare(ItemModel item) async {
    try {
      final shareImageUrl = _itemShareImageUrl(item);
      File? file;
      if (shareImageUrl != null) {
        final response = await http.get(Uri.parse(shareImageUrl));
        final bytes = response.bodyBytes;
        final tempDir = await getTemporaryDirectory();
        file = await File('${tempDir.path}/shared_image.png').create();
        await file.writeAsBytes(bytes);
      }

      final box = context.findRenderObject() as RenderBox?;
      String shareText =
          '''
  ${tr('feed.share_product_name')}:   ${item.name}

  💰 ${tr('feed.share_price')}: ${item.price} ${tr('feed.currency_qar')}

  📝 ${tr('feed.description')}: ${item.description}

  ${tr('feed.share_cta')}

  ''';
      final user = await FlutterSecureStorage().read(key: 'user_name');
      if (file != null) {
        await Share.shareXFiles(
          [XFile(file.path)],
          text: shareText,
          subject: '${tr('feed.share_subject')} - ${item.name}',
          sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
        ).then((_) {
          OneSignalService.sendNotificationToUser(
            playerId: item.seller.token,
            title: "مشاركة جديدة من $user",
            message: "لقد تمت مشاركة منتجك ${item.name} من قبل المستخدم $user",
          );
        });
      } else {
        await Share.share(
          shareText,
          subject: '${tr('feed.share_subject')} - ${item.name}',
        );
      }
      setState(() {
        item.interactions.shares++;
      });
      ApiService.trackInteraction(_currentUserId, item.id, 'share');
    } catch (e) {
      showAppSnackbar(
        context,
        message: tr('feed.share_error'),
        type: SnackType.error,
      );
    }
  }

  void _showCartBottomSheet(ItemModel item) async {
    bool isAdded = false;
    if (!_isLoggedIn) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    final currentUserId = await AuthService.getCurrentUserId();
    if (currentUserId == null) {
      showAppSnackbar(
        context,
        message: tr('common.login_required'),
        type: SnackType.error,
      );
      return;
    }

    ApiService.trackInteraction(currentUserId, item.id, 'cart');

    // ✅ جيب الكمية الحالية من السيرفر قبل ما تفتح الـ sheet
    try {
      final result = await ApiService.getCartQuantity(
        itemId: item.id,
        userId: currentUserId,
      );

      if (result['success'] == true) {
        final itemIndex = _items.indexWhere((i) => i.id == item.id);
        if (itemIndex != -1) {
          setState(() {
            _items[itemIndex].interactions.cartQuantity =
                result['quantity'] ?? 0;
          });
        }
      }
    } catch (e) {
      print('Error loading cart quantity: $e');
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          final isDark = _sheetIsDark(context);
          return Directionality(
            textDirection: context.appTextDirection,
            child: Container(
              decoration: BoxDecoration(
                color: _sheetBackground(context),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(25),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 50,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white30 : Colors.grey[400],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Text(
                    tr('feed.add_to_cart_title'),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 30),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isDark
                                  ? AppColors.darkBorder
                                  : Colors.grey.shade300,
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ItemThumbnailWidget.fromItem(
                            itemId: item.id,
                            itemIdx: item.idx,
                            storeId: item.storeid,
                            media: item.media,
                            fit: BoxFit.cover,
                            borderRadius: BorderRadius.circular(13),
                            placeholderColor: isDark
                                ? AppColors.darkElevated
                                : Colors.grey[300],
                          ),
                        ),

                        const SizedBox(width: 16),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.localizedName(
                                  LocalizationService.instance.currentLanguage,
                                ),
                                style: TextStyle(
                                  color: _sheetOnSurface(context),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${item.price} ${tr('feed.currency_qar')}',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),
                  _CartQuantityWidget(
                    itemId: item.id,
                    userId: currentUserId,
                    qtt: item.quantity,
                    onQuantityChanged: (newQuantity) {
                      final itemIndex = _items.indexWhere(
                        (i) => i.id == item.id,
                      );
                      if (itemIndex != -1) {
                        setState(() {
                          _items[itemIndex].interactions.cartQuantity =
                              newQuantity;
                        });
                      }
                      setModalState(() {});
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _gridScrollController.removeListener(_onGridScroll);
    _gridScrollController.dispose();
    _heartAnimController?.dispose();
    super.dispose();
  }
}

class _GridCartButton extends StatefulWidget {
  final int cartQuantity;
  final int stockQuantity;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onNotify;

  const _GridCartButton({
    required this.cartQuantity,
    required this.stockQuantity,
    required this.onAdd,
    required this.onRemove,
    required this.onNotify,
  });

  @override
  State<_GridCartButton> createState() => _GridCartButtonState();
}

class _GridCartButtonState extends State<_GridCartButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _bounceAnimation =
        TweenSequence<double>([
          TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25), weight: 40),
          TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0), weight: 60),
        ]).animate(
          CurvedAnimation(parent: _bounceController, curve: Curves.easeOut),
        );
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  bool get _isOutOfStock =>
      widget.cartQuantity == 0 && widget.stockQuantity == 0;

  bool get _showCounter => widget.cartQuantity > 0;

  Future<void> _handleAddTap() async {
    await _bounceController.forward(from: 0);
    widget.onAdd();
  }

  @override
  Widget build(BuildContext context) {
    if (_isOutOfStock) {
      return Material(
        color: Colors.grey.shade400,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: widget.onNotify,
          borderRadius: BorderRadius.circular(8),
          child: const SizedBox(
            width: 32,
            height: 32,
            child: Icon(Iconsax.notification, color: Colors.white, size: 18),
          ),
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      height: 32,
      width: _showCounter ? 100 : 32,
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, animation) {
          return ScaleTransition(
            scale: animation,
            alignment: Alignment.centerRight,
            child: child,
          );
        },
        child: _showCounter
            ? _buildCounter(key: const ValueKey('grid_cart_counter'))
            : _buildPlusButton(key: const ValueKey('grid_cart_plus')),
      ),
    );
  }

  Widget _buildPlusButton({required Key key}) {
    return KeyedSubtree(
      key: key,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _handleAddTap,
          borderRadius: BorderRadius.circular(8),
          child: ScaleTransition(
            scale: _bounceAnimation,
            child: const SizedBox(
              width: 32,
              height: 32,
              child: Icon(Icons.add, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCounter({required Key key}) {
    return KeyedSubtree(
      key: key,
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _counterIconButton(icon: Iconsax.minus, onTap: widget.onRemove),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, animation) {
                return FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: animation, child: child),
                );
              },
              child: Text(
                '${widget.cartQuantity}',
                key: ValueKey<int>(widget.cartQuantity),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            _counterIconButton(icon: Iconsax.add, onTap: widget.onAdd),
          ],
        ),
      ),
    );
  }

  Widget _counterIconButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: SizedBox(
          width: 28,
          height: 32,
          child: Icon(icon, color: Colors.white, size: 16),
        ),
      ),
    );
  }
}

// ✅ Widget السلة
class _CartQuantityWidget extends StatefulWidget {
  final String itemId;
  final String userId;
  final int qtt;
  final Function(int) onQuantityChanged;

  const _CartQuantityWidget({
    required this.itemId,
    required this.userId,
    required this.qtt,
    required this.onQuantityChanged,
  });

  @override
  State<_CartQuantityWidget> createState() => _CartQuantityWidgetState();
}

class _CartQuantityWidgetState extends State<_CartQuantityWidget> {
  int _currentQuantity = 0;
  bool _isLoading = true;
  bool _isUpdating = false;
  bool isAdded = false;
  @override
  void initState() {
    super.initState();
    _loadQuantity();
  }

  Future<void> _loadQuantity() async {
    try {
      final result = await ApiService.getCartQuantity(
        itemId: widget.itemId,
        userId: widget.userId,
      );

      if (mounted) {
        setState(() {
          if (result['success'] == true) {
            _currentQuantity = result['quantity'] ?? 0;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading quantity: $e');
      if (mounted) {
        setState(() {
          _currentQuantity = 0;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateQuantity(bool increase) async {
    if (_isUpdating) return;

    // ✅ شيك على الكمية قبل ما نبعت للسيرفر
    if (increase && _currentQuantity >= widget.qtt) {
      showAppSnackbar(
        context,
        message: tr('feed.available_quantity_only', {'n': widget.qtt}),
        type: SnackType.warning,
      );
      return;
    }

    if (!increase && _currentQuantity <= 0) {
      print('❌ Cannot decrease: quantity is already 0');
      return;
    }

    print('🔄 Updating quantity: ${increase ? "increase" : "decrease"}');

    setState(() {
      _isUpdating = true;
    });

    try {
      Map<String, dynamic> result;

      if (increase) {
        result = await ApiService.addToCart(
          itemId: widget.itemId,
          userId: widget.userId,
          quantity: 1,
        );
      } else {
        print('📤 Calling removeFromCart API'); // ← Debug
        result = await ApiService.removeFromCart(
          itemId: widget.itemId,
          userId: widget.userId,
        );
        print('📥 Remove API response: $result'); // ← Debug
      }

      if (result['success'] == true) {
        print(
          '✅ API Success! New quantity from server: ${result['quantity']}',
        ); // ← Debug

        if (mounted) {
          setState(() {
            // ✅ استخدم الكمية اللي جاية من السيرفر
            if (result['quantity'] != null) {
              _currentQuantity = result['quantity'];
              print('✅ Updated _currentQuantity to: $_currentQuantity');
              if (_currentQuantity == 0) {
                setState(() {
                  isAdded = false;
                });
              }
            } else {
              // Fallback
              if (increase) {
                _currentQuantity++;
              } else {
                if (_currentQuantity > 0) _currentQuantity--;
              }
            }
            _isUpdating = false;
          });
          widget.onQuantityChanged(_currentQuantity);
        }
      } else {
        print('❌ API Failed: ${result['error']}'); // ← Debug

        // ✅ لو السيرفر رفض بسبب الكمية
        if (mounted) {
          setState(() {
            _isUpdating = false;
          });

          String errorMessage = result['error'] ?? tr('common.error');

          // ✅ لو في معلومات عن الكمية المتاحة
          if (result['available_quantity'] != null) {
            errorMessage = tr('feed.available_quantity_only', {
              'n': result['available_quantity'],
            });
          }

          showAppSnackbar(
            context,
            message: errorMessage,
            type: SnackType.error,
          );
        }
      }
    } catch (e) {
      print('💥 Exception occurred: $e'); // ← Debug

      if (mounted) {
        setState(() {
          _isUpdating = false;
        });

        showAppSnackbar(
          context,
          message: tr('common.connection_error'),
          type: SnackType.error,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    // ✅ متغير يحدد إذا وصلنا للحد الأقصى
    final bool isMaxQuantity = _currentQuantity >= widget.qtt;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final onSurface = Theme.of(context).colorScheme.onSurface;

    return Column(
      children: [
        const SizedBox(height: 20),
        Directionality(
          textDirection: TextDirection.ltr,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // زر النقصان
              GestureDetector(
                onTap: _isUpdating || _currentQuantity <= 0
                    ? null
                    : () => _updateQuantity(false),
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isUpdating
                        ? Colors.grey.withOpacity(0.3)
                        : _currentQuantity > 0
                        ? Colors.red.withOpacity(0.8)
                        : Colors.grey.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: _isUpdating
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : const Icon(
                          Iconsax.minus,
                          color: Colors.white,
                          size: 24,
                        ),
                ),
              ),

              const SizedBox(width: 30),

              // عرض الكمية
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.darkSurface
                      : Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade300,
                    width: 2,
                  ),
                ),
                child: Text(
                  _currentQuantity.toString(),
                  style: TextStyle(
                    color: onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              const SizedBox(width: 30),

              // زر الزيادة
              GestureDetector(
                onTap: _isUpdating || isMaxQuantity
                    ? null
                    : () {
                        _updateQuantity(true);
                        setState(() {
                          isAdded = true;
                        });
                      },
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: _isUpdating
                        ? Colors.grey.withOpacity(0.3)
                        : isMaxQuantity
                        ? Colors.grey.withOpacity(
                            0.3,
                          ) // ✅ disable لو وصل للحد الأقصى
                        : AppColors.primary,
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: _isUpdating
                      ? const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : Icon(
                          Iconsax.add,
                          color: isMaxQuantity
                              ? Colors.white.withOpacity(0.5)
                              : Colors.white,
                          size: 24,
                        ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),
        ElevatedButton(
          onPressed: () => isAdded
              ? Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ShoppingCartScreen(userId: widget.userId),
                  ),
                )
              : Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(25),
            ),
          ),
          child: Text(
            isAdded ? tr('feed.go_to_cart') : tr('feed.done'),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
