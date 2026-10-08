import "dart:convert";
import "dart:io";

import "package:crypto/crypto.dart";
import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:image/image.dart" as img;
import "package:path/path.dart" as path;

Uint8List convertImageToJpg(Uint8List bytes) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    throw Exception("Failed to decode image");
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
}

class S3UploadService {
  static const String _accessKey = "AKIARVJRTCELH4VUZZ73";
  static const String _secretKey = "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";
  static const String _region = "ap-south-1";
  static const String _bucket = "martit";
  static const String _baseUrl = "https://martit.s3.ap-south-1.amazonaws.com";
  static const String _storeFolder = "store_2";
  static const String _host = "martit.s3.ap-south-1.amazonaws.com";
  static const String _globalFarmBaseUrl =
      "https://globalfarmnursery.s3.ap-south-1.amazonaws.com";
  static const String _globalFarmHost =
      "globalfarmnursery.s3.ap-south-1.amazonaws.com";

  static final Dio _dio = Dio();

  static bool _isVideoExtension(String extension) {
    return extension == ".mp4" || extension == ".mov" || extension == ".avi";
  }

  static bool _isImageExtension(String extension) {
    return extension == ".jpg" ||
        extension == ".jpeg" ||
        extension == ".png" ||
        extension == ".gif" ||
        extension == ".webp";
  }

  static Future<List<String>> uploadMediaFiles({
    required List<String> filePaths,
    required String clientItemId,
    int startIndex = 0,
    bool uploadToGlobalFarmNursery = false,
    Function(int current, int total, double progress)? onProgress,
  }) async {
    final uploadedUrls = <String>[];

    try {
      for (int i = 0; i < filePaths.length; i++) {
        final file = File(filePaths[i]);
        if (!file.existsSync()) continue;

        final extension = path.extension(filePaths[i]).toLowerCase();
        if (!_isImageExtension(extension) && !_isVideoExtension(extension)) {
          continue;
        }

        final String fileName;
        final List<int> payload;

        if (_isVideoExtension(extension)) {
          fileName = "${startIndex + i + 1}$extension";
          payload = await file.readAsBytes();
        } else {
          fileName = "${startIndex + i + 1}.jpg";
          try {
            final bytes = await file.readAsBytes();
            payload = await compute(convertImageToJpg, bytes);
          } catch (e) {
            print("Failed to convert image: ${filePaths[i]} — $e");
            continue;
          }
        }

        final objectKey = "$_storeFolder/$clientItemId/$fileName";
        final uploadUrl = await _uploadBytes(
          payload,
          objectKey,
          onProgress: (progress) {
            onProgress?.call(i + 1, filePaths.length, progress);
          },
        );
        if (uploadUrl != null) {
          uploadedUrls.add(uploadUrl);

          if (uploadToGlobalFarmNursery && !_isVideoExtension(extension)) {
            final mediaIndex = startIndex + i + 1;
            final globalFarmObjectKey = mediaIndex == 1
                ? "items/$clientItemId.jpg"
                : "items/${clientItemId}_$mediaIndex.jpg";
            await _uploadBytes(
              payload,
              globalFarmObjectKey,
              contentType: "image/jpeg",
              baseUrl: _globalFarmBaseUrl,
              host: _globalFarmHost,
            );
          }
        }
      }

      return uploadedUrls;
    } catch (e) {
      print("Error uploading files: $e");
      return [];
    }
  }

  /// Customer app reads `items/{clientItemId}.jpg` on globalfarmnursery bucket.
  static Future<void> uploadGlobalFarmPrimaryImage({
    required String clientItemId,
    required String filePath,
  }) async {
    if (clientItemId.isEmpty) return;
    try {
      final file = File(filePath);
      if (!file.existsSync()) return;

      final bytes = await file.readAsBytes();
      final jpgBytes = await compute(convertImageToJpg, bytes);
      await _uploadBytes(
        jpgBytes,
        "items/$clientItemId.jpg",
        contentType: "image/jpeg",
        baseUrl: _globalFarmBaseUrl,
        host: _globalFarmHost,
      );
    } catch (e) {
      print("GlobalFarm primary image upload failed: $e");
    }
  }

  static Future<String?> uploadProfileImage({
    required String userId,
    required String filePath,
    Function(double progress)? onProgress,
  }) async {
    if (userId.isEmpty) {
      print("Profile upload skipped: userId is empty");
      return null;
    }

    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        print("Profile upload skipped: file not found");
        return null;
      }

      final bytes = await file.readAsBytes();
      final jpgBytes = await compute(convertImageToJpg, bytes);
      final objectKey = "Users/store_2/$userId/1.jpg";

