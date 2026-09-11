import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/coupons/data/vendor_coupons_repository.dart';
import 'package:mnd_shop/features/coupons/domain/vendor_coupon.dart';
import 'package:mnd_shop/features/coupons/presentation/providers/vendor_coupons_providers.dart';

const int _kMaxPercentValue = 70;
const int _kMaxFlatValueLkr = 100000;

/// Vendor-created promo codes — the gap where coupons were 100% admin-driven
/// with zero vendor visibility or involvement. A vendor submits a coupon
/// here; it stays `pending` until admin approves it (mnd_web Coupons page)
/// before it can ever discount a real order.
class VendorCouponsPage extends ConsumerWidget {
  const VendorCouponsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<List<VendorCoupon>> coupons = ref.watch(vendorCouponsListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Coupons', si: 'Coupon')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openCreateSheet(context, ref),
        icon: const Icon(Icons.add_rounded),
        label: Text(_vTxt(context, en: 'New coupon', si: 'අලුත් coupon')),
      ),
      body: coupons.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              userFacingError(e, fallback: 'Could not load coupons.'),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
            ),
          ),
        ),
        data: (List<VendorCoupon> list) {
          if (list.isEmpty) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: <Widget>[
                const SizedBox(height: 60),
                Center(
                  child: Column(
                    children: <Widget>[
                      Icon(
                        Icons.confirmation_number_outlined,
                        size: 48,
                        color: AppColors.textMuted.withValues(alpha: 0.7),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _vTxt(context, en: 'No coupons yet', si: 'තවම coupons නැත'),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textCharcoal,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          _vTxt(
                            context,
                            en:
                                'Create a promo code for your store. It needs admin approval before customers can use it.',
                            si:
                                'ඔබේ store එකට promo code එකක් හදන්න. Customers ට use කරන්න කලින් admin approval ඕන.',
                          ),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
            children: list
                .map(
                  (VendorCoupon c) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _CouponTile(coupon: c),
                  ),
                )
                .toList(growable: false),
          );
        },
      ),
    );
  }

  void _openCreateSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => const _CreateCouponSheet(),
    );
  }
}

class _CouponTile extends ConsumerWidget {
  const _CouponTile({required this.coupon});

  final VendorCoupon coupon;

  static Color _statusColor(VendorCouponStatus status) {
    switch (status) {
      case VendorCouponStatus.approved:
        return AppColors.openGreen;
      case VendorCouponStatus.rejected:
        return AppColors.orderRejectRed;
      case VendorCouponStatus.pending:
        return AppColors.pendingAmber;
    }
  }

  static String _statusLabel(BuildContext context, VendorCouponStatus status) {
    switch (status) {
      case VendorCouponStatus.approved:
        return _vTxt(context, en: 'Approved', si: 'අනුමත');
      case VendorCouponStatus.rejected:
        return _vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප');
      case VendorCouponStatus.pending:
        return _vTxt(context, en: 'Pending review', si: 'සමාලෝචනයට');
    }
  }

