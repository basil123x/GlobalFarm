import "package:cached_network_image/cached_network_image.dart";
import "package:dio/dio.dart";
import "package:flutter/material.dart";
import "package:flutter_spinkit/flutter_spinkit.dart";
import "package:iconsax/iconsax.dart";

import "../utils/item_media_url_util.dart";
import "../constants/app_colors.dart";
import "video_player_widget.dart";

class MediaViewerWidget extends StatefulWidget {
  static const String s3BaseUrl = "https://martit.s3.ap-south-1.amazonaws.com";

  final List<String> mediaUrls;
  final String itmId;
  final String itmIdx;
  final String storeid;
  final bool autoPlayVideo;
  final bool showControls;
  final bool showIndicators;
  final VoidCallback? onMediaUnavailable;

  const MediaViewerWidget({
    super.key,
    required this.mediaUrls,
    required this.itmId,
    required this.itmIdx,
    required this.storeid,
    this.autoPlayVideo = true,
    this.showControls = false,
    this.showIndicators = true,
    this.onMediaUnavailable,
  });

  @override
  State<MediaViewerWidget> createState() => _MediaViewerWidgetState();
}

class _MediaViewerWidgetState extends State<MediaViewerWidget> {
  static const int _maxImages = 20;

  final PageController _pageController = PageController();
  final Dio _dio = Dio();
  int _currentIndex = 0;
  late Future<List<String>> _mediaFuture;
  bool _unavailableReported = false;

  @override
  void initState() {
    super.initState();
    _mediaFuture = _resolveMediaUrlsDeferred();
  }