      return _uploadBytes(
        jpgBytes,
        objectKey,
        contentType: "image/jpeg",
        onProgress: onProgress,
      );
    } catch (e) {
      print("Error uploading profile image: $e");
      return null;
    }
  }

  static Future<String?> uploadBytes({
    required List<int> bytes,
    required String objectKey,
    String? contentType,
    Function(double progress)? onProgress,
  }) async {
    return _uploadBytes(
      bytes,
      objectKey,
      contentType: contentType,
      onProgress: onProgress,
    );
  }

  static Future<String?> _uploadBytes(
    List<int> bytes,
    String objectKey, {
    String? contentType,
    Function(double progress)? onProgress,
    String baseUrl = _baseUrl,
    String host = _host,
  }) async {
    try {
      final resolvedContentType = contentType ?? _getContentType(objectKey);
      final headers = _signedHeaders(
        method: "PUT",
        objectKey: objectKey,
        contentType: resolvedContentType,
        payload: bytes,
        host: host,
      );

      final response = await _dio.put(
        "$baseUrl/$objectKey",
        data: bytes,
        options: Options(headers: headers),
        onSendProgress: (sent, total) {
          final progress = total != 0 ? sent / total : 0.0;
          onProgress?.call(progress);
          print(
            "Uploading $objectKey: ${(progress * 100).toStringAsFixed(1)}%",
          );
        },
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final url = "$baseUrl/$objectKey";
        print("Uploaded: $url");
        return url;
      }

      print("Upload failed for $objectKey: ${response.statusCode}");
      return null;
    } catch (e) {
      print("Error uploading $objectKey: $e");
      return null;
    }
  }

  static Future<bool> deleteFile(String remotePath) async {
    try {
      final objectKey = remotePath.startsWith("$_storeFolder/")
          ? remotePath
          : "$_storeFolder/$remotePath";
      final headers = _signedHeaders(
        method: "DELETE",
        objectKey: objectKey,
        contentType: "application/octet-stream",
        payload: const [],
      );

      final response = await _dio.delete(
        "$_baseUrl/$objectKey",
        options: Options(headers: headers),
      );

      return response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
    } catch (e) {
      print("Error deleting file: $e");
      return false;
    }
  }

  /// Deletes a banner by its full URL or object key.
  static Future<bool> deleteBannerImage(String urlOrKey) async {
    try {
      // استخرج الـ object key من الـ URL الكامل
      final objectKey = urlOrKey.startsWith('http')
          ? Uri.parse(urlOrKey).path.replaceFirst('/', '')
          : urlOrKey;

      final headers = _signedHeaders(
        method: "DELETE",
        objectKey: objectKey,
        contentType: "application/octet-stream",
        payload: const [],
      );

      final response = await _dio.delete(
        "$_baseUrl/$objectKey",
        options: Options(headers: headers),
      );

      return response.statusCode == 200 ||
          response.statusCode == 204 ||
          response.statusCode == 404;
    } catch (e) {
      print("Error deleting banner: $e");
      return false;
    }
  }

  /// Lists image URLs under `store_{storeId}/banners/` on Martit S3.
  static Future<List<String>> listBannerUrls({String? storeId}) async {
    final folder = (storeId != null && storeId.isNotEmpty)
        ? "store_$storeId"
        : _storeFolder;
    final prefix = "$folder/banners/";
    try {
      final query = <String, String>{
        "list-type": "2",
        "prefix": prefix,
      };
      final headers = _signedHeaders(
        method: "GET",
        objectKey: "",
        contentType: "application/octet-stream",
        payload: const [],
        queryParameters: query,
      );

      final canonicalQuery = _canonicalQueryString(query);
      final response = await _dio.get(
        "https://$_host/?$canonicalQuery",
        options: Options(
          headers: headers,
          responseType: ResponseType.plain,
        ),
      );

      if (response.statusCode != 200 || response.data == null) {
        print("listBannerUrls failed: ${response.statusCode}");
        return [];
      }

      final xml = response.data.toString();
      final keys = RegExp(r"<Key>([^<]+)</Key>")
          .allMatches(xml)
          .map((m) => m.group(1)!)
          .where((key) {
            if (!key.startsWith(prefix)) return false;
            if (key == prefix || key.endsWith("/")) return false;
            final lower = key.toLowerCase();
            return lower.endsWith(".jpg") ||
                lower.endsWith(".jpeg") ||
                lower.endsWith(".png") ||
                lower.endsWith(".webp") ||
                lower.endsWith(".gif");
          })
          .toList();

      keys.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      return keys.map((key) => "$_baseUrl/$key").toList();
    } catch (e) {
      print("Error listing banners: $e");
      return [];
    }
  }

  /// Upload a banner image to `store_{storeId}/banners/{fileName}`.
  static Future<String?> uploadBannerImage({
    required String filePath,
    String? storeId,
    String? fileName,
    Function(double progress)? onProgress,
  }) async {
    try {
      final file = File(filePath);
      if (!file.existsSync()) return null;

      final folder = (storeId != null && storeId.isNotEmpty)
          ? "store_$storeId"
          : _storeFolder;
      final extension = path.extension(filePath).toLowerCase();
      final stamp = DateTime.now().millisecondsSinceEpoch.toString();
      final resolvedName = fileName?.trim().isNotEmpty == true
          ? fileName!.trim()
          : "$stamp.jpg";

      late final List<int> payload;
      late final String objectKey;

      if (_isImageExtension(extension) &&
          extension != ".gif" &&
          extension != ".webp" &&
          extension != ".png") {
        final bytes = await file.readAsBytes();
        payload = await compute(convertImageToJpg, bytes);
        final base = path.basenameWithoutExtension(resolvedName);
        objectKey = "$folder/banners/$base.jpg";
      } else if (_isImageExtension(extension)) {
        payload = await file.readAsBytes();
        final base = path.basenameWithoutExtension(resolvedName);
        objectKey = "$folder/banners/$base$extension";
      } else {
        final bytes = await file.readAsBytes();
        payload = await compute(convertImageToJpg, bytes);
        objectKey = "$folder/banners/$stamp.jpg";
      }

      return _uploadBytes(
        payload,
        objectKey,
        contentType: _getContentType(objectKey),
        onProgress: onProgress,
      );
    } catch (e) {
      print("Error uploading banner: $e");
      return null;
    }
  }

  static Map<String, String> _signedHeaders({
    required String method,
    required String objectKey,
    required String contentType,
    required List<int> payload,
    String host = _host,
    Map<String, String>? queryParameters,
  }) {
    final now = DateTime.now().toUtc();
    final amzDate = _formatAmzDate(now);
    final dateStamp = _formatDateStamp(now);
    final payloadHash = sha256.convert(payload).toString();
    final canonicalUri =
        objectKey.isEmpty ? "/" : _canonicalUri(objectKey);
    final canonicalQuery = _canonicalQueryString(queryParameters);

    final canonicalHeaders =
        "content-type:$contentType\n"
        "host:$host\n"
        "x-amz-content-sha256:$payloadHash\n"
        "x-amz-date:$amzDate\n";
    const signedHeaders = "content-type;host;x-amz-content-sha256;x-amz-date";

    final canonicalRequest =
        "$method\n"
        "$canonicalUri\n"
        "$canonicalQuery\n"
        "$canonicalHeaders\n"
        "$signedHeaders\n"
        "$payloadHash";

    final credentialScope = "$dateStamp/$_region/s3/aws4_request";
    final stringToSign =
        "AWS4-HMAC-SHA256\n"
        "$amzDate\n"
        "$credentialScope\n"
        "${sha256.convert(utf8.encode(canonicalRequest))}";

    final signingKey = _getSignatureKey(_secretKey, dateStamp, _region, "s3");
    final signature = Hmac(
      sha256,
      signingKey,
    ).convert(utf8.encode(stringToSign)).toString();

    final authorization =
        "AWS4-HMAC-SHA256 "
        "Credential=$_accessKey/$credentialScope, "
        "SignedHeaders=$signedHeaders, "
        "Signature=$signature";

    return {
      "Authorization": authorization,
      "Content-Type": contentType,
      "x-amz-date": amzDate,
      "x-amz-content-sha256": payloadHash,
      "Host": host,
    };
  }

  static String _canonicalQueryString(Map<String, String>? params) {
    if (params == null || params.isEmpty) return "";
    final keys = params.keys.toList()..sort();
    return keys
        .map(
          (k) =>
              "${Uri.encodeQueryComponent(k)}=${Uri.encodeQueryComponent(params[k]!)}",
        )
        .join("&");
  }

  static List<int> _getSignatureKey(
    String secretKey,
    String dateStamp,
    String region,
    String service,
  ) {
    final kDate = Hmac(
      sha256,
      utf8.encode("AWS4$secretKey"),
    ).convert(utf8.encode(dateStamp)).bytes;
    final kRegion = Hmac(sha256, kDate).convert(utf8.encode(region)).bytes;
    final kService = Hmac(sha256, kRegion).convert(utf8.encode(service)).bytes;
    return Hmac(sha256, kService).convert(utf8.encode("aws4_request")).bytes;
  }

  static String _canonicalUri(String objectKey) {
    return "/${objectKey.split("/").map(Uri.encodeComponent).join("/")}";
  }

  static String _formatAmzDate(DateTime dateTime) {
    return "${dateTime.year.toString().padLeft(4, "0")}"
        "${dateTime.month.toString().padLeft(2, "0")}"
        "${dateTime.day.toString().padLeft(2, "0")}"
        "T"
        "${dateTime.hour.toString().padLeft(2, "0")}"
        "${dateTime.minute.toString().padLeft(2, "0")}"
        "${dateTime.second.toString().padLeft(2, "0")}"
        "Z";
  }

  static String _formatDateStamp(DateTime dateTime) {
    return "${dateTime.year.toString().padLeft(4, "0")}"
        "${dateTime.month.toString().padLeft(2, "0")}"
        "${dateTime.day.toString().padLeft(2, "0")}";
  }

  static String _getContentType(String filePath) {
    final extension = path.extension(filePath).toLowerCase();
    switch (extension) {
      case ".jpg":
      case ".jpeg":
        return "image/jpeg";
      case ".png":
        return "image/png";
      case ".gif":
        return "image/gif";
      case ".webp":
        return "image/webp";
      case ".mp4":
        return "video/mp4";
      case ".mov":
        return "video/quicktime";
      case ".avi":
        return "video/x-msvideo";
      default:
        return "application/octet-stream";
    }
  }
}
