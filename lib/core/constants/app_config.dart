import 'package:GlobalFarm/core/services/remote_config_service.dart';

class AppConfig {
  static const String storeId = '2';

  static const String s3BaseUrl =
      'https://martit.s3.ap-south-1.amazonaws.com';

  /// API host from remote `app_config.json` (cached). Fallback: mart-it.store/app2026.
  static String get apiBaseUrl => RemoteConfigService.instance.apiBaseUrl;

  /// GlobalFarm nursery sync endpoint from remote config.
  static String get syncReceiveUrl =>
      RemoteConfigService.instance.syncReceiveUrl;

  /// S3 folder for promotional banner images shown on Home.
  static String bannersFolder({String? storeId}) =>
      'store_${storeId ?? AppConfig.storeId}/banners';

  static String bannersBaseUrl({String? storeId}) =>
      '$s3BaseUrl/${bannersFolder(storeId: storeId)}/';
}
