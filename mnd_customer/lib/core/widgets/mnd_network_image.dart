import 'package:cached_network_image/cached_network_image.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';

/// Process-wide resolved download URL cache (skips repeat Storage getDownloadURL).
class MndImageUrlCache {
  MndImageUrlCache._();

  static const int _maxEntries = 256;
  static final Map<String, String> _resolved = <String, String>{};
  static final Map<String, Future<String>> _inFlight = <String, Future<String>>{};

  static Future<String> resolve(String raw) {
    final String key = raw.trim();
    if (key.isEmpty) {
      return Future<String>.value('');
    }
    final String? cached = _resolved[key];
    if (cached != null) {
      return Future<String>.value(cached);
    }
    final Future<String>? pending = _inFlight[key];
    if (pending != null) {
      return pending;
    }
    final Future<String> future = _resolveUncached(key).then((String url) {
      _inFlight.remove(key);
      if (url.isNotEmpty) {
        if (_resolved.length >= _maxEntries) {
          _resolved.remove(_resolved.keys.first);
        }
        _resolved[key] = url;
      }
      return url;
    });
    _inFlight[key] = future;
    return future;
  }

  static Future<String> _resolveUncached(String trimmed) async {
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      // Tokenized Firebase HTTPS download URLs load as-is.
      // Non-token / gs-style https refs may need getDownloadURL.
      if (_looksLikeFirebaseStorageHttps(trimmed) &&
          !trimmed.contains('token=')) {
        try {
          return await FirebaseStorage.instance
              .refFromURL(trimmed)
              .getDownloadURL();
        } catch (e) {
          if (kDebugMode) {
            debugPrint('MndNetworkImage: getDownloadURL failed for $trimmed → $e');
          }
          return trimmed;
        }
      }
      return trimmed;
    }

    if (trimmed.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance
            .refFromURL(trimmed)
            .getDownloadURL();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('MndNetworkImage: gs:// resolve failed for $trimmed → $e');
        }
        return '';
      }
    }

    // Relative Storage object path.
    if (!trimmed.contains('://')) {
      try {
        return await FirebaseStorage.instance.ref(trimmed).getDownloadURL();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('MndNetworkImage: path resolve failed for $trimmed → $e');
        }
        return '';
      }
    }

    return '';
  }

  static bool _looksLikeFirebaseStorageHttps(String url) {
    final String lower = url.toLowerCase();
    return lower.contains('firebasestorage.googleapis.com') ||
        lower.contains('.firebasestorage.app') ||
        lower.contains('storage.googleapis.com');
  }
}

/// Network image for catalog cards — cached decode + shared Storage URL resolve.
class MndNetworkImage extends StatefulWidget {
  const MndNetworkImage({
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.showWatermarkOnError = true,
    this.errorChild,
    super.key,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final bool showWatermarkOnError;
  final Widget? errorChild;

  @override
  State<MndNetworkImage> createState() => _MndNetworkImageState();
}

class _MndNetworkImageState extends State<MndNetworkImage> {
  late Future<String> _resolvedUrlFuture;

  @override
  void initState() {
    super.initState();
    _resolvedUrlFuture = MndImageUrlCache.resolve(widget.imageUrl);
  }

  @override
  void didUpdateWidget(MndNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedUrlFuture = MndImageUrlCache.resolve(widget.imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String trimmed = widget.imageUrl.trim();
    if (trimmed.isEmpty) {
      return _errorBox(context);
    }

    return FutureBuilder<String>(
      future: _resolvedUrlFuture,
      builder: (BuildContext context, AsyncSnapshot<String> snap) {
        if (snap.connectionState != ConnectionState.done) {
          return _loadingBox(context);
        }

        final String url = (snap.data ?? '').trim();
        if (url.isEmpty ||
            !(url.startsWith('http://') || url.startsWith('https://'))) {
          if (kDebugMode) {
            debugPrint(
              'MndNetworkImage: no usable URL for "${widget.imageUrl}" '
              '(resolved: "$url")',
            );
          }
          return widget.errorChild ?? _errorBox(context);
        }

        final double dpr = MediaQuery.devicePixelRatioOf(context);
        final int? memW = _memCachePx(widget.width, dpr);
        final int? memH = _memCachePx(widget.height, dpr);

        // Web/CanvasKit needs CORS to decode Storage bytes into a Flutter image.
        // Prefer an HTML <img> platform view so catalog photos show even when the
        // bucket CORS config is missing or stale.
        final Widget image = kIsWeb
            ? Image.network(
                url,
                width: widget.width ?? double.infinity,
                height: widget.height ?? double.infinity,
                fit: widget.fit,
                filterQuality: FilterQuality.medium,
                gaplessPlayback: true,
                webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
                loadingBuilder: (
                  BuildContext context,
                  Widget child,
                  ImageChunkEvent? progress,
                ) {
                  if (progress == null) {
                    return child;
                  }
                  return _loadingBox(context);
                },
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  if (kDebugMode) {
                    debugPrint('MndNetworkImage: web load failed for $url → $error');
                  }
                  return widget.errorChild ?? _errorBox(context);
                },
              )
            : CachedNetworkImage(
                imageUrl: url,
                width: widget.width ?? double.infinity,
                height: widget.height ?? double.infinity,
                fit: widget.fit,
                filterQuality: FilterQuality.medium,
                memCacheWidth: memW,
                memCacheHeight: memH,
                fadeInDuration: const Duration(milliseconds: 120),
                fadeOutDuration: const Duration(milliseconds: 80),
                placeholder: (BuildContext context, String _) =>
                    _loadingBox(context),
                errorWidget: (BuildContext context, String _, Object error) {
                  if (kDebugMode) {
                    debugPrint('MndNetworkImage: load failed for $url → $error');
                  }
                  return widget.errorChild ?? _errorBox(context);
                },
              );

        if (widget.borderRadius != null) {
          return ClipRRect(borderRadius: widget.borderRadius!, child: image);
        }

        return image;
      },
    );
  }

  /// Decode at display size × DPR when width/height are finite layout sizes.
  static int? _memCachePx(double? logicalPx, double dpr) {
    if (logicalPx == null || !logicalPx.isFinite || logicalPx <= 0) {
      return null;
    }
    return (logicalPx * dpr).round().clamp(1, 4096);
  }

  Widget _loadingBox(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.homeMutedFill,
      alignment: Alignment.center,
      child: SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppColors.brandPrimary.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _errorBox(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      color: AppColors.homeMutedFill,
      alignment: Alignment.center,
      padding: const EdgeInsets.all(8),
      child: widget.showWatermarkOnError
          ? const FittedBox(
              fit: BoxFit.contain,
              child: MndBrandWatermark(
                mndFontSize: 36,
                subtitleFontSize: 10,
                mndOpacity: 0.22,
                subtitleOpacity: 0.16,
              ),
            )
          : Opacity(
              opacity: 0.15,
              child: Icon(
                Icons.image_not_supported_outlined,
                color: AppColors.textSecondary,
                size: 28,
              ),
            ),
    );
  }
}
