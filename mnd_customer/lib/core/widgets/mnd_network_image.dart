import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_brand_watermark.dart';

/// Network image for catalog cards — uses [Image.network] (reliable with Firebase Storage).
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
    _resolvedUrlFuture = _resolveUrl(widget.imageUrl);
  }

  @override
  void didUpdateWidget(MndNetworkImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageUrl != widget.imageUrl) {
      _resolvedUrlFuture = _resolveUrl(widget.imageUrl);
    }
  }

  static Future<String> _resolveUrl(String raw) async {
    final String trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    if (trimmed.startsWith('gs://')) {
      try {
        return await FirebaseStorage.instance.refFromURL(trimmed).getDownloadURL();
      } catch (_) {
        return trimmed;
      }
    }
    if (trimmed.startsWith('//')) {
      return 'https:$trimmed';
    }
    return trimmed;
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
        final String url = snap.data ?? trimmed;
        if (url.isEmpty) {
          return _errorBox(context);
        }

        Widget image = Image.network(
          url,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          filterQuality: FilterQuality.medium,
          gaplessPlayback: true,
          loadingBuilder: (
            BuildContext context,
            Widget child,
            ImageChunkEvent? progress,
          ) {
            if (progress == null) {
              return child;
            }
            return _loadingBox(context, progress);
          },
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) =>
              widget.errorChild ?? _errorBox(context),
        );

        if (widget.borderRadius != null) {
          image = ClipRRect(borderRadius: widget.borderRadius!, child: image);
        }

        return image;
      },
    );
  }

  Widget _loadingBox(BuildContext context, ImageChunkEvent progress) {
    final double? total = progress.expectedTotalBytes?.toDouble();
    final double? value = total != null && total > 0
        ? progress.cumulativeBytesLoaded / total
        : null;

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
          value: value,
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
          : Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.textSecondary.withValues(alpha: 0.5),
              size: 28,
            ),
    );
  }
}
