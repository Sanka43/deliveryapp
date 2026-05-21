import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
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
  });

  final String label;
  final String hint;
  final Uint8List? bytes;
  final ValueChanged<Uint8List> onPicked;
  final String? errorText;
  final IconData icon;

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
      await _showOpenSettingsDialog(context);
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
        await _showOpenSettingsDialog(context);
        return false;
      }
    }

    if (status.isPermanentlyDenied) {
      await _showOpenSettingsDialog(context);
      return false;
    }

    return false;
  }

  Future<void> _showOpenSettingsDialog(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          title: const Text('Photo access needed'),
          content: const Text(
            'MND Rider needs permission to read photos for registration. '
            'Open Settings, tap Permissions, then allow Photos (or Files and media).',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(ctx);
                await openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeniedSnackBar(BuildContext context) async {
    if (!context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Photo access is required to upload documents.'),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: openAppSettings,
        ),
      ),
    );
  }

  Future<XFile?> _pickFromGallery() async {
    final ImagePicker picker = ImagePicker();
    return picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 88,
    );
  }

  Future<void> _pick(BuildContext context) async {
    // Android 13+ system photo picker may work without runtime permission.
    if (Platform.isAndroid) {
      final XFile? direct = await _pickFromGallery();
      if (direct != null) {
        final Uint8List data = await direct.readAsBytes();
        if (data.isNotEmpty) {
          onPicked(data);
        }
        return;
      }
    }

    final bool permitted = await _ensureGalleryPermission(context);
    if (!permitted) {
      if (context.mounted) {
        await _showDeniedSnackBar(context);
      }
      return;
    }

    final XFile? image = await _pickFromGallery();
    if (image == null) {
      return;
    }

    final Uint8List data = await image.readAsBytes();
    if (data.isEmpty) {
      return;
    }
    onPicked(data);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool hasError = errorText != null && errorText!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Material(
          color: cs.surface,
          borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
          child: InkWell(
            onTap: () => _pick(context),
            borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
                border: Border.all(
                  color: hasError ? cs.error : cs.outlineVariant.withValues(alpha: 0.6),
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
                              color: cs.surfaceContainerHighest,
                              child: Icon(icon, color: cs.onSurfaceVariant),
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
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to choose from gallery',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText!,
            style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
          ),
        ],
      ],
    );
  }
}
