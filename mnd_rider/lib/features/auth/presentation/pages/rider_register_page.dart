import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/domain/rider_registration_form.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_legal_policy_dialog.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_photo_picker_tile.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/registration/rider_registration_progress_bar.dart';

/// 3-step registration wizard (Personal → Documents → Vehicle) — light
/// chrome matching [RiderPhoneLoginPage].
class RiderRegisterPage extends ConsumerStatefulWidget {
  const RiderRegisterPage({super.key});

  @override
  ConsumerState<RiderRegisterPage> createState() => _RiderRegisterPageState();
}

class _RiderRegisterPageState extends ConsumerState<RiderRegisterPage> {
  static const Color _ink = Color(0xFF0A0A0A);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _field = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = AppColors.primaryBlue;
  static const Color _border = Color(0xFFE5E7EB);

  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _nic = TextEditingController();
  final TextEditingController _vehicleNumber = TextEditingController();
  final TextEditingController _city = TextEditingController();

  RiderVehicleType? _vehicleType;
  Uint8List? _profilePhotoBytes;
  Uint8List? _licensePhotoBytes;
  final Map<RiderVehiclePhotoSide, Uint8List> _vehiclePhotos =
      <RiderVehiclePhotoSide, Uint8List>{};
  Uint8List? _insurancePhotoBytes;
  Uint8List? _revenueLicensePhotoBytes;
  DateTime? _licenseExpiresAt;
  DateTime? _insuranceExpiresAt;
  DateTime? _revenueLicenseExpiresAt;
  bool _sendingOtp = false;
  bool _termsAccepted = false;

  static const RiderRegistrationValidator _validator =
      RiderRegistrationValidator();

  static const int _stepCount = 3;
  static const List<String> _stepTitles = <String>[
    'Personal details',
    'Documents',
    'Vehicle & licenses',
  ];

