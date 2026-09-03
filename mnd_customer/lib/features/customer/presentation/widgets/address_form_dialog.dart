import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_pick_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/delivery_map_picker_page.dart';

/// Returns a [SavedAddress] (id may be empty for new records).
class AddressFormDialog extends StatefulWidget {
  const AddressFormDialog({
    required this.title,
    this.initial,
    this.onMapPickApplied,
    this.autoOpenMap = false,
    super.key,
  });

  final String title;
  final SavedAddress? initial;

  /// Called after a successful map pick so the host can sync (e.g. cart drop-off coords).
  final void Function(DeliveryMapPickResult result)? onMapPickApplied;

  /// When true, opens the map picker once after the dialog is shown.
  final bool autoOpenMap;

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
  double? _latitude;
  double? _longitude;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool _didAutoOpenMap = false;

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
    _latitude = i?.latitude;
    _longitude = i?.longitude;

    if (widget.autoOpenMap) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_didAutoOpenMap && mounted) {
          _didAutoOpenMap = true;
          _pickOnMap();
        }
      });
    }
  }

  /// Editing the address text by hand after a map pick means the pin may
  /// no longer match what's typed, so drop it and require a fresh pick.
  void _invalidatePin() {
    if (_latitude != null || _longitude != null) {
      setState(() {
        _latitude = null;
        _longitude = null;
      });
    }
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

  Future<void> _pickOnMap() async {
    final DeliveryMapPickResult? pick =
        await DeliveryMapPickerPage.pick(context);
    if (pick == null || !mounted) {
      return;
    }
    widget.onMapPickApplied?.call(pick);
    setState(() {
      _line1.text = pick.line1;
      _line2.text = pick.line2;
      _city.text = pick.city;
      _latitude = pick.latitude;
      _longitude = pick.longitude;
    });
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
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _DialogMapPickCta(onTap: _pickOnMap),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Or enter address details',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              TextFormField(
                controller: _label,
                decoration:
                    const InputDecoration(labelText: 'Label (e.g. Home)'),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
              ),
              TextFormField(
                controller: _line1,
                decoration: const InputDecoration(labelText: 'Address line 1'),
                validator: (String? v) =>
                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                onChanged: (_) => _invalidatePin(),
              ),
              TextFormField(
                controller: _line2,
                decoration:
                    const InputDecoration(labelText: 'Line 2 (optional)'),
              ),
              TextFormField(
                controller: _city,
                onChanged: (_) => _invalidatePin(),
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
                contentPadding: EdgeInsets.zero,
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
                latitude: _latitude,
                longitude: _longitude,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _DialogMapPickCta extends StatelessWidget {
  const _DialogMapPickCta({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primaryBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
            border: Border.all(
              color: AppColors.primaryBlue.withValues(alpha: 0.28),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.sm),
            child: Row(
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue,
                    borderRadius:
                        BorderRadius.circular(AppColors.cardRadiusSm),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.map_outlined,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Pick on map',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Fill address from a pinned location',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary.withValues(alpha: 0.9),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
