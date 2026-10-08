import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';

/// WhatsApp-style map preview with real satellite imagery + pin.
class ChatLocationPreview extends StatelessWidget {
  final double latitude;
  final double longitude;
  final VoidCallback? onTap;
  final String? timeLabel;
  final bool showReadReceipt;
  final bool isRead;

  const ChatLocationPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    this.onTap,
    this.timeLabel,
    this.showReadReceipt = false,
    this.isRead = false,
  });

  static String _arcGisExportUrl(
    String service,
    double lat,
    double lng, {
    double deltaLng = 0.0042,
    double deltaLat = 0.0024,
  }) {
    final west = (lng - deltaLng).toStringAsFixed(6);
    final east = (lng + deltaLng).toStringAsFixed(6);
    final south = (lat - deltaLat).toStringAsFixed(6);
    final north = (lat + deltaLat).toStringAsFixed(6);

    return 'https://services.arcgisonline.com/arcgis/rest/services/$service/MapServer/export'
        '?bbox=$west,$south,$east,$north'
        '&bboxSR=4326&imageSR=4326'
        '&size=520,280'
        '&format=jpg'
        '&f=image';
  }

  static List<String> mapImageUrls(double lat, double lng) {
    final latStr = lat.toStringAsFixed(6);
    final lngStr = lng.toStringAsFixed(6);

    return [
      // Satellite imagery (real aerial photo of the area)
      _arcGisExportUrl('World_Imagery', lat, lng),
      // Street map fallback
      _arcGisExportUrl('World_Street_Map', lat, lng),
      // OSM fallback
      'https://staticmap.openstreetmap.de/staticmap.php'
          '?center=$latStr,$lngStr&zoom=16&size=520x280&maptype=mapnik',
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 260,
          height: 140,
          child: Stack(
            fit: StackFit.expand,
            children: [
              _MapImageWithFallback(
                urls: mapImageUrls(latitude, longitude),
              ),
              const Center(
                child: Icon(
                  Icons.location_on,
                  color: Color(0xFFE53935),
                  size: 42,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
              ),
              if (timeLabel != null)
                Positioned(
                  right: 8,
                  bottom: 6,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      color: Colors.black.withOpacity(0.35),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            timeLabel!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (showReadReceipt) ...[
                            const SizedBox(width: 4),
                            Icon(
                              isRead ? Iconsax.tick_circle : Iconsax.tick_square,
                              size: 14,
                              color: isRead
                                  ? const Color(0xFF64B5F6)
                                  : Colors.white70,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapImageWithFallback extends StatefulWidget {
  final List<String> urls;

  const _MapImageWithFallback({required this.urls});

  @override
  State<_MapImageWithFallback> createState() => _MapImageWithFallbackState();
}

class _MapImageWithFallbackState extends State<_MapImageWithFallback> {
  int _attempt = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.urls.isEmpty) {
      return _buildError();
    }

    final url = widget.urls[_attempt.clamp(0, widget.urls.length - 1)];

    return CachedNetworkImage(
      key: ValueKey(url),
      imageUrl: url,
      fit: BoxFit.cover,
      httpHeaders: const {'User-Agent': 'GlobalFarm/1.0'},
      placeholder: (_, __) => Container(
        color: const Color(0xFFE8E8E8),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, __, ___) {
        if (_attempt < widget.urls.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() => _attempt++);
            }
          });
          return Container(
            color: const Color(0xFFE8E8E8),
            child: const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        return _buildError();
      },
    );
  }

  Widget _buildError() {
    return Container(
      color: const Color(0xFFDCE8DC),
      child: const Icon(
        Icons.map_outlined,
        size: 48,
        color: Color(0xFF6B7280),
      ),
    );
  }
}
