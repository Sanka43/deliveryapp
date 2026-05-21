import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/locale_provider.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/locale/app_language_option.dart';

class LanguageSelectorPage extends ConsumerWidget {
  const LanguageSelectorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Locale?> asyncLocale = ref.watch(appLocaleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Language'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: asyncLocale.when(
        data: (Locale? selected) {
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: AppLanguageOption.ordered.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
            itemBuilder: (BuildContext context, int index) {
              final AppLanguageOption opt = AppLanguageOption.ordered[index];
              final bool isOn = opt.isSystem
                  ? selected == null
                  : selected?.languageCode == opt.id;
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    try {
                      await ref.read(appLocaleProvider.notifier).setByOptionId(opt.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              opt.isSystem
                                  ? 'Using your device language.'
                                  : 'Language set to ${opt.title}.',
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Could not save: $e')),
                        );
                      }
                    }
                  },
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
                                opt.title,
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              if (opt.subtitle != null) ...<Widget>[
                                const SizedBox(height: 2),
                                Text(
                                  opt.subtitle!,
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
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, StackTrace _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load language.\n$e', textAlign: TextAlign.center),
          ),
        ),
      ),
    );
  }
}
