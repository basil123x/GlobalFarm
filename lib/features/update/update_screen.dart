import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

class ForceUpdateScreen extends StatefulWidget {
  final String message;
  final String storeUrl;

  const ForceUpdateScreen({
    super.key,
    required this.message,
    required this.storeUrl,
  });

  @override
  State<ForceUpdateScreen> createState() => _ForceUpdateScreenState();
}

class _ForceUpdateScreenState extends State<ForceUpdateScreen> {
  void _launchStore() async {
    if (await canLaunchUrl(Uri.parse(widget.storeUrl))) {
      await launchUrl(
        Uri.parse(widget.storeUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    print(widget.message);
    print(widget.storeUrl);
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.refresh_circle, size: 100, color: Colors.white),
            SizedBox(height: 20),
            Text(
              "تحديث جديد!",
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Text(
              widget.message,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            Container(
              margin: EdgeInsets.symmetric(horizontal: 10),
              child: GestureDetector(
                onTap: () {
                  _launchStore();
                },
                child: Container(
                  alignment: Alignment.center,
                  width: double.maxFinite,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: context.appSurface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    "تحديث الأن",
                    style: TextStyle(
                      color: Colors.black,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
