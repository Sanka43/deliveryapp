import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/widgets/rider_branded_dialog.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:permission_handler/permission_handler.dart';

class RiderPhotoPickerTile extends StatelessWidget {
  const RiderPhotoPickerTile({
    super.key,
    required this.label,
    required this.hint,
    required this.bytes,
    required this.onPicked,
    this.errorText,
    this.icon = Icons.add_a_photo_outlined,
    this.dark = false,
  });

  final String label;
  final String hint;
  final Uint8List? bytes;
  final ValueChanged<Uint8List> onPicked;
  final String? errorText;
  final IconData icon;
  final bool dark;

  Future<Permission> _galleryPermission() async {
    if (Platform.isIOS) {
      return Permission.photos;
    }
    if (Platform.isAndroid) {
      final PermissionStatus photosStatus = await Permission.photos.status;
      if (photosStatus != PermissionStatus.denied &&
          photosStatus != PermissionStatus.permanentlyDenied) {
        return Permission.photos;
      }
      final PermissionStatus storageStatus = await Permission.storage.status;
      if (storageStatus != PermissionStatus.denied &&
          storageStatus != PermissionStatus.permanentlyDenied) {
        return Permission.storage;
      }
      return Permission.photos;
    }
    return Permission.photos;
  }

  Future<bool> _ensureGalleryPermission(BuildContext context) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return true;
    }

    Permission permission = await _galleryPermission();
    PermissionStatus status = await permission.status;

    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(
        context,
        title: 'Photo access needed',
        message:
            'MND Rider needs permission to read photos for registration. '
            'Open Settings, tap Permissions, then allow Photos (or Files and media).',
      );
      return false;
    }

    status = await permission.request();
    if (status.isGranted || status.isLimited) {
      return true;
    }

    if (Platform.isAndroid && permission == Permission.photos) {
      final PermissionStatus storageStatus = await Permission.storage.request();
      if (storageStatus.isGranted) {
        return true;
      }
      if (storageStatus.isPermanentlyDenied) {
        await _showOpenSettingsDialog(
          context,
          title: 'Photo access needed',
          message:
              'MND Rider needs permission to read photos for registration. '
              'Open Settings, tap Permissions, then allow Photos (or Files and media).',
        );
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(
        context,
        title: 'Photo access needed',
        message:
            'MND Rider needs permission to read photos for registration. '
            'Open Settings, tap Permissions, then allow Photos (or Files and media).',
      );
      return false;
    }

    return false;
  }

  Future<bool> _ensureCameraPermission(BuildContext context) async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      return true;
    }

    PermissionStatus status = await Permission.camera.status;
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(
        context,
        title: 'Camera access needed',
        message:
            'MND Rider needs camera access to capture registration documents. '
            'Open Settings, tap Permissions, then allow Camera.',
      );
      return false;
    }

    status = await Permission.camera.request();
    if (status.isGranted) {
      return true;
    }

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(
        context,
        title: 'Camera access needed',
        message:
            'MND Rider needs camera access to capture registration documents. '
            'Open Settings, tap Permissions, then allow Camera.',
      );
      return false;
    }

    return false;
  }

  Future<void> _showOpenSettingsDialog(
    BuildContext context, {
    required String title,
    required String message,
  }) async {
    if (!context.mounted) {
      return;
    }
    final bool openSettings = await showRiderConfirmDialog(
      context,
      title: title,
      message: message,
      confirmLabel: 'Open Settings',
    );
    if (openSettings) {
      await openAppSettings();
    }
  }

  Future<void> _showDeniedSnackBar(
    BuildContext context, {
    required String message,
  }) async {
    if (!context.mounted) {
      return;
    }
    showRiderSnackBar(
      context,
      message,
      actionLabel: 'Settings',
      onAction: openAppSettings,
    );
  }

  Future<XFile?> _pickImage(ImageSource source) async {
    final ImagePicker picker = ImagePicker();
    return picker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 88,
      preferredCameraDevice: CameraDevice.rear,
    );
  }

  Future<void> _deliverPicked(XFile? image) async {
    if (image == null) {
      return;
    }
    final Uint8List data = await image.readAsBytes();
    if (data.isEmpty) {
      return;
    }
    onPicked(data);
  }

  Future<void> _pickFromGallery(BuildContext context) async {
    // Android 13+ system photo picker may work without runtime permission.
    if (Platform.isAndroid) {
      try {
        final XFile? direct = await _pickImage(ImageSource.gallery);
        // null = user cancelled the system picker. Do not reopen it.
        await _deliverPicked(direct);
      } catch (_) {
        if (!context.mounted) {
          return;
        }
        final bool permitted = await _ensureGalleryPermission(context);
        if (!permitted) {
          if (context.mounted) {
            await _showDeniedSnackBar(
              context,
              message: 'Photo access is required to upload documents.',
            );
          }
          return;
        }
        await _deliverPicked(await _pickImage(ImageSource.gallery));
      }
      return;
    }

    final bool permitted = await _ensureGalleryPermission(context);
    if (!permitted) {
      if (context.mounted) {
        await _showDeniedSnackBar(
          context,
          message: 'Photo access is required to upload documents.',
        );
      }
      return;
    }

    await _deliverPicked(await _pickImage(ImageSource.gallery));
  }

  Future<void> _pickFromCamera(BuildContext context) async {
    final bool permitted = await _ensureCameraPermission(context);
    if (!permitted) {
      if (context.mounted) {
        await _showDeniedSnackBar(
          context,
          message: 'Camera access is required to capture documents.',
        );
      }
      return;
    }

    await _deliverPicked(await _pickImage(ImageSource.camera));
  }

  Future<void> _showSourceSheet(BuildContext context) async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    final ImageSource? source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: dark ? AppColors.darkSurface : cs.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        final Color titleColor = dark ? Colors.white : cs.onSurface;
        final Color subtitleColor = dark
            ? AppColors.mutedOnNavy
            : cs.onSurfaceVariant;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: (dark ? Colors.white : cs.onSurface)
                          .withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  'Add photo',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: titleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: subtitleColor,
                  ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.photo_camera_rounded,
                    color: dark ? AppColors.primaryBlue : cs.primary,
                  ),
                  title: Text(
                    'Take photo',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Use your camera',
                    style: TextStyle(color: subtitleColor),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                ListTile(
                  leading: Icon(
                    Icons.photo_library_rounded,
                    color: dark ? AppColors.primaryBlue : cs.primary,
                  ),
                  title: Text(
                    'Choose from gallery',
                    style: TextStyle(
                      color: titleColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Pick an existing image',
                    style: TextStyle(color: subtitleColor),
                  ),
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (!context.mounted || source == null) {
      return;
    }

    if (source == ImageSource.camera) {
      await _pickFromCamera(context);
    } else {
      await _pickFromGallery(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    final Color surface = dark ? AppColors.darkSurface : cs.surface;
    final Color border = hasError
        ? (dark ? AppColors.errorRed : cs.error)
        : (dark
            ? AppColors.authMist.withValues(alpha: 0.12)
            : cs.outlineVariant.withValues(alpha: 0.6));
    final Color labelColor = dark ? AppColors.authMist : cs.onSurface;
    final Color hintColor = dark
        ? AppColors.authMist.withValues(alpha: 0.55)
        : cs.onSurfaceVariant;
    final Color placeholderFill = dark
        ? const Color(0xFF121A28)
        : cs.surfaceContainerHighest;
    final Color iconColor = dark
        ? AppColors.authMist.withValues(alpha: 0.45)
        : cs.onSurfaceVariant;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            color: labelColor,
          ),
        ),
        const SizedBox(height: 8),
        Material(
          color: surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: InkWell(
            onTap: () => _showSourceSheet(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: border,
                  width: hasError ? 1.5 : 1,
                ),
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: bytes != null
                          ? Image.memory(bytes!, fit: BoxFit.cover)
                          : ColoredBox(
                              color: placeholderFill,
                              child: Icon(icon, color: iconColor),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          bytes != null ? 'Photo selected' : hint,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: labelColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to take photo or choose from gallery',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: hintColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: iconColor),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: dark ? AppColors.errorRed : cs.error,
            ),
          ),
        ],
      ],
    );
  }
}
