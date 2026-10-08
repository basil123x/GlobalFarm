import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/services/api_service.dart';
import 'package:GlobalFarm/core/services/auth_service.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/core/utils/snackbar_helper.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';
import 'package:GlobalFarm/features/product/product_detail_screen.dart';

/// Admin-only tab: look up a product by barcode (scan or type) → product details.
class BarcodeLookupScreen extends StatefulWidget {
  const BarcodeLookupScreen({super.key});

  @override
  State<BarcodeLookupScreen> createState() => _BarcodeLookupScreenState();
}

class _BarcodeLookupScreenState extends State<BarcodeLookupScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Map<String, dynamic> _detailMap(ItemModel item) {
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

  Future<void> _lookup(String raw) async {
    final code = raw.trim();
    if (code.isEmpty) {
      showAppSnackbar(
        context,
        message: _ar ? 'أدخل أو امسح الباركود' : 'Enter or scan a barcode',
        type: SnackType.warning,
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final userId = await AuthService.getCurrentUserId();
      final item = await ApiService.fetchItemByBarcode(
        code,
        userId: userId,
      );
      if (!mounted) return;

      if (item == null) {
        showAppSnackbar(
          context,
          message: _ar
              ? 'لم يتم العثور على منتج بهذا الباركود'
              : 'No product found for this barcode',
          type: SnackType.error,
        );
        return;
      }

      _controller.text = code;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProductDetailScreen(item: _detailMap(item)),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      showAppSnackbar(
        context,
        message: _ar ? 'حدث خطأ أثناء البحث' : 'Lookup failed',
        type: SnackType.error,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _openScanner() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const _BarcodeScannerSheet(),
    );
    if (result == null || result.isEmpty || !mounted) return;
    await _lookup(result);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.appBackground,
      appBar: AppBar(
        backgroundColor: context.appSurface,
        elevation: 0,
        centerTitle: true,
        title: Text(
          _ar ? 'باركود' : 'Barcode',
          style: TextStyle(
            color: context.appTextPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            children: [
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Iconsax.scan_barcode,
                  size: 44,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 22),
              Text(
                _ar ? 'البحث بالباركود' : 'Barcode lookup',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: context.appTextPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _ar
                    ? 'امسح أو أدخل باركود المنتج لفتح تفاصيله'
                    : 'Scan or type a product barcode to open its details',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: context.appTextSecondary,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _controller,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.search,
                onSubmitted: _lookup,
                style: TextStyle(
                  color: context.appTextPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
                decoration: InputDecoration(
                  hintText: _ar ? 'أدخل الباركود هنا' : 'Enter barcode here',
                  hintStyle: TextStyle(color: context.appTextSecondary),
                  prefixIcon: Icon(
                    Iconsax.barcode,
                    color: context.appTextSecondary,
                  ),
                  filled: true,
                  fillColor: context.appSurface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: context.appBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: AppColors.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isLoading
                      ? null
                      : () => _lookup(_controller.text),
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Iconsax.search_normal_1, size: 20),
                  label: Text(
                    _ar ? 'بحث' : 'Search',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _openScanner,
                  icon: const Icon(Iconsax.scan_barcode, size: 22),
                  label: Text(
                    _ar ? 'مسح الباركود' : 'Scan barcode',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary, width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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

class _BarcodeScannerSheet extends StatefulWidget {
  const _BarcodeScannerSheet();

  @override
  State<_BarcodeScannerSheet> createState() => _BarcodeScannerSheetState();
}

class _BarcodeScannerSheetState extends State<_BarcodeScannerSheet> {
  bool _handled = false;

  bool get _ar => LocalizationService.instance.currentLanguage == 'ar';

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    final value = capture.barcodes.firstOrNull?.rawValue;
    if (value == null || value.isEmpty) return;
    _handled = true;
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _ar ? 'مسح الباركود' : 'Scan barcode',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    _ar ? 'إلغاء' : 'Cancel',
                    style: const TextStyle(color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              child: MobileScanner(onDetect: _onDetect),
            ),
          ),
        ],
      ),
    );
  }
}
