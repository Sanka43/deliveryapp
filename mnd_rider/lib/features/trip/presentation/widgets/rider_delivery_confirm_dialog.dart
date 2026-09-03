import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';

/// Delivery hand-over confirmation.
///
/// Cash orders make the rider tick off the money first — the payment button
/// has to be pressed before "Confirm delivered" unlocks — so an order can't be
/// closed on a tap-through while the cash is still in the customer's hand.
/// Prepaid orders skip that step and say plainly that nothing is collected.
class RiderDeliveryConfirmDialog extends StatefulWidget {
  const RiderDeliveryConfirmDialog({
    super.key,
    required this.collectAmountLkr,
    required this.isPrepaidOnline,
    this.awayFromDropoff = false,
    this.breakdown = const <RiderCollectLine>[],
  });

  /// Cash the rider takes from the customer (0 for prepaid orders).
  final int collectAmountLkr;
  final bool isPrepaidOnline;

  /// Rider isn't within the drop-off radius yet — shown as a warning band.
  final bool awayFromDropoff;

  /// Optional products / delivery / service-charge split of the amount.
  final List<RiderCollectLine> breakdown;

  @override
  State<RiderDeliveryConfirmDialog> createState() =>
      _RiderDeliveryConfirmDialogState();
}

/// One row of the collect-amount breakdown.
class RiderCollectLine {
  const RiderCollectLine({required this.label, required this.amountLkr});

  final String label;
  final int amountLkr;
}

class _RiderDeliveryConfirmDialogState
    extends State<RiderDeliveryConfirmDialog> {
  bool _paymentConfirmed = false;

  bool get _needsCash => !widget.isPrepaidOnline && widget.collectAmountLkr > 0;

  bool get _canConfirm => !_needsCash || _paymentConfirmed;

  void _togglePayment() {
    HapticFeedback.selectionClick();
    setState(() => _paymentConfirmed = !_paymentConfirmed);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Dialog(
      backgroundColor: cs.surface,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.sheetRadius),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _Header(isPrepaidOnline: widget.isPrepaidOnline),
              if (widget.awayFromDropoff) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                const _WarningBand(
                  text: 'You do not appear to be at the drop-off yet.',
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              if (_needsCash)
                _CollectCard(
                  amountLkr: widget.collectAmountLkr,
                  breakdown: widget.breakdown,
                )
              else
                _PrepaidCard(isPrepaidOnline: widget.isPrepaidOnline),
              if (_needsCash) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                _PaymentConfirmButton(
                  confirmed: _paymentConfirmed,
                  amountLkr: widget.collectAmountLkr,
                  onPressed: _togglePayment,
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                _needsCash
                    ? (_paymentConfirmed
                          ? 'Cash confirmed. Hand over the order to finish.'
                          : 'Confirm the cash first, then mark the order delivered.')
                    : 'Confirm you have handed the order to the customer.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: _canConfirm
                          ? () => Navigator.of(context).pop(true)
                          : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppSpacing.buttonRadius,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Confirm delivered',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isPrepaidOnline});

  final bool isPrepaidOnline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Row(
      children: <Widget>[
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.onlineGreen.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.inventory_2_rounded,
            color: AppColors.onlineGreen,
            size: 22,
          ),
        ),
        const SizedBox(width: AppSpacing.itemGap),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                'Mark delivered?',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isPrepaidOnline
                    ? 'Paid online — no cash to collect'
                    : 'Collect the cash, then hand over',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WarningBand extends StatelessWidget {
  const _WarningBand({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = theme.brightness == Brightness.dark;
    final Color foreground = isDark
        ? Color.lerp(AppColors.warningAmber, Colors.white, 0.35) ??
              AppColors.warningAmber
        : Color.lerp(AppColors.warningAmber, Colors.black, 0.35) ??
              AppColors.warningAmber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: isDark ? 0.2 : 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(
          color: AppColors.warningAmber.withValues(alpha: 0.45),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, size: 18, color: foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CollectCard extends StatelessWidget {
  const _CollectCard({required this.amountLkr, required this.breakdown});

  final int amountLkr;
  final List<RiderCollectLine> breakdown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.onlineGreen.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.onlineGreen.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'COLLECT FROM CUSTOMER',
            style: theme.textTheme.labelSmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              LkrFormat.money(amountLkr),
              style: theme.textTheme.displaySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (breakdown.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: AppColors.onlineGreen.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            for (final RiderCollectLine line in breakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        line.label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Text(
                      LkrFormat.money(line.amountLkr),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _PrepaidCard extends StatelessWidget {
  const _PrepaidCard({required this.isPrepaidOnline});

  final bool isPrepaidOnline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            isPrepaidOnline ? Icons.verified_rounded : Icons.payments_rounded,
            size: 20,
            color: AppColors.onlineGreen,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              isPrepaidOnline
                  ? 'Already paid online. Do not collect any cash.'
                  : 'Nothing to collect for this order.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The payment gate: an unmissable button the rider presses once the money is
/// in hand. Pressing again clears it, in case it was hit by mistake.
class _PaymentConfirmButton extends StatelessWidget {
  const _PaymentConfirmButton({
    required this.confirmed,
    required this.amountLkr,
    required this.onPressed,
  });

  final bool confirmed;
  final int amountLkr;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String label = confirmed
        ? 'Payment received'
        : 'Confirm ${LkrFormat.money(amountLkr)} received';

    if (confirmed) {
      return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.onlineGreen,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
          ),
        ),
        icon: const Icon(Icons.check_circle_rounded, size: 22),
        label: Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      );
    }

    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onlineGreen,
        minimumSize: const Size.fromHeight(52),
        side: const BorderSide(color: AppColors.onlineGreen, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        ),
      ),
      icon: const Icon(Icons.radio_button_unchecked_rounded, size: 22),
      label: Text(
        label,
        style: theme.textTheme.titleSmall?.copyWith(
          color: AppColors.onlineGreen,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

/// Shows [RiderDeliveryConfirmDialog]; resolves false when dismissed.
Future<bool> showRiderDeliveryConfirmDialog(
  BuildContext context, {
  required int collectAmountLkr,
  required bool isPrepaidOnline,
  bool awayFromDropoff = false,
  List<RiderCollectLine> breakdown = const <RiderCollectLine>[],
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => RiderDeliveryConfirmDialog(
      collectAmountLkr: collectAmountLkr,
      isPrepaidOnline: isPrepaidOnline,
      awayFromDropoff: awayFromDropoff,
      breakdown: breakdown,
    ),
  );
  return result ?? false;
}
