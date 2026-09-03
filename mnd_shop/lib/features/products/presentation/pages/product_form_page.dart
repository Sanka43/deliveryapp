import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/products/data/product_image_storage.dart';
import 'package:mnd_shop/features/products/data/vendor_product_repository.dart';
import 'package:mnd_shop/features/products/domain/product_option_labels.dart';
import 'package:mnd_shop/features/products/domain/vendor_grocery_catalog.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/widgets/product_form_pricing_widgets.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';
import 'package:mnd_shop/features/products/presentation/providers/grocery_aisle_labels_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

const List<String> _kSizeLabels = kFoodSizeLabels;
const double _kFormFieldRadius = kVendorFormFieldRadius;

/// Prep-time presets for the ETA dropdown (Custom opens a text field).
const List<String> _kEtaPresets = <String>[
  '5-10 min',
  '10-15 min',
  '15-20 min',
  '20-30 min',
  '30-45 min',
  '45-60 min',
  '1 hr',
];

const String _kEtaCustomDropdownValue = '__eta_custom__';

String _portionLabelForSave({required bool single, required String personCountRaw}) {
  if (single) {
    return 'Single portion';
  }
  final String digits = personCountRaw.trim();
  final int n = int.tryParse(digits) ?? 2;
  final int safe = n < 1 ? 1 : (n > 99 ? 99 : n);
  return '$safe person';
}

class ProductFormPage extends ConsumerStatefulWidget {
  const ProductFormPage({super.key, required this.product});

  final VendorProduct? product;

  bool get isEdit => product != null;

  @override
  ConsumerState<ProductFormPage> createState() => _ProductFormPageState();
}

class _ComboPriceRow {
  _ComboPriceRow({
    required this.label,
    required this.priceCtrl,
  });

  final String label;
  final TextEditingController priceCtrl;
}

class _CustomRow {
  _CustomRow({
    required this.labelCtrl,
    required this.priceCtrl,
  });

  final TextEditingController labelCtrl;
  final TextEditingController priceCtrl;
}

