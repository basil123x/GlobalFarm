import "dart:io";

import "package:dio/dio.dart";

import "../utils/avatar_url_util.dart";
import "auth_service.dart";
import "s3_upload_service.dart";

class AvatarService {
  static final Dio _dio = Dio();

  static Future<bool> s3AvatarExists(String userId) async {
    if (userId.isEmpty) return false;
    try {
      final response = await _dio.head(AvatarUrlUtil.s3Path(userId));
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Uploads social photo to S3 only when no custom avatar exists yet.
  static Future<void> uploadSocialPhotoIfNeeded({
    required String userId,
    required String? photoUrl,
  }) async {
    if (userId.isEmpty || photoUrl == null || photoUrl.isEmpty) return;
    if (await s3AvatarExists(userId)) return;

    File? tempFile;
    try {
      final response = await _dio.get<List<int>>(
        photoUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return;

      tempFile = File(
        "${Directory.systemTemp.path}/avatar_${userId}_${DateTime.now().millisecondsSinceEpoch}.png",
      );
      await tempFile.writeAsBytes(bytes);

      final s3Url = await S3UploadService.uploadProfileImage(
        userId: userId,
        filePath: tempFile.path,
      );

      if (s3Url != null) {
        await AuthService.updateUserAvatarUrl(uid: userId, avatarUrl: s3Url);
        await AuthService.updateProfileImage(s3Url);
      }
    } catch (e) {
      print("Failed to upload social avatar: $e");
    } finally {
      if (tempFile != null && tempFile.existsSync()) {
        await tempFile.delete();
      }
    }
  }
}
