import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_shop/core/media/product_image_crop_page.dart';
import 'package:mnd_shop/core/media/product_image_spec.dart';
import 'package:mnd_shop/core/media/shop_cover_image_picker.dart';

/// Picks a gallery image and crops to the customer app product card aspect ratio.
class ProductImagePicker {
  ProductImagePicker._();

  /// Returns JPEG bytes sized for upload, or `null` if the user cancelled.
  static Future<Uint8List?> pickFromGalleryAndCrop(BuildContext context) async {
    final bool permitted = await ShopCoverImagePicker.ensurePhotoLibraryPermission();
    if (!permitted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission is required.')),
        );
      }
      return null;
    }

    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 95,
    );
    if (file == null) {
      return null;
    }
    final Uint8List raw = await file.readAsBytes();
    if (!context.mounted) {
      return null;
    }

    final Uint8List? cropped = await ProductImageCropPage.open(
      context,
      imageBytes: raw,
    );
    if (cropped == null) {
      return null;
    }
    return ProductImageSpec.encodeForUpload(cropped);
  }
}
