import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
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
    default:
      return Icons.circle_outlined;
  }
}

/// Horizontal four-step tracker with animated connectors and a pulsing current step.
class AnimatedOrderStatusTracker extends StatefulWidget {
  const AnimatedOrderStatusTracker({
    super.key,
    required this.statusRaw,
  });

  final String statusRaw;

  @override
  State<AnimatedOrderStatusTracker> createState() => _AnimatedOrderStatusTrackerState();
}

class _AnimatedOrderStatusTrackerState extends State<AnimatedOrderStatusTracker>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  int _activeStep = 0;
  bool _wasCancelled = false;

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
    if (oldWidget.statusRaw != widget.statusRaw) {
      setState(_syncFromStatus);
    }
  }

  void _syncFromStatus() {
    _wasCancelled = OrderTimelineLogic.isCancelled(widget.statusRaw);
    if (!_wasCancelled) {
      _activeStep = OrderTimelineLogic.currentDeliveryTrackerIndex(widget.statusRaw);
    }
    if (_activeStep < 3 && !_wasCancelled) {
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
      return _CancelledTrackerCard();
    }

    final ThemeData theme = Theme.of(context);
    const List<DeliveryTrackerStepDefinition> steps = OrderTimelineLogic.deliveryTrackerSteps;
    final int current = _activeStep.clamp(0, 3);

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
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
            ),
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    for (int i = 0; i < 4; i++) ...<Widget>[
                      if (i > 0) _ConnectorRow(leadingIndex: i - 1, currentStep: current),
                      _StepOrb(
                        index: i,
                        currentStep: current,
                        icon: _iconForDeliveryKey(steps[i].iconKey),
                        pulse: _pulseController,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: AppSpacing.lg),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 350),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  child: Column(
                    key: ValueKey<String>(widget.statusRaw),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        steps[current].title,
                        style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppColors.primaryBlue,
                            ),
                      ),
                      const SizedBox(height: 4),
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
        padding: const EdgeInsets.only(bottom: 20),
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
                        color: Colors.black.withValues(alpha: 0.12),
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
    required this.pulse,
  });

  final int index;
  final int currentStep;
  final IconData icon;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    final bool done = currentStep > index;
    final bool active = currentStep == index;
    final Color base = AppColors.primaryBlue;
    final Color muted = Colors.black.withValues(alpha: 0.28);

    final Widget core = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done || active
            ? base.withValues(alpha: 0.15)
            : Colors.transparent,
        border: Border.all(
          color: done || active ? base : muted,
          width: active ? 2.5 : 2,
        ),
        boxShadow: active
            ? <BoxShadow>[
                BoxShadow(
                  color: base.withValues(alpha: 0.35),
                  blurRadius: 8,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: Icon(
        done ? Icons.check_rounded : icon,
        size: done ? 20 : 19,
        color: done || active ? base : muted,
      ),
    );

    if (!active || currentStep == 3) {
      return core;
    }

    return AnimatedBuilder(
      animation: pulse,
      builder: (BuildContext context, Widget? child) {
        final double s = 1.0 + pulse.value * 0.06;
        return Transform.scale(scale: s, child: child);
      },
      child: core,
    );
  }
}

class _CancelledTrackerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color errorColor = theme.colorScheme.error;

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
        Card(
          color: errorColor.withValues(alpha: 0.08),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
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
        ),
      ],
    );
  }
}
