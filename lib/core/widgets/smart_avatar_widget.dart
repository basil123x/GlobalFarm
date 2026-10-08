import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart";

import "../constants/app_colors.dart";
import "../services/auth_service.dart";
import "../utils/avatar_url_util.dart";
import 'package:GlobalFarm/core/utils/theme_extensions.dart';

/// Avatar priority: S3 custom photo → social/API fallback URL → initials.
class SmartAvatarWidget extends StatefulWidget {
  final String userId;
  final String name;
  final double size;
  final String? socialAvatarUrl;
  final String? fallbackUrl;
  final bool loadSocialFromStorage;
  final int? cacheTimestamp;
  final String? heroTag;
  final BoxFit fit;
  final Color? backgroundColor;
  final TextStyle? initialsStyle;
  final bool clipOval;

  const SmartAvatarWidget({
    super.key,
    required this.userId,
    this.name = "",
    required this.size,
    this.socialAvatarUrl,
    this.fallbackUrl,
    this.loadSocialFromStorage = false,
    this.cacheTimestamp,
    this.heroTag,
    this.fit = BoxFit.cover,
    this.backgroundColor,
    this.initialsStyle,
    this.clipOval = true,
  });

  @override
  State<SmartAvatarWidget> createState() => _SmartAvatarWidgetState();
}

class _SmartAvatarWidgetState extends State<SmartAvatarWidget> {
  static const int _stageS3 = 0;
  static const int _stageSocial = 1;
  static const int _stageFallback = 2;
  static const int _stageInitials = 3;

  int _stage = _stageS3;
  String? _storedSocialUrl;

  @override
  void initState() {
    super.initState();
    _loadSocialUrl();
  }

  @override
  void didUpdateWidget(SmartAvatarWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId ||
        oldWidget.cacheTimestamp != widget.cacheTimestamp ||
        oldWidget.socialAvatarUrl != widget.socialAvatarUrl ||
        oldWidget.fallbackUrl != widget.fallbackUrl) {
      _stage = _stageS3;
      _loadSocialUrl();
    }
  }

  Future<void> _loadSocialUrl() async {
    if (widget.socialAvatarUrl != null && widget.socialAvatarUrl!.isNotEmpty) {
      _storedSocialUrl = widget.socialAvatarUrl;
      return;
    }
    if (widget.loadSocialFromStorage) {
      _storedSocialUrl = await AuthService.getSocialAvatar();
      if (mounted) setState(() {});
    }
  }

  String? get _socialUrl {
    if (widget.socialAvatarUrl != null && widget.socialAvatarUrl!.isNotEmpty) {
      return widget.socialAvatarUrl;
    }
    return _storedSocialUrl;
  }

  void _advanceStage() {
    setState(() {
      if (_stage == _stageS3) {
        if (_socialUrl != null && _socialUrl!.isNotEmpty) {
          _stage = _stageSocial;
        } else if (widget.fallbackUrl != null &&
            widget.fallbackUrl!.isNotEmpty) {
          _stage = _stageFallback;
        } else {
          _stage = _stageInitials;
        }
      } else if (_stage == _stageSocial) {
        if (widget.fallbackUrl != null && widget.fallbackUrl!.isNotEmpty) {
          _stage = _stageFallback;
        } else {
          _stage = _stageInitials;
        }
      } else {
        _stage = _stageInitials;
      }
    });
  }

  String? _imageUrlForStage() {
    switch (_stage) {
      case _stageS3:
        if (widget.userId.isEmpty) return null;
        return AvatarUrlUtil.displayUrl(
          widget.userId,
          timestamp: widget.cacheTimestamp,
        );
      case _stageSocial:
        if (_socialUrl == null || _socialUrl!.isEmpty) return null;
        return AvatarUrlUtil.withCacheBust(
          _socialUrl!,
          timestamp: widget.cacheTimestamp,
        );
      case _stageFallback:
        if (widget.fallbackUrl == null || widget.fallbackUrl!.isEmpty) {
          return null;
        }
        return AvatarUrlUtil.withCacheBust(
          widget.fallbackUrl!,
          timestamp: widget.cacheTimestamp,
        );
      default:
        return null;
    }
  }

  Widget _buildInitials() {
    final letter = widget.name.trim().isNotEmpty
        ? widget.name.trim()[0].toUpperCase()
        : "U";
    return Container(
      width: widget.size,
      height: widget.size,
      color: widget.backgroundColor ?? Colors.grey[300],
      alignment: Alignment.center,
      child: Text(
        letter,
        style:
            widget.initialsStyle ??
            TextStyle(
              color: widget.backgroundColor != null
                  ? Colors.white
                  : AppColors.primary,
              fontWeight: FontWeight.bold,
              fontSize: widget.size * 0.35,
            ),
      ),
    );
  }

  Widget _buildContent() {
    if (_stage == _stageInitials) {
      return _buildInitials();
    }

    final url = _imageUrlForStage();
    if (url == null) {
      return _buildInitials();
    }

    final cacheKey = widget.userId.isNotEmpty
        ? "${widget.userId}-${widget.cacheTimestamp ?? _stage}-$_stage"
        : "avatar-$_stage-${widget.cacheTimestamp ?? 0}";

    return CachedNetworkImage(
      imageUrl: url,
      cacheKey: cacheKey,
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      placeholder: (context, url) => Container(
        width: widget.size,
        height: widget.size,
        color: context.appSurfaceVariant,
        child: Center(
          child: SizedBox(
            width: widget.size * 0.3,
            height: widget.size * 0.3,
            child: const CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (context, url, error) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _stage != _stageInitials) {
            _advanceStage();
          }
        });
        return _buildInitials();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget child = _buildContent();
    if (widget.clipOval) {
      child = ClipOval(child: child);
    }
    if (widget.heroTag != null) {
      child = Hero(tag: widget.heroTag!, child: child);
    }
    return child;
  }
}
