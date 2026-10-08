import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Loads API domains from a JSON file on the server so a domain move
/// does not require an app store update.
///
/// Upload `app_config.json` next to `sql.php` on the API host.
class RemoteConfigService {
  RemoteConfigService._();
  static final RemoteConfigService instance = RemoteConfigService._();

  static const String _prefsApiKey = 'remote_api_base_url_v2';
  static const String _prefsSyncKey = 'remote_sync_receive_url_v2';

  /// Fallback used until the remote JSON is fetched (and if fetch fails).
  /// APIs live under `/app2026/` (same host as Mart-it).
  static const String defaultApiBaseUrl = 'https://www.mart-it.store/app2026';
  static const String defaultSyncReceiveUrl =
      'https://gfnursery.com/s2026/sync_receive.php';

  /// Shared `app_config.json` with Mart-it. Same keys: api_base_url, sync_receive_url.
  static const List<String> _bootstrapConfigUrls = [
    'https://www.mart-it.store/app2026/app_config.json',
    'https://www.mart-it.store/app_config.json',
    'https://www.Globee-Trading.com/app2026/app_config.json',
  ];

  String _apiBaseUrl = defaultApiBaseUrl;
  String _syncReceiveUrl = defaultSyncReceiveUrl;

  String get apiBaseUrl => _apiBaseUrl;
  String get syncReceiveUrl => _syncReceiveUrl;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final cachedApi = prefs.getString(_prefsApiKey);
    final cachedSync = prefs.getString(_prefsSyncKey);

    if (cachedApi != null && cachedApi.isNotEmpty) {
      _apiBaseUrl = _normalizeBase(cachedApi);
    }
    if (cachedSync != null && cachedSync.isNotEmpty) {
      _syncReceiveUrl = cachedSync.trim();
    }

    final urls = <String>[
      '$_apiBaseUrl/app_config.json',
      ..._bootstrapConfigUrls,
    ];

    final seen = <String>{};
    for (final raw in urls) {
      final url = raw.trim();
      if (url.isEmpty || !seen.add(url)) continue;
      final ok = await _tryFetch(url, prefs);
      if (ok) return;
    }
  }

  Future<bool> _tryFetch(String url, SharedPreferences prefs) async {
    try {
      final response = await Dio().get<dynamic>(
        url,
        queryParameters: {
          'k': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        options: Options(
          responseType: ResponseType.json,
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      if (response.statusCode != 200 || response.data == null) return false;

      Map<String, dynamic>? json;
      final data = response.data;
      if (data is Map) {
        json = Map<String, dynamic>.from(data);
      } else if (data is String && data.trim().isNotEmpty) {
        final decoded = jsonDecode(data);
        if (decoded is Map) {
          json = Map<String, dynamic>.from(decoded);
        }
      }
      if (json == null) return false;

      final api = json['api_base_url']?.toString().trim();
      if (api == null || api.isEmpty) return false;

      _apiBaseUrl = _normalizeBase(api);
      await prefs.setString(_prefsApiKey, _apiBaseUrl);

      final sync = json['sync_receive_url']?.toString().trim();
      if (sync != null && sync.isNotEmpty) {
        _syncReceiveUrl = sync;
        await prefs.setString(_prefsSyncKey, _syncReceiveUrl);
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  static String _normalizeBase(String url) {
    var value = url.trim();
    while (value.endsWith('/')) {
      value = value.substring(0, value.length - 1);
    }
    return value;
  }
}
