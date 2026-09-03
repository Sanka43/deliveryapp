import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/services/pwa_install_service.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';

/// Compact "Add to Home Screen" prompt — shown only in browser (not standalone).
class AddToHomeScreenBanner extends StatefulWidget {
  const AddToHomeScreenBanner({super.key});

  @override
  State<AddToHomeScreenBanner> createState() => _AddToHomeScreenBannerState();
}

class _AddToHomeScreenBannerState extends State<AddToHomeScreenBanner> {
  bool _visible = false;
  bool _checking = true;

  @override
  void initState() {
    super.initState();
    _resolveVisibility();
  }

  Future<void> _resolveVisibility() async {
    final bool show = await shouldShowA2hsBanner();
    if (!mounted) {
      return;
    }
    setState(() {
      _visible = show;
      _checking = false;
    });
  }

  Future<void> _dismiss() async {
    setState(() => _visible = false);
    await dismissA2hsBanner();
  }

  Future<void> _onAdd() async {
    if (canPromptPwaInstall()) {
      final bool accepted = await promptPwaInstall();
      if (!mounted) {
        return;
      }
      if (accepted) {
        await _dismiss();
      }
      return;
    }
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) => const _A2hsInstructionsSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checking || !_visible) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          decoration: BoxDecoration(
            color: AppColors.surfaceElevated,
            borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
            border: Border.all(
              color: AppColors.brandPrimary.withValues(alpha: 0.14),
            ),
            boxShadow: AppColors.cardShadow,
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.add_to_home_screen_rounded,
                  color: AppColors.brandPrimary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Add to Home Screen',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w700,
                            height: 1.2,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Open MND faster, like an app.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                    ),                  ],
                ),
              ),
              const SizedBox(width: 8),
              MndPressable(
                onTap: _onAdd,
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColors.brandGradient,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Add',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                  ),                ),
              ),
              IconButton(
                onPressed: _dismiss,
                tooltip: 'Dismiss',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: AppColors.textSecondary.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _A2hsInstructionsSheet extends StatelessWidget {
  const _A2hsInstructionsSheet();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: AppColors.surfaceElevated,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        boxShadow: AppColors.shadowElevated,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.homeMutedFill,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Add MND to your Home Screen',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Install from your browser menu so you can open MND in one tap.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.4,
                  fontWeight: FontWeight.w500,
                ),
          ),          const SizedBox(height: 20),
          const _InstructionStep(
            number: '1',
            title: 'Open the Share menu',
            detail: 'Tap the Share icon in Safari (or your browser menu).',
          ),
          const SizedBox(height: 12),
          const _InstructionStep(
            number: '2',
            title: 'Choose Add to Home Screen',
            detail: 'Scroll the share sheet and select Add to Home Screen.',
          ),
          const SizedBox(height: 12),
          const _InstructionStep(
            number: '3',
            title: 'Confirm',
            detail: 'Tap Add. MND will appear on your home screen.',
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
              ),
              child: Text(
                'Got it',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),            ),
          ),
        ],
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.number,
    required this.title,
    required this.detail,
  });

  final String number;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.brandPrimary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Text(
            number,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.brandPrimary,
                  fontWeight: FontWeight.w800,
                ),
          ),        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                title,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                detail,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
              ),            ],
          ),
        ),
      ],
    );
  }
}
