import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_picker_page.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_pick_result.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/profile/data/vendor_profile_repository.dart';

class VendorShopLocationPage extends ConsumerStatefulWidget {
  const VendorShopLocationPage({super.key});

  @override
  ConsumerState<VendorShopLocationPage> createState() => _VendorShopLocationPageState();
}

class _VendorShopLocationPageState extends ConsumerState<VendorShopLocationPage> {
  double? _latitude;
  double? _longitude;
  bool _hydrated = false;
  bool _saving = false;

  void _hydrate(Map<String, dynamic>? doc) {
    if (_hydrated || doc == null) {
      return;
    }
    _hydrated = true;
    final dynamic la = doc['latitude'];
    final dynamic lo = doc['longitude'];
    if (la is num && lo is num) {
      _latitude = la.toDouble();
      _longitude = lo.toDouble();
    }
  }

  Future<void> _pickOnMap() async {
    if (!isShopMapPickerSupported()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Map picker is available on Android and iOS only.'),
          ),
        );
      }
      return;
    }
    final LatLng initial = LatLng(
      _latitude ?? kDefaultShopMapCenter.latitude,
      _longitude ?? kDefaultShopMapCenter.longitude,
    );
    final ShopMapPickResult? picked = await ShopMapPickerPage.open(
      context,
      initialCenter: initial,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _latitude = picked.latitude;
      _longitude = picked.longitude;
    });
  }

  Future<void> _save() async {
    final double? la = _latitude;
    final double? lo = _longitude;
    if (la == null || lo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pick a location on the map first.')),
      );
      return;
    }
    setState(() => _saving = true);
    final String? err = await ref.read(vendorProfileRepositoryProvider).updateLocation(
          latitude: la,
          longitude: lo,
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Store location saved.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? doc = ref.watch(vendorAccountDocDataProvider).valueOrNull;
    _hydrate(doc);
    final String address = (doc?['addressLine'] as String?)?.trim() ?? '';
    final String city = (doc?['city'] as String?)?.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Store location')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: <Widget>[
          Text(
            'Move the map pin to your shop entrance. Customers use this for delivery.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          if (address.isNotEmpty || city.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              child: ListTile(
                leading: const Icon(Icons.location_on_outlined),
                title: Text(address.isEmpty ? city : address),
                subtitle: address.isNotEmpty && city.isNotEmpty ? Text(city) : null,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (_latitude != null && _longitude != null)
            Text(
              'Pin: ${_latitude!.toStringAsFixed(5)}, ${_longitude!.toStringAsFixed(5)}',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _pickOnMap,
            icon: const Icon(Icons.map_outlined),
            label: const Text('Update on map'),
          ),
        ],
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
        label: Text(_saving ? 'Saving…' : 'Save location'),
      ),
    );
  }
}
