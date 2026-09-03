import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/widgets/rider_primary_cta.dart';
import 'package:mnd_rider/core/widgets/rider_sheet_scaffold.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/earnings/data/rider_earnings_repository.dart';
import 'package:mnd_rider/features/earnings/domain/rider_wallet.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_earnings_from_orders_provider.dart';

Future<void> showRiderWithdrawSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: riderSheetShape,
    builder: (BuildContext ctx) => const _RiderWithdrawSheet(),
  );
}

class _RiderWithdrawSheet extends ConsumerStatefulWidget {
  const _RiderWithdrawSheet();

  @override
  ConsumerState<_RiderWithdrawSheet> createState() =>
      _RiderWithdrawSheetState();
}

class _RiderWithdrawSheetState extends ConsumerState<_RiderWithdrawSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _account = TextEditingController();
  String _method = 'bank';
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _account.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _busy = true);
    final String? err = await ref
        .read(riderEarningsRepositoryProvider)
        .requestWithdrawal(
          amountLkr: double.parse(_amount.text.trim()),
          payoutMethod: _method,
          payoutAccount: _account.text.trim(),
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      showRiderSnackBar(context, err);
      return;
    }
    Navigator.of(context).pop();
    showRiderSnackBar(context, 'Withdrawal request submitted.');
  }

  @override
  Widget build(BuildContext context) {
    final RiderWallet wallet =
        ref.watch(riderWalletProvider).valueOrNull ?? const RiderWallet.empty();

    return RiderSheetScaffold(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Request withdrawal',
              style: Theme.of(
                context,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Available: Rs. ${wallet.balanceLkr.round()} · Min Rs. ${RiderEarningsRepository.minWithdrawalLkr.round()}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            SegmentedButton<String>(
              segments: const <ButtonSegment<String>>[
                ButtonSegment<String>(value: 'bank', label: Text('Bank')),
                ButtonSegment<String>(value: 'mobile', label: Text('Mobile')),
              ],
              selected: <String>{_method},
              onSelectionChanged: (Set<String> v) {
                setState(() => _method = v.first);
              },
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Amount (LKR)',
                prefixText: 'Rs. ',
              ),
              validator: (String? v) {
                final double? n = double.tryParse(v?.trim() ?? '');
                if (n == null || n <= 0) {
                  return 'Enter an amount';
                }
                if (n < RiderEarningsRepository.minWithdrawalLkr) {
                  return 'Minimum Rs. ${RiderEarningsRepository.minWithdrawalLkr.round()}';
                }
                if (n > wallet.balanceLkr) {
                  return 'Exceeds available balance';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _account,
              decoration: InputDecoration(
                labelText: _method == 'bank'
                    ? 'Account number'
                    : 'Mobile number',
              ),
              validator: (String? v) {
                if (v == null || v.trim().length < 4) {
                  return 'Enter payout details';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            RiderPrimaryCta(
              label: 'Submit request',
              color: AppColors.primaryBlue,
              busy: _busy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
