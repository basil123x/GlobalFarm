import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:GlobalFarm/core/services/localization_service.dart';

class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const String _otpChannelId = 'otp_channel';
  static const String _otpChannelName = 'OTP Notifications';
  static const int _otpNotificationId = 1001;

  static Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _plugin.initialize(settings);

    const androidChannel = AndroidNotificationChannel(
      _otpChannelId,
      _otpChannelName,
      importance: Importance.high,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(androidChannel);
  }

  static Future<void> showOtpNotification(String otp) async {
    final lang = LocalizationService.instance.currentLanguage;
    final title = lang == 'ar' ? 'كود التحقق' : 'Verification Code';

    const androidDetails = AndroidNotificationDetails(
      _otpChannelId,
      _otpChannelName,
      importance: Importance.high,
      priority: Priority.high,
    );
    const iosDetails = DarwinNotificationDetails();
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _plugin.show(_otpNotificationId, title, otp, details);
  }
}
