import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/billing/data/vendor_wallet_repository.dart';
import 'package:mnd_shop/features/billing/domain/vendor_payout.dart';
import 'package:mnd_shop/features/billing/domain/vendor_wallet.dart';
import 'package:mnd_shop/features/billing/presentation/providers/vendor_wallet_providers.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

const int _kMinPayoutLkr = 1000;

/// Wallet balance + self-service payout requests for online (PayHere) sales.
/// Cash-on-delivery sales are settled separately by admin (see the
/// "CASH ..." badges on orders) and never appear in this wallet.
class VendorPayoutsPage extends ConsumerWidget {
  const VendorPayoutsPage({super.key});

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final AsyncValue<VendorWallet> wallet = ref.watch(vendorWalletProvider);
    final AsyncValue<List<VendorPayout>> payouts = ref.watch(vendorPayoutsListProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Payouts', si: 'ගෙවීම්')),
      ),
      body: storeId.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _vTxt(
                    context,
                    en: 'Link your store to view payouts.',
                    si: 'ගෙවීම් බැලීමට ඔබේ store එක link කරන්න.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            )
          : wallet.when(
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (Object e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    userFacingError(e, fallback: 'Could not load wallet.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                  ),
                ),
              ),
              data: (VendorWallet w) => ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                children: <Widget>[
                  _WalletSummaryCard(
                    wallet: w,
                    onRequestPayout: () => _openRequestSheet(context, ref, w),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      _vTxt(
                        context,
                        en:
                            'Only online-paid orders are credited here. Cash-on-delivery sales are settled by MND admin separately.',
                        si:
                            'මෙහි credit වන්නේ online ගෙවූ orders පමණි. Cash-on-delivery විකුණුම් MND admin විසින් වෙනමින් settle කරනු ලැබේ.',
                      ),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _vTxt(context, en: 'History', si: 'ඉතිහාසය'),
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textCharcoal,
                    ),
                  ),
                  const SizedBox(height: 10),
                  payouts.when(
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(child: CircularProgressIndicator.adaptive()),
                    ),
                    error: (Object e, _) => Text(
                      userFacingError(e, fallback: 'Could not load payout history.'),
                      style: theme.textTheme.bodySmall?.copyWith(color: cs.error),
                    ),
                    data: (List<VendorPayout> list) {
                      if (list.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Text(
                            _vTxt(
                              context,
                              en: 'No payout requests yet.',
                              si: 'තවම ගෙවීම් ඉල්ලීම් නැත.',
                            ),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: AppColors.textMuted,
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: list
                            .map(
                              (VendorPayout p) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _PayoutTile(payout: p),
                              ),
                            )
                            .toList(growable: false),
                      );
                    },
                  ),
                ],
              ),
            ),
    );
  }

  void _openRequestSheet(BuildContext context, WidgetRef ref, VendorWallet wallet) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => _RequestPayoutSheet(availableLkr: wallet.balanceLkr),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({required this.wallet, required this.onRequestPayout});

  final VendorWallet wallet;
  final VoidCallback onRequestPayout;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool canRequest = wallet.balanceLkr >= _kMinPayoutLkr;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _vTxt(context, en: 'Available balance', si: 'ලබා ගත හැකි ශේෂය'),
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            VendorPayoutsPage._money(wallet.balanceLkr),
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textCharcoal,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: _WalletStat(
                  label: _vTxt(context, en: 'Pending', si: 'අපේක්ෂිත'),
                  value: VendorPayoutsPage._money(wallet.pendingWithdrawalLkr),
                  color: AppColors.pendingAmber,
                ),
              ),
              Expanded(
                child: _WalletStat(
                  label: _vTxt(context, en: 'Lifetime earned', si: 'මුළු ඉපැයීම'),
                  value: VendorPayoutsPage._money(wallet.lifetimeEarnedLkr),
                  color: AppColors.textCharcoal,
                ),
              ),
              Expanded(
                child: _WalletStat(
                  label: _vTxt(context, en: 'Lifetime paid', si: 'මුළු ගෙවීම්'),
                  value: VendorPayoutsPage._money(wallet.lifetimeWithdrawnLkr),
                  color: AppColors.openGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: canRequest ? onRequestPayout : null,
              child: Text(
                canRequest
                    ? _vTxt(context, en: 'Request payout', si: 'ගෙවීමක් ඉල්ලන්න')
                    : _vTxt(
                        context,
                        en: 'Minimum Rs. $_kMinPayoutLkr to withdraw',
                        si: 'අවම වශයෙන් Rs. $_kMinPayoutLkr අවශ්‍යයි',
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletStat extends StatelessWidget {
  const _WalletStat({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: color,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _PayoutTile extends StatelessWidget {
  const _PayoutTile({required this.payout});

  final VendorPayout payout;

  static Color _statusColor(String status) {
    switch (status) {
      case 'paid':
        return AppColors.openGreen;
      case 'rejected':
        return AppColors.orderRejectRed;
      default:
        return AppColors.pendingAmber;
    }
  }

  static String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case 'paid':
        return _vTxt(context, en: 'Paid', si: 'ගෙවා ඇත');
      case 'rejected':
        return _vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප කරන ලදී');
      default:
        return _vTxt(context, en: 'Pending', si: 'අපේක්ෂිත');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color statusColor = _statusColor(payout.status);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  VendorPayoutsPage._money(payout.amountLkr),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${payout.payoutMethod == 'bank' ? _vTxt(context, en: 'Bank', si: 'බැංකු') : _vTxt(context, en: 'Mobile', si: 'ජංගම')} · ${payout.payoutAccount}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _statusLabel(context, payout.status),
              style: theme.textTheme.labelMedium?.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequestPayoutSheet extends ConsumerStatefulWidget {
  const _RequestPayoutSheet({required this.availableLkr});

  final double availableLkr;

  @override
  ConsumerState<_RequestPayoutSheet> createState() => _RequestPayoutSheetState();
}

class _RequestPayoutSheetState extends ConsumerState<_RequestPayoutSheet> {
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _accountCtrl = TextEditingController();
  final TextEditingController _noteCtrl = TextEditingController();
  String _method = 'bank';
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _amountCtrl.dispose();
    _accountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final double? amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount < _kMinPayoutLkr) {
      setState(() => _error = 'Enter an amount of at least Rs. $_kMinPayoutLkr.');
      return;
    }
    if (amount > widget.availableLkr) {
      setState(() => _error = 'Amount exceeds your available balance.');
      return;
    }
    if (_accountCtrl.text.trim().length < 4) {
      setState(() => _error = 'Enter your account or mobile wallet number.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });
    final String? error = await ref.read(vendorWalletRepositoryProvider).requestPayout(
          amountLkr: amount,
          payoutMethod: _method,
          payoutAccount: _accountCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
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
      const SnackBar(content: Text('Payout request submitted.')),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _vTxt(context, en: 'Request payout', si: 'ගෙවීමක් ඉල්ලන්න'),
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            _vTxt(
              context,
              en: 'Available: ${VendorPayoutsPage._money(widget.availableLkr)}',
              si: 'ලබා ගත හැක: ${VendorPayoutsPage._money(widget.availableLkr)}',
            ),
            style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _amountCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: false),
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: _vTxt(context, en: 'Amount (LKR)', si: 'ප්‍රමාණය (LKR)'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(
                value: 'bank',
                label: Text(_vTxt(context, en: 'Bank', si: 'බැංකු')),
                icon: const Icon(Icons.account_balance_outlined),
              ),
              ButtonSegment<String>(
                value: 'mobile',
                label: Text(_vTxt(context, en: 'Mobile wallet', si: 'ජංගම')),
                icon: const Icon(Icons.smartphone_outlined),
              ),
            ],
            selected: <String>{_method},
            onSelectionChanged: (Set<String> s) => setState(() => _method = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _accountCtrl,
            decoration: InputDecoration(
              labelText: _method == 'bank'
                  ? _vTxt(context, en: 'Bank account number', si: 'බැංකු ගිණුම් අංකය')
                  : _vTxt(context, en: 'Mobile wallet number', si: 'ජංගම අංකය'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _noteCtrl,
            decoration: InputDecoration(
              labelText: _vTxt(context, en: 'Note (optional)', si: 'සටහන (විකල්ප)'),
              border: const OutlineInputBorder(),
            ),
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
                  : Text(_vTxt(context, en: 'Submit request', si: 'ඉල්ලීම යවන්න')),
            ),
          ),
        ],
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