  @override
  void didUpdateWidget(MediaViewerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.itmId != widget.itmId ||
        oldWidget.itmIdx != widget.itmIdx ||
        oldWidget.storeid != widget.storeid ||
        oldWidget.mediaUrls.length != widget.mediaUrls.length ||
        !_sameMediaUrls(oldWidget.mediaUrls, widget.mediaUrls)) {
      _unavailableReported = false;
      _mediaFuture = _resolveMediaUrlsDeferred();
    }
  }

  bool _sameMediaUrls(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  void _reportMediaUnavailable() {
    if (_unavailableReported || widget.onMediaUnavailable == null) return;
    _unavailableReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.onMediaUnavailable?.call();
    });
  }

  bool get _hideUnavailablePlaceholder => widget.onMediaUnavailable != null;

  Future<List<String>> _resolveMediaUrlsDeferred() async {
    await Future<void>.delayed(Duration.zero);
    if (!mounted) {
      return [];
    }
    return _resolveMediaUrls();
  }

  String _mediaUrl(int index, String ext) {
    final pathKey = ItemMediaUrlUtil.resolveItemPathKey(
      itemIdx: widget.itmIdx,
      itemId: widget.itmId,
    );
    return "${MediaViewerWidget.s3BaseUrl}/store_${ItemMediaUrlUtil.normalizeStoreId(widget.storeid)}/$pathKey/$index.$ext";
  }

  Future<bool> _urlExists(String url) async {
    try {
      final response = await _dio.head(
        url,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      debugPrint("MediaViewerWidget: HEAD failed for $url: $e");
      return false;
    }
  }

  static final RegExp _filePattern = RegExp(
    r"(\d+)\.(webp|jpg|jpeg|mp4|mov|avi)",
    caseSensitive: false,
  );

  List<({int index, String ext})> _parseMediaSlots() {
    final slots = <({int index, String ext})>[];

    for (final mediaUrl in widget.mediaUrls) {
      final normalized = mediaUrl.split("]")[0].trim();
      if (normalized.isEmpty) continue;

      final match = _filePattern.firstMatch(normalized);
      if (match != null) {
        var ext = match.group(2)!.toLowerCase();
        if (ext == "jpeg") ext = "jpg";
        slots.add((index: int.parse(match.group(1)!), ext: ext));
        continue;
      }

      final fileName = normalized.split("/").last.split("?").first;
      final ext = ItemMediaUrlUtil.extensionFromFileName(fileName);
      final indexMatch = RegExp(r"^(\d+)\.").firstMatch(fileName);
      if (ext != null && indexMatch != null) {
        slots.add((
          index: int.parse(indexMatch.group(1)!),
          ext: ext,
        ));
      }
    }
    return slots;
  }

  bool _isVideoExt(String ext) {
    return ext == "mp4" || ext == "mov" || ext == "avi";
  }

  Future<String> _resolveSlotUrl(({int index, String ext}) slot) async {
    if (_isVideoExt(slot.ext)) {
      return _mediaUrl(slot.index, slot.ext);
    }
    if (slot.ext == "jpg") {
      return _mediaUrl(slot.index, "jpg");
    }
    // ملفات قديمة webp أو روابط API خاطئة — جرّب jpg ثم webp ثم فيديو
    final jpgUrl = _mediaUrl(slot.index, "jpg");
    if (await _urlExists(jpgUrl)) return jpgUrl;
    final webpUrl = _mediaUrl(slot.index, "webp");
    if (await _urlExists(webpUrl)) return webpUrl;
    for (final videoExt in ["mp4", "mov", "avi"]) {
      final videoUrl = _mediaUrl(slot.index, videoExt);
      if (await _urlExists(videoUrl)) return videoUrl;
    }
    return jpgUrl;
  }

  Future<List<String>> _resolveMediaUrls() async {
    final slots = _parseMediaSlots();

    if (slots.isNotEmpty) {
      final urls = <String>[];
      for (final slot in slots) {
        urls.add(await _resolveSlotUrl(slot));
      }
      if (urls.isNotEmpty) return urls;
    }

    // fallback: مفيش media في DB — افحص S3 بترتيب الامتدادات الصحيح لكل index
    final urls = <String>[];
    for (int index = 1; index <= _maxImages; index++) {
      String? found;
      for (final ext in ["mp4", "mov", "avi", "jpg", "webp"]) {
        final url = _mediaUrl(index, ext);
        if (await _urlExists(url)) {
          found = url;
          break;
        }
      }
      if (found == null) break;
      urls.add(found);
    }
    return urls;
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool _isVideoUrl(String url) {
    return url.toLowerCase().endsWith(".mp4") ||
        url.toLowerCase().endsWith(".mov") ||
        url.toLowerCase().endsWith(".avi");
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<String>>(
      future: _mediaFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.black,
            child: const Center(child: SpinKitPulse(color: AppColors.white)),
          );
        }

        final resolvedUrls = snapshot.data ?? [];

        if (resolvedUrls.isEmpty) {
          _reportMediaUnavailable();
          if (_hideUnavailablePlaceholder) {
            return const SizedBox.shrink();
          }
          return Container(
            color: Colors.black,
            child: const Center(
              child: Icon(Iconsax.image, size: 64, color: Colors.grey),
            ),
          );
        }

        if (resolvedUrls.length == 1) {
          return _buildSingleMedia(
            resolvedUrls.first,
            widget.itmId,
            widget.itmIdx,
            widget.storeid,
          );
        }

        return Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemCount: resolvedUrls.length,
              itemBuilder: (context, index) {
                return _buildSingleMedia(
                  resolvedUrls[index],
                  widget.itmId,
                  widget.itmIdx,
                  widget.storeid,
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildSingleMedia(
    String url,
    String itmId,
    String itmIdx,
    String storeid,
  ) {
    final urlx = url;
    String finalFullUrl = urlx.toString().split("]")[0];
    if (_isVideoUrl(finalFullUrl)) {
      return VideoPlayerWidget(
        networkUrl: finalFullUrl,
        autoPlay: widget.autoPlayVideo,
        showControls: widget.showControls,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: finalFullUrl,
        fit: BoxFit.contain,
        placeholder: (context, url) => Container(
          color: Colors.black,
          child: const Center(child: SpinKitPulse(color: AppColors.white)),
        ),
        errorWidget: (context, url, error) {
          _reportMediaUnavailable();
          if (_hideUnavailablePlaceholder) {
            return const SizedBox.shrink();
          }
          return Container(
            color: Colors.grey[300],
            child: const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Iconsax.image, size: 64, color: Colors.grey),
                  SizedBox(height: 8),
                  Text(
                    "فشل في تحميل الصورة",
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                ],
              ),
            ),
          );
        },
      );
    }
  }
}
