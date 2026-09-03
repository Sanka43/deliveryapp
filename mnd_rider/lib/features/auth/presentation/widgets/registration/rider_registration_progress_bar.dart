import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Segmented step-progress bar for the registration wizard. Hand-rolled
/// (not `Stepper`) to match the app's flat, no-shadow visual language.
class RiderRegistrationProgressBar extends StatelessWidget {
  const RiderRegistrationProgressBar({
    super.key,
    required this.currentStep,
    required this.stepCount,
  });

  final int currentStep;
  final int stepCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(stepCount, (int i) {
        final bool done = i <= currentStep;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              right: i == stepCount - 1 ? 0 : AppSpacing.xs,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              height: 4,
              decoration: BoxDecoration(
                color: done
                    ? AppColors.primaryBlue
                    : AppColors.primaryBlue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        );
      }),
    );
  }
}
