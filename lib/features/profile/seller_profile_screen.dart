import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/app_responsive.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/core/widgets/item_thumbnail_widget.dart';
import 'package:GlobalFarm/core/widgets/smart_avatar_widget.dart';
import 'package:GlobalFarm/features/product/product_detail_screen.dart';

/// Seller storefront — products with رائجة / أحدث / أقدم filters.
class SellerProfileScreen extends StatefulWidget {
  final String userId;

  const SellerProfileScreen({super.key, required this.userId});

  @override
  State<SellerProfileScreen> createState() => _SellerProfileScreenState();
}

class _SellerProfileScreenState extends State<SellerProfileScreen> {
  UserProfileModel? _profile;
  List<Map<String, dynamic>> _items = [];
  bool _isLoading = true;
  bool _isLoadingItems = true;
  bool _isLoadingMore = false;
  bool _hasError = false;
  bool _hasErrorItems = false;
  bool _hasMore = true;
  int _currentOffset = 0;
  final int _pageSize = 20;
  String _selectedFilter = 'الرائجة';
  final List<String> _filters = ['الرائجة', 'الأحدث', 'الأقدم'];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      if (!_isLoadingMore && _hasMore) _loadMoreItems();
    }
  }

  String _getSortParam() {
    switch (_selectedFilter) {
      case 'الأحدث':
        return 'newest';
      case 'الأقدم':
        return 'oldest';
      case 'الرائجة':
      default:
        return 'views';
    }
  }

  String _filterLabel(String filter) {
    switch (filter) {
      case 'الأحدث':
        return tr('profile.newest');
      case 'الأقدم':
        return tr('profile.oldest');
      case 'الرائجة':
      default:
        return tr('profile.trending');
    }
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });
    try {
      final response = await ApiService.getUserProfile(widget.userId);
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _profile = UserProfileModel.fromJson(response['data']);
          _isLoading = false;
        });
        await _loadItems();
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

  Future<void> _loadItems() async {
    setState(() {
      _isLoadingItems = true;
      _hasErrorItems = false;
      _currentOffset = 0;
      _items = [];
      _hasMore = true;
    });
    try {
      final uid = _profile?.uid.isNotEmpty == true
          ? _profile!.uid
          : widget.userId;
      final response = await ApiService.getUserProfileItems(
        uid,
        limit: _pageSize,
        offset: 0,
        sort: _getSortParam(),
      );
      if (!mounted) return;
      if (response['success'] == true) {
        setState(() {
          _items = List<Map<String, dynamic>>.from(response['data'] ?? []);
          _hasMore = response['hasMore'] == true;
          _currentOffset = _pageSize;
          _isLoadingItems = false;
        });
      } else {
        setState(() {
          _hasErrorItems = true;
          _isLoadingItems = false;
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasErrorItems = true;
        _isLoadingItems = false;
      });
    }
  }

  Future<void> _loadMoreItems() async {
    if (_isLoadingMore || !_hasMore) return;
    setState(() => _isLoadingMore = true);
    try {
      final uid = _profile?.uid.isNotEmpty == true
          ? _profile!.uid
          : widget.userId;
      final response = await ApiService.getUserProfileItems(
        uid,
        limit: _pageSize,
        offset: _currentOffset,
        sort: _getSortParam(),
      );
      if (!mounted) return;
      if (response['success'] == true) {
        final newItems =
            List<Map<String, dynamic>>.from(response['data'] ?? []);
        setState(() {
          _items.addAll(newItems);
          _hasMore = response['hasMore'] == true;
          _currentOffset += _pageSize;
          _isLoadingMore = false;
        });
      } else {
        setState(() => _isLoadingMore = false);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingMore = false);
    }
  }

  void _onFilterChanged(String filter) {
    if (_selectedFilter == filter) return;
    setState(() => _selectedFilter = filter);
    _loadItems();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _hasError || _profile == null
              ? _buildErrorState()
              : CustomScrollView(
                  controller: _scrollController,
                  slivers: [
                    SliverAppBar(
                      expandedHeight: 220,
                      pinned: true,
                      backgroundColor: AppColors.primary,
                      leading: IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Iconsax.arrow_right_3,
                          color: Colors.white,
                        ),
                      ),
                      title: Text(
                        tr('profile.seller_profile'),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      centerTitle: true,
                      flexibleSpace: FlexibleSpaceBar(
                        background: Container(
                          color: AppColors.primary,
                          padding: EdgeInsets.only(
                            top: MediaQuery.of(context).padding.top + 48,
                          ),
                          child: Column(
                            children: [
                              SmartAvatarWidget(
                                userId: widget.userId,
                                name: _profile!.name,
                                size: 88,
                                fallbackUrl: _profile!.avatar,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                _profile!.name,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${_profile!.itemsCount} ${tr('profile.products')}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SliverToBoxAdapter(child: _buildFilterButtons()),
                    SliverToBoxAdapter(child: _buildItemsSection()),
                  ],
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Iconsax.warning_2, size: 56, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            tr('profile.seller_load_error'),
            style: TextStyle(color: context.appTextSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _loadProfile();
              _loadItems();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(tr('profile.retry')),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButtons() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: _filters.map((filter) {
          final selected = _selectedFilter == filter;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Material(
                color: selected ? AppColors.primary : context.appSurface,
                borderRadius: BorderRadius.circular(22),
                child: InkWell(
                  onTap: () => _onFilterChanged(filter),
                  borderRadius: BorderRadius.circular(22),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : context.appBorder,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _filterLabel(filter),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: selected
                            ? Colors.white
                            : context.appTextPrimary,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Column(
        children: [
          if (_isLoadingItems)
            _buildSkeletonGrid()
          else if (_hasErrorItems)
            _buildItemsError()
          else if (_items.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Iconsax.box_1, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    tr('profile.no_products'),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.appTextPrimary,
                    ),
                  ),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _items.length,
              gridDelegate: AppResponsive.productGridDelegate(
                context,
                childAspectRatio: AppResponsive.isTablet(context) ? 0.8 : 0.78,
              ),
              itemBuilder: (context, index) {
                final item = _items[index];
                return _SellerItemCard(
                  item: item,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(item: item),
                      ),
                    );
                  },
                );
              },
            ),
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildSkeletonGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 6,
      gridDelegate: AppResponsive.productGridDelegate(
        context,
        childAspectRatio: AppResponsive.isTablet(context) ? 0.8 : 0.78,
      ),
      itemBuilder: (_, __) => Shimmer.fromColors(
        baseColor: context.isDarkMode
            ? AppColors.darkElevated
            : Colors.grey[300]!,
        highlightColor: context.isDarkMode
            ? AppColors.darkSurface
            : Colors.grey[100]!,
        child: Container(
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  Widget _buildItemsError() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Iconsax.warning_2, color: Colors.red[300], size: 40),
          const SizedBox(height: 10),
          Text(
            tr('profile.load_error'),
            style: TextStyle(color: context.appTextSecondary),
          ),
          TextButton(
            onPressed: _loadItems,
            child: Text(tr('profile.retry')),
          ),
        ],
      ),
    );
  }
}

class _SellerItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  const _SellerItemCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final name = item['name']?.toString() ??
        item['name_ar']?.toString() ??
        '—';
    final price = item['price']?.toString() ?? '0';
    final views = item['views']?.toString() ?? '0';
    final id = item['id']?.toString() ?? '';
    final idx = item['idx']?.toString() ?? '';
    final storeId = item['storeid']?.toString() ?? '2';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: ColoredBox(
                color: context.appSurfaceVariant,
                child: ItemThumbnailWidget.fromItem(
                  itemId: id,
                  itemIdx: idx,
                  storeId: storeId,
                  media: const [],
                  width: double.infinity,
                  height: double.infinity,
                  fit: BoxFit.contain,
                  placeholderColor: context.appSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$price ${tr('profile.currency')}',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Icon(
                          Iconsax.eye,
                          size: 12,
                          color: context.appTextSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          views,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
