import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Crop and export sizes aligned with the customer app's [ProductCard]:
/// premium listing image band (`premiumWidth` × `premiumImageHeight`).
///
/// See `mnd_customer/.../product_card.dart`.
class ProductImageSpec {
  ProductImageSpec._();

  static const double premiumWidthLogical = 168;
  static const double premiumImageHeightLogical = 148;

  /// Width ÷ height for product thumbnails (`BoxFit.cover` on customer cards).
  static const double cropAspectRatio =
      premiumWidthLogical / premiumImageHeightLogical;

  static const double previewAspectRatio = cropAspectRatio;

  /// Store product sheet uses ~1.15 — same crop works well with cover fit.
  static const double storeDetailAspectRatio = 1.15;

  static const int exportWidth = 840;
  static const int exportHeight = 740;

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
