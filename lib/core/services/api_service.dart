import 'dart:convert';
import 'dart:io';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:GlobalFarm/core/services/onesignal_service.dart';
import 'package:GlobalFarm/core/services/s3_upload_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static String get baseUrl => AppConfig.apiBaseUrl;

  // Test server connection
  static Future<Map<String, dynamic>> testConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/test.php'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Server returned status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection test failed: $e');
    }
  }

  // Fetch items with pagination for infinite scroll
  // Fetch items with pagination for infinite scroll
  static Future<List<ItemModel>> fetchItems({
    required int page,
    String? userId,
    String? initialItemId,
    String? category,
    String? country,
    String? pinnedItemId,
  }) async {
    try {
      final url = Uri.parse(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
      );

      // http.post body must be Map<String, String> — never put null values
      final body = <String, String>{
        'action': 'fetch',
        'page': page.toString(),
        'limit': '10',
        'itemSrchId': initialItemId ?? '',
        'country': (country != null && country.isNotEmpty) ? country : 'QA',
        'store_id': AppConfig.storeId,
      };

      if (userId != null && userId.isNotEmpty) {
        body['user_id'] = userId;
      }

      if (category != null && category.isNotEmpty) {
        body['category'] = category;
      }

      if (pinnedItemId != null && pinnedItemId.isNotEmpty && page == 0) {
        body['pinnedItemId'] = pinnedItemId;
      }

      print('📦 fetchItems Request: $body');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: body,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("SSSSS $data");

        if (data['success'] == true) {
          final List<dynamic> itemsJson = data['data'];
          return itemsJson.map((json) => ItemModel.fromJson(json)).toList();
        } else {
          throw Exception(data['error'] ?? 'فشل في جلب البيانات');
        }
      } else {
        throw Exception('خطأ في الاتصال بالخادم: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching items: $e');
      throw Exception('فشل في جلب البيانات: $e');
    }
  }

  static Future<ItemModel?> fetchItemById({
    required String itemId,
    String? userId,
    String? country,
  }) async {
    try {
      if (userId != null && userId.isNotEmpty) {
        final items = await fetchItemsWithLikes(
          userId: userId,
          limit: 1,
          offset: 0,
          initialItemId: itemId,
          country: country,
        );
        if (items.isNotEmpty) return items.first;
      } else {
        final items = await fetchItems(
          page: 0,
          initialItemId: itemId,
          country: country,
        );
        if (items.isNotEmpty) return items.first;
      }

      return await _fetchItemViaGetAction(itemId, userId: userId);
    } catch (e) {
      print('Error fetching item by id: $e');
      return await _fetchItemViaGetAction(itemId, userId: userId);
    }
  }

  static Future<ItemModel?> _fetchItemViaGetAction(
    String itemId, {
    String? userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_item',
          'item_id': itemId,
          'store_id': AppConfig.storeId,
          if (userId != null && userId.isNotEmpty) 'user_id': userId,
        }),
      );

      if (response.statusCode != 200) return null;
      final data = response.data;
      if (data is! Map || data['success'] != true || data['data'] == null) {
        return null;
      }

      return ItemModel.fromJson(
        Map<String, dynamic>.from(data['data'] as Map),
      );
    } catch (e) {
      print('get_item fallback error: $e');
      return null;
    }
  }

  /// Lookup by id, idx, or barcode via `get_item` (exact match).
  static Future<ItemModel?> fetchItemByBarcode(
    String barcode, {
    String? userId,
  }) async {
    final code = barcode.trim();
    if (code.isEmpty) return null;
    return _fetchItemViaGetAction(code, userId: userId);
  }

  static Future<Map<String, dynamic>> updateItemMedia({
    required String itemId,
    required String media,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'update_item_media',
          'item_id': itemId,
          'media': media,
        }),
      );
      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return {
        'success': false,
        'error': 'Failed to update media: ${response.statusCode}',
      };
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<int?> getLastGlobalFarmItemId() async {
    try {
      final response = await Dio().get(
        '${AppConfig.syncReceiveUrl}?action=get_last_id',
      );

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] == true && data['last_id'] != null) {
          return int.tryParse(data['last_id'].toString());
        }
      }
      return null;
    } catch (e) {
      print('GlobalFarm get_last_id error: $e');
      return null;
    }
  }

  static Future<int?> insertEmptyGlobalFarmItem() async {
    try {
      final response = await Dio().post(
        AppConfig.syncReceiveUrl,
        data: {'action': 'insert_empty'},
        options: Options(
          headers: {
            'X-Sync-Key': 'GlobalFarm_Secret_2026',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        if (data['success'] == true && data['id'] != null) {
          final id = int.tryParse(data['id'].toString());
          print('GlobalFarm insert_empty id: $id');
          return id;
        }
      }
      print('GlobalFarm insert_empty failed: ${response.data}');
      return null;
    } catch (e) {
      print('GlobalFarm insert_empty error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> syncItemToGlobalFarm({
    required String clientId,
    String? globalFarmItemId,
    String? martitItemId,
    required String itemName,
    required String itemNameEn,
    required String category,
    required String description,
    required String price,
    required String barcode,
    required String descriptionArb,
    required String quantity,
  }) async {
    try {
      final parsedQuantity = int.tryParse(quantity) ?? 0;

      final response = await Dio().post(
        AppConfig.syncReceiveUrl,
        data: {
          'id': int.tryParse(clientId) ?? clientId,
          'martit_item_id': martitItemId ?? '',
          'a1': barcode,
          'a3': itemName,
          'a4': itemNameEn,
          'a5': category,
          'a7': descriptionArb,
          'a8': description,
          'a10': price,
          'a30': parsedQuantity,
        },
        options: Options(
          headers: {
            'X-Sync-Key': 'GlobalFarm_Secret_2026',
            'Content-Type': 'application/json',
          },
        ),
      );

      print('GlobalFarm sync response: ${response.data}');
      if (response.data is Map) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      return null;
    } catch (e) {
      print('GlobalFarm sync error: $e');
      return null;
    }
  }

  // Search items by name
  static Future<Map<String, dynamic>> searchItems(String query) async {
    try {
      final trimmed = query.trim();
      if (trimmed.isEmpty) {
        return {'success': true, 'data': []};
      }

      final response = await Dio().get(
        '$baseUrl/search.php',
        queryParameters: {
          'q': trimmed,
          'store_id': AppConfig.storeId,
          'k': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map && data['success'] == true) {
          return Map<String, dynamic>.from(data);
        }
      }

      // fallback: sql.php search action
      final fallback = await Dio().get(
        '$baseUrl/sql.php',
        queryParameters: {
          'action': 'search',
          'q': trimmed,
          'store_id': AppConfig.storeId,
          'k': DateTime.now().millisecondsSinceEpoch.toString(),
        },
      );
      if (fallback.statusCode == 200 && fallback.data is Map) {
        return Map<String, dynamic>.from(fallback.data as Map);
      }

      throw Exception('Failed to search items: ${response.statusCode}');
    } catch (e) {
      print('Search error: $e');
      throw Exception('Search error: $e');
    }
  }

  // Get user profile
  static Future getUserProfile(String userId) async {
    try {
      print('📤 getUserProfile called with: $userId');

      final payload = <String, dynamic>{'action': 'get_user_profile'};
      final numericId = int.tryParse(userId);
      if (numericId != null && numericId > 0) {
        payload['user_id'] = userId;
        print('📤 Sending as user_id (numeric)');
      } else {
        payload['uid'] = userId;
        print('📤 Sending as uid (string)');
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(payload),
      );

      print('📥 getUserProfile raw response: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ getUserProfile exception: $e');
      throw Exception('Profile error: $e');
    }
  }

  static Future getUserProfileItems(
    String uid, {
    int limit = 20,
    int offset = 0,
    String sort = 'views',
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "fetch_items_one_account",
          "uid": uid,
          "limit": limit,
          "offset": offset,
          "sort": sort,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Profile error: $e');
    }
  }

  // Get comments for item
  static Future<Map<String, dynamic>> getComments(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse(
          '$baseUrl/comments.php?item_id=$itemId&k=${DateTime.now().millisecondsSinceEpoch}',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to load comments: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Comments error: $e');
    }
  }

  // Add comment to item
  static Future<Map<String, dynamic>> addComment({
    required int itemId,
    required String userId,
    required String comment,
  }) async {
    try {
      final response = await http.post(
        Uri.parse(
          '$baseUrl/comments.php?item_id=$itemId&k=${DateTime.now().millisecondsSinceEpoch}',
        ),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'comment': comment,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw Exception('Failed to add comment: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Add comment error: $e');
    }
  }

  // Get item statistics
  static Future<Map<String, dynamic>> getItemStats(String itemId) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({"action": "get_stats", "item_id": itemId}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Stats error: $e');
    }
  }

  // Add report
  static Future<Map<String, dynamic>> addReport({
    required String itemId,
    required String userId,
    required String reason,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "add_report",
          "item_id": itemId,
          "user_id": userId,
          "reason": reason,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to add report: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Report error: $e');
    }
  }

  // Toggle like
  static Future<Map<String, dynamic>> toggleLike({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "toggle_like",
          "item_id": itemId,
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to toggle like: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Like error: $e');
    }
  }

  // Add to cart
  // Add to cart with timeout
  // Add to cart with longer timeout
  static Future<Map<String, dynamic>> addToCart({
    required String itemId,
    required String userId,
    int quantity = 1,
  }) async {
    try {
      String? oid = await FlutterSecureStorage().read(key: "user_oid");
      final response = await Dio()
          .post(
            '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
            data: FormData.fromMap({
              "action": "add_to_cart",
              "item_id": itemId,
              "user_id": userId,
              "oid": oid,
              "quantity": quantity.toString(),
            }),
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 30), // ← ✅ زودها
              receiveTimeout: const Duration(seconds: 30), // ← ✅ زودها
            ),
          )
          .timeout(
            const Duration(seconds: 30), // ← ✅ زودها
            onTimeout: () {
              throw Exception('انتهت مهلة الاتصال بالخادم');
            },
          );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to add to cart: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Add to cart error: $e');
      throw Exception('Cart error: $e');
    }
  }

  // Remove from cart with longer timeout
  static Future<Map<String, dynamic>> removeFromCart({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio()
          .post(
            '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
            data: FormData.fromMap({
              "action": "remove_from_cart",
              "item_id": itemId,
              "user_id": userId,
            }),
            options: Options(
              headers: {'Content-Type': 'application/json'},
              sendTimeout: const Duration(seconds: 30), // ← ✅ زودها
              receiveTimeout: const Duration(seconds: 30), // ← ✅ زودها
            ),
          )
          .timeout(
            const Duration(seconds: 30), // ← ✅ زودها
            onTimeout: () {
              throw Exception('انتهت مهلة الاتصال بالخادم');
            },
          );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to remove from cart: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Remove from cart error: $e');
      throw Exception('Cart error: $e');
    }
  }

  // Get cart quantity
  static Future<Map<String, dynamic>> getCartQuantity({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_cart_quantity",
          "item_id": itemId,
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get cart quantity: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cart error: $e');
    }
  }

  static Future<Map<String, dynamic>> addNotifyRequest({
    required String itemId,
    required String userId,
    required String storeId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'add_notify_request',
          'item_id': itemId,
          'user_id': userId,
          'store_id': storeId,
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Failed to add notify request: ${response.statusCode}');
    } catch (e) {
      print('❌ addNotifyRequest error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<Map<String, dynamic>> checkNotifyStatus({
    required String itemId,
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'check_notify_status',
          'item_id': itemId,
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(response.data as Map);
      }
      throw Exception('Failed to check notify status: ${response.statusCode}');
    } catch (e) {
      print('❌ checkNotifyStatus error: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  static Future<List<String>> getUserNotifySubscriptions(String userId) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_user_notify_subscriptions',
          'user_id': userId,
        }),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data is Map &&
            data['success'] == true &&
            data['item_ids'] is List) {
          final list = data['item_ids'] as List<dynamic>;
          return list.map((e) => e.toString()).toList();
        }
      }
    } catch (e) {
      print('❌ getUserNotifySubscriptions error: $e');
    }
    return [];
  }

  /// Sends OneSignal alerts for users returned in [response]['notify_users'].
  static Future<void> dispatchRestockNotifications(
    Map<String, dynamic> response,
  ) async {
    final notifyUsers = response['notify_users'];
    if (notifyUsers is! List || notifyUsers.isEmpty) return;

    for (final entry in notifyUsers) {
      if (entry is! Map) continue;
      final playerId = entry['player_id']?.toString() ?? '';
      if (playerId.isEmpty) continue;

      await OneSignalService.sendNotificationToUser(
        playerId: playerId,
        title: 'المنتج متاح الآن!',
        message: 'المنتج الذي طلبت إشعاره أصبح متاحاً، تسوق الآن!',
        data: {
          'item_id': entry['item_id']?.toString() ?? '',
          'type': 'restock_notify',
        },
      );
    }
  }

  // Fetch items with likes status
  static Future<List<ItemModel>> fetchItemsWithLikes({
    required String userId,
    int limit = 10,
    int offset = 0,
    String? initialItemId,
    String? category,
    String? country,
    String? pinnedItemId,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        "action": "fetch_with_likes",
        "user_id": userId,
        "limit": limit.toString(),
        "offset": offset.toString(),
        'itemSrchId': initialItemId ?? "",
        'country': (country != null && country.isNotEmpty) ? country : 'QA',
        'store_id': AppConfig.storeId,
      };

      // ✅ لو في category، نضيفه للـ request
      if (category != null && category.isNotEmpty) {
        requestData['category'] = category;
      }

      if (pinnedItemId != null && pinnedItemId.isNotEmpty && offset == 0) {
        requestData['pinnedItemId'] = pinnedItemId;
      }

      print('📦 fetchItemsWithLikes Request: $requestData');

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(requestData),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final List<dynamic> itemsData = data['data'] ?? [];
          print(
            '📦 First item raw: ${itemsData.isNotEmpty ? itemsData[0] : "empty"}',
          );
          print(
            '📦 Raw response keys: ${itemsData.isNotEmpty ? (itemsData[0] as Map).keys.toList() : "empty"}',
          );
          return itemsData.map((item) => ItemModel.fromJson(item)).toList();
        } else {
          throw Exception(data['error'] ?? 'Failed to fetch items');
        }
      } else {
        throw Exception('Failed to fetch items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Fetch error: $e');
    }
  }

  // Get cart items
  static Future<Map<String, dynamic>> getCartItems({
    required String userId,
    String? storeId,
  }) async {
    try {
      final resolvedStoreId = storeId ?? AppConfig.storeId;
      final payload = <String, dynamic>{
        'action': 'get_from_cart',
        'user_id': userId,
      };
      if (resolvedStoreId.isNotEmpty) {
        payload['store_id'] = resolvedStoreId;
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(payload),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        print('Cart API response: $result');
        if (result is Map && result['data'] is List) {
          for (final item in result['data'] as List) {
            print('Cart item raw JSON: $item');
          }
        }
        return result;
      } else {
        throw Exception('Failed to get cart items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Cart error: $e');
    }
  }

  // Update cart quantity
  static Future<Map<String, dynamic>> updateCartQuantity({
    required String cartId,
    required int quantity,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "update_cart_quantity",
          "cart_id": cartId,
          "quantity": quantity.toString(),
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to update cart quantity: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Cart error: $e');
    }
  }

  // Add shipping address
  static Future<Map<String, dynamic>> addShippingAddress({
    required String fullname,
    required String mobile,
    required String email,
    required String country,
    required String city,
    required String zoneNumber,
    required String streetNumber,
    required String buildingNumber,
    required String uid,
    required String oid,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "add_shipping_address",
          "fullname": fullname,
          "mobile": mobile,
          "email": email,
          "country": country,
          "city": city,
          "zone_number": zoneNumber,
          "street_number": streetNumber,
          "building_number": buildingNumber,
          "uid": uid,
          "oid": oid,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to add shipping address: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Shipping address error: $e');
    }
  }

  // Get shipping addresses
  static Future<Map<String, dynamic>> getShippingAddresses({
    required String uid,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_shipping_addresses",
          "uid": uid,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to get shipping addresses: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Shipping address error: $e');
    }
  }

  // Get user sellers
  static Future<Map<String, dynamic>> getUserSellers({
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_user_sellers",
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get user sellers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Sellers error: $e');
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    File? avatar,
  }) async {
    try {
      if (avatar != null) {
        await _uploadAvatar(uid, avatar);
      }

      final data = <String, dynamic>{
        "action": "update_user_profile",
        "uid": uid,
      };
      if (name != null && name.isNotEmpty) {
        data["name"] = name;
      }
      if (phone != null && phone.isNotEmpty) {
        data["phone"] = phone;
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(data),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to update profile: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Profile update error: $e');
    }
  }

  static Future<void> _uploadAvatar(String uid, File avatar) async {
    try {
      final bytes = await avatar.readAsBytes();
      final jpgBytes = await compute(convertImageToJpg, bytes);
      final objectKey = 'Users/store_${AppConfig.storeId}/$uid/1.jpg';
      final url = await S3UploadService.uploadBytes(
        bytes: jpgBytes,
        objectKey: objectKey,
        contentType: 'image/jpeg',
      );
      if (url == null) {
        throw Exception('Avatar upload failed');
      }
    } catch (e) {
      throw Exception('Avatar upload error: $e');
    }
  }

  // Clear cart and update OID
  static Future<Map<String, dynamic>> clearCartAndUpdateOID({
    required String userId,
    required String newOid,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "clear_cart_update_oid",
          "user_id": userId,
          "new_oid": newOid,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to clear cart and update OID: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Clear cart error: $e');
    }
  }

  // Get chat messages between two users
  static Future<Map<String, dynamic>> getChatMessages({
    required String senderId,
    required String receiverId,
    String? conversationId,
  }) async {
    try {
      final data = {
        "action": "get_chat_messages",
        "sender_id": senderId,
        "receiver_id": receiverId,
      };

      if (conversationId != null && conversationId.isNotEmpty) {
        data["conversation_id"] = conversationId;
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(data),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get chat messages: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Chat messages error: $e');
    }
  }

  // Send chat message
  static Future<Map<String, dynamic>> sendChatMessage({
    required String senderId,
    required String receiverId,
    required String message,
    String? conversationId,
    String messageType = 'text',
    double? locationLat,
    double? locationLng,
  }) async {
    try {
      final data = {
        "action": "send_chat_message",
        "sender_id": senderId,
        "receiver_id": receiverId,
        "message": message,
        "message_type": messageType,
      };

      print(data);

      if (conversationId != null && conversationId.isNotEmpty) {
        data["conversation_id"] = conversationId;
      }

      if (locationLat != null) {
        data["location_lat"] = locationLat.toString();
      }

      if (locationLng != null) {
        data["location_lng"] = locationLng.toString();
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(data),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to send message: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Send message error: $e');
    }
  }

  // Send chat notification
  static Future<Map<String, dynamic>> sendChatNotification({
    required String receiverId,
    required String senderName,
    required String message,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "send_chat_notification",
          "receiver_id": receiverId,
          "sender_name": senderName,
          "message": message,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to send notification: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Notification error: $e');
    }
  }

  // Update user online status
  static Future<Map<String, dynamic>> updateOnlineStatus({
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "update_online_status",
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to update status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Update status error: $e');
    }
  }

  // Get user online status
  static Future<Map<String, dynamic>> getUserStatus({
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_user_status",
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get status: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get status error: $e');
    }
  }

  // Get chat conversations list
  static Future<Map<String, dynamic>> getChatConversations({
    required String userId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "get_chat_conversations",
          "user_id": userId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get conversations: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Conversations error: $e');
    }
  }

  // Create order
  static Future<Map<String, dynamic>> createOrder({
    required String uid,
    required String custId,
    required String oid,
    required String shipId,
    required String items,
    required String totalAmount,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "create_order",
          "uid": uid,
          "cust_id": custId,
          "oid": oid,
          "ship_id": shipId,
          "items": items,
          "total_amount": totalAmount,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to create order: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Create order error: $e');
    }
  }

  /// Sync a completed app order into Gfnursery `inv` + `inv_det`.
  /// Requires client endpoint: POST sync_receive.php action=create_invoice
  static Future<Map<String, dynamic>?> syncOrderToGlobalFarm({
    required String oid,
    required String customerName,
    required String customerPhone,
    required String customerUid,
    required String notes,
    required double total,
    required String paymentMode,
    required List<Map<String, dynamic>> items,
    String? martitOrderId,
    String branch = AppConfig.storeId,
    String typex = 'a14',
  }) async {
    try {
      final now = DateTime.now();
      final datex =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
      final date2 =
          '$datex '
          '${now.hour.toString().padLeft(2, '0')}:'
          '${now.minute.toString().padLeft(2, '0')}:'
          '${now.second.toString().padLeft(2, '0')}';

      final isElectronic =
          paymentMode == 'visa' ||
          paymentMode == 'card' ||
          paymentMode == 'sadad';
      final cash = isElectronic ? 0.0 : 0.0;
      final visa = isElectronic ? total : 0.0;
      final credit = isElectronic ? 0.0 : total;

      final response = await Dio().post(
        AppConfig.syncReceiveUrl,
        data: {
          'action': 'create_invoice',
          'invoice': {
            'datex': datex,
            'date2': date2,
            'custvend': customerName,
            'phone': customerPhone,
            'store': branch,
            'notes': notes,
            'typex': typex,
            'total': total,
            'disc': 0,
            'net': total,
            'cash': cash,
            'visa': visa,
            'credit': credit,
            'branch': branch,
            'uid': customerUid,
            'status': 1,
            'martit_oid': oid,
            'martit_order_id': martitOrderId ?? '',
            'payment_mode': paymentMode,
          },
          'items': items,
        },
        options: Options(
          headers: {
            'X-Sync-Key': 'GlobalFarm_Secret_2026',
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.data is Map) {
        final data = Map<String, dynamic>.from(response.data as Map);
        print('GlobalFarm create_invoice response: $data');
        return data;
      }
      return null;
    } catch (e) {
      print('GlobalFarm create_invoice error: $e');
      return null;
    }
  }

  // Get my orders as buyer
  static Future<Map<String, dynamic>> getMyOrders({
    required String custId,
  }) async {
    try {
      print('🔍 API getMyOrders - Sending request with cust_id: $custId');

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({"action": "get_my_orders", "cust_id": custId}),
      );

      print('📦 API getMyOrders - Response status: ${response.statusCode}');
      print('📦 API getMyOrders - Response data: ${response.data}');

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to get my orders: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ API getMyOrders - Error: $e');
      throw Exception('Get my orders error: $e');
    }
  }

  // Get customer orders as seller (or all store orders when [storeId] is set).
  static Future<Map<String, dynamic>> getCustomerOrders({
    required String uid,
    String? storeId,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_customer_orders',
          'uid': uid,
          if (storeId != null && storeId.isNotEmpty) 'store_id': storeId,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to get customer orders: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Get customer orders error: $e');
    }
  }

  // Update order status
  static Future<Map<String, dynamic>> updateOrderStatus({
    required String orderId,
    required String status,
    required String uid,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "update_order_status",
          "order_id": orderId,
          "status": status,
          "uid": uid,
        }),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception(
          'Failed to update order status: ${response.statusCode}',
        );
      }
    } catch (e) {
      throw Exception('Update order status error: $e');
    }
  }

  // Get categories/groups by store_id
  static Future<List<String>> getCategories({String? storeId}) async {
    try {
      final data = <String, dynamic>{"action": "get_group"};
      final resolvedStoreId = storeId ?? AppConfig.storeId;

      if (resolvedStoreId.isNotEmpty) {
        data["store_id"] = resolvedStoreId;
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(data),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        if (result['success'] == true) {
          final List<dynamic> categoriesData = result['data'] ?? [];
          return categoriesData
              .map((item) => item['category']?.toString() ?? '')
              .where((c) => c.isNotEmpty)
              .toList();
        } else {
          throw Exception(result['error'] ?? 'Failed to get categories');
        }
      } else {
        throw Exception('Failed to get categories: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Get categories error: $e');
    }
  }

  /// Promo banners from S3: `store_{id}/banners/*`.
  static Future<List<String>> getBanners({String? storeId}) async {
    try {
      return await S3UploadService.listBannerUrls(
        storeId: storeId ?? AppConfig.storeId,
      );
    } catch (e) {
      print('getBanners error: $e');
      return [];
    }
  }

  static Future<void> trackInteraction(
    String? userId,
    String itemId,
    String action, {
    int watchSeconds = 0,
  }) async {
    if (userId == null) return;
    try {
      await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'track_interaction',
          'user_id': userId,
          'item_id': itemId,
          'interaction': action,
          'watch_seconds': watchSeconds.toString(),
        }),
      );
    } catch (_) {}
  }

  static Future<Map<String, dynamic>> getUserScores(String userId) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          'action': 'get_user_scores',
          'user_id': userId,
        }),
      );
      if (response.statusCode == 200) {
        return response.data;
      }
      return {'success': false};
    } catch (e) {
      return {'success': false, 'error': e.toString()};
    }
  }
}


// AKIARVJRTCELECEKHATH

// rbxI5l6k7GSVwQyxL8rsBYgqe69GtjJhc+TDbEXe