import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/orders/data/customer_orders_repository.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_detail.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';

/// Rate rider card shown on delivered orders (submit or read-only thanks).
class RiderRatingCard extends ConsumerStatefulWidget {
  const RiderRatingCard({super.key, required this.detail});

  final CustomerOrderDetail detail;

  static bool isRateable(CustomerOrderDetail detail) {
    final String status = detail.statusRaw.toLowerCase().trim();
    final bool hasRider = detail.riderId != null && detail.riderId!.trim().isNotEmpty;
    return hasRider && (status == 'delivered' || status == 'completed');
  }

  @override
  ConsumerState<RiderRatingCard> createState() => _RiderRatingCardState();
}

class _RiderRatingCardState extends ConsumerState<RiderRatingCard> {
  int _stars = 0;
  final TextEditingController _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_stars < 1 || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    final StoreRatingResult result =
        await ref.read(customerOrdersRepositoryProvider).submitRiderRating(
              orderId: widget.detail.id,
              stars: _stars,
              comment: _commentController.text,
            );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (result.ok) {
      showMndSnackBar(context, 'Thanks for rating your rider!', variant: MndSnackBarVariant.success);
    } else {
      showMndSnackBar(context, result.message ?? 'Could not submit rating.', variant: MndSnackBarVariant.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerOrderDetail detail = widget.detail;
    final bool rateable = RiderRatingCard.isRateable(detail);
    if (!rateable) {
      return const SizedBox.shrink();
    }

    if (detail.riderRated) {
      final int stars = detail.riderRatingStars ?? 0;
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Your rider rating',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Row(
                children: <Widget>[
                  for (int i = 1; i <= 5; i++)
                    Icon(
                      i <= stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 28,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Thanks for your feedback.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
        side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Rate your rider',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'How was your delivery?',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Row(
              children: <Widget>[
                for (int i = 1; i <= 5; i++)
                  IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    onPressed: _submitting
                        ? null
                        : () => setState(() => _stars = i),
                    icon: Icon(
                      i <= _stars
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: const Color(0xFFF59E0B),
                      size: 32,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _commentController,
              enabled: !_submitting,
              maxLength: 500,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Optional comment',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: (_stars < 1 || _submitting) ? null : _submit,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit rating'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
