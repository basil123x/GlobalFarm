import "dart:math";

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:onesignal_flutter/onesignal_flutter.dart";
import "package:sign_in_with_apple/sign_in_with_apple.dart";
import "package:GlobalFarm/core/constants/app_config.dart";
import "package:GlobalFarm/core/services/auth_service.dart";

class AppleAuthResult {
  final String uid;
  final String oid;
  final String email;
  final String name;
  final String? role;
  final String? storeId;

  const AppleAuthResult({
    required this.uid,
    required this.oid,
    required this.email,
    required this.name,
    this.role,
    this.storeId,
  });
}

class AppleAuthService {
  static String get _apiUrl => "${AppConfig.apiBaseUrl}/sql.php";
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static String _cacheKey(String userIdentifier, String field) {
    return "apple_${userIdentifier}_$field";
  }

  static Future<AppleAuthResult?> signIn() async {
    try {
      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final userIdentifier = credential.userIdentifier ?? "";
      if (userIdentifier.isEmpty) {
        throw Exception("Apple user identifier is missing");
      }

      String? email = credential.email;
      if (email != null && email.isNotEmpty) {
        await _storage.write(
          key: _cacheKey(userIdentifier, "email"),
          value: email,
        );
      } else {
        email = await _storage.read(key: _cacheKey(userIdentifier, "email"));
      }

      if (email == null || email.isEmpty) {
        throw Exception(
          "Apple email is unavailable. Sign in with Apple again.",
        );
      }

      String fullName = "";
      final givenName = credential.givenName ?? "";
      final familyName = credential.familyName ?? "";
      if (givenName.isNotEmpty || familyName.isNotEmpty) {
        fullName = "$givenName $familyName".trim();
        await _storage.write(
          key: _cacheKey(userIdentifier, "name"),
          value: fullName,
        );
      } else {
        fullName =
            await _storage.read(key: _cacheKey(userIdentifier, "name")) ?? "";
      }

      if (fullName.isEmpty) {
        fullName = email.contains("@") ? email.split("@").first : "Apple User";
      }

      if (kDebugMode) {
        print("Apple Sign In — userId: $userIdentifier, email: $email");
      }

      final cacheBust =
          "$_apiUrl?k=${DateTime.now().millisecondsSinceEpoch}";

      // Look up existing account by email (no token verification — credential only)
      final checkResponse = await Dio().post(
        cacheBust,
        data: FormData.fromMap({
          "action": "get_user_by_email",
          "email": email,
        }),
      );

      if (kDebugMode) {
        print("Apple get_user_by_email response: ${checkResponse.data}");
      }

      final checkData = checkResponse.data;
      if (checkData is! Map) {
        throw Exception("Invalid API response for Apple sign in");
      }

      final checkMap = Map<String, dynamic>.from(checkData);
      final message = checkMap["message"]?.toString() ?? "";

      // Existing user — success true with data
      if (checkMap["success"] == true && checkMap["data"] != null) {
        final userData = Map<String, dynamic>.from(
          checkMap["data"] as Map,
        );
        await _updateFcmToken(email);
        return AppleAuthResult(
          uid: userData["id"]?.toString() ?? "",
          oid: userData["oid"]?.toString() ?? "",
          email: userData["email"]?.toString() ?? email,
          name: userData["name"]?.toString() ?? fullName,
          role: userData["role"]?.toString(),
          storeId:
              userData["store_id"]?.toString() ??
              userData["storeid"]?.toString(),
        );
      }

      // New user — API returns success: false, message: "المستخدم غير موجود"
      if (message == "المستخدم غير موجود") {
        return await _createAppleAccount(
          email: email,
          fullName: fullName,
          cacheBust: cacheBust,
        );
      }

      throw Exception(
        message.isNotEmpty
            ? message
            : checkMap["error"]?.toString() ?? "Failed to verify Apple account",
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (kDebugMode) {
        print("Apple Sign In authorization error: ${e.code} — ${e.message}");
      }
      rethrow;
    } catch (e, stack) {
      if (kDebugMode) {
        print("Apple Sign In error: $e");
        print(stack);
      }
      rethrow;
    }
  }

  static Future<AppleAuthResult> _createAppleAccount({
    required String email,
    required String fullName,
    required String cacheBust,
  }) async {
    final uid = (1000 + Random().nextInt(9000)).toString();
    final oid = (1000 + Random().nextInt(9000)).toString();
    final String? playerId = OneSignal.User.pushSubscription.id;

    final createResponse = await Dio().post(
      cacheBust,
      data: FormData.fromMap({
        "action": "create_social_account",
        "name": fullName,
        "email": email,
        "login_type": "Apple",
        "player_id": playerId ?? "",
        "avatar_url": "",
        "store_id": AppConfig.storeId,
      }),
    );

    if (kDebugMode) {
      print("Apple create_social_account response: ${createResponse.data}");
    }

    final createData = createResponse.data;
    if (createData is! Map || createData["success"] != true) {
      throw Exception(
        createData is Map
            ? createData["message"]?.toString() ??
                createData["error"]?.toString() ??
                "Failed to create Apple account"
            : "Failed to create Apple account",
      );
    }

    await _updateFcmToken(email);

    final data = createData["data"] is Map
        ? Map<String, dynamic>.from(createData["data"] as Map)
        : null;

    return AppleAuthResult(
      uid: data?["id"]?.toString() ?? uid,
      oid: data?["oid"]?.toString() ?? oid,
      email: data?["email"]?.toString() ?? email,
      name: data?["name"]?.toString() ?? fullName,
      role: data?["role"]?.toString(),
      storeId: data?["store_id"]?.toString() ?? data?["storeid"]?.toString(),
    );
  }

  static Future<void> saveSession(AppleAuthResult result) async {
    await _storage.write(key: "user_uid", value: result.uid);
    await _storage.write(key: "user_oid", value: result.oid);
    await _storage.write(key: "user_email", value: result.email);
    await _storage.write(key: "social_email", value: result.email);
    await _storage.write(key: "user_name", value: result.name);
    await _storage.write(key: "social_name", value: result.name);
    await _storage.write(key: "login_type", value: "Apple");
    await AuthService.saveUserRoleAndStore(result.role, result.storeId);
  }

  static Future<void> _updateFcmToken(String email) async {
    try {
      final String? playerId = OneSignal.User.pushSubscription.id;
      await Dio().post(
        "$_apiUrl?k=${DateTime.now().millisecondsSinceEpoch}",
        data: FormData.fromMap({
          "action": "update_fcm_token",
          "email": email,
          "fcm_token": playerId,
        }),
      );
    } catch (e) {
      if (kDebugMode) {
        print("Apple FCM token update failed (non-fatal): $e");
      }
    }
  }
}
