import 'package:dio/dio.dart';
import 'package:GlobalFarm/core/constants/app_config.dart';

class DatabaseService {
  static String get _baseUrl => AppConfig.apiBaseUrl;
  static final Dio _dio = Dio();

  static Future<int> getLastIdx({String storeId = '2'}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_last_idx',
          'store_id': storeId,
        }),
      );

      if (response.data is Map && response.data['success'] == true) {
        final lastIdx = response.data['last_idx'];
        if (lastIdx is num) return lastIdx.toInt();
        return int.tryParse(lastIdx?.toString() ?? '') ?? 0;
      }
    } catch (e) {
      print('Error getting last idx: $e');
    }
    return 0;
  }

  static Future<Map<String, dynamic>> updateItem({
    required String itemId,
    String? clientId,
    String? idx,
    required String uid,
    required String barcode,
    required String name,
    required String eng,
    required String description,
    required String description_arb,
    required String category,
    required String price,
    required String quantity,
    required String visibility,
    required String comments,
    required String media,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'insert',
          'item_id': itemId,
          'client_id': clientId ?? '0',
          if (idx != null && idx.isNotEmpty) 'idx': idx,
          'uid': uid,
          'barcode': barcode,
          'name': name,
          'eng': eng,
          'description': description,
          'description_arb': description_arb,
          'category': category,
          'price': price,
          'qtt': quantity,
          'visibility': visibility,
          'comments': comments,
          'media': media,
        }),
      );

      return response.data;
    } catch (e) {
      print('Error updating item: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> updateItemIdx({
    required String itemId,
    required String idx,
  }) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'update_item_idx',
          'item_id': itemId,
          'idx': idx,
        }),
      );
      return response.data is Map
          ? Map<String, dynamic>.from(response.data as Map)
          : {'success': false};
    } catch (e) {
      print('Error updating item idx: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> followUser({
    required String buyerId,
    required String userId,
    String? userToken,
  }) async {
    try {
      final url =
          '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}';

      final response = await Dio().post(
        url,
        data: {
          'action': 'follow_user',
          'buyer_id': buyerId,
          'user_id': userId,
          'user_token': userToken ?? '',
        },
        options: Options(
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        ),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        return data;
      } else {
        return {
          'success': false,
          'error': 'خطأ في الاتصال بالخادم: ${response.statusCode}',
        };
      }
    } catch (e) {
      print('Error in followUser: $e');
      return {'success': false, 'error': 'فشل في الاتصال بالخادم'};
    }
  }

  static Future<Map<String, dynamic>> getItems({int page = 0}) async {
    try {
      final response = await _dio.post(
        '$_baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_items',
          'page': page.toString(),
        }),
      );

      return response.data;
    } catch (e) {
      print('Error getting items: $e');
      return {'success': false, 'error': e.toString()};
    }
  }
}
