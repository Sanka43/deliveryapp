import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/profile/data/vendor_profile_repository.dart';
import 'package:permission_handler/permission_handler.dart';

class VendorShopGalleryPage extends ConsumerStatefulWidget {
  const VendorShopGalleryPage({super.key});

  @override
  ConsumerState<VendorShopGalleryPage> createState() => _VendorShopGalleryPageState();
}

class _VendorShopGalleryPageState extends ConsumerState<VendorShopGalleryPage> {
  final List<String?> _remoteUrls = List<String?>.filled(4, null);
  final List<Uint8List?> _pendingBytes = List<Uint8List?>.filled(4, null);
  bool _hydrated = false;
  bool _saving = false;

  void _hydrate(List<dynamic>? gallery) {
    if (_hydrated) {
      return;
    }
    _hydrated = true;
    if (gallery == null) {
      return;
    }
    for (int i = 0; i < 4 && i < gallery.length; i++) {
      final String u = (gallery[i] as String?)?.trim() ?? '';
      if (u.isNotEmpty) {
        _remoteUrls[i] = u;
      }
    }
  }

  Future<bool> _ensurePhotoPermission() async {
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

  Future<void> _pick(int index) async {
    if (!await _ensurePhotoPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Photo permission is required.')),
        );
      }
      return;
    }
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) {
      return;
    }
    final Uint8List bytes = await file.readAsBytes();
    setState(() {
      _pendingBytes[index] = bytes;
      if (index == 0) {
        for (int i = 1; i < 4; i++) {
          _pendingBytes[i] = null;
          _remoteUrls[i] = null;
        }
      }
    });
  }

  void _clearSlot(int index) {
    setState(() {
      _pendingBytes[index] = null;
      _remoteUrls[index] = null;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final VendorProfileRepository repo = ref.read(vendorProfileRepositoryProvider);
    final List<String> urls = <String>[];

    for (int i = 0; i < 4; i++) {
      final Uint8List? pending = _pendingBytes[i];
      if (pending != null) {
        final ({String? error, String? url}) uploaded = await repo.uploadGalleryPhoto(
          index: i,
          bytes: pending,
          fileName: 'shop_$i.jpg',
        );
        if (uploaded.error != null) {
          if (mounted) {
            setState(() => _saving = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(uploaded.error!)),
            );
          }
          return;
        }
        urls.add(uploaded.url!);
      } else {
        final String? existing = _remoteUrls[i];
        if (existing != null && existing.isNotEmpty) {
          urls.add(existing);
        }
      }
    }

    final String? err = await repo.updateGalleryUrls(urls);
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Shop photos saved.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? doc = ref.watch(vendorAccountDocDataProvider).valueOrNull;
    _hydrate(doc?['galleryImageUrls'] as List<dynamic>?);

    return Scaffold(
      appBar: AppBar(title: const Text('Shop photos')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: <Widget>[
            Text(
              'Add up to 4 photos. The first photo is your main shop image.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            for (int i = 0; i < 4; i++) ...<Widget>[
              Text(
                i == 0 ? 'Main photo' : 'Photo ${i + 1}',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Material(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _saving ? null : () => _pick(i),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        if (_pendingBytes[i] != null)
                          Image.memory(_pendingBytes[i]!, fit: BoxFit.cover)
                        else if (_remoteUrls[i] != null)
                          Image.network(_remoteUrls[i]!, fit: BoxFit.cover)
                        else
                          Center(
                            child: Icon(
                              Icons.add_photo_alternate_outlined,
                              size: 40,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        if ((_pendingBytes[i] != null || _remoteUrls[i] != null) && !_saving)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: IconButton.filled(
                              style: IconButton.styleFrom(
                                minimumSize: const Size(36, 36),
                                padding: EdgeInsets.zero,
                              ),
                              onPressed: () => _clearSlot(i),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _save,
        icon: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.save_rounded),
        label: Text(_saving ? 'Saving…' : 'Save photos'),
      ),
    );
  }
}
