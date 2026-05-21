import 'dart:typed_data';

import 'package:flutter/material.dart';import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/domain/rider_registration_form.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_photo_picker_tile.dart';

class RiderRegisterPage extends ConsumerStatefulWidget {
  const RiderRegisterPage({super.key});

  @override
  ConsumerState<RiderRegisterPage> createState() => _RiderRegisterPageState();
}

class _RiderRegisterPageState extends ConsumerState<RiderRegisterPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _nic = TextEditingController();
  final TextEditingController _vehicleNumber = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  RiderVehicleType? _vehicleType;
  Uint8List? _profilePhotoBytes;
  Uint8List? _licensePhotoBytes;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _nic.dispose();
    _vehicleNumber.dispose();
    _city.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  RiderRegistrationForm _buildForm() {
    return RiderRegistrationForm(
      fullName: _name.text,
      phone: _phone.text,
      nicNumber: _nic.text,
      password: _password.text,
      confirmPassword: _confirmPassword.text,
      vehicleType: _vehicleType,
      vehicleNumber: _vehicleNumber.text,
      city: _city.text,
      profilePhotoBytes: _profilePhotoBytes,
      licensePhotoBytes: _licensePhotoBytes,
    );
  }

  Future<void> _submit() async {
    ref.read(riderRegistrationFormProvider.notifier).update(_buildForm());

    final bool ok = await ref.read(riderRegistrationSubmitProvider.notifier).submit();
    if (!mounted) {
      return;
    }

    final RiderRegistrationSubmitState state = ref.read(riderRegistrationSubmitProvider);
    if (!ok) {
      if (state.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.errorMessage!)),
        );
      }
      setState(() {});
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Registration submitted. An admin must approve your account before you can drive.',
        ),
        duration: Duration(seconds: 5),
      ),
    );
    context.go(RoutePaths.shell);
  }

  String? _fieldError(String key) =>
      ref.read(riderRegistrationSubmitProvider).fieldErrors[key];

  @override
  Widget build(BuildContext context) {
    final RiderRegistrationSubmitState submit = ref.watch(riderRegistrationSubmitProvider);
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider registration'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.canPop() ? context.pop() : context.go(RoutePaths.login),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            12,
            AppSpacing.screenPadding,
            32,
          ),
          children: <Widget>[
            Text(
              'Complete your profile',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Upload documents and vehicle info. Admin may review before you go online.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _name,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'Full name',
                errorText: _fieldError('fullName'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  margin: const EdgeInsets.only(top: 8),
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
                      labelText: 'Phone number',
                      hintText: '771234567 or 0771234567',
                      errorText: _fieldError('phone'),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nic,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'NIC number',
                errorText: _fieldError('nicNumber'),
              ),
            ),
            const SizedBox(height: 20),
            RiderPhotoPickerTile(
              label: 'Profile photo',
              hint: 'Clear face photo',
              bytes: _profilePhotoBytes,
              errorText: _fieldError('profilePhoto'),
              icon: Icons.person_outline,
              onPicked: (Uint8List data) => setState(() => _profilePhotoBytes = data),
            ),
            const SizedBox(height: 16),
            RiderPhotoPickerTile(
              label: 'Driving license photo',
              hint: 'Front of license',
              bytes: _licensePhotoBytes,
              errorText: _fieldError('licensePhoto'),
              icon: Icons.badge_outlined,
              onPicked: (Uint8List data) => setState(() => _licensePhotoBytes = data),
            ),
            const SizedBox(height: 20),
            Text(
              'Vehicle type',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (_fieldError('vehicleType') != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _fieldError('vehicleType')!,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: RiderVehicleType.values.map((RiderVehicleType type) {
                final bool selected = _vehicleType == type;
                return FilterChip(
                  label: Text(type.label),
                  selected: selected,
                  onSelected: (_) => setState(() => _vehicleType = type),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _vehicleNumber,
              textInputAction: TextInputAction.next,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: 'Vehicle number',
                errorText: _fieldError('vehicleNumber'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _city,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'City',
                errorText: _fieldError('city'),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _password,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Password',
                errorText: _fieldError('password'),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _confirmPassword,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                labelText: 'Confirm password',
                errorText: _fieldError('confirmPassword'),
              ),
              onFieldSubmitted: (_) => submit.isLoading ? null : _submit(),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: submit.isLoading ? null : _submit,
              child: submit.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit registration'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => context.go(RoutePaths.login),
              child: const Text('Already registered? Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
