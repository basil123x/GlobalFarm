import 'package:GlobalFarm/core/services/onesignal_service.dart';

/// Same REST sender used by background/web-style call sites.
class OneSignalServiceWebSys {
  static Future<bool> sendNotificationToMultipleUsers({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) {
    return OneSignalService.sendNotificationToMultipleUsers(
      playerIds: playerIds,
      title: title,
      message: message,
      data: data,
    );
  }
}
