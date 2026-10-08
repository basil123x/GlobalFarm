import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

import '../constants/app_colors.dart';
import '../constants/app_config.dart';
import '../utils/item_media_url_util.dart';

class ItemThumbnailWidget extends StatelessWidget {
  final String itemId;
  final String? itemIdx;
  final String? storeId;
  final List<String>? mediaUrls;
  final String? mediaValue;
  final String? thumbnailUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;
  final Color? placeholderColor;
  final IconData placeholderIcon;

  const ItemThumbnailWidget({
    super.key,
    required this.itemId,
    this.itemIdx,
    this.storeId,
    this.mediaUrls,
    this.mediaValue,
    this.thumbnailUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.placeholderColor,
    this.placeholderIcon = Iconsax.image,
  });

  factory ItemThumbnailWidget.fromItem({
    Key? key,
    required String itemId,
    String? itemIdx,
    String? storeId,
    required List<String> media,
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    BorderRadius? borderRadius,
    Color? placeholderColor,
  }) {
    return ItemThumbnailWidget(
      key: key,
      itemId: itemId,
      itemIdx: itemIdx,
      storeId: storeId,
      mediaUrls: media,
      fit: fit,
      width: width,
      height: height,
      borderRadius: borderRadius,
      placeholderColor: placeholderColor,
    );
  }

  String get _resolvedUrl => ItemMediaUrlUtil.resolveThumbnailUrl(
        mediaUrls: mediaUrls,
        mediaValue: mediaValue,
        storeId: storeId ?? AppConfig.storeId,
        itemId: itemId,
        itemIdx: itemIdx,
        preferredUrl: thumbnailUrl,
      );

  @override
  Widget build(BuildContext context) {
    final url = _resolvedUrl;
    final child = ItemMediaUrlUtil.isVideoUrl(url)
        ? _VideoThumbnailPreview(
            videoUrl: url,
            fit: fit,
            placeholderColor: placeholderColor,
          )
        : CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            width: width,
            height: height,
            placeholder: (context, _) => _placeholder(context),
            errorWidget: (context, _, __) => _placeholder(context),
          );

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: child);
    }
    return SizedBox(width: width, height: height, child: child);
  }

  Widget _placeholder(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: placeholderColor ?? Colors.grey.shade300,
      child: Icon(placeholderIcon, color: Colors.grey, size: 28),
    );
  }
}

class _VideoThumbnailPreview extends StatefulWidget {
  final String videoUrl;
  final BoxFit fit;
  final Color? placeholderColor;

  const _VideoThumbnailPreview({
    required this.videoUrl,
    required this.fit,
    this.placeholderColor,
  });

  @override
  State<_VideoThumbnailPreview> createState() => _VideoThumbnailPreviewState();
}

class _VideoThumbnailPreviewState extends State<_VideoThumbnailPreview> {
  late final Future<Uint8List?> _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    _thumbnailFuture = VideoThumbnail.thumbnailData(
      video: widget.videoUrl,
      imageFormat: ImageFormat.JPEG,
      maxWidth: 480,
      quality: 75,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _thumbnailFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _videoFallback(showLoader: true);
        }
        if (snapshot.hasData && snapshot.data != null) {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.memory(snapshot.data!, fit: widget.fit),
              const _VideoPlayBadge(),
            ],
          );
        }
        return _videoFallback();
      },
    );
  }

  Widget _videoFallback({bool showLoader = false}) {
    return Container(
      color: widget.placeholderColor ?? AppColors.primary.withValues(alpha: 0.85),
      child: Center(
        child: showLoader
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const _VideoPlayBadge(size: 36),
      ),
    );
  }
}

class _VideoPlayBadge extends StatelessWidget {
  final double size;

  const _VideoPlayBadge({this.size = 28});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(size * 0.2),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Iconsax.video_play,
          color: Colors.white,
          size: size,
        ),
      ),
    );
  }
}
