import 'dart:async';
import 'dart:io';

import 'package:GlobalFarm/features/chat/chat_screen.dart';
import 'package:GlobalFarm/shared/providers/app_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'package:provider/provider.dart';
import 'package:restart_app/restart_app.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:terminate_restart/terminate_restart.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/app_theme.dart';
import 'core/services/local_notification_service.dart';
import 'core/services/localization_service.dart';
import 'core/services/remote_config_service.dart';
import 'features/splash/splash_screen.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  const appToken = "d511bd3c-816b-410f-8377-2203131fa013";
  OneSignal.initialize(appToken);
  await OneSignal.Notifications.requestPermission(true);

  OneSignal.Notifications.addClickListener((event) {
    print('OneSignal: notification clicked: ${event.notification.title}');

    final additionalData = event.notification.additionalData;

    if (additionalData != null) {
      final sellerId = additionalData['receiverId'];
      final sellerName = additionalData['receiverName'] ?? 'Unknown';
      final sellerAvatar = additionalData['receiverAvatar'] ?? '';
      final sellerToken = additionalData['receiverToken'] ?? '';
      final convers = additionalData['conversationId'] ?? '';

      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            receiverId: sellerId,
            receiverName: sellerName,
            receiverAvatar: sellerAvatar,
            receiverToken: sellerToken,
            conversationId: convers,
            isOnline: false,
          ),
        ),
      );
    }
  });

  OneSignal.Notifications.addForegroundWillDisplayListener((event) {
    print('OneSignal: notification received: ${event.notification.title}');
    event.preventDefault();
    event.notification.display();
  });

  await LocalizationService.instance.init();
  await LocalNotificationService.initialize();
  await RemoteConfigService.instance.load();

  final prefs = await SharedPreferences.getInstance();
  final isDark = prefs.getBool(AppProvider.darkModeKey) ?? false;

  runApp(MartItApp(initialDarkMode: isDark));
}

class MartItApp extends StatefulWidget {
  final bool? initialDarkMode;

  const MartItApp({super.key, this.initialDarkMode});

  @override
  State<MartItApp> createState() => _MartItAppState();
}

class _MartItAppState extends State<MartItApp> {
  final updater = ShorebirdUpdater();
  Timer? _timer;
  static const _lastPatchKey = "last_applied_patch";

  Future<void> ensureDoubleRestart() async {
    if (!Platform.isAndroid) return;

    final prefs = await SharedPreferences.getInstance();
    final lastPatchNumber = prefs.getInt(_lastPatchKey) ?? 0;
    final currentPatch = await updater.readCurrentPatch();

    if (currentPatch != null && currentPatch.number != lastPatchNumber) {
      await prefs.setInt(_lastPatchKey, currentPatch.number);
      await Future.delayed(const Duration(seconds: 2));
      if (Platform.isIOS) {
        Restart.restartApp();
      } else {
        await TerminateRestart.instance.restartApp(
          options: const TerminateRestartOptions(terminate: true),
        );
      }
    }
  }

  Future<void> checkForUpdates() async {
    final status = await updater.checkForUpdate();

    if (status == UpdateStatus.outdated) {
      try {
        await updater.update();
        final prefs = await SharedPreferences.getInstance();
        final currentPatch = await updater.readCurrentPatch();
        if (currentPatch != null) {
          await prefs.setInt(_lastPatchKey, currentPatch.number - 1);
        }

        if (Platform.isIOS) {
          Restart.restartApp(
            notificationTitle: "إشعار هام",
            notificationBody: "قم بتحديث التطبيق الأن",
          );
        } else {
          await TerminateRestart.instance.restartApp(
            options: const TerminateRestartOptions(terminate: true),
          );
        }
      } on UpdateException catch (error) {
        print("Update failed: $error");
      }
    }
  }

  @override
  void initState() {
    ensureDoubleRestart();
    checkForUpdates();
    _timer = Timer.periodic(const Duration(minutes: 1), (timer) {
      checkForUpdates();
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: LocalizationService.instance),
        ChangeNotifierProvider(
          create: (_) {
            final provider = AppProvider(
              initialDarkMode: widget.initialDarkMode,
            );
            provider.loadPreferences();
            return provider;
          },
        ),
      ],
      child: Consumer2<LocalizationService, AppProvider>(
        builder: (context, localization, appProvider, _) {
          return MaterialApp(
            title: AppStrings.appName,
            theme: AppTheme.lightTheme,
            navigatorKey: navigatorKey,
            darkTheme: AppTheme.darkTheme,
            themeMode: appProvider.themeMode,
            debugShowCheckedModeBanner: false,
            locale: Locale(localization.currentLanguage),
            builder: (context, child) {
              return Directionality(
                textDirection: localization.textDirection,
                child: DefaultTextStyle(
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontFamily: 'Cairo',
                  ),
                  child: child!,
                ),
              );
            },
            home: const SplashScreen(),
          );
        },
      ),
    );
  }
}
