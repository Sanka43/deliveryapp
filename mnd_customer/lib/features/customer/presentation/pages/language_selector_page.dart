import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/locale/app_language_option.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';

class LanguageSelectorPage extends ConsumerWidget {
  const LanguageSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Locale?> asyncLocale = ref.watch(appLocaleProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'Language'),
      body: asyncLocale.when(
        data: (Locale? selected) {
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.md),
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.primaryBlue.withValues(alpha: 0.22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline_rounded,
                        color: AppColors.primaryBlue,
                        size: 22,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          'Most of the app UI is still in English. '
                          'Sinhala and Tamil currently affect system/date formatting only.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.black87,
                                height: 1.35,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              for (int index = 0;
                  index < AppLanguageOption.ordered.length;
                  index++) ...<Widget>[
                if (index > 0) const SizedBox(height: AppSpacing.xs),
                _LanguageTile(
                  option: AppLanguageOption.ordered[index],
                  selected: selected,
                  onSelect: (String id) async {
                    try {
                      await ref
                          .read(appLocaleProvider.notifier)
                          .setByOptionId(id);
                      if (context.mounted) {
                        final AppLanguageOption opt =
                            AppLanguageOption.ordered[index];
                        showMndSnackBar(context, opt.isSystem
                              ? 'Using your device language.'
                              : 'Language set to ${opt.title}.', variant: MndSnackBarVariant.success);
                      }
                    } catch (e) {
                      if (context.mounted) {
                        showMndSnackBar(
                          context,
                          userFacingError(
                            e,
                            fallback: 'Could not save language. Please try again.',
                          ),
                          variant: MndSnackBarVariant.error,
                        );
                      }
                    }
                  },
                ),
              ],
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              userFacingError(
                e,
                fallback: 'Could not load language. Please try again.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.option,
    required this.selected,
    required this.onSelect,
  });

  final AppLanguageOption option;
  final Locale? selected;
  final Future<void> Function(String id) onSelect;

  @override
  Widget build(BuildContext context) {
    final bool isOn = option.isSystem
        ? selected == null
        : selected?.languageCode == option.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => onSelect(option.id),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm + 4,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isOn
                  ? AppColors.primaryBlue.withValues(alpha: 0.65)
                  : Colors.black.withValues(alpha: 0.08),
              width: isOn ? 2 : 1,
            ),
            color: isOn
                ? AppColors.primaryBlue.withValues(alpha: 0.06)
                : Colors.transparent,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                isOn
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_off_rounded,
                color: isOn ? AppColors.primaryBlue : Colors.black38,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      option.title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    if (option.subtitle != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        option.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Colors.black54,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (isOn)
                Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue),
            ],
          ),
        ),
      ),
    );
  }
}
