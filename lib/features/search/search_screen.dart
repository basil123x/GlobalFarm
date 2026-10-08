import 'dart:async';

import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:shimmer/shimmer.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/widgets/item_thumbnail_widget.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/product/product_detail_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  Timer? _debounce;
  List<dynamic> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _onSearchChanged() {
    setState(() {});

    _debounce?.cancel();
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _isLoading = false;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 500), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isLoading = true;
      _hasSearched = true;
    });

    try {
      final response = await ApiService.searchItems(query);

      if (!mounted) return;

      if (response['success'] == true) {
        setState(() {
          _searchResults = response['data'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() {
          _searchResults = [];
          _isLoading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searchResults = [];
        _isLoading = false;
      });
    }
  }

  void _navigateToItem(dynamic item) {
    final map = item is Map<String, dynamic>
        ? item
        : Map<String, dynamic>.from(item as Map);

    final seller = map['seller'];
    final sellerMap = seller is Map ? Map<String, dynamic>.from(seller) : null;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          item: {
            'id': map['id']?.toString() ?? '',
            'idx': map['idx']?.toString() ?? '',
            'storeid':
                map['storeid']?.toString() ??
                map['store_id']?.toString() ??
                AppConfig.storeId,
            'name': map['name']?.toString() ?? '',
            'eng': map['eng']?.toString() ?? '',
            'price': map['price']?.toString() ?? '0',
            'qtt': map['qtt'] ?? map['quantity'] ?? 0,
            'description': map['description']?.toString() ?? '',
            'description_arb': map['description_arb']?.toString() ?? '',
            'seller_name':
                sellerMap?['name']?.toString() ?? map['seller_name']?.toString() ?? '',
            'seller_id':
                sellerMap?['id']?.toString() ??
                sellerMap?['uid']?.toString() ??
                map['seller_id']?.toString() ??
                map['uid']?.toString() ??
                '',
            'media': map['media'],
            'thumbnail': map['thumbnail'],
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lang = LocalizationService.instance.currentLanguage;
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: context.appBackground,
        appBar: AppBar(
          backgroundColor: context.appSurface,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(Iconsax.arrow_right_3, color: context.appTextPrimary),
            onPressed: () => Navigator.pop(context),
          ),
          title: Container(
            height: 46,
            decoration: BoxDecoration(
              color: context.appSurfaceVariant,
              borderRadius: BorderRadius.circular(30),
            ),
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              autofocus: true,
              textAlign: TextAlign.right,
              textInputAction: TextInputAction.search,
              onSubmitted: (value) {
                _debounce?.cancel();
                if (value.trim().isNotEmpty) {
                  _performSearch(value.trim());
                }
              },
              style: TextStyle(fontSize: 15, color: context.appTextPrimary),
              decoration: InputDecoration(
                hintText: lang == 'ar'
                    ? 'ابحث عن المنتجات...'
                    : 'Search for products...',
                hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                prefixIcon: Icon(
                  Iconsax.search_normal_1,
                  color: Colors.grey[500],
                  size: 22,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.requestFocus();
                        },
                        icon: Icon(
                          Iconsax.close_circle,
                          color: Colors.grey[500],
                          size: 22,
                        ),
                      )
                    : null,
              ),
            ),
          ),
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (!_hasSearched) {
      return _buildInitialEmptyState();
    }
    if (_isLoading) {
      return _buildLoadingState();
    }
    if (_searchResults.isEmpty) {
      return _buildNoResultsState();
    }
    return _buildResultsList();
  }

  Widget _buildInitialEmptyState() {
    final lang = LocalizationService.instance.currentLanguage;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.search_normal,
              size: 80,
              color: context.appTextSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              lang == 'ar' ? 'ابحث عن ما تريد' : 'Search for what you want',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'ar'
                  ? 'اكتب اسم المنتج في مربع البحث'
                  : 'Type product name in search box',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoResultsState() {
    final lang = LocalizationService.instance.currentLanguage;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.emoji_sad, size: 80, color: context.appTextSecondary),
            const SizedBox(height: 24),
            Text(
              lang == 'ar' ? 'لا توجد نتائج' : 'No results found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: context.appTextSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              lang == 'ar'
                  ? 'جرب كلمة بحث مختلفة'
                  : 'Try a different search term',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: context.appTextSecondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _buildShimmerCard(),
      ),
    );
  }

  Widget _buildShimmerCard() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1E1E2E) : Colors.grey[300]!,
      highlightColor: isDark ? const Color(0xFF2A2A3E) : Colors.grey[100]!,
      child: Container(
        height: 94,
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkElevated : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: isDark ? AppColors.darkElevated : Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 12,
                    width: 120,
                    color: isDark ? AppColors.darkElevated : Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 14,
                    width: 80,
                    color: isDark ? AppColors.darkElevated : Colors.grey[300],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildSearchResultItem(_searchResults[index]),
        );
      },
    );
  }

  Widget _buildSearchResultItem(dynamic item) {
    final lang = LocalizationService.instance.currentLanguage;
    final itemId = item['id']?.toString() ?? '';
    final storeId =
        item['storeid']?.toString() ??
        item['store_id']?.toString() ??
        AppConfig.storeId;
    final itemIdx = item['idx']?.toString();
    final sellerName = item['seller']?['name']?.toString() ?? 'بائع';
    final mediaValue = item['media']?.toString() ?? '';
    final thumbnailUrl = item['thumbnail']?.toString();

    return InkWell(
      onTap: itemId.isEmpty ? null : () => _navigateToItem(item),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    lang == 'ar'
                        ? (item['name']?.toString() ?? '')
                        : ((item['eng']?.toString().isNotEmpty == true)
                              ? item['eng'].toString()
                              : item['name']?.toString() ?? ''),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: context.appTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Iconsax.shop, size: 14, color: Colors.grey[500]),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          sellerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appTextSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${item['price']} ${lang == 'ar' ? 'ريال' : 'QAR'}',
                    style: const TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ItemThumbnailWidget(
              itemId: itemId,
              itemIdx: itemIdx,
              storeId: storeId,
              mediaValue: mediaValue.isNotEmpty ? mediaValue : null,
              thumbnailUrl: thumbnailUrl,
              width: 70,
              height: 70,
              fit: BoxFit.cover,
              borderRadius: BorderRadius.circular(12),
              placeholderColor: context.appSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Icon(Iconsax.arrow_left_2, color: Colors.grey[400], size: 22),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }
}
