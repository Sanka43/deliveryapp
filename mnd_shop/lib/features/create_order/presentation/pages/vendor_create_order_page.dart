import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_pick_result.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_map_picker_page.dart';
import 'package:mnd_shop/features/create_order/data/vendor_manual_order_repository.dart';
import 'package:mnd_shop/features/create_order/presentation/providers/create_order_draft_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') {
    return si;
  }
  if (languageCode == 'ta') {
    return ta ?? vendorTamilFallback(en);
  }
  return en;
}

/// Multi-step wizard: customer → package → delivery → review.
///
/// This is a flash/courier-style order (deliver something not in the shop's
/// own product catalogue) — the vendor and customer agree a single package
/// price by phone before creating the order, so there's no item picker here.
class VendorCreateOrderPage extends ConsumerStatefulWidget {
  const VendorCreateOrderPage({super.key});

  static Future<bool?> open(BuildContext context) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext context) => const VendorCreateOrderPage(),
      ),
    );
  }

  @override
  ConsumerState<VendorCreateOrderPage> createState() =>
      _VendorCreateOrderPageState();
}

class _VendorCreateOrderPageState extends ConsumerState<VendorCreateOrderPage> {
  bool _shopCitySeeded = false;

  void _seedShopCityIfNeeded(Map<String, dynamic>? doc) {
    if (_shopCitySeeded) {
      return;
    }
    final CreateOrderDraft draft = ref.read(createOrderDraftProvider);
    if (draft.city.trim().isNotEmpty) {
      _shopCitySeeded = true;
      return;
    }
    if (doc == null) {
      return;
    }
    _shopCitySeeded = true;
    final String shopCity = (doc['city'] as String?)?.trim() ?? '';
    if (shopCity.isEmpty) {
      return;
    }
    ref.read(createOrderDraftProvider.notifier).setAddress(city: shopCity);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _seedShopCityIfNeeded(
        ref.read(vendorAccountDocDataProvider).valueOrNull,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final CreateOrderDraft draft = ref.watch(createOrderDraftProvider);
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;

    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      vendorAccountDocDataProvider,
      (AsyncValue<Map<String, dynamic>?>? _, AsyncValue<Map<String, dynamic>?> next) {
        _seedShopCityIfNeeded(next.valueOrNull);
      },
    );

    return Scaffold(
      backgroundColor: isDark
          ? theme.colorScheme.surface
          : AppColors.canvas,
      appBar: AppBar(
        title: Text(
          _vTxt(context, en: 'Create order', si: 'ඇණවුමක් සාදන්න'),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: draft.submitting
              ? null
              : () => Navigator.of(context).maybePop(false),
        ),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
            child: _StepHeader(step: draft.step),
          ),
          if (draft.errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Material(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          draft.errorMessage!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: switch (draft.step) {
                0 => const _CustomerStep(key: ValueKey<int>(0)),
                1 => const _PackageStep(key: ValueKey<int>(1)),
                2 => const _DeliveryStep(key: ValueKey<int>(2)),
                _ => const _ReviewStep(key: ValueKey<int>(3)),
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step});

  final int step;

  @override
  Widget build(BuildContext context) {
    final List<String> labels = <String>[
      _vTxt(context, en: 'Customer', si: 'පාරිභෝගික'),
      _vTxt(context, en: 'Package', si: 'පැකේජය'),
      _vTxt(context, en: 'Delivery', si: 'බෙදාහැරීම'),
      _vTxt(context, en: 'Review', si: 'සමාලෝචනය'),
    ];
    return Row(
      children: <Widget>[
        for (int i = 0; i < labels.length; i++) ...<Widget>[
          if (i > 0)
            Expanded(
              child: Container(
                height: 2,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                color: i <= step
                    ? AppColors.vendorHeroBlue
                    : AppColors.borderLight,
              ),
            ),
          Column(
            children: <Widget>[
              CircleAvatar(
                radius: 14,
                backgroundColor: i <= step
                    ? AppColors.vendorHeroBlue
                    : AppColors.surfaceMuted,
                foregroundColor:
                    i <= step ? Colors.white : AppColors.textMuted,
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                labels[i],
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontWeight:
                          i == step ? FontWeight.w700 : FontWeight.w500,
                      color: i == step
                          ? AppColors.vendorHeroBlue
                          : AppColors.textMuted,
                    ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CustomerStep extends ConsumerStatefulWidget {
  const _CustomerStep({super.key});

  @override
  ConsumerState<_CustomerStep> createState() => _CustomerStepState();
}

class _CustomerStepState extends ConsumerState<_CustomerStep> {
  late final TextEditingController _phone;
  late final TextEditingController _name;

  @override
  void initState() {
    super.initState();
    final CreateOrderDraft d = ref.read(createOrderDraftProvider);
    _phone = TextEditingController(text: d.phoneInput);
    _name = TextEditingController(text: d.isGuest ? d.customerName : '');
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreateOrderDraft draft = ref.watch(createOrderDraftProvider);
    final CreateOrderDraftNotifier notifier =
        ref.read(createOrderDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        Text(
          _vTxt(
            context,
            en: 'Customer phone',
            si: 'පාරිභෝගික දුරකථනය',
          ),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          _vTxt(
            context,
            en: 'We look up MND accounts by phone. If none, create as guest.',
            si:
                'දුරකථනයෙන් MND ගිණුම් සොයයි. නැත්නම් guest ලෙස සාදයි.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9+\s-]')),
          ],
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'Phone', si: 'දුරකථනය'),
            hintText: '077…',
            prefixIcon: const Icon(Icons.phone_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: notifier.setPhoneInput,
        ),
        const SizedBox(height: 12),
        FilledButton.tonalIcon(
          onPressed: draft.submitting
              ? null
              : () async {
                  notifier.setPhoneInput(_phone.text);
                  await notifier.lookupCustomer();
                  if (!mounted) {
                    return;
                  }
                  final CreateOrderDraft next =
                      ref.read(createOrderDraftProvider);
                  if (next.isGuest && _name.text.trim().isEmpty) {
                    _name.text = next.customerName;
                  }
                },
          icon: draft.submitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.search_rounded),
          label: Text(
            _vTxt(context, en: 'Look up', si: 'සොයන්න'),
          ),
        ),
        if (draft.lookupDone) ...<Widget>[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: draft.isGuest
                  ? AppColors.pendingAmber.withValues(alpha: 0.12)
                  : AppColors.openGreen.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: draft.isGuest
                    ? AppColors.pendingAmber.withValues(alpha: 0.4)
                    : AppColors.openGreen.withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              draft.isGuest
                  ? _vTxt(
                      context,
                      en:
                          'No MND account for ${draft.phoneE164}. Continue as guest — SMS verification will confirm this order at delivery.',
                      si:
                          '${draft.phoneE164} සඳහා MND ගිණුමක් නැත. Guest ලෙස ඉදිරියට — delivery එකේදී SMS verification එකෙන් confirm වේ.',
                    )
                  : _vTxt(
                      context,
                      en:
                          'Found: ${draft.customerName.isNotEmpty ? draft.customerName : 'Customer'} (${draft.phoneE164})',
                      si:
                          'හමුවිය: ${draft.customerName.isNotEmpty ? draft.customerName : 'Customer'} (${draft.phoneE164})',
                    ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          if (draft.isGuest) ...<Widget>[
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(
                labelText: _vTxt(
                  context,
                  en: 'Customer name (optional)',
                  si: 'පාරිභෝගික නම (අනිවාර්ය නොවේ)',
                ),
                hintText: _vTxt(
                  context,
                  en: 'Leave blank to use "Guest ${draft.phoneE164.length >= 4 ? draft.phoneE164.substring(draft.phoneE164.length - 4) : ''}"',
                  si: 'හිස්ව තැබුවොත් "Guest ####" ලෙස යොදයි',
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onChanged: notifier.setCustomerName,
            ),
            const SizedBox(height: 24),
          ] else ...<Widget>[
            // Found account: name comes from the account, not editable here.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest
                    .withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(Icons.lock_outline_rounded, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      draft.customerName.isNotEmpty
                          ? draft.customerName
                          : _vTxt(context, en: 'Customer', si: 'පාරිභෝගික'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          FilledButton(
            onPressed: () => notifier.goToStep(1),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              backgroundColor: AppColors.vendorHeroBlue,
            ),
            child: Text(_vTxt(context, en: 'Next', si: 'ඊළඟ')),
          ),
        ],
      ],
    );
  }
}

class _PackageStep extends ConsumerStatefulWidget {
  const _PackageStep({super.key});

  @override
  ConsumerState<_PackageStep> createState() => _PackageStepState();
}

class _PackageStepState extends ConsumerState<_PackageStep> {
  late final TextEditingController _price;
  late final TextEditingController _description;

  @override
  void initState() {
    super.initState();
    final CreateOrderDraft d = ref.read(createOrderDraftProvider);
    _price = TextEditingController(text: d.packagePriceInput);
    _description = TextEditingController(text: d.packageDescription);
  }

  @override
  void dispose() {
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final CreateOrderDraft draft = ref.watch(createOrderDraftProvider);
    final CreateOrderDraftNotifier notifier =
        ref.read(createOrderDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        Text(
          _vTxt(context, en: 'Package price', si: 'පැකේජ මිල'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          _vTxt(
            context,
            en:
                'For items outside your catalogue — enter the price you already agreed with the customer by phone.',
            si:
                'ඔබේ catalogue එකේ නැති items සඳහා — phone එකෙන් customer සමඟ agree කරගත් මිල ඇතුළත් කරන්න.',
          ),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _price,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
          ],
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'Package price (Rs.) *', si: 'පැකේජ මිල (Rs.) *'),
            prefixText: 'Rs. ',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: notifier.setPackagePriceInput,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          maxLines: 3,
          maxLength: 300,
          decoration: InputDecoration(
            labelText: _vTxt(
              context,
              en: "What's in the package (optional)",
              si: 'පැකේජයේ ඇත්තේ මොනවාද (අනිවාර්ය නොවේ)',
            ),
            hintText: _vTxt(
              context,
              en: 'e.g. 2 birthday cakes + candles',
              si: 'උදා: birthday cake 2ක් + candles',
            ),
            alignLabelWithHint: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: notifier.setPackageDescription,
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () => notifier.goToStep(0),
              child: Text(_vTxt(context, en: 'Back', si: 'ආපසු')),
            ),
            const Spacer(),
            FilledButton(
              onPressed: draft.packagePriceLkr > 0
                  ? () => notifier.goToStep(2)
                  : null,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.vendorHeroBlue,
              ),
              child: Text(_vTxt(context, en: 'Next', si: 'ඊළඟ')),
            ),
          ],
        ),
      ],
    );
  }
}

class _DeliveryStep extends ConsumerStatefulWidget {
  const _DeliveryStep({super.key});

  @override
  ConsumerState<_DeliveryStep> createState() => _DeliveryStepState();
}

class _DeliveryStepState extends ConsumerState<_DeliveryStep> {
  late final TextEditingController _line1;
  late final TextEditingController _line2;
  late final TextEditingController _city;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  bool _shopCityPrefillAttempted = false;

  @override
  void initState() {
    super.initState();
    final CreateOrderDraft d = ref.read(createOrderDraftProvider);
    _line1 = TextEditingController(text: d.line1);
    _line2 = TextEditingController(text: d.line2);
    _city = TextEditingController(text: d.city);
    _phone = TextEditingController(text: d.addressPhone);
    _note = TextEditingController(text: d.deliveryNote);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryPrefillShopCity(
        ref.read(vendorAccountDocDataProvider).valueOrNull,
      );
    });
  }

  @override
  void dispose() {
    _line1.dispose();
    _line2.dispose();
    _city.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  void _tryPrefillShopCity(Map<String, dynamic>? doc) {
    if (_shopCityPrefillAttempted) {
      return;
    }
    if (_city.text.trim().isNotEmpty) {
      _shopCityPrefillAttempted = true;
      return;
    }
    if (doc == null) {
      return;
    }
    _shopCityPrefillAttempted = true;
    final String shopCity = (doc['city'] as String?)?.trim() ?? '';
    if (shopCity.isEmpty) {
      return;
    }
    _city.text = shopCity;
    ref.read(createOrderDraftProvider.notifier).setAddress(city: shopCity);
  }

  void _sync() {
    ref.read(createOrderDraftProvider.notifier).setAddress(
          line1: _line1.text,
          line2: _line2.text,
          city: _city.text,
          addressPhone: _phone.text,
          deliveryNote: _note.text,
        );
  }

  @override
  Widget build(BuildContext context) {
    final CreateOrderDraft draft = ref.watch(createOrderDraftProvider);
    final CreateOrderDraftNotifier notifier =
        ref.read(createOrderDraftProvider.notifier);

    ref.listen<AsyncValue<Map<String, dynamic>?>>(
      vendorAccountDocDataProvider,
      (AsyncValue<Map<String, dynamic>?>? _, AsyncValue<Map<String, dynamic>?> next) {
        _tryPrefillShopCity(next.valueOrNull);
      },
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        Text(
          _vTxt(context, en: 'Delivery address', si: 'බෙදාහැරීමේ ලිපිනය'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _line1,
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'Address line 1 *', si: 'ලිපිනය 1 *'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => _sync(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _line2,
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'Address line 2', si: 'ලිපිනය 2'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => _sync(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _city,
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'City *', si: 'නගරය *'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => _sync(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'Contact phone', si: 'සම්බන්ධ දුරකථනය'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => _sync(),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _note,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: _vTxt(context, en: 'Delivery note', si: 'සටහන'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          onChanged: (_) => _sync(),
        ),
        const SizedBox(height: 16),
        Text(
          _vTxt(
            context,
            en: 'Package payment',
            si: 'පැකේජ ගෙවීම',
          ),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 8),
        SegmentedButton<bool>(
          segments: <ButtonSegment<bool>>[
            ButtonSegment<bool>(
              value: false,
              label: Text(_vTxt(context, en: 'Not paid', si: 'ගෙවී නැත')),
              icon: const Icon(Icons.money_off_outlined, size: 18),
            ),
            ButtonSegment<bool>(
              value: true,
              label: Text(_vTxt(context, en: 'Paid', si: 'ගෙවා ඇත')),
              icon: const Icon(Icons.payments_outlined, size: 18),
            ),
          ],
          selected: <bool>{draft.productsPaid},
          onSelectionChanged: (Set<bool> next) {
            if (next.isEmpty) {
              return;
            }
            notifier.setProductsPaid(next.first);
          },
        ),
        const SizedBox(height: 6),
        Text(
          draft.productsPaid
              ? _vTxt(
                  context,
                  en:
                      'Customer paid for the package. Rider collects delivery fee only.',
                  si:
                      'පැකේජය සඳහා ගෙවා ඇත. Rider ට delivery fee පමණක් අය කරයි.',
                )
              : _vTxt(
                  context,
                  en:
                      'Not paid. Rider collects package price + delivery fee.',
                  si:
                      'ගෙවී නැත. Rider ට පැකේජ මිල + delivery fee අය කරයි.',
                ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            final ShopMapPickResult? pick = await ShopMapPickerPage.open(
              context,
              initialCenter: draft.hasDropoff
                  ? LatLng(draft.dropoffLatitude!, draft.dropoffLongitude!)
                  : null,
            );
            if (pick == null) {
              if (context.mounted && !isShopMapPickerSupported()) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _vTxt(
                        context,
                        en: 'Map picker needs Android or iOS.',
                        si: 'සිතියම Android/iOS මත පමණි.',
                      ),
                    ),
                  ),
                );
              }
              return;
            }
            notifier.setDropoff(
              latitude: pick.latitude,
              longitude: pick.longitude,
              suggestedLine1: pick.suggestedAddressLine,
              suggestedCity: pick.suggestedCity,
            );
            if (pick.suggestedAddressLine.isNotEmpty &&
                _line1.text.trim().isEmpty) {
              _line1.text = pick.suggestedAddressLine;
            }
            if (pick.suggestedCity.isNotEmpty && _city.text.trim().isEmpty) {
              _city.text = pick.suggestedCity;
            }
            _sync();
          },
          icon: const Icon(Icons.pin_drop_outlined),
          label: Text(
            draft.hasDropoff
                ? _vTxt(
                    context,
                    en:
                        'Dropoff pinned (${draft.dropoffLatitude!.toStringAsFixed(4)}, ${draft.dropoffLongitude!.toStringAsFixed(4)})',
                    si: 'ස්ථානය සලකුණු කළා',
                  )
                : _vTxt(
                    context,
                    en: 'Pin dropoff on map (optional)',
                    si: 'සිතියමේ ස්ථානය (අනිවාර්ය නොවේ)',
                  ),
          ),
        ),
        if (!isShopMapPickerSupported()) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            _vTxt(
              context,
              en:
                  'On desktop/web, enter coordinates manually below after testing on a device.',
              si: 'Desktop/web මත device එකකින් පරීක්ෂා කරන්න.',
            ),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Latitude',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String v) {
                    final double? lat = double.tryParse(v.trim());
                    final double? lng = draft.dropoffLongitude;
                    if (lat != null && lng != null) {
                      notifier.setDropoff(latitude: lat, longitude: lng);
                    } else if (lat != null) {
                      notifier.setDropoff(
                        latitude: lat,
                        longitude: draft.dropoffLongitude ?? 79.8612,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Longitude',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (String v) {
                    final double? lng = double.tryParse(v.trim());
                    final double lat = draft.dropoffLatitude ?? 6.9271;
                    if (lng != null) {
                      notifier.setDropoff(latitude: lat, longitude: lng);
                    }
                  },
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: () {
                _sync();
                notifier.goToStep(1);
              },
              child: Text(_vTxt(context, en: 'Back', si: 'ආපසු')),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                _sync();
                if (_line1.text.trim().isEmpty || _city.text.trim().isEmpty) {
                  return;
                }
                notifier.goToStep(3);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.vendorHeroBlue,
              ),
              child: Text(_vTxt(context, en: 'Next', si: 'ඊළඟ')),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewStep extends ConsumerWidget {
  const _ReviewStep({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final CreateOrderDraft draft = ref.watch(createOrderDraftProvider);
    final CreateOrderDraftNotifier notifier =
        ref.read(createOrderDraftProvider.notifier);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: <Widget>[
        Text(
          _vTxt(context, en: 'Review & place', si: 'සමාලෝචනය කර යවන්න'),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 12),
        _ReviewCard(
          title: _vTxt(context, en: 'Customer', si: 'පාරිභෝගික'),
          body:
              '${draft.customerName.isNotEmpty ? draft.customerName : 'Guest'}\n'
              '${draft.phoneE164}\n'
              '${draft.isGuest ? 'Guest order — SMS code verifies delivery' : 'Linked MND account'}',
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          title: _vTxt(context, en: 'Package', si: 'පැකේජය'),
          body:
              'Rs. ${draft.packagePriceLkr}'
              '${draft.packageDescription.trim().isNotEmpty ? '\n${draft.packageDescription.trim()}' : ''}',
        ),
        const SizedBox(height: 10),
        _ReviewCard(
          title: _vTxt(context, en: 'Delivery', si: 'බෙදාහැරීම'),
          body:
              '${draft.line1}'
              '${draft.line2.isNotEmpty ? '\n${draft.line2}' : ''}'
              '\n${draft.city}'
              '\n${draft.addressPhone}'
              '${draft.hasDropoff ? '\nPin: ${draft.dropoffLatitude!.toStringAsFixed(5)}, ${draft.dropoffLongitude!.toStringAsFixed(5)}' : '\nPin: not set'}'
              '\n${draft.productsPaid ? 'Package: Paid' : 'Package: Not paid'}',
        ),
        const SizedBox(height: 8),
        Text(
          _vTxt(
            context,
            en: draft.productsPaid
                ? 'Package: Rs. ${draft.packagePriceLkr} (already paid). Delivery fee is calculated from the rider’s trip distance.'
                : 'Package: Rs. ${draft.packagePriceLkr}. Rider collects the package price + delivery fee (fee from trip distance).',
            si: draft.productsPaid
                ? 'පැකේජය: Rs. ${draft.packagePriceLkr} (ගෙවා ඇත). Delivery fee rider ගමනේ දුරින් ගණනය වේ.'
                : 'පැකේජය: Rs. ${draft.packagePriceLkr}. Rider ට පැකේජ මිල + delivery fee අය කරයි (fee ගමනේ දුරින්).',
          ),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
        ),
        const SizedBox(height: 24),
        Row(
          children: <Widget>[
            TextButton(
              onPressed: draft.submitting ? null : () => notifier.goToStep(2),
              child: Text(_vTxt(context, en: 'Back', si: 'ආපසු')),
            ),
            const Spacer(),
            FilledButton(
              onPressed: draft.submitting
                  ? null
                  : () async {
                      final VendorManualOrderResult? result =
                          await notifier.submit();
                      if (!context.mounted) {
                        return;
                      }
                      if (result == null) {
                        return;
                      }
                      final String message = result.isGuestCustomer &&
                              result.guestSmsSent == false
                          ? _vTxt(
                              context,
                              en:
                                  'Order ${result.trackingNumber} created, but the confirmation SMS failed to send. Contact support before dispatch.',
                              si:
                                  'ඇණවුම ${result.trackingNumber} සාදන ලදී, එහෙත් confirmation SMS එක යැවීම අසාර්ථක විය. dispatch කිරීමට පෙර support අමතන්න.',
                            )
                          : _vTxt(
                              context,
                              en:
                                  'Order ${result.trackingNumber} created · Rs. ${result.total}',
                              si:
                                  'ඇණවුම ${result.trackingNumber} සාදන ලදී · Rs. ${result.total}',
                            );
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(message)),
                      );
                      Navigator.of(context).pop(true);
                    },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.vendorHeroBlue,
                minimumSize: const Size(160, 48),
              ),
              child: draft.submitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: Colors.white,
                      ),
                    )
                  : Text(
                      _vTxt(context, en: 'Place order', si: 'ඇණවුම යවන්න'),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppColors.vendorHeroBlue,
                ),
          ),
          const SizedBox(height: 6),
          Text(body),
        ],
      ),
    );
  }
}
