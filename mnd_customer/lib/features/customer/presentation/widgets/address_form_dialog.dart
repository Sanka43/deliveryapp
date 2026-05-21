import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_picker_page.dart';

/// Returns a [SavedAddress] (id may be empty for new records).
class AddressFormDialog extends StatefulWidget {
  const AddressFormDialog({
    required this.title,
    this.initial,
    this.onMapPickApplied,
    super.key,
  });

  final String title;
  final SavedAddress? initial;

  /// Called after a successful map pick so the host can sync (e.g. cart drop-off coords).
  final void Function(DeliveryMapPickResult result)? onMapPickApplied;

  @override
  State<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends State<AddressFormDialog> {
  late final TextEditingController _label;
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late bool _isDefault;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final SavedAddress? i = widget.initial;
    _label = TextEditingController(text: i?.label ?? '');
    _line1 = TextEditingController(text: i?.line1 ?? '');
    _line2 = TextEditingController(text: i?.line2 ?? '');
    _city = TextEditingController(text: i?.city ?? '');
    _phone = TextEditingController(text: i?.phone ?? '');
    _isDefault = i?.isDefault ?? false;
  }

  @override
  void dispose() {
    _label.dispose();
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () async {
                    if (!isDeliveryMapPickerSupported()) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Map picker is available on Android and iOS only.'),
                        ),
                      );
                      return;
                    }
                    final DeliveryMapPickResult? pick =
                        await DeliveryMapPickerPage.pick(context);
                    if (pick == null || !context.mounted) {
                      return;
                    }
                    widget.onMapPickApplied?.call(pick);
                    setState(() {
                      _line1.text = pick.line1;
                      _line2.text = pick.line2;
                      _city.text = pick.city;
                    });
                  },
                  icon: const Icon(Icons.map_outlined, size: 20),
                  label: const Text('Pick on map'),
                ),
              ),
              TextFormField(
                controller: _label,
                decoration: const InputDecoration(labelText: 'Label (e.g. Home)'),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _line1,
                decoration: const InputDecoration(labelText: 'Address line 1'),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _line2,
                decoration: const InputDecoration(labelText: 'Line 2 (optional)'),
              ),
              TextFormField(
                controller: _city,
                decoration: const InputDecoration(labelText: 'City'),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'Phone'),
                keyboardType: TextInputType.phone,
                validator: (String? v) {
                  if (v == null || v.trim().length < 8) {
                    return 'Enter a valid phone';
                  }
                  return null;
                },
              ),
              SwitchListTile(
                title: const Text('Default address'),
                value: _isDefault,
                onChanged: (bool v) => setState(() => _isDefault = v),
              ),
            ],
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.pop(
              context,
              SavedAddress(
                id: widget.initial?.id ?? '',
                label: _label.text.trim(),
                line1: _line1.text.trim(),
                line2: _line2.text.trim(),
                city: _city.text.trim(),
                phone: _phone.text.trim(),
                isDefault: _isDefault,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
