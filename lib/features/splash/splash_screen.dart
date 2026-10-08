import 'dart:io';

import 'package:GlobalFarm/features/update/update_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/constants/app_colors.dart';
import 'package:GlobalFarm/core/constants/app_constants.dart';
import 'package:GlobalFarm/core/constants/app_strings.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';
import 'package:GlobalFarm/features/shell/main_shell.dart';
import 'package:GlobalFarm/features/onboarding/onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _logoController;
  late AnimationController _textController;
  late AnimationController _sloganController;
  late Animation<double> _logoAnimation;
  late Animation<double> _textAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _sloganAnimation;

  String _appVersion = '';
  int? _patchNumber;

  Future<void> _loadVersionInfo() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final updater = ShorebirdUpdater();
    final patch = await updater.readCurrentPatch();
    if (mounted) {
      setState(() {
        _appVersion = packageInfo.version;
        _patchNumber = patch?.number;
      });
    }
  }

  Future<void> checkForForceUpdate() async {
    try {
      final dio = Dio();
      String platform = "";
      if (Platform.isIOS) {
        setState(() {
          platform = "IOS";
        });
      } else {
        setState(() {
          platform = "Android";
        });
      }

      print("platform: $platform");

      final response = await dio.get(
        '${AppConfig.apiBaseUrl}/get_update_info.php?platform=$platform&store_id=${AppConfig.storeId}&k=${DateTime.now().millisecondsSinceEpoch}',
      );

      if (response.statusCode == 200) {
        final data = response.data;
        final latestVersion = data['latest_version'];
        final forceUpdate = data['force_update'].toString() == "1";
        final message = data['message'];
        final storeUrl = data['store_link'];

        final packageInfo = await PackageInfo.fromPlatform();
        final currentVersion = packageInfo.version;

        if (forceUpdate && currentVersion != latestVersion) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) {
                return ForceUpdateScreen(message: message, storeUrl: storeUrl);
              },
            ),
          );
        }
      }
    } catch (e) {
      print("Error while checking for update: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    checkForForceUpdate();
    _loadVersionInfo();
    _initializeAnimations();
    _navigateToHome();
  }

  void _initializeAnimations() {
    // Logo Animation Controller
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    // Text Animation Controller
    _textController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    // Slogan Animation Controller
    _sloganController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Logo Scale Animation
    _logoAnimation = Tween<double>(begin: 0.0, end: 1).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.elasticOut),
    );

    // Text Fade Animation
    _textAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeInOut),
    );

    // Slide Animation
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 1), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _textController, curve: Curves.easeOutCubic),
        );

    // Slogan Fade Animation
    _sloganAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _sloganController, curve: Curves.easeIn));

    // Start animations
    _logoController.forward();
    Future.delayed(const Duration(milliseconds: 500), () {
      _textController.forward();
    });
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _sloganController.forward();
    });
  }

  void _navigateToHome() {
    Future.delayed(AppConstants.splashDuration, () async {
      if (!mounted) return;

      final prefs = await SharedPreferences.getInstance();
      final onboardingDone = prefs.getBool('onboarding_done') ?? false;
      if (!onboardingDone) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const OnboardingScreen()),
        );
        return;
      }

      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const MainShell()),
      );
    });
  }

  @override
  void dispose() {
    _logoController.dispose();
    _textController.dispose();
    _sloganController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: LocalizationService.instance.textDirection,
      child: Scaffold(
        backgroundColor: AppColors.primary,
        body: Container(
          color: AppColors.primary,
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  flex: 3,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Animated Rive Logo
                        // Animated Rive Logo
                        AnimatedBuilder(
                          animation: _logoAnimation,
                          builder: (context, child) {
                            return Transform.scale(
                              scale: _logoAnimation.value,
                              child: Container(
                                width: 150, // كان 200
                                height: 150, // كان 200
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(
                                    30,
                                  ), // كان 40
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(
                                    30,
                                  ), // كان 40
                                  child: Padding(
                                    padding: const EdgeInsets.all(30),
                                    child: Image.asset(
                                      "assets/images/Logo.png",
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 30),

                        // Animated App Name
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _textAnimation,
                            child: Column(
                              children: [
                                Text(
                                  AppStrings.appName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        color: Color(0xFFF08D39),
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  tr('splash.tagline_ar'),
                                  style: Theme.of(context).textTheme.titleMedium
                                      ?.copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        fontWeight: FontWeight.w300,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // Slogan with fade-in animation
                        FadeTransition(
                          opacity: _sloganAnimation,
                          child: Text(
                            tr('splash.tagline_en'),
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: AppColors.white.withValues(
                                    alpha: 0.70,
                                  ),
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.6,
                                  fontSize: 16,
                                ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(height: 14),
                      ],
                    ),
                  ),
                ),

                // Loading Indicator
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      FadeTransition(
                        opacity: _textAnimation,
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.white,
                          ),
                          strokeWidth: 3,
                        ),
                      ),
                    ],
                  ),
                ),

                // Version Info
                Padding(
                  padding: const EdgeInsets.only(bottom: 30),
                  child: Column(
                    children: [
                      FadeTransition(
                        opacity: _textAnimation,
                        child: Text(
                          _appVersion.isNotEmpty
                              ? '$_appVersion v'
                              : '${AppConstants.appVersion} v',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.white.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                      // Dynamic version + patch
                      FadeTransition(
                        opacity: _sloganAnimation,
                        child: Column(
                          children: [
                            if (_patchNumber != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Patch: #$_patchNumber',
                                style: Theme.of(context).textTheme.bodySmall
                                    ?.copyWith(
                                      color: AppColors.white.withValues(
                                        alpha: 0.50,
                                      ),
                                      fontWeight: FontWeight.w400,
                                      letterSpacing: 0.5,
                                    ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
