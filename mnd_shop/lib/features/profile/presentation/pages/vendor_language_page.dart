import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/locale_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/app_language_option.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';

class VendorLanguagePage extends ConsumerWidget {
  const VendorLanguagePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Locale?> asyncLocale = ref.watch(appLocaleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Language')),
      body: asyncLocale.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Text(
            'Could not load language.\n${userFacingError(e, fallback: 'Please try again.')}',
          ),
        ),
        data: (Locale? selected) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: AppLanguageOption.ordered.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
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
                          SnackBar(
                            content: Text(
                              userFacingError(
                                e,
                                fallback: 'Could not save. Please try again.',
                              ),
                            ),
                          ),
                        );
                      }
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOn
                            ? AppColors.primaryBlue.withValues(alpha: 0.65)
                            : Theme.of(context).colorScheme.outlineVariant,
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
                        const SizedBox(width: 14),
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
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
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
      ),
    );
  }
}
