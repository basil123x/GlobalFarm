import 'dart:convert';

import 'package:http/http.dart' as http;

class OneSignalService {
  // Settings → Keys & IDs → REST API Key
  static const String _restApiKey =
      "os_v2_app_2ui32pebnnaq7a3xeibrgh5acone5ogktcmekunssgpwr5injkjoul75wux65abkk7bgwasqizp6d3c52lppp67rw7ptk4pos3isuiy";
  static const String _appId = "d511bd3c-816b-410f-8377-2203131fa013";
  static const String _apiUrl = "https://onesignal.com/api/v1/notifications";

  /// Must match MainActivity NotificationChannel id.
  static const String androidChannelId = 'globalfarm_crowing_v2';

  /// Android: res/raw/crowing.mp3 (name without extension)
  static const String androidSound = 'crowing';

  /// iOS: Runner/crowing.caf (name with extension)
  static const String iosSound = 'crowing.caf';

  static Map<String, dynamic> _soundPayload() => {
        // Channel created in MainActivity — use existing_android_channel_id
        // (android_channel_id is only for channels created in OneSignal Dashboard)
        'existing_android_channel_id': androidChannelId,
        'android_sound': androidSound,
        'ios_sound': iosSound,
        'priority': 10,
      };

  static Future<bool> sendNotificationToUser({
    required String playerId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (playerId.trim().isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_player_ids': [playerId],
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );
      if (response.statusCode == 200) {
        print('Notification sent successfully!');
        print('Response: ${response.body}');
        return true;
      } else {
        print('Error: ${response.statusCode}');
        print('Response: ${response.body}');
        return false;
      }
    } catch (e) {
      print('Exception: $e');
      return false;
    }
  }

  static Future<bool> sendNotificationToMultipleUsers({
    required List<String> playerIds,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final ids = playerIds.where((e) => e.trim().isNotEmpty).toList();
    if (ids.isEmpty) return false;
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'include_player_ids': ids,
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );
      if (response.statusCode == 200) {
        print('Notifications sent successfully!');
        return true;
      } else {
        print('Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception: $e');
      return false;
    }
  }

  static Future<bool> sendNotificationToAll({
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(_apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $_restApiKey',
        },
        body: jsonEncode({
          'app_id': _appId,
          'included_segments': ['All'],
          'headings': {'en': title, 'ar': title},
          'contents': {'en': message, 'ar': message},
          'data': data ?? {},
          ..._soundPayload(),
        }),
      );
      if (response.statusCode == 200) {
        print('Notification sent to all users!');
        return true;
      } else {
        print('Error: ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('Exception: $e');
      return false;
    }
  }
}
