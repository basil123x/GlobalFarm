import 'package:flutter/material.dart';

/// iPad-friendly breakpoints without changing phone layouts.
/// Phone: shortestSide < 600. Tablet/iPad: >= 600.
class AppResponsive {
  AppResponsive._();

  static const double tabletBreakpoint = 600;
  static const double largeTabletBreakpoint = 900;
  static const double desktopLikeBreakpoint = 1100;

  static Size sizeOf(BuildContext context) => MediaQuery.sizeOf(context);

  static bool isTablet(BuildContext context) =>
      sizeOf(context).shortestSide >= tabletBreakpoint;

  static bool isLargeTablet(BuildContext context) =>
      sizeOf(context).width >= largeTabletBreakpoint;

  /// Product grids: 2 phone / 3 iPad / 4 large iPad / 5 very wide.
  static int productGridColumns(BuildContext context) {
    final width = sizeOf(context).width;
    if (width >= desktopLikeBreakpoint) return 5;
    if (width >= largeTabletBreakpoint) return 4;
    if (width >= tabletBreakpoint) return 3;
    return 2;
  }

  static double productAspectRatio(BuildContext context) {
    return isTablet(context) ? 0.72 : 0.68;
  }

  static double productGridSpacing(BuildContext context) {
    return isTablet(context) ? 16 : 12;
  }

  static EdgeInsets productGridPadding(BuildContext context) {
    if (isTablet(context)) {
      return const EdgeInsets.fromLTRB(20, 12, 20, 28);
    }
    return const EdgeInsets.fromLTRB(14, 8, 14, 20);
  }

  static SliverGridDelegate productGridDelegate(
    BuildContext context, {
    double? childAspectRatio,
  }) {
    final spacing = productGridSpacing(context);
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: productGridColumns(context),
      crossAxisSpacing: spacing,
      mainAxisSpacing: isTablet(context) ? 16 : 14,
      childAspectRatio: childAspectRatio ?? productAspectRatio(context),
    );
  }

  static double homeBannerHeight(BuildContext context) {
    return isTablet(context) ? 200 : 148;
  }

  /// Keeps forms readable on iPad; no effect on iPhone widths.
  static double formMaxWidth(BuildContext context) {
    return isTablet(context) ? 560 : double.infinity;
  }

  static EdgeInsets pageHorizontalPadding(BuildContext context) {
    return EdgeInsets.symmetric(horizontal: isTablet(context) ? 24 : 14);
  }

  static double navBarHeight(BuildContext context) {
    return isTablet(context) ? 76 : 68;
  }
}