class _ProductFormPageState extends ConsumerState<ProductFormPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _stockCtrl;
  late final TextEditingController _etaCtrl;
  late final List<TextEditingController> _sizeDraftPriceCtrls;
  late final List<TextEditingController> _packDraftPriceCtrls;
  late final TextEditingController _portionSingleLkrCtrl;
  late final TextEditingController _portionMultiPersonCtrl;
  late final TextEditingController _portionMultiLkrCtrl;
  late final TextEditingController _halfLkrCtrl;
  late final TextEditingController _fullLkrCtrl;
  late final TextEditingController _customTypeCtrl;
  final List<_ComboPriceRow> _comboRows = <_ComboPriceRow>[];
  final List<_CustomRow> _customRows = <_CustomRow>[];
  /// Food-only second dimension (Chicken / Beef / …). Empty = single-dimension pricing.
  final List<String> _selectedTypes = <String>[];
  /// Absolute LKR for `{Type} · {Size}` combos when [_selectedTypes] is non-empty.
  final Map<String, TextEditingController> _matrixPriceCtrls =
      <String, TextEditingController>{};
  bool _active = true;
  bool _manageStock = false;
  bool _pricedOptionsMode = false;
  /// Which variable type is being edited: `size`, `portion`, `half`, or `pack`.
  String _priceVariableKind = 'size';
  String _productCategory = '';
  Uint8List? _pickedBytes;
  String? _pickedName;
  bool _saving = false;
  bool _appliedCatalogDefaults = false;

  @override
  void initState() {
    super.initState();
    final VendorProduct? p = widget.product;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _descCtrl = TextEditingController(text: p?.description ?? '');
    _priceCtrl = TextEditingController(
      text: p != null ? '${p.priceLkr}' : '',
    );
    _manageStock = p?.manageStock ?? false;
    _stockCtrl = TextEditingController(
      text: p != null && p.manageStock ? '${p.stockQty}' : '0',
    );
    final String initialEta = (p?.etaLabel ?? '').trim();
    _etaCtrl = TextEditingController(
      text: initialEta.isNotEmpty ? initialEta : _kEtaPresets[2],
    );
    _active = p?.active ?? true;
    _productCategory = (p?.productCategory ?? '').trim();
    _sizeDraftPriceCtrls = List<TextEditingController>.generate(
      _kSizeLabels.length,
      (_) => TextEditingController(),
      growable: false,
    );
    _packDraftPriceCtrls = List<TextEditingController>.generate(
      kGroceryPackLabels.length,
      (_) => TextEditingController(),
      growable: false,
    );
    _portionSingleLkrCtrl = TextEditingController();
    _portionMultiPersonCtrl = TextEditingController(text: '2');
    _portionMultiLkrCtrl = TextEditingController();
    _halfLkrCtrl = TextEditingController();
    _fullLkrCtrl = TextEditingController();
    _customTypeCtrl = TextEditingController();

    if (p != null && p.sizeOptions.isNotEmpty) {
      _pricedOptionsMode = true;
      final bool looksGroceryPack = p.sizeOptions.any(
        (ProductSizeOption o) => kGroceryPackLabels.contains(o.name.trim()),
      );
      if (looksGroceryPack) {
        _priceVariableKind = 'pack';
      } else {
        _hydrateTypeSizeMatrixFromOptions(p.sizeOptions);
      }
      for (final ProductSizeOption opt in p.sizeOptions) {
        if (_selectedTypes.isNotEmpty &&
            parseTypeSizeComboLabel(opt.name) != null) {
          // Already loaded into the Type × Size matrix.
          continue;
        }
        // When matrix mode is active, leftovers must live in custom rows —
        // combo/draft rows are not written on save in matrix mode.
        if (_selectedTypes.isNotEmpty ||
            !labelLooksLikePresetOption(opt.name)) {
          _customRows.add(
            _CustomRow(
              labelCtrl: TextEditingController(text: opt.name),
              priceCtrl: TextEditingController(text: '${opt.priceLkr}'),
            ),
          );
        } else {
          _comboRows.add(
            _ComboPriceRow(
              label: opt.name,
              priceCtrl: TextEditingController(text: '${opt.priceLkr}'),
            ),
          );
        }
      }
    }
  }

  /// Reconstructs Type chips + matrix prices from saved `{Type} · {Size}` options.
  void _hydrateTypeSizeMatrixFromOptions(List<ProductSizeOption> options) {
    final List<({String type, String size, int priceLkr})> typed =
        <({String type, String size, int priceLkr})>[];
    String? inferredKind;
    for (final ProductSizeOption opt in options) {
      final ({String type, String size})? parsed =
          parseTypeSizeComboLabel(opt.name);
      if (parsed == null) {
        continue;
      }
      final String size = _normalizeMatrixSizeLabel(parsed.size);
      final String? kind = priceKindForSizeLabel(size);
      if (kind == null || kind == 'pack') {
        continue;
      }
      inferredKind ??= kind;
      if (kind != inferredKind) {
        // Mixed kinds → do not enter matrix mode.
        _selectedTypes.clear();
        _disposeMatrixCtrls();
        return;
      }
      typed.add((type: parsed.type, size: size, priceLkr: opt.priceLkr));
    }
    if (typed.isEmpty || inferredKind == null) {
      return;
    }
    _priceVariableKind = inferredKind;
    if (inferredKind == 'portion') {
      for (final ({String type, String size, int priceLkr}) row in typed) {
        final Match? m = RegExp(r'^(\d+)\s*person$').firstMatch(row.size);
        if (m != null) {
          _portionMultiPersonCtrl.text = m.group(1)!;
          break;
        }
      }
    }
    final List<String> types = <String>[];
    final Set<String> seen = <String>{};
    for (final ({String type, String size, int priceLkr}) row in typed) {
      if (seen.add(row.type.toLowerCase())) {
        types.add(row.type);
      }
    }
    _selectedTypes
      ..clear()
      ..addAll(types);
    for (final ({String type, String size, int priceLkr}) row in typed) {
      final String label = typeSizeComboLabel(type: row.type, size: row.size);
      _matrixPriceCtrls.putIfAbsent(
        label,
        () => TextEditingController(text: '${row.priceLkr}'),
      );
    }
  }

  String _normalizeMatrixSizeLabel(String size) {
    final String t = size.trim();
    if (t == 'Half plate') {
      return 'Half';
    }
    if (t == 'Full plate') {
      return 'Full';
    }
    return t;
  }

  void _ensureCatalogDefaults({required bool isGrocery}) {
    if (_appliedCatalogDefaults) {
      return;
    }
    _appliedCatalogDefaults = true;
    if (!isGrocery || widget.isEdit) {
      return;
    }
    // New grocery items: initState runs before the vendor doc is known.
    final String eta = _etaCtrl.text.trim();
    if (eta.isEmpty || _kEtaPresets.contains(eta)) {
      _etaCtrl.text = kGroceryEtaPresets.first;
    }
    if (_priceVariableKind == 'size') {
      _priceVariableKind = 'pack';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _stockCtrl.dispose();
    _etaCtrl.dispose();
    for (final TextEditingController c in _sizeDraftPriceCtrls) {
      c.dispose();
    }
    for (final TextEditingController c in _packDraftPriceCtrls) {
      c.dispose();
    }
    _portionSingleLkrCtrl.dispose();
    _portionMultiPersonCtrl.dispose();
    _portionMultiLkrCtrl.dispose();
    _halfLkrCtrl.dispose();
    _fullLkrCtrl.dispose();
    _customTypeCtrl.dispose();
    _disposeMatrixCtrls();
    for (final _ComboPriceRow r in _comboRows) {
      r.priceCtrl.dispose();
    }
    for (final _CustomRow r in _customRows) {
      r.labelCtrl.dispose();
      r.priceCtrl.dispose();
    }
    super.dispose();
  }

  void _disposeMatrixCtrls() {
    for (final TextEditingController c in _matrixPriceCtrls.values) {
      c.dispose();
    }
    _matrixPriceCtrls.clear();
  }

  String? _validateEta(String? value, {required bool isGrocery}) {
    if (value == null || value.trim().isEmpty) {
      return isGrocery ? 'Pick a ready time' : 'Pick a prep time';
    }
    if (value.trim().length > 40) {
      return 'Keep ETA under 40 characters';
    }
    return null;
  }

  void _addCustomRow() {
    setState(() {
      _customRows.add(
        _CustomRow(
          labelCtrl: TextEditingController(),
          priceCtrl: TextEditingController(),
        ),
      );
    });
  }

  void _removeCustomRow(int index) {
    setState(() {
      final _CustomRow r = _customRows.removeAt(index);
      r.labelCtrl.dispose();
      r.priceCtrl.dispose();
    });
  }

  void _setPricedOptionsMode(bool value) {
    if (!value && _pricedOptionsMode) {
      final List<ProductSizeOption>? built = _tryBuildSizeOptionsList();
      if (built != null && built.isNotEmpty) {
        final int minLkr =
            built.map((ProductSizeOption e) => e.priceLkr).reduce((int a, int b) => a < b ? a : b);
        _priceCtrl.text = '$minLkr';
      }
      for (final _ComboPriceRow r in _comboRows) {
        r.priceCtrl.dispose();
      }
      _comboRows.clear();
      _clearSizeDraftFields();
      for (final TextEditingController c in _packDraftPriceCtrls) {
        c.clear();
      }
      _portionSingleLkrCtrl.clear();
      _portionMultiPersonCtrl.text = '2';
      _portionMultiLkrCtrl.clear();
      _halfLkrCtrl.clear();
      _fullLkrCtrl.clear();
      _selectedTypes.clear();
      _disposeMatrixCtrls();
      _customTypeCtrl.clear();
      for (final _CustomRow r in _customRows) {
        r.labelCtrl.dispose();
        r.priceCtrl.dispose();
      }
      _customRows.clear();
    }
    setState(() {
      _pricedOptionsMode = value;
      if (!value) {
        _priceVariableKind = 'size';
      } else if (ref.read(isGroceryShopProvider)) {
        _priceVariableKind = 'pack';
      }
    });
  }

  void _clearSizeDraftFields() {
    for (final TextEditingController c in _sizeDraftPriceCtrls) {
      c.clear();
    }
  }

  /// Reads non-empty draft fields for the currently selected price kind and
  /// returns them as `(label, lkr)` entries. Returns `null` if any non-empty
  /// field has an invalid value (e.g. non-numeric LKR or bad person count) so
  /// the caller can surface a single validation error.
  List<MapEntry<String, int>>? _readCurrentKindDrafts() {
    final List<MapEntry<String, int>> out = <MapEntry<String, int>>[];
    switch (_priceVariableKind) {
      case 'size':
        for (int i = 0; i < _kSizeLabels.length; i++) {
          final String raw = _sizeDraftPriceCtrls[i].text.trim();
          if (raw.isEmpty) {
            continue;
          }
          final int? v = _parseNonNegativeInt(raw);
          if (v == null) {
            return null;
          }
          out.add(MapEntry<String, int>(_kSizeLabels[i], v));
        }
        break;
      case 'portion':
        final String singleRaw = _portionSingleLkrCtrl.text.trim();
        if (singleRaw.isNotEmpty) {
          final int? v = _parseNonNegativeInt(singleRaw);
          if (v == null) {
            return null;
          }
          out.add(MapEntry<String, int>('Single portion', v));
        }
        final String multiRaw = _portionMultiLkrCtrl.text.trim();
        if (multiRaw.isNotEmpty) {
          final int? v = _parseNonNegativeInt(multiRaw);
          if (v == null) {
            return null;
          }
          final String peopleRaw = _portionMultiPersonCtrl.text.trim();
          final int? n = int.tryParse(peopleRaw);
          if (n == null || n < 1) {
            return null;
          }
          final String label = _portionLabelForSave(
            single: false,
            personCountRaw: _portionMultiPersonCtrl.text,
          );
          out.add(MapEntry<String, int>(label, v));
        }
        break;
      case 'half':
        final String halfRaw = _halfLkrCtrl.text.trim();
        if (halfRaw.isNotEmpty) {
          final int? v = _parseNonNegativeInt(halfRaw);
          if (v == null) {
            return null;
          }
          out.add(MapEntry<String, int>('Half', v));
        }
        final String fullRaw = _fullLkrCtrl.text.trim();
        if (fullRaw.isNotEmpty) {
          final int? v = _parseNonNegativeInt(fullRaw);
          if (v == null) {
            return null;
          }
          out.add(MapEntry<String, int>('Full', v));
        }
        break;
      case 'pack':
        for (int i = 0; i < kGroceryPackLabels.length; i++) {
          final String raw = _packDraftPriceCtrls[i].text.trim();
          if (raw.isEmpty) {
            continue;
          }
          final int? v = _parseNonNegativeInt(raw);
          if (v == null) {
            return null;
          }
          out.add(MapEntry<String, int>(kGroceryPackLabels[i], v));
        }
        break;
    }
    return out;
  }

  void _removeComboRow(int index) {
    setState(() {
      final _ComboPriceRow r = _comboRows.removeAt(index);
      r.priceCtrl.dispose();
    });
  }

  int? _parseNonNegativeInt(String raw) {
    final int? n = int.tryParse(raw.trim());
    if (n == null || n < 0) {
      return null;
    }
    return n;
  }

  /// Size columns used when Type × Size matrix mode is active.
  List<String> _matrixSizeLabels() {
    switch (_priceVariableKind) {
      case 'size':
        return List<String>.from(_kSizeLabels);
      case 'portion':
        return <String>[
          'Single portion',
          _portionLabelForSave(
            single: false,
            personCountRaw: _portionMultiPersonCtrl.text,
          ),
        ];
      case 'half':
        return const <String>['Half', 'Full'];
      default:
        return const <String>[];
    }
  }

  bool get _useTypeSizeMatrix =>
      _pricedOptionsMode &&
      _selectedTypes.isNotEmpty &&
      _priceVariableKind != 'pack';

  TextEditingController _matrixCtrlFor(String type, String size) {
    final String label = typeSizeComboLabel(type: type, size: size);
    return _matrixPriceCtrls.putIfAbsent(label, TextEditingController.new);
  }

  void _pruneMatrixCtrlsToCurrent() {
    if (_selectedTypes.isEmpty) {
      return;
    }
    final Set<String> keep = <String>{};
    for (final String type in _selectedTypes) {
      for (final String size in _matrixSizeLabels()) {
        keep.add(typeSizeComboLabel(type: type, size: size));
      }
    }
    final List<String> orphanKeys = _matrixPriceCtrls.keys
        .where((String k) => !keep.contains(k))
        .toList(growable: false);
    for (final String key in orphanKeys) {
      _matrixPriceCtrls.remove(key)?.dispose();
    }
  }

  void _toggleType(String type) {
    final String trimmed = type.trim();
    if (trimmed.isEmpty) {
      return;
    }
    setState(() {
      final int existing = _selectedTypes.indexWhere(
        (String t) => t.toLowerCase() == trimmed.toLowerCase(),
      );
      if (existing >= 0) {
        final String removed = _selectedTypes.removeAt(existing);
        final List<String> sizeLabels = _matrixSizeLabels();
        for (final String size in sizeLabels) {
          final String key = typeSizeComboLabel(type: removed, size: size);
          final TextEditingController? c = _matrixPriceCtrls.remove(key);
          c?.dispose();
        }
      } else {
        _selectedTypes.add(trimmed);
        // Leaving single-dimension drafts behind when entering matrix mode.
        for (final _ComboPriceRow r in _comboRows) {
          r.priceCtrl.dispose();
        }
        _comboRows.clear();
        _clearSizeDraftFields();
        _portionSingleLkrCtrl.clear();
        _portionMultiLkrCtrl.clear();
        _halfLkrCtrl.clear();
        _fullLkrCtrl.clear();
      }
    });
  }

  void _addCustomTypeFromField() {
    final String raw = _customTypeCtrl.text.trim();
    if (raw.isEmpty) {
      return;
    }
    final bool already = _selectedTypes.any(
      (String t) => t.toLowerCase() == raw.toLowerCase(),
    );
    if (already) {
      _customTypeCtrl.clear();
      return;
    }
    _toggleType(raw);
    _customTypeCtrl.clear();
  }

  /// Builds the final list of priced options from three sources, in order of
  /// precedence: Type × Size matrix (when types selected), previously committed
  /// `_comboRows`, then the current kind's draft fields (so users can just type
  /// and submit without an explicit "Add to list" step), then any custom rows.
  /// Drafts that duplicate an already-listed label are silently ignored (the
  /// committed row wins).
  ///
  /// Returns null if any non-empty value fails validation (invalid LKR or a
  /// duplicate custom label).
  List<ProductSizeOption>? _tryBuildSizeOptionsList() {
    final List<ProductSizeOption> out = <ProductSizeOption>[];
    final Set<String> seen = <String>{};

    if (_useTypeSizeMatrix) {
      final List<String> sizeLabels = _matrixSizeLabels();
      for (final String type in _selectedTypes) {
        for (final String size in sizeLabels) {
          final String label = typeSizeComboLabel(type: type, size: size);
          final TextEditingController ctrl = _matrixCtrlFor(type, size);
          final String raw = ctrl.text.trim();
          if (raw.isEmpty) {
            continue;
          }
          final int? lkr = _parseNonNegativeInt(raw);
          if (lkr == null) {
            return null;
          }
          final String key = label.toLowerCase();
          if (seen.contains(key)) {
            return null;
          }
          seen.add(key);
          out.add(ProductSizeOption(name: label, priceLkr: lkr));
        }
      }
    } else {
      for (final _ComboPriceRow r in _comboRows) {
        final int? lkr = _parseNonNegativeInt(r.priceCtrl.text);
        if (lkr == null) {
          return null;
        }
        final String key = r.label.trim().toLowerCase();
        if (seen.contains(key)) {
          return null;
        }
        seen.add(key);
        out.add(ProductSizeOption(name: r.label, priceLkr: lkr));
      }

      final List<MapEntry<String, int>>? drafts = _readCurrentKindDrafts();
      if (drafts == null) {
        return null;
      }
      for (final MapEntry<String, int> e in drafts) {
        final String key = e.key.trim().toLowerCase();
        if (seen.contains(key)) {
          continue;
        }
        seen.add(key);
        out.add(ProductSizeOption(name: e.key, priceLkr: e.value));
      }
    }

    for (final _CustomRow r in _customRows) {
      final String name = r.labelCtrl.text.trim();
      if (name.isEmpty) {
        continue;
      }
      final int? lkr = _parseNonNegativeInt(r.priceCtrl.text);
      if (lkr == null) {
        return null;
      }
      final String key = name.toLowerCase();
      if (seen.contains(key)) {
        return null;
      }
      seen.add(key);
      out.add(ProductSizeOption(name: name, priceLkr: lkr));
    }

    return out;
  }

  Future<bool> _ensurePhotoLibraryPermission() async {
    if (kIsWeb) {
      return true;
    }
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

  Future<void> _pickImage() async {
    final bool ok = await _ensurePhotoLibraryPermission();
    if (!ok) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Photos permission is needed to pick from gallery. Enable it in app settings.',
            ),
            action: SnackBarAction(
              label: 'Settings',
              onPressed: () => openAppSettings(),
            ),
          ),
        );
      }
      return;
    }
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 88,
      );
      if (file == null) {
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      setState(() {
        _pickedBytes = bytes;
        _pickedName = file.name;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not open gallery. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  void _clearPicked() {
    setState(() {
      _pickedBytes = null;
      _pickedName = null;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final bool isGrocery = ref.read(isGroceryShopProvider);
    if (isGrocery && _pricedOptionsMode) {
      _priceVariableKind = 'pack';
    }
    final String storeId = ref.read(vendorProductCatalogStoreIdProvider).trim();
    if (storeId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Sign in and open Products again so your store can load.')),
      );
      return;
    }
    if (isGrocery && _productCategory.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a product aisle.')),
      );
      return;
    }

    List<ProductSizeOption> sizeOptions = const <ProductSizeOption>[];
    int priceLkr;

    if (_pricedOptionsMode) {
      final List<ProductSizeOption>? built = _tryBuildSizeOptionsList();
      if (built == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Check prices: each LKR must be a whole number ≥ 0 and names must not duplicate.',
            ),
          ),
        );
        return;
      }
      if (built.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Enter at least one price (or add a custom option).'),
          ),
        );
        return;
      }
      sizeOptions = built;
      priceLkr = built.map((e) => e.priceLkr).reduce((a, b) => a < b ? a : b);
    } else {
      priceLkr = int.parse(_priceCtrl.text.trim());
      sizeOptions = const <ProductSizeOption>[];
    }

    setState(() => _saving = true);
    try {
      final VendorProductRepository repo =
          ref.read(vendorProductRepositoryProvider);
      final ProductImageStorage storage =
          ref.read(productImageStorageProvider);

      final String name = _nameCtrl.text.trim();
      final String description = _descCtrl.text.trim();
      final bool manageStock = isGrocery ? _manageStock : false;
      final int stock = manageStock
          ? (int.tryParse(_stockCtrl.text.trim()) ?? 0)
          : (widget.product?.stockQty ?? 0);
      final String eta = _etaCtrl.text.trim();
      final String aisle = isGrocery ? _productCategory.trim() : '';
      final String storeName = widget.product?.storeName ??
          await repo.fetchVendorDisplayName(storeId);

      if (widget.isEdit) {
        final VendorProduct existing = widget.product!;
        String imageUrl = existing.imageUrl;
        if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
          await repo.deleteStoredProductImage(existing.imageUrl);
          imageUrl = await storage.uploadProductImage(
            storeId: storeId,
            productId: existing.id,
            bytes: _pickedBytes!,
            fileName: _pickedName ?? 'photo.jpg',
          );
        }
        await repo.updateProduct(
          existing: existing,
          storeName: storeName,
          name: name,
          description: description,
          priceLkr: priceLkr,
          sizeOptions: sizeOptions,
          imageUrl: imageUrl,
          active: _active,
          stockQty: stock,
          manageStock: manageStock,
          etaLabel: eta,
          productCategory: aisle,
        );
      } else {
        final String productId = repo.allocateProductId();
        String imageUrl = '';
        if (_pickedBytes != null && _pickedBytes!.isNotEmpty) {
          imageUrl = await storage.uploadProductImage(
            storeId: storeId,
            productId: productId,
            bytes: _pickedBytes!,
            fileName: _pickedName ?? 'photo.jpg',
          );
        }
        await repo.createProduct(
          productId: productId,
          storeId: storeId,
          storeName: storeName,
          name: name,
          description: description,
          priceLkr: priceLkr,
          sizeOptions: sizeOptions,
          imageUrl: imageUrl,
          active: _active,
          stockQty: stock,
          manageStock: manageStock,
          etaLabel: eta,
          productCategory: aisle,
          maxProducts: vendorProductLimitForShop(isGrocery: isGrocery),
        );
      }

      final List<String> customTypesToRemember = mergeCustomFoodTypeLists(
        <Iterable<String>>[
          _selectedTypes.where((String t) => !isPresetFoodType(t)),
          customFoodTypesFromOptionNames(
            sizeOptions.map((ProductSizeOption o) => o.name),
          ),
        ],
      );
      if (customTypesToRemember.isNotEmpty) {
        await repo.mergeCustomFoodTypes(
          storeId: storeId,
          types: customTypesToRemember,
        );
      }

      if (mounted) {
        Navigator.of(context).pop<void>();
      }
    } on VendorProductLimitExceededException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Product limit reached for this shop.',
              ),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not save. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _onPriceKindChanged(String next) {
    setState(() {
      if (next != _priceVariableKind) {
        _disposeMatrixCtrls();
        _clearSizeDraftFields();
        _portionSingleLkrCtrl.clear();
        _portionMultiLkrCtrl.clear();
        _halfLkrCtrl.clear();
        _fullLkrCtrl.clear();
      }
      _priceVariableKind = next;
    });
  }

  Widget _buildPricingSection({
    required BuildContext context,
    required ThemeData theme,
    required bool isGrocery,
  }) {
    final Color muted = VendorProductsTheme.mutedText(context);
    final List<String> remembered =
        ref.watch(shopRememberedCustomFoodTypesProvider);
    final List<String> customChips = mergeCustomFoodTypeLists(
      <Iterable<String>>[
        remembered,
        _selectedTypes.where((String t) => !isPresetFoodType(t)),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const PricingStepHeader(
          step: 1,
          title: 'How do you price this?',
          subtitle: 'One fixed price, or separate prices for options.',
        ),
        const SizedBox(height: 12),
        _PricingModeToggle(
          optionsMode: _pricedOptionsMode,
          onChanged: _setPricedOptionsMode,
        ),
        if (!_pricedOptionsMode) ...<Widget>[
          const SizedBox(height: 16),
          PricingNestedPanel(
            title: 'Fixed price',
            child: TextFormField(
              controller: _priceCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                prefixText: 'Rs. ',
                prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: muted,
                  fontWeight: FontWeight.w700,
                ),
                hintText: '0',
                filled: true,
                fillColor: VendorProductsTheme.inputFill(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              validator: (String? v) {
                if (v == null || v.trim().isEmpty) {
                  return 'Enter price';
                }
                final int? n = int.tryParse(v.trim());
                if (n == null || n < 0) {
                  return 'Whole number ≥ 0';
                }
                return null;
              },
            ),
          ),
        ],
        if (_pricedOptionsMode) ...<Widget>[
          const SizedBox(height: 18),
          PricingStepHeader(
            step: 2,
            title: isGrocery ? 'Pack / weight' : 'Choose option style',
            subtitle: isGrocery
                ? 'Set a price for each pack size you sell.'
                : 'Half/Full for rice plates, Size for S/M/L, Portion for people.',
          ),
          const SizedBox(height: 12),
          if (isGrocery)
            PricingNestedPanel(
              child: Text(
                'Pack / weight',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: VendorProductsTheme.primaryText(context),
                ),
              ),
            )
          else
            PricingKindSelector(
              value: _priceVariableKind,
              onChanged: _onPriceKindChanged,
            ),
          if (!isGrocery) ...<Widget>[
            const SizedBox(height: 18),
            const PricingStepHeader(
              step: 3,
              title: 'Add type? (optional)',
              subtitle:
                  'Chicken, Beef, Egg… builds combos like Chicken · Full. Custom types stay on your shop.',
            ),
            const SizedBox(height: 12),
            PricingNestedPanel(
              title: 'Types',
              trailing: _selectedTypes.isEmpty
                  ? Text(
                      'Skip',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: muted,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : Text(
                      '${_selectedTypes.length} selected',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: VendorProductsTheme.accent(context),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  PricingTypeChipWrap(
                    presets: kFoodTypePresets,
                    customTypes: customChips,
                    selectedTypes: _selectedTypes,
                    onToggle: _toggleType,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _customTypeCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            hintText: 'Custom type (e.g. Mutton)',
                            isDense: true,
                            filled: true,
                            fillColor: VendorProductsTheme.inputFill(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onSubmitted: (_) => _addCustomTypeFromField(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: _addCustomTypeFromField,
                        style: FilledButton.styleFrom(
                          backgroundColor: VendorProductsTheme.accent(context),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Icon(Icons.add_rounded, size: 20),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          PricingStepHeader(
            step: isGrocery ? 3 : 4,
            title: 'Enter prices',
            subtitle: _useTypeSizeMatrix
                ? 'Fill each combo you sell. Leave blank to skip.'
                : 'Leave a row blank to skip that option.',
          ),
          const SizedBox(height: 12),
          // Pack pricing only exists for grocery — gated on the vendor's
          // *current* classification, not `_priceVariableKind`, which for a
          // legacy grocery-shaped product is inferred from saved data at
          // load time and can otherwise stay 'pack' even after the vendor
          // is reclassified back to food (matching the isGrocery gates
          // already used above/below for the Type×Size vs Pack sections).
          if (isGrocery)
            PricingNestedPanel(
              title: 'Pack prices',
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < kGroceryPackLabels.length; i++)
                    PricingAmountRow(
                      label: kGroceryPackLabels[i],
                      controller: _packDraftPriceCtrls[i],
                      leadingWidth: 92,
                    ),
                ],
              ),
            )
          else if (_useTypeSizeMatrix) ...<Widget>[
            if (_priceVariableKind == 'portion') ...<Widget>[
              PricingNestedPanel(
                title: 'People count',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        'Multi-person label uses this number',
                        style: theme.textTheme.bodySmall?.copyWith(color: muted),
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _portionMultiPersonCtrl,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          hintText: '2',
                          isDense: true,
                          filled: true,
                          fillColor: VendorProductsTheme.inputFill(context),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (_) {
                          setState(() {
                            _pruneMatrixCtrlsToCurrent();
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
            for (final String type in _selectedTypes) ...<Widget>[
              PricingNestedPanel(
                title: type,
                child: Column(
                  children: <Widget>[
                    for (final String size in _matrixSizeLabels())
                      PricingAmountRow(
                        label: size,
                        controller: _matrixCtrlFor(type, size),
                        leadingWidth: 100,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],
          ] else if (_priceVariableKind == 'size')
            PricingNestedPanel(
              title: 'Size prices',
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _kSizeLabels.length; i++)
                    PricingAmountRow(
                      label: _kSizeLabels[i],
                      controller: _sizeDraftPriceCtrls[i],
                      leadingWidth: 88,
                    ),
                ],
              ),
            )
          else if (_priceVariableKind == 'portion')
            PricingNestedPanel(
              title: 'Portion prices',
              child: Column(
                children: <Widget>[
                  PricingAmountRow(
                    label: 'Single',
                    controller: _portionSingleLkrCtrl,
                    leadingWidth: 88,
                  ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(
                        width: 88,
                        child: Text(
                          'People',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: VendorProductsTheme.primaryText(context),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 64,
                        child: TextField(
                          controller: _portionMultiPersonCtrl,
                          keyboardType: TextInputType.number,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            hintText: '2',
                            isDense: true,
                            filled: true,
                            fillColor: VendorProductsTheme.inputFill(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _portionMultiLkrCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            prefixText: 'Rs. ',
                            prefixStyle: theme.textTheme.bodyMedium?.copyWith(
                              color: muted,
                              fontWeight: FontWeight.w700,
                            ),
                            hintText: '0',
                            isDense: true,
                            filled: true,
                            fillColor: VendorProductsTheme.inputFill(context),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          else
            PricingNestedPanel(
              title: 'Half / Full prices',
              child: Column(
                children: <Widget>[
                  PricingAmountRow(
                    label: 'Half',
                    controller: _halfLkrCtrl,
                    leadingWidth: 88,
                  ),
                  PricingAmountRow(
                    label: 'Full',
                    controller: _fullLkrCtrl,
                    leadingWidth: 88,
                  ),
                ],
              ),
            ),
          if (!_useTypeSizeMatrix && _comboRows.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            PricingNestedPanel(
              title: 'Saved options',
              child: Column(
                children: <Widget>[
                  for (int i = 0; i < _comboRows.length; i++)
                    PricingAmountRow(
                      label: _comboRows[i].label,
                      controller: _comboRows[i].priceCtrl,
                      leadingWidth: 120,
                      onRemove: () => _removeComboRow(i),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          PricingNestedPanel(
            title: 'Extra custom options',
            trailing: TextButton.icon(
              onPressed: _addCustomRow,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(
                foregroundColor: VendorProductsTheme.accent(context),
                visualDensity: VisualDensity.compact,
              ),
            ),
            child: _customRows.isEmpty
                ? Text(
                    'Optional labels that are not size/type presets.',
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  )
                : Column(
                    children: <Widget>[
                      for (int i = 0; i < _customRows.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _customRows[i].labelCtrl,
                                  decoration: InputDecoration(
                                    hintText: 'Label',
                                    isDense: true,
                                    filled: true,
                                    fillColor:
                                        VendorProductsTheme.inputFill(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _customRows[i].priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: InputDecoration(
                                    prefixText: 'Rs. ',
                                    isDense: true,
                                    filled: true,
                                    fillColor:
                                        VendorProductsTheme.inputFill(context),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () => _removeCustomRow(i),
                                icon: const Icon(Icons.close_rounded, size: 20),
                                tooltip: 'Remove',
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final VendorProduct? p = widget.product;
    final bool accountLoading = ref.watch(vendorAccountDocLoadingProvider);
    final bool isGrocery = ref.watch(isGroceryShopProvider);
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color canvas = VendorProductsTheme.canvas(context);
    final Color primary = VendorProductsTheme.primaryText(context);
    final Color muted = VendorProductsTheme.mutedText(context);
    final Color accent = VendorProductsTheme.accent(context);

    if (accountLoading) {
      return Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: canvas,
          foregroundColor: primary,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop<void>(),
          ),
          title: Text(
            widget.isEdit ? 'EDIT PRODUCT' : 'ADD PRODUCT',
            style: GoogleFonts.bebasNeue(
              fontSize: 28,
              letterSpacing: 1.0,
              height: 1.05,
              color: primary,
            ).copyWith(fontFamilyFallback: const <String>['Poppins']),
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    _ensureCatalogDefaults(isGrocery: isGrocery);

    final OutlineInputBorder outline = OutlineInputBorder(
      borderRadius: BorderRadius.circular(_kFormFieldRadius),
      borderSide: BorderSide(color: VendorProductsTheme.inputBorder(context)),
    );
    final ThemeData formTheme = theme.copyWith(
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: VendorProductsTheme.inputFill(context),
        labelStyle: theme.textTheme.labelMedium?.copyWith(
          color: muted,
          fontWeight: FontWeight.w600,
        ),
        border: outline,
        enabledBorder: outline,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kFormFieldRadius),
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kFormFieldRadius),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(_kFormFieldRadius),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );

    return Theme(
      data: formTheme,
      child: Scaffold(
        backgroundColor: canvas,
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 0,
          backgroundColor: canvas,
          foregroundColor: primary,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: _saving ? null : () => Navigator.of(context).pop<void>(),
          ),
          title: Text(
            widget.isEdit
                ? (isGrocery ? 'EDIT GROCERY ITEM' : 'EDIT PRODUCT')
                : (isGrocery ? 'ADD GROCERY ITEM' : 'ADD PRODUCT'),
            style: GoogleFonts.bebasNeue(
              fontSize: 28,
              letterSpacing: 1.0,
              height: 1.05,
              color: primary,
            ).copyWith(fontFamilyFallback: const <String>['Poppins']),
          ),
          actions: <Widget>[
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert_rounded, color: primary),
              onSelected: (String value) {
                if (value == 'discard') {
                  Navigator.of(context).pop<void>();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'discard',
                  child: Text('Discard draft'),
                ),
              ],
            ),
          ],
        ),
        body: AbsorbPointer(
          absorbing: _saving,
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(kVendorScreenPadding, 10, kVendorScreenPadding, 24),
              children: <Widget>[
                if (isGrocery) ...<Widget>[
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: VendorProductsTheme.softAccentFill(context),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: accent.withValues(alpha: 0.28),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: <Widget>[
                          Icon(Icons.local_grocery_store_rounded,
                              color: accent, size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Grocery catalog — aisle, optional stock, pack sizes',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _ProductImagePickerZone(
                  existingUrl: p?.imageUrl,
                  pickedBytes: _pickedBytes,
                  onBrowse: _pickImage,
                  onClearPick: _clearPicked,
                ),
                const SizedBox(height: 16),
                _ProductFormSectionCard(
                  title: 'Product Name',
                  child: TextFormField(
                    controller: _nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: InputDecoration(
                      labelText: 'Product Name',
                      hintText: isGrocery
                          ? 'e.g. Anchor Full Cream Milk 1L'
                          : 'e.g. Vegetable fried rice',
                    ),
                    validator: (String? v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Enter a name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (isGrocery) ...<Widget>[
                  _ProductFormSectionCard(
                    title: 'Aisle',
                    child: Builder(
                      builder: (BuildContext context) {
                        final AsyncValue<List<String>> aisleAsync =
                            ref.watch(groceryAisleLabelsProvider);
                        final List<String> aisleLabels =
                            groceryAisleLabelsOrFallback(aisleAsync);
                        final String selected = _productCategory.trim();
                        final List<String> items = List<String>.from(aisleLabels);
                        if (selected.isNotEmpty && !items.contains(selected)) {
                          items.insert(0, selected);
                        }
                        return DropdownButtonFormField<String>(
                          key: ValueKey<String>(
                            'aisle_${selected}_${items.join('|')}',
                          ),
                          initialValue: selected.isEmpty ? null : selected,
                          decoration: const InputDecoration(
                            labelText: 'Product aisle',
                            hintText: 'Select aisle',
                          ),
                          items: items
                              .map(
                                (String label) => DropdownMenuItem<String>(
                                  value: label,
                                  child: Text(label),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: (String? v) {
                            setState(() => _productCategory = v ?? '');
                          },
                          validator: (String? v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Select an aisle';
                            }
                            return null;
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  _ProductFormSectionCard(
                    title: 'Stock',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Manage stock'),
                          subtitle: Text(
                            _manageStock
                                ? 'Track units; customers see out of stock at 0.'
                                : 'Stock not tracked — product stays available.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: muted,
                            ),
                          ),
                          value: _manageStock,
                          onChanged: (bool v) {
                            setState(() => _manageStock = v);
                          },
                        ),
                        if (_manageStock) ...<Widget>[
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _stockCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Stock on hand',
                              hintText: 'Units available to sell',
                              prefixIcon:
                                  Icon(Icons.inventory_2_outlined, size: 20),
                            ),
                            validator: (String? v) {
                              if (!_manageStock) {
                                return null;
                              }
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter stock quantity';
                              }
                              final int? n = int.tryParse(v.trim());
                              if (n == null || n < 0) {
                                return 'Whole number ≥ 0';
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                _ProductFormSectionCard(
                  title: 'Description',
                  child: TextFormField(
                    controller: _descCtrl,
                    minLines: 4,
                    maxLines: 6,
                    decoration: InputDecoration(
                      labelText: 'Description',
                      hintText: isGrocery
                          ? 'Brand, pack size, storage notes…'
                          : 'Ingredients, portions, spice level…',
                      alignLabelWithHint: true,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _ProductFormSectionCard(
                  title: 'Pricing',
                  child: _buildPricingSection(
                    context: context,
                    theme: theme,
                    isGrocery: isGrocery,
                  ),
                ),
                const SizedBox(height: 14),
                _ProductFormSectionCard(
                  title: isGrocery ? 'Ready time' : 'ETA',
                  child: _EtaQuickPicker(
                    controller: _etaCtrl,
                    presets: isGrocery ? kGroceryEtaPresets : _kEtaPresets,
                    validator: (String? v) =>
                        _validateEta(v, isGrocery: isGrocery),
                  ),
                ),
                const SizedBox(height: 14),
                _VisibilityCard(
                  active: _active,
                  isGrocery: isGrocery,
                  onChanged: (bool v) => setState(() => _active = v),
                ),
                const SizedBox(height: 88),
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: canvas,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: VendorProductsTheme.isDark(context) ? 0.35 : 0.08,
                  ),
                  blurRadius: 16,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(kVendorScreenPadding, 12, kVendorScreenPadding, 14),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop<void>(),
                    style: TextButton.styleFrom(
                      foregroundColor: VendorProductsTheme.mutedText(context),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    child: const Text(
                      'Discard draft',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      backgroundColor: VendorProductsTheme.accent(context),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              const Icon(Icons.check_rounded, size: 22),
                              const SizedBox(width: 8),
                              Text(
                                widget.isEdit ? 'Save product' : 'Submit product',
                                style: theme.textTheme.labelLarge?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EtaQuickPicker extends StatefulWidget {
  const _EtaQuickPicker({
    required this.controller,
    required this.validator,
    this.presets = _kEtaPresets,
  });

  final TextEditingController controller;
  final String? Function(String? value) validator;
  final List<String> presets;

  @override
  State<_EtaQuickPicker> createState() => _EtaQuickPickerState();
}

class _EtaQuickPickerState extends State<_EtaQuickPicker> {
  late String _dropdownValue;

  List<String> get _presets => widget.presets;

  @override
  void initState() {
    super.initState();
    _dropdownValue =
        _presets.isNotEmpty ? _presets.first : _kEtaCustomDropdownValue;
    _syncDropdownFromController();
  }

  @override
  void didUpdateWidget(covariant _EtaQuickPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.presets, widget.presets)) {
      _syncDropdownFromController();
    }
  }

  void _syncDropdownFromController() {
    final String current = widget.controller.text.trim();
    if (current.isEmpty) {
      _dropdownValue =
          _presets.isNotEmpty ? _presets.first : _kEtaCustomDropdownValue;
      if (_presets.isNotEmpty) {
        widget.controller.text = _dropdownValue;
      }
    } else if (_presets.contains(current)) {
      _dropdownValue = current;
    } else {
      _dropdownValue = _kEtaCustomDropdownValue;
    }
  }

  bool get _customMode => _dropdownValue == _kEtaCustomDropdownValue;

  @override
  Widget build(BuildContext context) {
    return FormField<String>(
      initialValue: _dropdownValue == _kEtaCustomDropdownValue
          ? widget.controller.text
          : _dropdownValue,
      validator: (String? value) {
        if (_customMode) {
          return widget.validator(widget.controller.text);
        }
        if (_dropdownValue == _kEtaCustomDropdownValue) {
          return widget.validator(widget.controller.text);
        }
        return widget.validator(_dropdownValue);
      },
      builder: (FormFieldState<String> field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InputDecorator(
              decoration: InputDecoration(
                labelText: 'Ready / prep time',
                prefixIcon: const Icon(Icons.schedule_rounded, size: 20),
                errorText: field.errorText,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _dropdownValue,
                  isExpanded: true,
                  isDense: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded),
                  items: <DropdownMenuItem<String>>[
                    ..._presets.map(
                      (String preset) => DropdownMenuItem<String>(
                        value: preset,
                        child: Text(preset),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: _kEtaCustomDropdownValue,
                      child: Text('Custom…'),
                    ),
                  ],
                  onChanged: (String? value) {
                    if (value == null) {
                      return;
                    }
                    setState(() {
                      _dropdownValue = value;
                      if (value == _kEtaCustomDropdownValue) {
                        if (_presets.contains(widget.controller.text.trim())) {
                          widget.controller.clear();
                        }
                        field.didChange(widget.controller.text);
                      } else {
                        widget.controller.text = value;
                        field.didChange(value);
                      }
                    });
                  },
                ),
              ),
            ),
            if (_customMode) ...<Widget>[
              const SizedBox(height: 12),
              TextFormField(
                controller: widget.controller,
                decoration: const InputDecoration(
                  labelText: 'Custom time',
                  hintText: 'e.g. 25-35 min',
                ),
                onChanged: (String value) {
                  field.didChange(value);
                  field.validate();
                },
                validator: widget.validator,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ProductFormSectionCard extends StatelessWidget {
  const _ProductFormSectionCard({
    required this.child,
    this.title,
  });

  final String? title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VendorProductsTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: VendorProductsTheme.cardShadow(context),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (title != null) ...<Widget>[
              VendorSectionTitle(title!),
              const SizedBox(height: 14),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

class _PricingModeToggle extends StatelessWidget {
  const _PricingModeToggle({
    required this.optionsMode,
    required this.onChanged,
  });

  final bool optionsMode;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VendorProductsTheme.toggleTrack(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _PricingModeSegment(
              label: 'One price',
              icon: Icons.payments_outlined,
              selected: !optionsMode,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _PricingModeSegment(
              label: 'Options',
              icon: Icons.grid_view_rounded,
              selected: optionsMode,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingModeSegment extends StatelessWidget {
  const _PricingModeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = VendorProductsTheme.accent(context);
    final Color fg = selected
        ? VendorProductsTheme.chipSelectedFg(context)
        : VendorProductsTheme.chipUnselectedFg(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? accent : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? <BoxShadow>[
                    BoxShadow(
                      color: accent.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, size: 17, color: fg),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _VisibilityCard extends StatelessWidget {
  const _VisibilityCard({
    required this.active,
    required this.onChanged,
    this.isGrocery = false,
  });

  final bool active;
  final ValueChanged<bool> onChanged;
  final bool isGrocery;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color accent = VendorProductsTheme.accent(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: VendorProductsTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        boxShadow: VendorProductsTheme.cardShadow(context),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            DecoratedBox(
              decoration: BoxDecoration(
                color: VendorProductsTheme.softAccentFill(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(Icons.visibility_outlined, color: accent, size: 22),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Visible to customers',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: VendorProductsTheme.primaryText(context),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isGrocery
                        ? 'Turn off to hide from your store catalog'
                        : 'Turn off to hide from your store menu',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: VendorProductsTheme.mutedText(context),
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: active,
              activeThumbColor: accent,
              activeTrackColor: accent.withValues(alpha: 0.35),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductImagePickerZone extends StatelessWidget {
  const _ProductImagePickerZone({
    required this.existingUrl,
    required this.pickedBytes,
    required this.onBrowse,
    required this.onClearPick,
  });

  final String? existingUrl;
  final Uint8List? pickedBytes;
  final VoidCallback onBrowse;
  final VoidCallback onClearPick;

  bool get _hasNewPick => pickedBytes != null && pickedBytes!.isNotEmpty;

  bool get _hasRemote =>
      !_hasNewPick && existingUrl != null && existingUrl!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    Widget preview;
    if (_hasNewPick) {
      preview = Image.memory(
        pickedBytes!,
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
      );
    } else if (_hasRemote) {
      preview = Image.network(
        existingUrl!.trim(),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (BuildContext context, Object error, StackTrace? stackTrace) => ColoredBox(
          color: VendorProductsTheme.thumbPlaceholderFill(context),
          child: Center(
            child: Icon(Icons.broken_image_outlined, size: 40, color: cs.onSurfaceVariant),
          ),
        ),
      );
    } else {
      preview = const SizedBox.shrink();
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: VendorProductsTheme.cardShadow(context),
      ),
      child: Material(
        color: VendorProductsTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onBrowse,
          child: Container(
            width: double.infinity,
            height: 176,
            decoration: BoxDecoration(
              color: VendorProductsTheme.softAccentFill(
                context,
                lightAlpha: 0.05,
                darkAlpha: 0.12,
              ),
            ),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (_hasNewPick || _hasRemote) preview else _EmptyImageHint(theme: theme, cs: cs),
              if (_hasNewPick)
                Positioned(
                  top: 8,
                  right: 8,
                  child: Material(
                    color: Colors.black54,
                    shape: const CircleBorder(),
                    clipBehavior: Clip.antiAlias,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                      onPressed: onClearPick,
                      tooltip: 'Remove new photo',
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}

class _EmptyImageHint extends StatelessWidget {
  const _EmptyImageHint({required this.theme, required this.cs});

  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(
            Icons.cloud_upload_outlined,
            size: 44,
            color: VendorProductsTheme.accent(context).withValues(alpha: 0.85),
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VendorProductsTheme.primaryText(context),
              ),
              children: <InlineSpan>[
                const TextSpan(text: 'Tap to upload or '),
                TextSpan(
                  text: 'browse',
                  style: TextStyle(
                    color: VendorProductsTheme.accent(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'JPG or PNG · recommended under 10 MB',
            style: theme.textTheme.bodySmall?.copyWith(
              color: VendorProductsTheme.mutedText(context),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
