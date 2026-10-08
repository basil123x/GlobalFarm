import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/core/widgets/animated_cart_button.dart';
import 'package:GlobalFarm/core/widgets/item_thumbnail_widget.dart';

/// Shared product card used on Home + Categories grids.
class ProductGridCard extends StatelessWidget {
  final ItemModel item;
  final int quantity;
  final bool isOwn;
  final bool isAdmin;
  final bool isArabic;
  final VoidCallback onTap;
  final VoidCallback onLike;
  final VoidCallback onAddToCart;
  final VoidCallback onRemoveFromCart;

  const ProductGridCard({
    super.key,
    required this.item,
    required this.quantity,
    required this.isOwn,
    this.isAdmin = false,
    required this.isArabic,
    required this.onTap,
    required this.onLike,
    required this.onAddToCart,
    required this.onRemoveFromCart,
  });

  @override
  Widget build(BuildContext context) {
    final liked = item.interactions.isLiked;
    final name = item.localizedName(
      LocalizationService.instance.currentLanguage,
    );
    final hideCart = isOwn || isAdmin;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: context.isDarkMode ? 0.35 : 0.07,
              ),
              blurRadius: context.isDarkMode ? 10 : 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 58,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    color: context.appSurfaceVariant,
                    child: ItemThumbnailWidget.fromItem(
                      itemId: item.id,
                      itemIdx: item.idx,
                      storeId: item.storeid,
                      media: item.media,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.contain,
                      placeholderColor: context.appSurfaceVariant,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    height: 48,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black.withValues(alpha: 0.06),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: isArabic ? null : 10,
                    right: isArabic ? 10 : null,
                    child: _CircleAction(
                      onTap: onLike,
                      child: Icon(
                        liked ? Iconsax.heart5 : Iconsax.heart,
                        size: 16,
                        color: liked
                            ? const Color(0xFFE53935)
                            : context.appTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 42,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                        height: 1.3,
                        color: context.appTextPrimary,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isArabic ? 'السعر' : 'Price',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: context.appTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: item.price,
                                      style: const TextStyle(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                      ),
                                    ),
                                    TextSpan(
                                      text: isArabic ? ' ر.ق' : ' QAR',
                                      style: TextStyle(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.75),
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!hideCart)
                          AnimatedCartButton(
                            quantity: quantity,
                            stockQuantity: item.quantity,
                            onAdd: onAddToCart,
                            onRemove: onRemoveFromCart,
                          )
                        else if (isAdmin)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  isArabic ? 'المخزون' : 'Stock',
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: context.appTextSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  '${item.quantity}',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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

class _CircleAction extends StatelessWidget {
  final Widget child;
  final VoidCallback onTap;

  const _CircleAction({required this.child, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appSurface,
      elevation: context.isDarkMode ? 0 : 2,
      shadowColor: Colors.black26,
      shape: CircleBorder(
        side: BorderSide(color: context.appBorder),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Center(child: child),
        ),
      ),
    );
  }
}
