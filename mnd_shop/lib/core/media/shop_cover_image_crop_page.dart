import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import 'package:mnd_shop/core/media/shop_cover_image_spec.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';

/// Full-screen crop UI locked to the customer app shop card aspect ratio.
class ShopCoverImageCropPage extends StatefulWidget {
  const ShopCoverImageCropPage({required this.imageBytes, super.key});

  final Uint8List imageBytes;

  static Future<Uint8List?> open(
    BuildContext context, {
    required Uint8List imageBytes,
  }) {
    return Navigator.of(context).push<Uint8List>(
      MaterialPageRoute<Uint8List>(
        fullscreenDialog: true,
        builder: (_) => ShopCoverImageCropPage(imageBytes: imageBytes),
      ),
    );
  }

  @override
  State<ShopCoverImageCropPage> createState() => _ShopCoverImageCropPageState();
}

class _ShopCoverImageCropPageState extends State<ShopCoverImageCropPage> {
  final CropController _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) {
      return;
    }
    setState(() => _cropping = false);
    switch (result) {
      case CropSuccess(:final Uint8List croppedImage):
        Navigator.of(context).pop(croppedImage);
      case CropFailure(:final Object cause):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                cause,
                fallback: 'Could not crop image. Please try again.',
              ),
            ),
          ),
        );
    }
  }

  void _applyCrop() {
    setState(() => _cropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('Crop shop photo'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _cropping ? null : () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Frame your photo to match how customers see your shop on the home feed.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white70,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Crop(
                image: widget.imageBytes,
                controller: _controller,
                aspectRatio: ShopCoverImageSpec.cropAspectRatio,
                interactive: true,
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                  size: 0.9,
                  aspectRatio: ShopCoverImageSpec.cropAspectRatio,
                ),
                baseColor: Colors.black,
                maskColor: Colors.black.withValues(alpha: 0.55),
                radius: 8,
                onCropped: _onCropped,
                progressIndicator: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            ),
          ),
          SafeArea(
            top: false,
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _cropping ? null : _applyCrop,
                style: FilledButton.styleFrom(
                  backgroundColor: cs.primary,
                  foregroundColor: cs.onPrimary,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _cropping
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Use this crop'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
