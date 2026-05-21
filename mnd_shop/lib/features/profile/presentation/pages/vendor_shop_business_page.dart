import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/profile/data/vendor_profile_repository.dart';

class VendorShopBusinessPage extends ConsumerStatefulWidget {
  const VendorShopBusinessPage({super.key});

  @override
  ConsumerState<VendorShopBusinessPage> createState() => _VendorShopBusinessPageState();
}

class _VendorShopBusinessPageState extends ConsumerState<VendorShopBusinessPage> {
  final TextEditingController _minOrder = TextEditingController();
  final TextEditingController _kitchen = TextEditingController();
  final TextEditingController _counter = TextEditingController();
  final TextEditingController _delivery = TextEditingController();
  bool _hydrated = false;
  bool _saving = false;

  @override
  void dispose() {
    _minOrder.dispose();
    _kitchen.dispose();
    _counter.dispose();
    _delivery.dispose();
    super.dispose();
  }

  void _hydrate(Map<String, dynamic>? doc) {
    if (_hydrated || doc == null) {
      return;
    }
    _hydrated = true;
    final dynamic min = doc['minOrderLkr'];
    if (min is num && min > 0) {
      _minOrder.text = min.toStringAsFixed(0);
    }
    final Map<String, dynamic>? notes = doc['wageNotes'] as Map<String, dynamic>?;
    _kitchen.text = (notes?['kitchen'] as String?)?.trim() ?? '';
    _counter.text = (notes?['counter'] as String?)?.trim() ?? '';
    _delivery.text = (notes?['delivery'] as String?)?.trim() ?? '';
  }

  Future<void> _save() async {
    double? minLkr;
    final String minRaw = _minOrder.text.trim();
    if (minRaw.isNotEmpty) {
      minLkr = double.tryParse(minRaw);
      if (minLkr == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enter a valid minimum order amount.')),
        );
        return;
      }
    }
    setState(() => _saving = true);
    final String? err = await ref.read(vendorProfileRepositoryProvider).updateBusinessSettings(
          minOrderLkr: minLkr,
          kitchenNotes: _kitchen.text,
          counterNotes: _counter.text,
          deliveryNotes: _delivery.text,
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
      const SnackBar(content: Text('Business settings saved.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? doc = ref.watch(vendorAccountDocDataProvider).valueOrNull;
    _hydrate(doc);

    return Scaffold(
      appBar: AppBar(title: const Text('Business settings')),
      body: AbsorbPointer(
        absorbing: _saving,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
          children: <Widget>[
            Text(
              'Optional rules and internal notes for your team.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minOrder,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Minimum order (LKR)',
                hintText: 'Leave empty for no minimum',
                prefixText: 'Rs. ',
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Staff notes',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _kitchen,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Kitchen notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _counter,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Counter notes',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _delivery,
              maxLines: 2,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: 'Delivery notes',
                alignLabelWithHint: true,
              ),
            ),
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
        label: Text(_saving ? 'Saving…' : 'Save'),
      ),
    );
  }
}
