import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';

class InvoiceWebView extends StatefulWidget {
  final String url;
  const InvoiceWebView({super.key, required this.url});

  /// GlobalFarm invoice URL — always includes [AppConfig.storeId].
  static String buildUrl({
    required String orderId,
    String? view,
    String? userId,
  }) {
    final params = <String, String>{
      'order_id': orderId,
      'store_id': AppConfig.storeId,
      'k': DateTime.now().millisecondsSinceEpoch.toString(),
    };
    if (view != null && view.isNotEmpty) params['view'] = view;
    if (userId != null && userId.isNotEmpty) params['user_id'] = userId;
    return Uri.parse('${AppConfig.apiBaseUrl}/invoice.php')
        .replace(queryParameters: params)
        .toString();
  }

  @override
  State<InvoiceWebView> createState() => _InvoiceWebViewState();
}

class _InvoiceWebViewState extends State<InvoiceWebView> {
  late final WebViewController _controller;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(NavigationDelegate(
        onPageFinished: (_) {
          _controller.runJavaScript('''
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) {
              meta = document.createElement('meta');
              meta.name = 'viewport';
              document.head.appendChild(meta);
            }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=5.0, user-scalable=yes';
          ''');
          setState(() => _isLoading = false);
        },
      ))
      ..loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفاتورة'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 12),
            child: Material(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () {
                  setState(() => _isLoading = true);
                  _controller.reload();
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(Iconsax.refresh, size: 18, color: Colors.white),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          WebViewWidget(controller: _controller),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
        ],
      ),
    );
  }
}
