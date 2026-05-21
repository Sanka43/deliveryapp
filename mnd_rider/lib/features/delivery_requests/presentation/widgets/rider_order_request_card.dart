import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';

/// Bottom-sheet style offer card with countdown.
class RiderOrderRequestCard extends StatelessWidget {
  const RiderOrderRequestCard({
    super.key,
    required this.request,
    required this.secondsRemaining,
    required this.totalSeconds,
    required this.onAccept,
    required this.onReject,
    this.accepting = false,
  });

  final RiderDeliveryRequest request;
  final int secondsRemaining;
  final int totalSeconds;
  final VoidCallback onAccept;
  final VoidCallback onReject;
  final bool accepting;

  IconData _deliveryIcon(RiderDeliveryType type) {
    switch (type) {
      case RiderDeliveryType.cashOnDelivery:
        return Icons.payments_outlined;
      case RiderDeliveryType.express:
        return Icons.bolt_rounded;
      case RiderDeliveryType.standard:
        return Icons.local_shipping_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final double progress = totalSeconds <= 0
        ? 0
        : (secondsRemaining / totalSeconds).clamp(0.0, 1.0);

    return Material(
      elevation: 24,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      color: cs.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: cs.outlineVariant,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      'NEW REQUEST',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.primaryBlue,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${secondsRemaining}s',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: secondsRemaining <= 10 ? cs.error : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: cs.surfaceContainerHighest,
                  color: secondsRemaining <= 10 ? cs.error : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                request.vendorName,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: <Widget>[
                  Icon(_deliveryIcon(request.deliveryType), size: 18, color: cs.onSurfaceVariant),
                  const SizedBox(width: 6),
                  Text(
                    request.deliveryType.label,
                    style: theme.textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    request.referenceForDisplay,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontFamily: 'monospace',
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _EarningsRow(amount: LkrFormat.money(request.estimatedEarningsLkr)),
              const SizedBox(height: 18),
              _LocationRow(
                icon: Icons.store_mall_directory_outlined,
                label: 'Pickup',
                address: request.pickupAddress,
                distanceLabel: request.distanceToPickupLabel,
                accent: AppColors.primaryBlue,
              ),
              const SizedBox(height: 14),
              _LocationRow(
                icon: Icons.location_on_outlined,
                label: 'Customer',
                address: request.customerAddress,
                distanceLabel: request.routeKmLabel,
                accent: AppColors.onlineGreen,
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  _MetaChip(icon: Icons.shopping_bag_outlined, text: request.itemsSummary),
                ],
              ),
              const SizedBox(height: 22),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: accepting ? null : onReject,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: cs.error,
                        side: BorderSide(color: cs.error.withValues(alpha: 0.7)),
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      onPressed: accepting ? null : onAccept,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.onlineGreen,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: accepting
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Accept order'),
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

class _EarningsRow extends StatelessWidget {
  const _EarningsRow({required this.amount});

  final String amount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: <Color>[
            AppColors.primaryBlue.withValues(alpha: 0.14),
            AppColors.primaryBlue.withValues(alpha: 0.05),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.statRadius),
        border: Border.all(color: AppColors.primaryBlue.withValues(alpha: 0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: <Widget>[
            const Icon(Icons.payments_outlined, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Text(
              'Estimated earnings',
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              amount,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.label,
    required this.address,
    required this.distanceLabel,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String address;
  final String distanceLabel;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, color: accent, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Text(
                    label,
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    distanceLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(address, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 16, color: cs.onSurfaceVariant),
            const SizedBox(width: 6),
            Text(text, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
