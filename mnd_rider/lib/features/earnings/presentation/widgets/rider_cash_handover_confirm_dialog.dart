import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';

/// One line of the owed-amount breakdown shown before a rider hands cash
/// over — kept local to this feature rather than importing the similarly
/// shaped `RiderCollectLine` from the `trip` feature's delivery-confirm
/// dialog, since a 2-field value class isn't worth a cross-feature import.
class RiderCashBreakdownLine {
  const RiderCashBreakdownLine({required this.label, required this.amountLkr});

  final String label;
  final int amountLkr;
}

/// Confirms a cash handover request, itemizing what's owed and — just as
/// prominently — what the rider keeps. Mirrors the established pattern in
/// `RiderDeliveryConfirmDialog` (a custom `Dialog`, not `showRiderConfirmDialog`,
/// since that helper only renders one flat text string and three itemized
/// amounts plus a kept-earning figure don't fit in a sentence).
class RiderCashHandoverConfirmDialog extends StatelessWidget {
  const RiderCashHandoverConfirmDialog({
    super.key,
    required this.owedLkr,
    required this.yourEarningLkr,
    this.breakdown = const <RiderCashBreakdownLine>[],
  });

  final int owedLkr;
  final int yourEarningLkr;

  /// Only rendered when the lines actually sum to [owedLkr] — same defensive
  /// reconciliation convention as the trip feature's collect-breakdown, so a
  /// rare rounding/legacy-entry mismatch never shows numbers that don't add up.
  final List<RiderCashBreakdownLine> breakdown;

  bool get _breakdownReconciles {
    if (breakdown.isEmpty) {
      return false;
    }
    final int sum = breakdown.fold(0, (int s, RiderCashBreakdownLine l) => s + l.amountLkr);
    return sum == owedLkr;
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
              _Header(),
              const SizedBox(height: AppSpacing.md),
              _OwedCard(
                owedLkr: owedLkr,
                breakdown: _breakdownReconciles ? breakdown : const <RiderCashBreakdownLine>[],
              ),
              const SizedBox(height: AppSpacing.sm),
              _KeepBand(yourEarningLkr: yourEarningLkr),
              const SizedBox(height: AppSpacing.md),
              Text(
                'This stays outstanding until Admin confirms they received it.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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
                      onPressed: () => Navigator.of(context).pop(true),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                        ),
                      ),
                      child: const Text(
                        'Request confirm',
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
            color: AppColors.warningAmber.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.upload_outlined,
            color: AppColors.warningAmber,
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
                'Hand over cash?',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 2),
              Text(
                'Tells Admin you\'re bringing this in',
                style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OwedCard extends StatelessWidget {
  const _OwedCard({required this.owedLkr, required this.breakdown});

  final int owedLkr;
  final List<RiderCashBreakdownLine> breakdown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.warningAmber.withValues(alpha: isDark ? 0.16 : 0.1),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: AppColors.warningAmber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'OWED TO ADMIN',
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
              LkrFormat.money(owedLkr),
              style: theme.textTheme.displaySmall?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          if (breakdown.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Divider(height: 1, color: AppColors.warningAmber.withValues(alpha: 0.3)),
            const SizedBox(height: AppSpacing.sm),
            for (final RiderCashBreakdownLine line in breakdown)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        line.label,
                        style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
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

class _KeepBand extends StatelessWidget {
  const _KeepBand({required this.yourEarningLkr});

  final int yourEarningLkr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.onlineGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.check_circle_outline, size: 18, color: AppColors.onlineGreen),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'You keep',
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            LkrFormat.money(yourEarningLkr),
            style: theme.textTheme.titleMedium?.copyWith(
              color: AppColors.onlineGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows [RiderCashHandoverConfirmDialog]; resolves false when dismissed.
Future<bool> showRiderCashHandoverConfirmDialog(
  BuildContext context, {
  required int owedLkr,
  required int yourEarningLkr,
  List<RiderCashBreakdownLine> breakdown = const <RiderCashBreakdownLine>[],
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext ctx) => RiderCashHandoverConfirmDialog(
      owedLkr: owedLkr,
      yourEarningLkr: yourEarningLkr,
      breakdown: breakdown,
    ),
  );
  return result ?? false;
}
