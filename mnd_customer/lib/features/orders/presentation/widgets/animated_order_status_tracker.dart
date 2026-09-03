import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/features/orders/domain/order_timeline.dart';

IconData _iconForDeliveryKey(String key) {
  switch (key) {
    case 'restaurant':
      return Icons.restaurant_rounded;
    case 'takeout':
      return Icons.takeout_dining_rounded;
    case 'delivery':
      return Icons.delivery_dining_rounded;
    case 'home':
      return Icons.home_rounded;
    case 'shopping_bag':
      return Icons.shopping_bag_outlined;
    case 'inventory':
      return Icons.inventory_2_outlined;
    default:
      return Icons.circle_outlined;
  }
}

/// Horizontal four-step tracker with animated connectors and a pulsing current step.
///
/// By default renders its own "Order status" heading and card. Pass
/// [embedded] to render just the tracker content (no heading, no card
/// wrapper) so a caller can fuse it into another card — e.g. the order
/// details hero card, which stacks this directly beneath the order total.
class AnimatedOrderStatusTracker extends StatefulWidget {
  const AnimatedOrderStatusTracker({
    super.key,
    required this.statusRaw,
    this.isSelfPickup = false,
    this.embedded = false,
  });

  final String statusRaw;
  final bool isSelfPickup;
  final bool embedded;

  @override
  State<AnimatedOrderStatusTracker> createState() => _AnimatedOrderStatusTrackerState();
}

class _AnimatedOrderStatusTrackerState extends State<AnimatedOrderStatusTracker>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _activeStep = 0;
  bool _wasCancelled = false;
  bool _awaitingPayment = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _syncFromStatus();
  }

  @override
  void didUpdateWidget(AnimatedOrderStatusTracker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.statusRaw != widget.statusRaw ||
        oldWidget.isSelfPickup != widget.isSelfPickup) {
      setState(_syncFromStatus);
    }
  }

  void _syncFromStatus() {
    _wasCancelled = OrderTimelineLogic.isCancelled(widget.statusRaw);
    _awaitingPayment = OrderTimelineLogic.isAwaitingPayment(widget.statusRaw);
    if (!_wasCancelled && !_awaitingPayment) {
      _activeStep = OrderTimelineLogic.currentDeliveryTrackerIndex(
        widget.statusRaw,
        isSelfPickup: widget.isSelfPickup,
      );
    }
    if (_activeStep < 3 && !_wasCancelled && !_awaitingPayment) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_wasCancelled) {
      return _CancelledTrackerCard(embedded: widget.embedded);
    }
    if (_awaitingPayment) {
      return _AwaitingPaymentTrackerCard(embedded: widget.embedded);
    }

    final ThemeData theme = Theme.of(context);
    final List<DeliveryTrackerStepDefinition> steps =
        OrderTimelineLogic.trackerStepsFor(isSelfPickup: widget.isSelfPickup);
    final int current = _activeStep.clamp(0, 3);

    final Widget content = Column(
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int i = 0; i < 4; i++) ...<Widget>[
              if (i > 0) _ConnectorRow(leadingIndex: i - 1, currentStep: current),
              _StepOrb(
                index: i,
                currentStep: current,
                icon: _iconForDeliveryKey(steps[i].iconKey),
                label: steps[i].title,
                pulse: _pulseController,
              ),
            ],
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: Container(
            key: ValueKey<String>(widget.statusRaw),
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.sm + 2),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _PulsingDot(pulse: _pulseController, active: current < 3),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        steps[current].title,
                        style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        steps[current].subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                              color: Colors.black87,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (widget.embedded) {
      return content;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Order status',
          style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        MndPremiumCard(
          borderRadius: AppColors.cardRadiusLg,
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: content,
        ),
      ],
    );
  }
}

class _PulsingDot extends StatelessWidget {
  const _PulsingDot({required this.pulse, required this.active});

  final AnimationController pulse;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final Widget dot = Container(
      width: 8,
      height: 8,
      margin: const EdgeInsets.only(top: 5),
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        shape: BoxShape.circle,
      ),
    );
    if (!active) {
      return dot;
    }
    return AnimatedBuilder(
      animation: pulse,
      builder: (BuildContext context, Widget? child) {
        return Opacity(opacity: 0.5 + pulse.value * 0.5, child: child);
      },
      child: dot,
    );
  }
}

class _ConnectorRow extends StatelessWidget {
  const _ConnectorRow({
    required this.leadingIndex,
    required this.currentStep,
  });

  final int leadingIndex;
  final int currentStep;

  @override
  Widget build(BuildContext context) {
    final bool filled = currentStep > leadingIndex;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(top: 19),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
          tween: Tween<double>(end: filled ? 1.0 : 0.0),
          builder: (BuildContext context, double t, Widget? child) {
            return LayoutBuilder(
              builder: (BuildContext context, BoxConstraints c) {
                return Stack(
                  clipBehavior: Clip.hardEdge,
                  children: <Widget>[
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        height: 3,
                        width: c.maxWidth * t,
                        decoration: BoxDecoration(
                          color: AppColors.primaryBlue,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _StepOrb extends StatelessWidget {
  const _StepOrb({
    required this.index,
    required this.currentStep,
    required this.icon,
    required this.label,
    required this.pulse,
  });

  final int index;
  final int currentStep;
  final IconData icon;
  final String label;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final bool done = currentStep > index;
    final bool active = currentStep == index;
    final Color base = AppColors.primaryBlue;
    final Color muted = Colors.black.withValues(alpha: 0.32);
    final Color trackFill = Colors.black.withValues(alpha: 0.06);

    final Widget orb = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? base
            : active
                ? base.withValues(alpha: 0.14)
                : trackFill,
        border: active
            ? Border.all(color: base, width: 2.5)
            : null,
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(
                  color: base.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: done ? 20 : 18,
        color: done
            ? Colors.white
            : active
                ? base
                : muted,
      ),
    );

    final Widget core = active && currentStep != 3
        ? AnimatedBuilder(
            animation: pulse,
            builder: (BuildContext context, Widget? child) {
              final double s = 1.0 + pulse.value * 0.06;
              return Transform.scale(scale: s, child: child);
            },
            child: orb,
          )
        : orb;

    return SizedBox(
      width: 68,
      child: Column(
        children: <Widget>[
          core,
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: active || done ? FontWeight.w700 : FontWeight.w500,
                  color: active
                      ? base
                      : done
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                ),
          ),
        ],
      ),
    );
  }
}

class _AwaitingPaymentTrackerCard extends StatelessWidget {
  const _AwaitingPaymentTrackerCard({this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color warnColor = AppColors.warning;

    final Widget banner = Card(
      color: warnColor.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        side: BorderSide(color: warnColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.hourglass_top_rounded, color: warnColor, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'Payment not completed — this order has not been placed yet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: warnColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );

    if (embedded) {
      return banner;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Order status',
          style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        banner,
      ],
    );
  }
}

class _CancelledTrackerCard extends StatelessWidget {
  const _CancelledTrackerCard({this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color errorColor = theme.colorScheme.error;

    final Widget banner = Card(
      color: errorColor.withValues(alpha: 0.08),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        side: BorderSide(color: errorColor.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Icon(Icons.cancel_rounded, color: errorColor, size: 28),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Text(
                'This order was cancelled and will not be delivered.',
                style: theme.textTheme.bodyMedium?.copyWith(
                      color: errorColor,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );

    if (embedded) {
      return banner;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Order status',
          style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: AppSpacing.md),
        banner,
      ],
    );
  }
}
