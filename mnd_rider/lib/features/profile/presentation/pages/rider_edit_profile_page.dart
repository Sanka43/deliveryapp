import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_photo_picker_tile.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile_edit_form.dart';
import 'package:mnd_rider/features/profile/presentation/providers/rider_profile_edit_provider.dart';

class RiderEditProfilePage extends ConsumerStatefulWidget {
  const RiderEditProfilePage({super.key, required this.initialProfile});

  final RiderProfile initialProfile;

  @override
  ConsumerState<RiderEditProfilePage> createState() =>
      _RiderEditProfilePageState();
}

class _RiderEditProfilePageState extends ConsumerState<RiderEditProfilePage> {
  late final RiderProfileEditForm _seed;
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _nic;
  late final TextEditingController _city;
  late final TextEditingController _vehicleNumber;
  RiderVehicleType _vehicleType = RiderVehicleType.bike;
  Uint8List? _profileBytes;

  @override
  void initState() {
    super.initState();
    _seed = RiderProfileEditForm.fromProfile(widget.initialProfile);
    _vehicleType = _seed.vehicleType;
    _name = TextEditingController(text: _seed.fullName);
    _phone = TextEditingController(text: _seed.phoneLocal);
    _nic = TextEditingController(text: _seed.nicNumber);
    _city = TextEditingController(text: _seed.city);
    _vehicleNumber = TextEditingController(text: _seed.vehicleNumber);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nic.dispose();
    _city.dispose();
    _vehicleNumber.dispose();
    super.dispose();
  }

  RiderProfileEditForm _buildForm() {
    return RiderProfileEditForm(
      fullName: _name.text,
      phoneLocal: _phone.text,
      nicNumber: _nic.text,
      city: _city.text,
      vehicleType: _vehicleType,
      vehicleNumber: _vehicleNumber.text,
      newProfilePhotoBytes: _profileBytes,
    );
  }

  String? _fieldError(String key) {
    return ref.watch(riderProfileEditProvider(_seed)).fieldErrors[key];
  }

  Future<void> _save() async {
    ref.read(riderProfileEditProvider(_seed).notifier).updateForm(_buildForm());
    final bool ok = await ref
        .read(riderProfileEditProvider(_seed).notifier)
        .submit();
    if (!mounted) {
      return;
    }
    if (ok) {
      showRiderSnackBar(context, 'Profile updated');
      context.pop();
      return;
    }
    final String? err = ref.read(riderProfileEditProvider(_seed)).errorMessage;
    if (err != null) {
      showRiderSnackBar(context, err);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final RiderProfileEditState editState = ref.watch(
      riderProfileEditProvider(_seed),
    );
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        actions: <Widget>[
          TextButton(
            onPressed: editState.isLoading ? null : _save,
            child: editState.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(
          AppSpacing.screenPadding,
          12,
          AppSpacing.screenPadding,
          32 + MediaQuery.paddingOf(context).bottom,
        ),
        children: <Widget>[
          if (_profileBytes == null)
            Center(
              child: CircleAvatar(
                radius: 44,
                backgroundImage:
                    (widget.initialProfile.profilePhotoUrl?.isNotEmpty ?? false)
                    ? NetworkImage(widget.initialProfile.profilePhotoUrl!)
                    : null,
                child:
                    (widget.initialProfile.profilePhotoUrl?.isNotEmpty ?? false)
                    ? null
                    : const Icon(Icons.person, size: 44),
              ),
            ),
          const SizedBox(height: 12),
          RiderPhotoPickerTile(
            label: 'Profile photo',
            hint: 'Tap to change from gallery or camera',
            bytes: _profileBytes,
            icon: Icons.person_outline,
            onPicked: (Uint8List data) => setState(() => _profileBytes = data),
          ),
          const SizedBox(height: 20),
          Text(
            'Personal details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: 'Full name',
              errorText: _fieldError('fullName'),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  '+94',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  readOnly: true,
                  enableInteractiveSelection: false,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'Mobile (verified)',
                    hintText: '771234567',
                    suffixIcon: Icon(
                      Icons.lock_outline_rounded,
                      size: 18,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    helperText: 'Phone can only change with a new OTP sign-in.',
                    helperMaxLines: 2,
                    errorText: _fieldError('phone'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _nic,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'NIC number',
              errorText: _fieldError('nicNumber'),
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _city,
            decoration: InputDecoration(
              labelText: 'City',
              errorText: _fieldError('city'),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Vehicle details',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: RiderVehicleType.values.map((RiderVehicleType type) {
              return FilterChip(
                label: Text(type.label),
                selected: _vehicleType == type,
                onSelected: (_) => setState(() => _vehicleType = type),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _vehicleNumber,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'Vehicle number',
              errorText: _fieldError('vehicleNumber'),
            ),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: editState.isLoading ? null : _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(editState.isLoading ? 'Saving…' : 'Save changes'),
            ),
          ),
        ],
      ),
    );
  }
}
