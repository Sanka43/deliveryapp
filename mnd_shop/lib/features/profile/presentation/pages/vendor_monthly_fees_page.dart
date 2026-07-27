import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/features/billing/domain/vendor_monthly_invoice.dart';
import 'package:mnd_shop/features/billing/presentation/providers/vendor_monthly_invoices_providers.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

/// Monthly platform fee invoices for the signed-in shop (read-only).
class VendorMonthlyFeesPage extends ConsumerWidget {
  const VendorMonthlyFeesPage({super.key});

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  static String _monthLabel(String monthKey) {
    final List<String> parts = monthKey.split('-');
    if (parts.length != 2) {
      return monthKey;
    }
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    if (year == null || month == null || month < 1 || month > 12) {
      return monthKey;
    }
    const List<String> names = <String>[
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${names[month - 1]} $year';
  }

  static Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.openGreen;
      case 'invoiced':
        return AppColors.pendingAmber;
      default:
        return AppColors.textMuted;
    }
  }

  static String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'paid':
        return _vTxt(context, en: 'Paid', si: 'ගෙවා ඇත');
      case 'invoiced':
        return _vTxt(context, en: 'Invoiced', si: 'ඉන්වොයිස් කර ඇත');
      default:
        return _vTxt(context, en: 'Pending', si: 'අපේක්ෂිත');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final AsyncValue<List<VendorMonthlyInvoice>> list =
        ref.watch(vendorMonthlyInvoicesListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(
          _vTxt(context, en: 'Monthly platform fees', si: 'මාසික වේදිකා ගාස්තු'),
        ),
      ),
      body: storeId.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _vTxt(
                    context,
                    en: 'Link your store to view monthly fees.',
                    si: 'මාසික ගාස්තු බැලීමට ඔබේ store එක link කරන්න.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textMuted,
                  ),
                ),
              ),
            )
          : list.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator.adaptive()),
              error: (Object e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '${_vTxt(context, en: 'Could not load fees.', si: 'ගාස්තු පූරණය කළ නොහැක.')}\n$e',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: cs.error,
                    ),
                  ),
                ),
              ),
              data: (List<VendorMonthlyInvoice> invoices) {
                if (invoices.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: AppColors.textMuted.withValues(alpha: 0.7),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _vTxt(
                              context,
                              en: 'No monthly fees yet',
                              si: 'තවම මාසික ගාස්තු නැත',
                            ),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textCharcoal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _vTxt(
                              context,
                              en:
                                  'When MND generates your monthly platform fee invoice, it will show up here.',
                              si:
                                  'MND මාසික වේදිකා ගාස්තු ඉන්වොයිස් එකක් සාදන විට එය මෙහි පෙනේ.',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final double outstanding = invoices
                    .where((VendorMonthlyInvoice i) => !i.isPaid)
                    .fold<double>(
                      0,
                      (double s, VendorMonthlyInvoice i) => s + i.feeLkr,
                    );

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _vTxt(
                              context,
                              en: 'Outstanding',
                              si: 'ගෙවිය යුතු',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _money(outstanding),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: outstanding > 0
                                  ? AppColors.pendingAmber
                                  : AppColors.openGreen,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _vTxt(
                              context,
                              en:
                                  'Pay via MND support after you receive an invoice. Status is updated by admin.',
                              si:
                                  'ඉන්වොයිස් ලැබුණු පසු MND support හරහා ගෙවන්න. තත්ත්වය admin විසින් යාවත්කාලීන කෙරේ.',
                            ),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: AppColors.textMuted,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _vTxt(context, en: 'History', si: 'ඉතිහාසය'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...invoices.map(
                      (VendorMonthlyInvoice inv) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _InvoiceTile(invoice: inv),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _InvoiceTile extends StatelessWidget {
  const _InvoiceTile({required this.invoice});

  final VendorMonthlyInvoice invoice;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor =
        VendorMonthlyFeesPage._statusColor(invoice.status);

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
                  VendorMonthlyFeesPage._monthLabel(invoice.monthKey),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
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
                  VendorMonthlyFeesPage._statusLabel(context, invoice.status),
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: statusColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MetaRow(
            label: _vTxt(context, en: 'Net sales', si: 'ශුද්ධ විකුණුම්'),
            value: VendorMonthlyFeesPage._money(invoice.netSalesLkr),
          ),
          const SizedBox(height: 4),
          _MetaRow(
            label: _vTxt(context, en: 'Fee rate', si: 'ගාස්තු අනුපාතය'),
            value: '${invoice.feePercent.toStringAsFixed(
              invoice.feePercent == invoice.feePercent.roundToDouble() ? 0 : 1,
            )}%',
          ),
          const SizedBox(height: 4),
          _MetaRow(
            label: _vTxt(context, en: 'Platform fee', si: 'වේදිකා ගාස්තුව'),
            value: VendorMonthlyFeesPage._money(invoice.feeLkr),
            emphasize: true,
          ),
          if (invoice.notes.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              invoice.notes.trim(),
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textMuted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
            color: AppColors.textCharcoal,
          ),
        ),
      ],
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
