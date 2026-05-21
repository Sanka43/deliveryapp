import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_photo_picker_tile.dart';
import 'package:mnd_rider/features/profile/data/rider_avatar_storage.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile_edit_form.dart';
import 'package:mnd_rider/features/profile/presentation/providers/rider_profile_edit_provider.dart';

class RiderEditProfilePage extends ConsumerStatefulWidget {
  const RiderEditProfilePage({
    super.key,
    required this.initialProfile,
  });

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
  Uint8List? _licenseBytes;
  bool _uploadingPhoto = false;

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

  ImageProvider? _avatarImage() {
    if (_profileBytes != null) {
      return MemoryImage(_profileBytes!);
    }
    final String? url = widget.initialProfile.profilePhotoUrl;
    if (url != null && url.isNotEmpty) {
      return NetworkImage(url);
    }
    return null;
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
      newLicensePhotoBytes: _licenseBytes,
    );
  }

  String? _fieldError(String key) {
    return ref.watch(riderProfileEditProvider(_seed)).fieldErrors[key];
  }

  Future<void> _save() async {
    ref.read(riderProfileEditProvider(_seed).notifier).updateForm(_buildForm());
    final bool ok =
        await ref.read(riderProfileEditProvider(_seed).notifier).submit();
    if (!mounted) {
      return;
    }
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      context.pop();
      return;
    }
    final String? err = ref.read(riderProfileEditProvider(_seed)).errorMessage;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    }
    setState(() {});
  }

  Future<void> _quickUploadProfilePhoto() async {
    setState(() => _uploadingPhoto = true);
    final String? err =
        await ref.read(riderAvatarStorageProvider).pickAndUploadProfile();
    if (mounted) {
      setState(() => _uploadingPhoto = false);
      if (err != null && err.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      } else if (err == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile photo updated')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final RiderProfileEditState editState =
        ref.watch(riderProfileEditProvider(_seed));
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
          Center(
            child: Stack(
              children: <Widget>[
                CircleAvatar(
                  radius: 48,
                  backgroundImage: _avatarImage(),
                  child: _avatarImage() == null
                      ? const Icon(Icons.person, size: 48)
                      : null,
                ),
                if (_uploadingPhoto)
                  const Positioned.fill(
                    child: ColoredBox(
                      color: Color(0x66000000),
                      child: Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton.icon(
              onPressed: _uploadingPhoto ? null : _quickUploadProfilePhoto,
              icon: const Icon(Icons.cloud_upload_outlined, size: 18),
              label: const Text('Upload now'),
            ),
          ),
          const SizedBox(height: 8),
          RiderPhotoPickerTile(
            label: 'New profile photo (optional)',
            hint: 'Tap to pick from gallery',
            bytes: _profileBytes,
            icon: Icons.person_outline,
            onPicked: (Uint8List data) => setState(() => _profileBytes = data),
          ),
          const SizedBox(height: 16),
          RiderPhotoPickerTile(
            label: 'Driving license photo',
            hint: 'Update license image',
            bytes: _licenseBytes,
            icon: Icons.badge_outlined,
            onPicked: (Uint8List data) => setState(() => _licenseBytes = data),
          ),
          if (widget.initialProfile.licensePhotoUrl != null &&
              _licenseBytes == null) ...<Widget>[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                widget.initialProfile.licensePhotoUrl!,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text(
            'Personal details',
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text('+94', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Mobile',
                    hintText: '771234567',
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
            style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
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
