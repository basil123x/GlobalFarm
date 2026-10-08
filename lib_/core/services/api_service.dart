import 'dart:convert';
import 'dart:io';
import 'package:GlobalFarm/core/constants/app_config.dart';
import 'package:GlobalFarm/core/models/item_model.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://www.Globee-Trading.com/app2026';

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
  }) async {
    try {
      final url = Uri.parse('$baseUrl/sql.php');

      // ✅ نبعت user_id لو موجود
      final body = {
        'action': 'fetch',
        'page': page.toString(),
        'limit': '10',
        // 'itemSrchId': initialItemId ?? "",
        'country': country,
        'store_id': AppConfig.storeId
      };

      // ✅ لو في user_id، نضيفه للـ body
      if (userId != null && userId.isNotEmpty) {
        body['user_id'] = userId;
      }

      // ✅ لو في category، نضيفه للـ body
      if (category != null && category.isNotEmpty) {
        body['category'] = category;
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

  // Search items by name
  static Future<Map<String, dynamic>> searchItems(String query) async {
    try {
      final response = await Dio().get(
        '$baseUrl/search.php?q=$query&store_id=${AppConfig.storeId}&k=${DateTime.now().millisecondsSinceEpoch}',
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to search items: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Search error: $e');
    }
  }

  // Get user profile
  static Future getUserProfile(int userId) async {
    try {
      final response = await Dio().get(
        '$baseUrl/profile.php?user_id=$userId',
        options: Options(headers: {'Content-Type': 'application/json'}),
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

  static Future getUserProfileItems(int userId, {int limit = 20, int offset = 0, String sort = 'views'}) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "fetch_items_one_account",
          "uid": userId,
          "limit": limit,
          "offset": offset,
          "sort": sort,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
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
  static Future getComments(int itemId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/comments.php?item_id=$itemId&k=${DateTime.now().millisecondsSinceEpoch}'),
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
    required int userId,
    required String comment,
  }) async {
    try {
      print(DateTime.now().toString());
      final response = await http.post(
        Uri.parse('$baseUrl/comments.php?item_id=$itemId'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'comment': comment,
          'user_id': userId,
          'created_atx': DateTime.now().toString(),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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

  // Fetch items with likes status
  static Future<List<ItemModel>> fetchItemsWithLikes({
    required String userId,
    int limit = 10,
    int offset = 0,
    String? initialItemId,
    String? category,
    String? country,
  }) async {
    try {
      final Map<String, dynamic> requestData = {
        "action": "fetch_with_likes",
        "user_id": userId,
        "limit": limit.toString(),
        "offset": offset.toString(),
        'country': country,
        'store_id': AppConfig.storeId
      };

      // ✅ لو في category، نضيفه للـ request
      if (category != null && category.isNotEmpty) {
        initialItemId = null;
        requestData['category'] = category;
      }

      if (initialItemId != null && initialItemId.isNotEmpty) {
        requestData['itemSrchId'] = initialItemId;
      }

      print('📦 fetchItemsWithLikes Request: $requestData');

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(requestData),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final data = response.data;
        if (data['success'] == true) {
          final List<dynamic> itemsData = data['data'] ?? [];
          return itemsData.map((item) {
            // Create ItemModel with likes data
            final itemModel = ItemModel.fromJson(item);
            // Update interactions with server data
            itemModel.interactions.likes = item['likes_count'] ?? 0;
            itemModel.interactions.isLiked = item['is_liked'] ?? false;
            // Update seller following status from seller data
            if (item['seller'] != null &&
                item['seller']['isFollowing'] != null) {
              itemModel.seller.isFollowing = item['seller']['isFollowing'];
            }
            return itemModel;
          }).toList();
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
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({"action": "get_from_cart", "user_id": userId, 'store_id': AppConfig.storeId}),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        return response.data;
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
    required String name,
    required String phone,
    File? avatar,
  }) async {
    try {
      // First, upload avatar if provided
      if (avatar != null) {
        await _uploadAvatar(uid, avatar);
      }

      // Update user info in database
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "update_user_profile",
          "uid": uid,
          "name": name,
          "phone": phone,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
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

  // Upload avatar to Bunny.net
  static Future<void> _uploadAvatar(String uid, File avatar) async {
    try {
      List<int> fileBytes = await avatar.readAsBytes();

      await Dio().put(
        "https://storage.bunnycdn.com/globee-trading/users/$uid/avatar.jpg",
        data: Stream.fromIterable([fileBytes]),
        options: Options(
          headers: {
            "AccessKey": "18808acb-f5f1-473e-bd84cf669411-20c0-499c",
            "Content-Type": "application/octet-stream",
          },
        ),
      );
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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
        options: Options(headers: {'Content-Type': 'application/json'}),
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

  // Get my orders as buyer
  static Future<Map<String, dynamic>> getMyOrders({
    required String custId,
  }) async {
    try {
      print('🔍 API getMyOrders - Sending request with cust_id: $custId');
      
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({"action": "get_my_orders", "cust_id": custId}),
        options: Options(headers: {'Content-Type': 'application/json'}),
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

  // Get customer orders as seller
  static Future<Map<String, dynamic>> getCustomerOrders({
    required String uid,
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({"action": "get_customer_orders", "uid": uid}),
        options: Options(headers: {'Content-Type': 'application/json'}),
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
  }) async {
    try {
      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap({
          "action": "update_order_status",
          "order_id": orderId,
          "status": status,
        }),
        options: Options(headers: {'Content-Type': 'application/json'}),
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
      final data = <String, dynamic>{
        "action": "get_group",
      };
      final resolvedStoreId = storeId ?? AppConfig.storeId;

      if (resolvedStoreId.isNotEmpty) {
        data["store_id"] = resolvedStoreId;
      }

      final response = await Dio().post(
        '$baseUrl/sql.php?k=${DateTime.now().millisecondsSinceEpoch}',
        data: FormData.fromMap(data),
        options: Options(headers: {'Content-Type': 'application/json'}),
      );

      if (response.statusCode == 200) {
        final result = response.data;
        if (result['success'] == true) {
          final List<dynamic> categoriesData = result['data'] ?? [];
          return categoriesData
              .map((item) => item['category'] as String)
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
}


// AKIARVJRTCELECEKHATH

// rbxI5l6k7GSVwQyxL8rsBYgqe69GtjJhc+TDbEXe