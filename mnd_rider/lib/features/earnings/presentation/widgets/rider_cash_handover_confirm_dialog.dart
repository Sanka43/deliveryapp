import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_photo_picker_tile.dart';

/// One line of the owed-amount breakdown shown before a rider hands cash
/// over — kept local to this feature rather than importing the similarly
/// shaped `RiderCollectLine` from the `trip` feature's delivery-confirm
/// dialog, since a 2-field value class isn't worth a cross-feature import.
class RiderCashBreakdownLine {
  const RiderCashBreakdownLine({required this.label, required this.amountLkr});

  final String label;
  final int amountLkr;
}

/// What the rider actually asked for when confirming the dialog.
class RiderCashHandoverResult {
  const RiderCashHandoverResult({
    required this.amountLkr,
    this.referenceImageBytes,
  });

  /// The amount the rider typed — may be less than the full owed balance
  /// (a partial handover); the backend decides which whole jobs that covers.
  final int amountLkr;

  /// Photo evidence (e.g. a bank deposit slip) picked in the dialog, if any.
  final Uint8List? referenceImageBytes;
}

/// Confirms a cash handover request, itemizing what's owed and — just as
/// prominently — what the rider keeps. Lets the rider declare a smaller
/// amount than the full balance (a partial handover, when they can't bring
/// everything right now) and attach photo evidence such as a bank deposit
/// slip. Mirrors the established pattern in `RiderDeliveryConfirmDialog` (a
/// custom `Dialog`, not `showRiderConfirmDialog`, since that helper only
/// renders one flat text string and this needs an editable field, an
/// itemized breakdown, and a photo picker).
class RiderCashHandoverConfirmDialog extends StatefulWidget {
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

  @override
  State<RiderCashHandoverConfirmDialog> createState() =>
      _RiderCashHandoverConfirmDialogState();
}

class _RiderCashHandoverConfirmDialogState
    extends State<RiderCashHandoverConfirmDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount = TextEditingController(
    text: widget.owedLkr.toString(),
  );
  Uint8List? _referenceBytes;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool get _breakdownReconciles {
    if (widget.breakdown.isEmpty) {
      return false;
    }
    final int sum = widget.breakdown.fold(
      0,
      (int s, RiderCashBreakdownLine l) => s + l.amountLkr,
    );
    return sum == widget.owedLkr;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final int amount = int.parse(_amount.text.trim());
    Navigator.of(context).pop(
      RiderCashHandoverResult(
        amountLkr: amount,
        referenceImageBytes: _referenceBytes,
      ),
    );
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
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _Header(),
                const SizedBox(height: AppSpacing.md),
                _OwedCard(
                  owedLkr: widget.owedLkr,
                  breakdown: _breakdownReconciles
                      ? widget.breakdown
                      : const <RiderCashBreakdownLine>[],
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Amount you\'re bringing',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Lower this if you can\'t hand over the full amount right '
                  'now — the rest stays outstanding for next time.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _amount,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Amount (LKR)',
                    prefixText: 'Rs. ',
                  ),
                  validator: (String? v) {
                    final int? n = int.tryParse(v?.trim() ?? '');
                    if (n == null || n <= 0) {
                      return 'Enter an amount';
                    }
                    if (n > widget.owedLkr) {
                      return 'Can\'t exceed the amount owed';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                RiderPhotoPickerTile(
                  label: 'Reference photo (optional)',
                  hint: 'e.g. bank deposit slip',
                  icon: Icons.receipt_long_outlined,
                  bytes: _referenceBytes,
                  onPicked: (Uint8List bytes) {
                    setState(() => _referenceBytes = bytes);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),
                _KeepBand(yourEarningLkr: widget.yourEarningLkr),
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
                        onPressed: () => Navigator.of(context).pop(null),
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
                        onPressed: _submit,
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

/// Shows [RiderCashHandoverConfirmDialog]; resolves null when cancelled or
/// dismissed.
Future<RiderCashHandoverResult?> showRiderCashHandoverConfirmDialog(
  BuildContext context, {
  required int owedLkr,
  required int yourEarningLkr,
  List<RiderCashBreakdownLine> breakdown = const <RiderCashBreakdownLine>[],
}) {
  return showDialog<RiderCashHandoverResult>(
    context: context,
    builder: (BuildContext ctx) => RiderCashHandoverConfirmDialog(
      owedLkr: owedLkr,
      yourEarningLkr: yourEarningLkr,
      breakdown: breakdown,
    ),
  );
}
