import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_shop/core/media/shop_cover_image_crop_page.dart';
import 'package:mnd_shop/core/media/shop_cover_image_spec.dart';
import 'package:permission_handler/permission_handler.dart';

/// Picks a gallery image and runs the customer-card crop flow.
class ShopCoverImagePicker {
  ShopCoverImagePicker._();

  static Future<bool> ensurePhotoLibraryPermission() async {
    if (kIsWeb) {
      return true;
    }
    if (Platform.isIOS) {
      final PermissionStatus s = await Permission.photos.request();
      return s.isGranted || s.isLimited;
    }
    if (Platform.isAndroid) {
      PermissionStatus s = await Permission.photos.request();
      if (s.isGranted || s.isLimited) {
        return true;
      }
      s = await Permission.storage.request();
      return s.isGranted;
    }
    return true;
  }

  /// Returns JPEG bytes sized for upload, or `null` if the user cancelled.
  static Future<Uint8List?> pickFromGalleryAndCrop(BuildContext context) async {
    final bool permitted = await ensurePhotoLibraryPermission();
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

    final Uint8List? cropped = await ShopCoverImageCropPage.open(
      context,
      imageBytes: raw,
    );
    if (cropped == null) {
      return null;
    }
    return ShopCoverImageSpec.encodeForUpload(cropped);
  }
}