  int _currentStep = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _restoreDraft();
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _phone,
      _nic,
      _vehicleNumber,
      _city,
    ]) {
      controller.addListener(_onFormChanged);
    }
  }

  void _restoreDraft() {
    final RiderRegistrationForm draft = ref.read(riderRegistrationFormProvider);
    _name.text = draft.fullName;
    _phone.text = draft.phone;
    _nic.text = draft.nicNumber;
    _vehicleNumber.text = draft.vehicleNumber;
    _city.text = draft.city;
    _vehicleType = draft.vehicleType;
    _profilePhotoBytes = draft.profilePhotoBytes;
    _licensePhotoBytes = draft.licensePhotoBytes;
    _licenseExpiresAt = draft.licenseExpiresAt;
    _insurancePhotoBytes = draft.insurancePhotoBytes;
    _revenueLicensePhotoBytes = draft.revenueLicensePhotoBytes;
    _insuranceExpiresAt = draft.insuranceExpiresAt;
    _revenueLicenseExpiresAt = draft.revenueLicenseExpiresAt;
    for (final RiderVehiclePhotoSide side in RiderVehiclePhotoSide.values) {
      final Uint8List? bytes = draft.vehiclePhotoBytesFor(side);
      if (bytes != null && bytes.isNotEmpty) {
        _vehiclePhotos[side] = bytes;
      }
    }
    if (draft.hasAllVehiclePhotos && draft.fullName.trim().isNotEmpty) {
      _termsAccepted = true;
    }
  }

  void _onFormChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  bool get _isFormComplete => _validator.validate(_buildForm()).isValid;

  bool _canSubmit(bool busy) => !busy && _termsAccepted && _isFormComplete;

  @override
  void dispose() {
    for (final TextEditingController controller in <TextEditingController>[
      _name,
      _phone,
      _nic,
      _vehicleNumber,
      _city,
    ]) {
      controller.removeListener(_onFormChanged);
    }
    _name.dispose();
    _phone.dispose();
    _nic.dispose();
    _vehicleNumber.dispose();
    _city.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    showRiderSnackBar(context, message);
  }

  RiderRegistrationForm _buildForm() {
    return RiderRegistrationForm(
      fullName: _name.text,
      phone: _phone.text,
      nicNumber: _nic.text,
      vehicleType: _vehicleType,
      vehicleNumber: _vehicleNumber.text,
      city: _city.text,
      profilePhotoBytes: _profilePhotoBytes,
      licensePhotoBytes: _licensePhotoBytes,
      licenseExpiresAt: _licenseExpiresAt,
      vehiclePhotoFrontBytes: _vehiclePhotos[RiderVehiclePhotoSide.front],
      vehiclePhotoBackBytes: _vehiclePhotos[RiderVehiclePhotoSide.back],
      vehiclePhotoLeftBytes: _vehiclePhotos[RiderVehiclePhotoSide.left],
      vehiclePhotoRightBytes: _vehiclePhotos[RiderVehiclePhotoSide.right],
      insurancePhotoBytes: _insurancePhotoBytes,
      insuranceExpiresAt: _insuranceExpiresAt,
      revenueLicensePhotoBytes: _revenueLicensePhotoBytes,
      revenueLicenseExpiresAt: _revenueLicenseExpiresAt,
    );
  }

  void _syncForm() {
    ref.read(riderRegistrationFormProvider.notifier).update(_buildForm());
  }

  void _finishRegistration() {
    context.go(RoutePaths.registerSubmitting);
  }

  Future<void> _submit() async {
    if (!_termsAccepted) {
      _showSnack('Please agree to the Terms of Service and Privacy Policy.');
      return;
    }
    _syncForm();
    if (!ref.read(riderRegistrationSubmitProvider.notifier).validateOnly()) {
      setState(() {});
      return;
    }

    final String e164 = normalizeSriLankaPhone(
      RiderPhoneAuthController.dialCode,
      _phone.text.trim(),
    );
    final RiderAuthRepository authRepo = ref.read(riderAuthRepositoryProvider);

    if (authRepo.isPhoneVerifiedFor(e164)) {
      _finishRegistration();
      return;
    }

    // Drop stale login/register OTP sessions so we always request a fresh code.
    ref.read(riderPhoneAuthProvider.notifier).clearSession();

    // Avoid Auth uid / phone mismatches during registration OTP.
    final User? currentUser = authRepo.currentUser;
    if (currentUser != null && !authRepo.isPhoneVerifiedFor(e164)) {
      try {
        await authRepo.signOut();
      } catch (_) {}
      if (!mounted) {
        return;
      }
    }

    setState(() => _sendingOtp = true);
    final String? verificationId = await ref
        .read(riderPhoneAuthProvider.notifier)
        .sendOtp(_phone.text.trim(), intent: 'register', force: true);
    if (!mounted) {
      return;
    }
    setState(() => _sendingOtp = false);

    if (verificationId == null || verificationId.isEmpty) {
      final String? err = ref.read(riderPhoneAuthProvider).errorMessage;
      _showSnack(
        err ?? 'Could not send verification code. Please try again.',
      );
      return;
    }

    _showSnack('Verification code sent to ${_formatPhoneForSnack(e164)}');
    context.go(RoutePaths.otp);
  }

  String _formatPhoneForSnack(String e164) {
    final String digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 11 && digits.startsWith('94')) {
      final String local = digits.substring(2);
      if (local.length == 9) {
        return '+94 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
      }
    }
    return e164;
  }

  Future<void> _goToLogin() async {
    try {
      await ref.read(riderAuthRepositoryProvider).signOut();
    } catch (_) {}
    if (!mounted) {
      return;
    }
    context.go(RoutePaths.login);
  }

  /// Validates only the current step's fields (reusing the same field-error
  /// surfacing the full-form submit already uses) and advances if valid.
  void _goNext() {
    _syncForm();
    final bool valid = ref
        .read(riderRegistrationSubmitProvider.notifier)
        .validateStepOnly(_currentStep);
    if (!valid) {
      setState(() {});
      return;
    }
    if (_currentStep >= _stepCount - 1) {
      return;
    }
    setState(() => _currentStep += 1);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  /// Steps 1-2 step back without losing data; step 0 exits to login.
  void _goBack() {
    if (_currentStep == 0) {
      _goToLogin();
      return;
    }
    setState(() => _currentStep -= 1);
    _pageController.animateToPage(
      _currentStep,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOut,
    );
  }

  String? _fieldError(String key) =>
      ref.read(riderRegistrationSubmitProvider).fieldErrors[key];

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select expiry date';
    }
    return DateFormat('dd MMM yyyy').format(date);
  }

  Future<void> _pickExpiryDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final DateTime now = DateTime.now();
    final DateTime initial = current ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 15),
      builder: (BuildContext context, Widget? child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: _ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      onPicked(picked);
    }
  }

  Widget _gap([double h = 12]) => SizedBox(height: h);

  Widget _sectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: _ink,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            color: _muted,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        color: _ink,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required String? errorText,
    required VoidCallback onTap,
  }) {
    final bool hasError = errorText != null && errorText.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _fieldLabel(label),
        const SizedBox(height: 8),
        Material(
          color: _field,
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            child: Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                border: Border.all(
                  color: hasError ? AppColors.errorRed : _border,
                ),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.event_rounded,
                    size: 20,
                    color: _muted.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _formatDate(value),
                      style: GoogleFonts.plusJakartaSans(
                        color: value == null ? const Color(0xFF9CA3AF) : _ink,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: _muted.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (hasError) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            errorText,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.errorRed,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPersonalSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sectionTitle('Personal details', 'Name, phone, NIC and city'),
        const SizedBox(height: 16),
        _fieldLabel('Full name'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _name,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle(),
          cursorColor: _accent,
          decoration: _fieldDecoration(
            hint: 'Your full name',
            errorText: _fieldError('fullName'),
          ),
        ),
        _gap(16),
        _fieldLabel('Phone number'),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _field,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                border: Border.all(color: _border),
              ),
              child: Text(
                '+94',
                style: GoogleFonts.plusJakartaSans(
                  color: _ink,
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                style: _fieldTextStyle(letterSpacing: 0.4),
                cursorColor: _accent,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                decoration: _fieldDecoration(
                  hint: '7X XXX XXXX',
                  errorText: _fieldError('phone'),
                ),
              ),
            ),
          ],
        ),
        _gap(16),
        _fieldLabel('NIC number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _nic,
          textInputAction: TextInputAction.next,
          textCapitalization: TextCapitalization.characters,
          style: _fieldTextStyle(),
          cursorColor: _accent,
          decoration: _fieldDecoration(
            hint: 'NIC number',
            errorText: _fieldError('nicNumber'),
          ),
        ),
        _gap(16),
        _fieldLabel('City'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _city,
          textInputAction: TextInputAction.next,
          style: _fieldTextStyle(),
          cursorColor: _accent,
          decoration: _fieldDecoration(
            hint: 'City',
            errorText: _fieldError('city'),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sectionTitle(
          'Documents',
          'Clear photos help approval go faster',
        ),
        const SizedBox(height: 16),
        RiderPhotoPickerTile(
          label: 'Profile photo',
          hint: 'Clear face photo',
          bytes: _profilePhotoBytes,
          errorText: _fieldError('profilePhoto'),
          icon: Icons.person_outline,
          onPicked: (Uint8List data) => setState(() => _profilePhotoBytes = data),
        ),
        _gap(14),
        RiderPhotoPickerTile(
          label: 'Driving license',
          hint: 'Front of license',
          bytes: _licensePhotoBytes,
          errorText: _fieldError('licensePhoto'),
          icon: Icons.badge_outlined,
          onPicked: (Uint8List data) => setState(() => _licensePhotoBytes = data),
        ),
      ],
    );
  }

  Widget _buildVehicleSection(bool busy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _sectionTitle(
          'Vehicle & licenses',
          'Vehicle, insurance and revenue license',
        ),
        const SizedBox(height: 16),
        _fieldLabel('Vehicle type'),
        if (_fieldError('vehicleType') != null) ...<Widget>[
          const SizedBox(height: 6),
          Text(
            _fieldError('vehicleType')!,
            style: GoogleFonts.plusJakartaSans(
              color: AppColors.errorRed,
              fontSize: 12,
            ),
          ),
        ],
        const SizedBox(height: 10),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 2.6,
          children: RiderVehicleType.values.map((RiderVehicleType type) {
            final bool selected = _vehicleType == type;
            return Material(
              color: selected ? _ink : _field,
              borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
              child: InkWell(
                onTap: busy ? null : () => setState(() => _vehicleType = type),
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                child: Container(
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                    border: Border.all(
                      color: selected ? _ink : _border,
                    ),
                  ),
                  child: Text(
                    type.label,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      color: selected ? Colors.white : _ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        _gap(16),
        _fieldLabel('Vehicle number'),
        const SizedBox(height: 8),
        TextFormField(
          controller: _vehicleNumber,
          textInputAction: TextInputAction.done,
          textCapitalization: TextCapitalization.characters,
          style: _fieldTextStyle(),
          cursorColor: _accent,
          decoration: _fieldDecoration(
            hint: 'Vehicle number',
            errorText: _fieldError('vehicleNumber'),
          ),
        ),
        _gap(14),
        _fieldLabel('Vehicle photos'),
        const SizedBox(height: 4),
        Text(
          'Upload front, back, left and right views',
          style: GoogleFonts.plusJakartaSans(
            color: _muted,
            fontSize: 13,
            height: 1.35,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        ...RiderVehiclePhotoSide.values.expand((RiderVehiclePhotoSide side) {
          return <Widget>[
            RiderPhotoPickerTile(
              label: 'Vehicle — ${side.label}',
              hint: side.hint,
              bytes: _vehiclePhotos[side],
              errorText: _fieldError(side.fieldErrorKey),
              icon: Icons.two_wheeler_rounded,
              onPicked: (Uint8List data) => setState(() {
                _vehiclePhotos[side] = data;
              }),
            ),
            _gap(14),
          ];
        }),
        _dateField(
          label: 'Driving license expiry date',
          value: _licenseExpiresAt,
          errorText: _fieldError('licenseExpiresAt'),
          onTap: busy
              ? () {}
              : () => _pickExpiryDate(
                    current: _licenseExpiresAt,
                    onPicked: (DateTime d) =>
                        setState(() => _licenseExpiresAt = d),
                  ),
        ),
        _gap(14),
        RiderPhotoPickerTile(
          label: 'Insurance photo',
          hint: 'Insurance certificate / card',
          bytes: _insurancePhotoBytes,
          errorText: _fieldError('insurancePhoto'),
          icon: Icons.health_and_safety_outlined,
          onPicked: (Uint8List data) =>
              setState(() => _insurancePhotoBytes = data),
        ),
        _gap(14),
        _dateField(
          label: 'Insurance expiry date',
          value: _insuranceExpiresAt,
          errorText: _fieldError('insuranceExpiresAt'),
          onTap: busy
              ? () {}
              : () => _pickExpiryDate(
                    current: _insuranceExpiresAt,
                    onPicked: (DateTime d) =>
                        setState(() => _insuranceExpiresAt = d),
                  ),
        ),
        _gap(14),
        RiderPhotoPickerTile(
          label: 'Revenue license photo',
          hint: 'Revenue license document',
          bytes: _revenueLicensePhotoBytes,
          errorText: _fieldError('revenueLicensePhoto'),
          icon: Icons.description_outlined,
          onPicked: (Uint8List data) =>
              setState(() => _revenueLicensePhotoBytes = data),
        ),
        _gap(14),
        _dateField(
          label: 'Revenue license expiry date',
          value: _revenueLicenseExpiresAt,
          errorText: _fieldError('revenueLicenseExpiresAt'),
          onTap: busy
              ? () {}
              : () => _pickExpiryDate(
                    current: _revenueLicenseExpiresAt,
                    onPicked: (DateTime d) =>
                        setState(() => _revenueLicenseExpiresAt = d),
                  ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox(bool busy) {
    final TextStyle linkStyle = GoogleFonts.plusJakartaSans(
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w700,
      color: _accent,
      decoration: TextDecoration.underline,
      decorationColor: _accent,
    );
    final TextStyle bodyStyle = GoogleFonts.plusJakartaSans(
      fontSize: 13,
      height: 1.45,
      fontWeight: FontWeight.w500,
      color: _muted,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: 24,
          width: 24,
          child: Checkbox(
            value: _termsAccepted,
            onChanged: busy
                ? null
                : (bool? value) =>
                    setState(() => _termsAccepted = value ?? false),
            activeColor: _ink,
            side: BorderSide(color: _muted.withValues(alpha: 0.5)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              Text('I agree to the ', style: bodyStyle),
              GestureDetector(
                onTap: busy
                    ? null
                    : () => showRiderLegalPolicyDialog(
                          context,
                          type: RiderLegalPolicyType.terms,
                        ),
                child: Text('Terms of Service', style: linkStyle),
              ),
              Text(' and ', style: bodyStyle),
              GestureDetector(
                onTap: busy
                    ? null
                    : () => showRiderLegalPolicyDialog(
                          context,
                          type: RiderLegalPolicyType.privacy,
                        ),
                child: Text('Privacy Policy', style: linkStyle),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final RiderRegistrationSubmitState submit =
        ref.watch(riderRegistrationSubmitProvider);
    final bool busy = submit.isLoading || _sendingOtp;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _RegisterBrandBackground(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.lg, 0),
                    child: Row(
                      children: <Widget>[
                        IconButton(
                          onPressed: busy ? null : _goBack,
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: _ink.withValues(alpha: busy ? 0.35 : 0.9),
                          ),
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _stepTitles[_currentStep],
                                style: GoogleFonts.plusJakartaSans(
                                  color: _ink,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0,
                                ),
                              ),
                              Text(
                                'Step ${_currentStep + 1} of $_stepCount',
                                style: GoogleFonts.plusJakartaSans(
                                  color: _muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      12,
                      AppSpacing.lg,
                      0,
                    ),
                    child: RiderRegistrationProgressBar(
                      currentStep: _currentStep,
                      stepCount: _stepCount,
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: <Widget>[
                        _buildStepScroll(_buildPersonalSection()),
                        _buildStepScroll(_buildDocumentsSection()),
                        _buildStepScroll(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              _buildVehicleSection(busy),
                              if (submit.errorMessage != null) ...<Widget>[
                                const SizedBox(height: AppSpacing.md),
                                Text(
                                  submit.errorMessage!,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: AppColors.errorRed,
                                    fontSize: 13,
                                    height: 1.35,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 28),
                              _buildTermsCheckbox(busy),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      12,
                      AppSpacing.lg,
                      16,
                    ),
                    child: _currentStep < _stepCount - 1
                        ? SizedBox(
                            height: AppSpacing.ctaHeight,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: busy ? null : _goNext,
                              style: FilledButton.styleFrom(
                                backgroundColor: _ink,
                                disabledBackgroundColor:
                                    _ink.withValues(alpha: 0.4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.buttonRadius,
                                  ),
                                ),
                              ),
                              child: Text(
                                'Next',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          )
                        : SizedBox(
                            height: AppSpacing.ctaHeight,
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: _canSubmit(busy) ? _submit : null,
                              style: FilledButton.styleFrom(
                                backgroundColor: _ink,
                                disabledBackgroundColor:
                                    _ink.withValues(alpha: 0.4),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    AppSpacing.buttonRadius,
                                  ),
                                ),
                              ),
                              child: busy
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Text(
                                      'Verify phone & register',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16,
                                      ),
                                    ),
                            ),
                          ),
                  ),
                  if (_currentStep == 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: TextButton(
                        onPressed: busy ? null : _goToLogin,
                        style: TextButton.styleFrom(
                          foregroundColor: _accent,
                          disabledForegroundColor:
                              _muted.withValues(alpha: 0.4),
                        ),
                        child: Text.rich(
                          TextSpan(
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: _muted,
                            ),
                            children: <InlineSpan>[
                              const TextSpan(text: 'Already registered? '),
                              TextSpan(
                                text: 'Sign in',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  color: _accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStepScroll(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(AppSpacing.lg, 8, AppSpacing.lg, 24),
      child: child,
    );
  }
}

/// Soft photo wash + light overlay — matches login.
class _RegisterBrandBackground extends StatelessWidget {
  const _RegisterBrandBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/onboarding/deliver.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return const ColoredBox(color: Color(0xFFF5F5F5));
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xB3F5F5F5),
                Color(0xE6F5F5F5),
                Color(0xF5F5F5F5),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _fieldBorder({Color? color}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      borderSide: BorderSide(color: color ?? const Color(0xFFE5E7EB)),
    );

InputDecoration _fieldDecoration({
  required String hint,
  String? errorText,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.plusJakartaSans(
      color: const Color(0xFF9CA3AF),
      fontWeight: FontWeight.w400,
      fontSize: 15,
    ),
    errorText: errorText,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _fieldBorder(),
    enabledBorder: _fieldBorder(),
    focusedBorder: _fieldBorder(color: AppColors.primaryBlue),
    errorBorder: _fieldBorder(color: AppColors.errorRed),
    focusedErrorBorder: _fieldBorder(color: AppColors.errorRed),
    errorStyle: GoogleFonts.plusJakartaSans(
      color: AppColors.errorRed,
      fontSize: 12,
    ),
  );
}

TextStyle _fieldTextStyle({double letterSpacing = 0}) =>
    GoogleFonts.plusJakartaSans(
      color: const Color(0xFF0A0A0A),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: letterSpacing,
    );