  static String _formatDate(DateTime? d) {
    if (d == null) {
      return '';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor = _statusColor(coupon.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  coupon.code,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFamily: 'monospace',
                    color: AppColors.textCharcoal,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _statusLabel(context, coupon.status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            coupon.discountLabel,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textCharcoal,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            coupon.expiresAt != null
                ? '${_vTxt(context, en: 'Expires', si: 'කල් ඉකුත් වන දිනය')} ${_formatDate(coupon.expiresAt)}'
                : '',
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          if (coupon.status == VendorCouponStatus.approved) ...<Widget>[
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Text(
                  _vTxt(context, en: 'Active', si: 'සක්‍රීයයි'),
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                ),
                const Spacer(),
                Switch.adaptive(
                  value: coupon.active,
                  onChanged: (bool value) async {
                    final String? error = await ref
                        .read(vendorCouponsRepositoryProvider)
                        .setActive(coupon.code, value);
                    if (error != null && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text(error)));
                    }
                  },
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateCouponSheet extends ConsumerStatefulWidget {
  const _CreateCouponSheet();

  @override
  ConsumerState<_CreateCouponSheet> createState() => _CreateCouponSheetState();
}

class _CreateCouponSheetState extends ConsumerState<_CreateCouponSheet> {
  final TextEditingController _codeCtrl = TextEditingController();
  final TextEditingController _valueCtrl = TextEditingController();
  final TextEditingController _minOrderCtrl = TextEditingController();
  final TextEditingController _maxDiscountCtrl = TextEditingController();
  final TextEditingController _maxUsesCtrl = TextEditingController();
  final TextEditingController _perCustomerCtrl = TextEditingController();
  VendorCouponDiscountType _type = VendorCouponDiscountType.percent;
  DateTime? _expiresAt;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _codeCtrl.dispose();
    _valueCtrl.dispose();
    _minOrderCtrl.dispose();
    _maxDiscountCtrl.dispose();
    _maxUsesCtrl.dispose();
    _perCustomerCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final DateTime now = DateTime.now();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 30)),
      firstDate: now.add(const Duration(days: 1)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _expiresAt = picked);
    }
  }

  Future<void> _submit() async {
    final String code = _codeCtrl.text.trim().toUpperCase();
    if (code.length < 3 || code.length > 20 || !RegExp(r'^[A-Z0-9]+$').hasMatch(code)) {
      setState(() => _error = 'Code must be 3-20 letters/numbers.');
      return;
    }
    final int? value = int.tryParse(_valueCtrl.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid discount value.');
      return;
    }
    if (_type == VendorCouponDiscountType.percent && value > _kMaxPercentValue) {
      setState(() => _error = 'Percent discount cannot exceed $_kMaxPercentValue%.');
      return;
    }
    if (_type == VendorCouponDiscountType.flat && value > _kMaxFlatValueLkr) {
      setState(() => _error = 'Flat discount cannot exceed Rs. $_kMaxFlatValueLkr.');
      return;
    }
    if (_expiresAt == null) {
      setState(() => _error = 'Choose when this coupon expires.');
      return;
    }
    // Left blank means "unlimited" server-side — but a typed 0 would create
    // a coupon nobody can ever redeem, with no explanation why it never works.
    final int? maxUses = int.tryParse(_maxUsesCtrl.text.trim());
    if (maxUses != null && maxUses < 1) {
      setState(() => _error = 'Total uses must be at least 1, or left blank for unlimited.');
      return;
    }
    final int? perCustomerLimit = int.tryParse(_perCustomerCtrl.text.trim());
    if (perCustomerLimit != null && perCustomerLimit < 1) {
      setState(() => _error = 'Per-customer limit must be at least 1, or left blank for unlimited.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final String? error = await ref.read(vendorCouponsRepositoryProvider).requestCoupon(
          code: code,
          discountType: _type,
          value: value,
          expiresAt: _expiresAt!,
          minSubtotalLkr: int.tryParse(_minOrderCtrl.text.trim()),
          maxDiscountLkr: _type == VendorCouponDiscountType.percent
              ? int.tryParse(_maxDiscountCtrl.text.trim())
              : null,
          maxUses: maxUses,
          perCustomerLimit: perCustomerLimit,
        );
    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _submitting = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Coupon submitted for admin approval.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _vTxt(context, en: 'New coupon', si: 'අලුත් coupon'),
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              _vTxt(
                context,
                en: 'Only usable at your store, once approved.',
                si: 'Approve වුනාට පස්සේ ඔබේ store එකේ විතරයි use කරන්න පුළුවන්.',
              ),
              style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeCtrl,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                LengthLimitingTextInputFormatter(20),
              ],
              decoration: InputDecoration(
                labelText: _vTxt(context, en: 'Coupon code', si: 'Coupon code'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<VendorCouponDiscountType>(
              segments: <ButtonSegment<VendorCouponDiscountType>>[
                ButtonSegment<VendorCouponDiscountType>(
                  value: VendorCouponDiscountType.percent,
                  label: Text(_vTxt(context, en: 'Percent off', si: '% Off')),
                ),
                ButtonSegment<VendorCouponDiscountType>(
                  value: VendorCouponDiscountType.flat,
                  label: Text(_vTxt(context, en: 'Flat amount', si: 'Flat')),
                ),
              ],
              selected: <VendorCouponDiscountType>{_type},
              onSelectionChanged: (Set<VendorCouponDiscountType> s) =>
                  setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _valueCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: _type == VendorCouponDiscountType.percent
                    ? _vTxt(context, en: 'Percent off (1-$_kMaxPercentValue)', si: 'Percent')
                    : _vTxt(context, en: 'Amount off (LKR)', si: 'Amount (LKR)'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _pickExpiry,
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: _vTxt(context, en: 'Expires on', si: 'කල් ඉකුත් වන දිනය'),
                  border: const OutlineInputBorder(),
                ),
                child: Text(
                  _expiresAt == null
                      ? _vTxt(context, en: 'Choose a date', si: 'දිනයක් තෝරන්න')
                      : '${_expiresAt!.day}/${_expiresAt!.month}/${_expiresAt!.year}',
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _minOrderCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: _vTxt(context, en: 'Min order (optional)', si: 'අවම order'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                if (_type == VendorCouponDiscountType.percent) ...<Widget>[
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _maxDiscountCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        labelText: _vTxt(context, en: 'Max discount', si: 'Max discount'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _maxUsesCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: _vTxt(context, en: 'Total uses (optional)', si: 'මුළු uses'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _perCustomerCtrl,
                    keyboardType: TextInputType.number,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: InputDecoration(
                      labelText: _vTxt(context, en: 'Per customer (optional)', si: 'එක් customer'),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                _error!,
                style: theme.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submitting ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                      )
                    : Text(_vTxt(context, en: 'Submit for approval', si: 'Approval එකට යවන්න')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

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
