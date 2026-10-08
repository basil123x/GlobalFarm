import 'package:GlobalFarm/core/constants/app_config.dart';

class ItemMediaUrlUtil {
  static const String baseUrl = "https://martit.s3.ap-south-1.amazonaws.com";

  static String normalizeStoreId(String? storeId) {
    final value = storeId?.trim() ?? "";
    return value.isEmpty ? "1" : value;
  }

  /// S3 object folder uses [itemIdx] when set; otherwise falls back to [itemId].
  static String resolveItemPathKey({
    required String? itemIdx,
    required String itemId,
  }) {
    final idx = itemIdx?.trim() ?? "";
    if (idx.isNotEmpty) return idx;
    final id = itemId.trim();
    return id.isNotEmpty ? id : "1";
  }

  static String mediaUrl({
    required String? storeId,
    required String itemId,
    String? itemIdx,
    int index = 1,
    String extension = 'webp',
  }) {
    final store = normalizeStoreId(storeId);
    final pathKey = resolveItemPathKey(itemIdx: itemIdx, itemId: itemId);
    final safeIndex = index < 1 ? 1 : index;
    final ext = extension.toLowerCase() == 'jpeg' ? 'jpg' : extension.toLowerCase();
    return "$baseUrl/store_$store/$pathKey/$safeIndex.$ext";
  }

  static String? extensionFromFileName(String fileName) {
    final lower = fileName.trim().toLowerCase();
    if (lower.endsWith('.mp4')) return 'mp4';
    if (lower.endsWith('.mov')) return 'mov';
    if (lower.endsWith('.avi')) return 'avi';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    return null;
  }

  static List<String> mediaUrlsFromDbValue({
    required String mediaValue,
    required String storeId,
    required String itemId,
    String? itemIdx,
  }) {
    final urls = <String>[];
    for (final raw in mediaValue.split(',')) {
      final file = raw.trim();
      if (file.isEmpty) continue;

      if (file.startsWith('http')) {
        urls.add(normalizeMediaUrl(
          url: file,
          storeId: storeId,
          itemId: itemId,
          itemIdx: itemIdx,
        ));
        continue;
      }

      final match = RegExp(
        r'^(\d+)\.(\w+)$',
        caseSensitive: false,
      ).firstMatch(file);
      if (match == null) continue;

      var ext = match.group(2)!.toLowerCase();
      if (ext == 'jpeg') ext = 'jpg';
      urls.add(
        mediaUrl(
          storeId: storeId,
          itemId: itemId,
          itemIdx: itemIdx,
          index: int.parse(match.group(1)!),
          extension: ext,
        ),
      );
    }
    return urls;
  }

  static String normalizeMediaUrl({
    required String url,
    required String storeId,
    required String itemId,
    String? itemIdx,
  }) {
    final fileName = url.split('/').last.split('?').first.trim();
    final ext = extensionFromFileName(fileName);
    final indexMatch = RegExp(r'^(\d+)\.').firstMatch(fileName);
    if (ext != null && indexMatch != null) {
      return mediaUrl(
        storeId: storeId,
        itemId: itemId,
        itemIdx: itemIdx,
        index: int.parse(indexMatch.group(1)!),
        extension: ext,
      );
    }
    return url;
  }

  static bool isVideoExtension(String ext) {
    final normalized = ext.toLowerCase();
    return normalized == 'mp4' || normalized == 'mov' || normalized == 'avi';
  }

  static bool isImageExtension(String ext) {
    final normalized = ext.toLowerCase();
    return normalized == 'jpg' ||
        normalized == 'jpeg' ||
        normalized == 'webp' ||
        normalized == 'png';
  }

  static bool isVideoUrl(String url) {
    final ext = extensionFromFileName(url.split('/').last.split('?').first);
    return ext != null && isVideoExtension(ext);
  }

  static bool isImageUrl(String url) {
    final ext = extensionFromFileName(url.split('/').last.split('?').first);
    return ext != null && isImageExtension(ext);
  }

  static List<String> _collectMediaUrls({
    List<String>? mediaUrls,
    String? mediaValue,
    String? storeId,
    required String itemId,
    String? itemIdx,
  }) {
    if (mediaUrls != null && mediaUrls.isNotEmpty) {
      return mediaUrls
          .map(
            (url) => normalizeMediaUrl(
              url: url,
              storeId: storeId ?? AppConfig.storeId,
              itemId: itemId,
              itemIdx: itemIdx,
            ),
          )
          .toList();
    }
    if (mediaValue != null && mediaValue.trim().isNotEmpty) {
      return mediaUrlsFromDbValue(
        mediaValue: mediaValue,
        storeId: storeId ?? AppConfig.storeId,
        itemId: itemId,
        itemIdx: itemIdx,
      );
    }
    return const [];
  }

  /// First image in upload order; if none, first video; else index 1 jpg.
  static String resolveThumbnailUrl({
    List<String>? mediaUrls,
    String? mediaValue,
    String? storeId,
    required String itemId,
    String? itemIdx,
    String? preferredUrl,
  }) {
    if (preferredUrl != null && preferredUrl.trim().isNotEmpty) {
      final clean = preferredUrl.split(']')[0].trim();
      if (clean.startsWith('http')) {
        return clean;
      }
      final normalized = normalizeMediaUrl(
        url: clean,
        storeId: storeId ?? AppConfig.storeId,
        itemId: itemId,
        itemIdx: itemIdx,
      );
      if (!isVideoUrl(normalized)) {
        return normalized;
      }
    }

    final urls = _collectMediaUrls(
      mediaUrls: mediaUrls,
      mediaValue: mediaValue,
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
    );

    String? firstVideo;
    for (final url in urls) {
      if (isImageUrl(url)) return url;
      if (isVideoUrl(url) && firstVideo == null) firstVideo = url;
    }
    if (firstVideo != null) return firstVideo;

    return mediaUrl(
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
      index: 1,
      extension: 'webp',
    );
  }

  /// For sharing — images only.
  static String? resolveShareImageUrl({
    List<String>? mediaUrls,
    String? mediaValue,
    String? storeId,
    required String itemId,
    String? itemIdx,
  }) {
    for (final url in _collectMediaUrls(
      mediaUrls: mediaUrls,
      mediaValue: mediaValue,
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
    )) {
      if (isImageUrl(url)) return url;
    }
    return null;
  }

  static String thumbnailFromItem({
    required List<String> media,
    required String? storeId,
    required String itemId,
    String? itemIdx,
  }) {
    return resolveThumbnailUrl(
      mediaUrls: media,
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
    );
  }

  static String thumbnail({
    required String? storeId,
    required String itemId,
    String? itemIdx,
    String? mediaValue,
    List<String>? mediaUrls,
    String extension = 'jpg',
  }) {
    if ((mediaValue != null && mediaValue.isNotEmpty) ||
        (mediaUrls != null && mediaUrls.isNotEmpty)) {
      return resolveThumbnailUrl(
        mediaValue: mediaValue,
        mediaUrls: mediaUrls,
        storeId: storeId,
        itemId: itemId,
        itemIdx: itemIdx,
      );
    }
    return mediaUrl(
      storeId: storeId,
      itemId: itemId,
      itemIdx: itemIdx,
      index: 1,
      extension: extension,
    );
  }
}
