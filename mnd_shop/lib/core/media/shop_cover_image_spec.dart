import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Crop and export sizes aligned with the customer app's [MndShopCard]:
/// full-bleed width with [cardHeight] 200 logical px and horizontal padding 16.
///
/// See `mnd_customer/.../mnd_shop_card.dart` (`cardHeight = 200`).
class ShopCoverImageSpec {
  ShopCoverImageSpec._();

  static const double cardHeightLogical = 200;
  static const double horizontalPaddingLogical = 16;

  /// Typical phone width used to derive a stable crop frame (not device-dependent at upload).
  static const double referenceViewportWidthLogical = 390;

  /// Width ÷ height for the customer listing cover (`BoxFit.cover` on [MndShopCard]).
  static const double cropAspectRatio =
      (referenceViewportWidthLogical - 2 * horizontalPaddingLogical) /
      cardHeightLogical;

  /// Preview frame on vendor forms (matches crop aspect).
  static const double previewAspectRatio = cropAspectRatio;

  static const int exportWidth = 1432;
  static const int exportHeight = 800;

  /// JPEG re-encode after crop so uploads stay consistent and reasonably small.
  static Uint8List encodeForUpload(Uint8List croppedBytes, {int quality = 85}) {
    final img.Image? decoded = img.decodeImage(croppedBytes);
    if (decoded == null) {
      return croppedBytes;
    }
    final img.Image resized = img.copyResize(
      decoded,
      width: exportWidth,
      height: exportHeight,
      interpolation: img.Interpolation.linear,
    );
    return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
  }
}
