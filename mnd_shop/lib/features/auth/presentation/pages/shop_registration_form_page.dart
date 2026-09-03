import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_shop/core/media/shop_cover_image_picker.dart';
import 'package:mnd_shop/features/auth/data/shop_registration_repository.dart';
import 'package:mnd_shop/features/auth/domain/shop_registration_payload.dart';
import 'package:mnd_shop/features/auth/presentation/providers/shop_registration_category_provider.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_pick_result.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_picker_page.dart';

/// Full vendor onboarding form (location, hours, wages, up to four shop photos).
/// Creates `vendors/{uid}` with `approvalStatus: pending` and `active: false`.
class ShopRegistrationFormPage extends ConsumerStatefulWidget {
  const ShopRegistrationFormPage({super.key});

  @override
  ConsumerState<ShopRegistrationFormPage> createState() =>
      _ShopRegistrationFormPageState();
}

class _ShopRegistrationFormPageState
    extends ConsumerState<ShopRegistrationFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  int _currentStep = 0;

  final TextEditingController _shopName = TextEditingController();
  final TextEditingController _shopDescription = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _address = TextEditingController();
  final TextEditingController _city = TextEditingController();

  /// Set only via [Pin on map]; defaults to Colombo until pinned.
  double _pinLatitude = 6.9271;
  double _pinLongitude = 79.8612;
  bool _locationPinned = false;
  String _pinnedAddressLabel = '';
  final TextEditingController _hoursNote = TextEditingController();

  /// Doc id from `shop_categories` (or synthetic `__fb_*` when offline).
  String? _selectedCategoryId;
  String _shopTypeLabel = '';
  TimeOfDay _open = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _close = const TimeOfDay(hour: 21, minute: 0);
  bool _closedSunday = false;
  final List<Uint8List?> _photos = List<Uint8List?>.filled(4, null);

  bool _submitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _error;

  static const List<ShopCategoryOption> _fallbackCategories =
      <ShopCategoryOption>[
        ShopCategoryOption(id: '__fb_food', label: 'Food', isGrocery: false),
        ShopCategoryOption(id: '__fb_grocery', label: 'Grocery', isGrocery: true),
      ];

  static const Map<String, List<String>> _fallbackShopTypesByCategory =
      <String, List<String>>{
        '__fb_food': <String>[
          'Restaurant',
          'Juice bar',
          'Rice and curry',
          'General',
        ],
        '__fb_grocery': <String>['Mini mart', 'General'],
      };

  @override
  void dispose() {
    _shopName.dispose();
    _shopDescription.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _address.dispose();
    _city.dispose();
    _hoursNote.dispose();
    super.dispose();
  }

  static String _fmtTime(TimeOfDay t) {
    final String h = t.hour.toString().padLeft(2, '0');
    final String m = t.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _pickShopPhoto() async {
    final Uint8List? bytes = await ShopCoverImagePicker.pickFromGalleryAndCrop(
      context,
    );
    if (bytes == null || !mounted) {
      return;
    }
    setState(() {
      _photos[0] = bytes;
      for (int i = 1; i < _photos.length; i++) {
        _photos[i] = null;
      }
    });
  }

  void _clearShopPhoto() {
    setState(() => _photos[0] = null);
  }

  Future<void> _openMapPicker() async {
    if (!isShopMapPickerSupported()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Map pin works on Android and iOS. Submitting uses Colombo-area defaults until you pin from a phone.',
            ),
          ),
        );
      }
      return;
    }
    final LatLng initial = LatLng(_pinLatitude, _pinLongitude);

    final ShopMapPickResult? picked = await ShopMapPickerPage.open(
      context,
      initialCenter: initial,
    );
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _pinLatitude = picked.latitude;
      _pinLongitude = picked.longitude;
      _locationPinned = true;
      if (picked.suggestedAddressLine.trim().isNotEmpty) {
        _address.text = picked.suggestedAddressLine.trim();
      }
      if (picked.suggestedCity.trim().isNotEmpty) {
        _city.text = picked.suggestedCity.trim();
      }
      _pinnedAddressLabel = _formatPinnedAddressLabel();
    });
  }

  String _formatPinnedAddressLabel() {
    final String line = _address.text.trim();
    final String city = _city.text.trim();
    if (line.isNotEmpty && city.isNotEmpty) {
      return '$line, $city';
    }
    if (line.isNotEmpty) {
      return line;
    }
    if (city.isNotEmpty) {
      return city;
    }
    return 'Lat ${_pinLatitude.toStringAsFixed(5)}, Lng ${_pinLongitude.toStringAsFixed(5)}';
  }

  Future<void> _pickTime({required bool open}) async {
    final TimeOfDay initial = open ? _open : _close;
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (picked != null) {
      setState(() {
        if (open) {
          _open = picked;
        } else {
          _close = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });
    if (_password.text != _confirmPassword.text) {
      setState(() => _error = 'Passwords do not match.');
      return;
    }
    final double la = _pinLatitude;
    final double ln = _pinLongitude;
    if (la.abs() > 90 || ln.abs() > 180) {
      setState(() => _error = 'Invalid pin location. Use Pin on map again.');
      return;
    }
    if (_photos.every((Uint8List? b) => b == null)) {
      setState(
        () => _error = 'Add at least one shop photo (you can add up to four).',
      );
      return;
    }

    if (_selectedCategoryId == null || _selectedCategoryId!.trim().isEmpty) {
      setState(() => _error = 'Select a shop category and shop type.');
      return;
    }

    final List<ShopCategoryOption> categoryOpts = _resolvedCategories(
      ref.read(shopRegistrationCategoriesProvider),
    );
    String categoryLabel = 'General';
    bool? categoryIsGrocery;
    for (final ShopCategoryOption c in categoryOpts) {
      if (c.id == _selectedCategoryId) {
        categoryLabel = c.label;
        categoryIsGrocery = c.isGrocery;
        break;
      }
    }

    final String cid = _selectedCategoryId!;
    final List<String> typeOpts = cid.startsWith('__fb_')
        ? (_fallbackShopTypesByCategory[cid] ?? const <String>['General'])
        : ref
              .read(shopRegistrationShopTypeLabelsProvider(cid))
              .maybeWhen(
                data: (List<String> list) =>
                    list.isNotEmpty ? list : const <String>['General'],
                orElse: () => const <String>['General'],
              );
    final String shopTypeResolved = typeOpts.isEmpty
        ? 'General'
        : (typeOpts.contains(_shopTypeLabel) ? _shopTypeLabel : typeOpts.first);

    final ShopRegistrationPayload payload = ShopRegistrationPayload(
      shopDisplayName: _shopName.text,
      email: _email.text.trim(),
      password: _password.text,
      phone: _phone.text.trim(),
      whatsapp: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
      addressLine: _address.text.trim(),
      city: _city.text.trim(),
      latitude: la,
      longitude: ln,
      shopDescription: _shopDescription.text.trim(),
      categoryLabel: categoryLabel,
      categoryIsGrocery: categoryIsGrocery,
      shopTypeLabel: shopTypeResolved,
      openTime: _fmtTime(_open),
      closeTime: _fmtTime(_close),
      closedSunday: _closedSunday,
      openingHoursExtraNote: _hoursNote.text.trim(),
      wageKitchenNotes: '',
      wageCounterNotes: '',
      wageDeliveryNotes: '',
      shopPhotos: List<Uint8List?>.from(_photos),
    );

    setState(() => _submitting = true);
    final ShopRegistrationResult result = await ref
        .read(shopRegistrationRepositoryProvider)
        .registerNewShop(payload);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (!result.isSuccess) {
      setState(() => _error = result.errorMessage);
      return;
    }
    // On success the user is signed in. Close this pushed form so the app shell
    // can show the dashboard/home immediately.
    if (mounted) {
      Navigator.of(context).pop<void>();
    }
  }

  List<ShopCategoryOption> _resolvedCategories(
    AsyncValue<List<ShopCategoryOption>> async,
  ) {
    return async.maybeWhen(
      data: (List<ShopCategoryOption> list) =>
          list.isNotEmpty ? list : _fallbackCategories,
      orElse: () => _fallbackCategories,
    );
  }

  List<String> _resolvedTypeLabels(
    String? categoryId,
    AsyncValue<List<String>> typesAsync,
  ) {
    final String id = categoryId ?? '';
    if (id.startsWith('__fb_')) {
      return _fallbackShopTypesByCategory[id] ?? const <String>['General'];
    }
    return typesAsync.maybeWhen(
      data: (List<String> list) =>
          list.isNotEmpty ? list : const <String>['General'],
      orElse: () => const <String>['General'],
    );
  }

  String? _effectiveCategoryId(List<ShopCategoryOption> categories) {
    if (_selectedCategoryId != null &&
        categories.any((ShopCategoryOption c) => c.id == _selectedCategoryId)) {
      return _selectedCategoryId;
    }
    return null;
  }

  bool _validateCurrentStep() {
    setState(() => _error = null);
    if (!_formKey.currentState!.validate()) {
      return false;
    }
    if (_currentStep == 0 && _photos.every((Uint8List? b) => b == null)) {
      setState(() => _error = 'Step 1: add at least one photo.');
      return false;
    }
    if (_currentStep == 1 &&
        (_selectedCategoryId == null || _selectedCategoryId!.trim().isEmpty)) {
      setState(() => _error = 'Step 2: select category and shop type.');
      return false;
    }
    if (_currentStep == 2) {
      if (!_locationPinned) {
        setState(() => _error = 'Step 3: pin your shop location on the map.');
        return false;
      }
      if (_pinLatitude.abs() > 90 || _pinLongitude.abs() > 180) {
        setState(() => _error = 'Step 3: set a valid map pin location.');
        return false;
      }
    }
    return true;
  }

  void _goToStep(int step) {
    if (step < 0 || step > 3 || step == _currentStep || _submitting) {
      return;
    }
    if (step < _currentStep) {
      setState(() {
        _error = null;
        _currentStep = step;
      });
      return;
    }
    if (!_validateCurrentStep()) {
      return;
    }
    setState(() => _currentStep = step);
  }

  void _handleBack() {
    if (_submitting) {
      return;
    }
    if (_currentStep > 0) {
      _prevStep();
      return;
    }
    Navigator.of(context).maybePop<void>();
  }

  void _nextStep() {
    if (!_validateCurrentStep()) {
      return;
    }
    if (_currentStep < 3) {
      setState(() => _currentStep += 1);
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      setState(() {
        _error = null;
        _currentStep -= 1;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<ShopCategoryOption>> categoriesAsync = ref.watch(
      shopRegistrationCategoriesProvider,
    );
    final List<ShopCategoryOption> categoryRows = _resolvedCategories(
      categoriesAsync,
    );
    final String? categoryValueId = _effectiveCategoryId(categoryRows);

    final AsyncValue<List<String>> shopTypesAsync =
        categoryValueId != null && !categoryValueId.startsWith('__fb_')
        ? ref.watch(shopRegistrationShopTypeLabelsProvider(categoryValueId))
        : const AsyncValue<List<String>>.data(<String>[]);

    final List<String> typeLabels = _resolvedTypeLabels(
      categoryValueId,
      shopTypesAsync,
    );
    final String shopTypeDropdownValue = typeLabels.isEmpty
        ? 'General'
        : (typeLabels.contains(_shopTypeLabel)
              ? _shopTypeLabel
              : typeLabels.first);

    final List<String> stepTitles = <String>[
      'Images, shop details & contact',
      'Category and shop type',
      'Location and opening hours',
      'Account and submit',
    ];
    Widget stepContent;
    if (_currentStep == 0) {
      stepContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _shopName,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Shop display name *'),
            validator: (String? v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _shopDescription,
            maxLength: 200,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Shop description *',
              hintText: 'Short description customers will see (max 200 chars)',
              alignLabelWithHint: true,
            ),
            validator: (String? v) {
              final String t = (v ?? '').trim();
              if (t.isEmpty) return 'Required';
              if (t.length < 10) return 'At least 10 characters';
              if (t.length > 200) return 'Max 200 characters';
              return null;
            },
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Shop phone *'),
            validator: (String? v) {
              final String t = v?.trim() ?? '';
              if (t.length < 8) {
                return 'Enter a valid phone';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _whatsapp,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'WhatsApp (optional)'),
          ),
          const SizedBox(height: 16),
          Text(
            'Shop image *',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Material(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: _submitting ? null : _pickShopPhoto,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    if (_photos[0] != null)
                      Image.memory(_photos[0]!, fit: BoxFit.cover)
                    else
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: <Color>[
                              Color(0xFFDCE3EA),
                              Color(0xFFC4CED8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.add_photo_alternate_outlined,
                            size: 42,
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    if (_photos[0] != null && !_submitting)
                      Positioned(
                        top: 6,
                        right: 6,
                        child: IconButton.filled(
                          style: IconButton.styleFrom(
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                          onPressed: _clearShopPhoto,
                          icon: const Icon(Icons.close, size: 18),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    } else if (_currentStep == 1) {
      stepContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (categoriesAsync.isLoading) ...<Widget>[
            const LinearProgressIndicator(),
            const SizedBox(height: 10),
          ],
          if (categoriesAsync.hasError) ...<Widget>[
            Text(
              'Could not load categories from server — using defaults.',
              style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
            ),
            const SizedBox(height: 10),
          ],
          DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: categoryValueId,
            decoration: const InputDecoration(labelText: 'Category *'),
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Choose category'),
              ),
              ...categoryRows.map(
                (ShopCategoryOption c) => DropdownMenuItem<String?>(
                  value: c.id,
                  child: Text(c.label),
                ),
              ),
            ],
            onChanged: _submitting
                ? null
                : (String? v) {
                    setState(() {
                      _selectedCategoryId = v;
                      _shopTypeLabel = '';
                    });
                  },
          ),
          if (categoryValueId != null &&
              !categoryValueId.startsWith('__fb_') &&
              shopTypesAsync.isLoading) ...<Widget>[
            const SizedBox(height: 8),
            const LinearProgressIndicator(),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            // ignore: deprecated_member_use
            value: shopTypeDropdownValue,
            decoration: InputDecoration(
              labelText: 'Shop type *',
              hintText: categoryValueId == null
                  ? 'Select category first'
                  : null,
            ),
            items: typeLabels
                .map(
                  (String t) =>
                      DropdownMenuItem<String>(value: t, child: Text(t)),
                )
                .toList(),
            onChanged:
                _submitting || categoryValueId == null || typeLabels.isEmpty
                ? null
                : (String? v) {
                    if (v != null) {
                      setState(() => _shopTypeLabel = v);
                    }
                  },
          ),
        ],
      );
    } else if (_currentStep == 2) {
      final ButtonStyle pillOutlineStyle = OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(44),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.9)),
        foregroundColor: const Color(0xFF40507D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
      stepContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _address,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Street / building / landmark *',
            ),
            validator: (String? v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _city,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'City *'),
            validator: (String? v) =>
                v == null || v.trim().isEmpty ? 'Required' : null,
          ),
          const SizedBox(height: 12),
          if (_locationPinned) ...<Widget>[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5EE),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF8BC9A8)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1F7A4A),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Pinned location',
                        style: theme.textTheme.labelLarge?.copyWith(
                          color: const Color(0xFF1F7A4A),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _pinnedAddressLabel,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF1E2330),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _submitting ? null : _openMapPicker,
              style: pillOutlineStyle,
              icon: const Icon(Icons.edit_location_alt_outlined, size: 18),
              label: const Text('Change pinned location'),
            ),
          ] else ...<Widget>[
            OutlinedButton.icon(
              onPressed: _submitting ? null : _openMapPicker,
              style: pillOutlineStyle,
              icon: const Icon(Icons.map_outlined, size: 18),
              label: const Text('Pin on map'),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(open: true),
                  style: pillOutlineStyle,
                  icon: const Icon(Icons.schedule_outlined, size: 17),
                  label: Text('Opens ${_fmtTime(_open)}'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickTime(open: false),
                  style: pillOutlineStyle,
                  icon: const Icon(Icons.schedule_outlined, size: 17),
                  label: Text('Closes ${_fmtTime(_close)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    'Closed on Sundays',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF2F3545),
                    ),
                  ),
                ),
                Switch.adaptive(
                  value: _closedSunday,
                  onChanged: (bool v) => setState(() => _closedSunday = v),
                ),
              ],
            ),
          ),
          TextFormField(
            controller: _hoursNote,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Extra hours note (optional)',
              hintText: 'e.g. closes 3–5pm Fri',
            ),
          ),
        ],
      );
    } else {
      stepContent = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: 'Email (login) *'),
            validator: (String? v) {
              final String t = v?.trim() ?? '';
              if (t.isEmpty) return 'Required';
              if (!t.contains('@')) return 'Invalid email';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _password,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password *',
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (String? v) =>
                v == null || v.length < 6 ? 'Min 6 characters' : null,
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _confirmPassword,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: 'Confirm password *',
              suffixIcon: IconButton(
                onPressed: () => setState(
                  () => _obscureConfirmPassword = !_obscureConfirmPassword,
                ),
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                ),
              ),
            ),
            validator: (String? v) =>
                v == null || v.isEmpty ? 'Required' : null,
          ),
        ],
      );
    }

    return PopScope(
      canPop: _currentStep == 0 && !_submitting,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        _handleBack();
      },
      child: Stack(
        children: <Widget>[
          Scaffold(
            backgroundColor: const Color(0xFFF3F5FF),
            appBar: AppBar(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: _submitting ? null : _handleBack,
              ),
              centerTitle: false,
              title: Text(
                'MND Shop Manager',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1E2330),
                  letterSpacing: -0.2,
                ),
              ),
            ),
            body: SafeArea(
        child: Theme(
          data: theme.copyWith(
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: const Color(0xFFFDFDFF),
              isDense: false,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 14,
              ),
              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF8B93A8),
              ),
              labelStyle: theme.textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF59617A),
                fontWeight: FontWeight.w600,
              ),
              floatingLabelStyle: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF2E55C7),
                fontWeight: FontWeight.w700,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(
                  color: cs.outlineVariant.withValues(alpha: 0.65),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF2F5EE9),
                  width: 1.4,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.error.withValues(alpha: 0.8)),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: cs.error, width: 1.3),
              ),
            ),
            dropdownMenuTheme: DropdownMenuThemeData(
              textStyle: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2432),
              ),
            ),
          ),
          child: LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              return Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 40),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - 50,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'STEP ${_currentStep + 1} OF 4',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: const Color(0xFF5A6AA5),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                stepTitles[_currentStep],
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF1E2330),
                                  height: 1.15,
                                  letterSpacing: -0.25,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              '${((_currentStep + 1) * 25)}% Complete',
                              style: theme.textTheme.labelMedium?.copyWith(
                                color: const Color(0xFF464D66),
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.1,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: List<Widget>.generate(4, (int i) {
                            final bool active = i == _currentStep;
                            final bool completed = i < _currentStep;
                            return Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(left: i == 0 ? 0 : 4),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _submitting
                                        ? null
                                        : () => _goToStep(i),
                                    borderRadius: BorderRadius.circular(999),
                                    child: AnimatedContainer(
                                      duration: const Duration(milliseconds: 200),
                                      height: 6,
                                      decoration: BoxDecoration(
                                        color: active || completed
                                            ? const Color(0xFF3C58B8)
                                            : const Color(0xFFD7DCEC),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.45),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              stepContent,
                              if (_error != null) ...<Widget>[
                                const SizedBox(height: 16),
                                Text(
                                  _error!,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.error,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 20),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.icon(
                                  onPressed: _submitting
                                      ? null
                                      : (_currentStep == 3
                                            ? _submit
                                            : _nextStep),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFF0F52CC),
                                    foregroundColor: Colors.white,
                                    minimumSize: const Size.fromHeight(48),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    textStyle: theme.textTheme.labelLarge
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  icon: _submitting
                                      ? const SizedBox(
                                          height: 18,
                                          width: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Icon(
                                          _currentStep == 3
                                              ? Icons.check_rounded
                                              : Icons.arrow_forward_rounded,
                                          size: 18,
                                        ),
                                  label: _submitting
                                      ? const Text('Processing...')
                                      : Text(
                                          _currentStep == 3
                                              ? 'Submit application'
                                              : 'Continue to Step ${_currentStep + 2}',
                                        ),
                                ),
                              ),
                              if (_currentStep > 0) ...<Widget>[
                                const SizedBox(height: 10),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: _submitting ? null : _prevStep,
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(46),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      side: BorderSide(
                                        color: cs.outlineVariant.withValues(
                                          alpha: 0.85,
                                        ),
                                      ),
                                    ),
                                    child: const Text('Back'),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Center(
                                child: TextButton(
                                  onPressed: _submitting
                                      ? null
                                      : () => Navigator.of(context).pop<void>(),
                                  child: const Text(
                                    'Already have an account? Login',
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ),
          if (_submitting)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.45),
                child: Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 32),
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 36,
                          height: 36,
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Creating your shop account…',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Uploading photos and saving your details. Please wait.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
