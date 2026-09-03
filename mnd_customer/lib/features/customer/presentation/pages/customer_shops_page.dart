import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/mnd_shop_card.dart';

class CustomerShopsPage extends ConsumerWidget {
  const CustomerShopsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchStore>> async = ref.watch(storesStreamProvider);
    final double bottomClearance =
        MediaQuery.paddingOf(context).bottom + AppSpacing.lg;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'All Shops'),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(catalogLoadErrorMessage(error)),
          ),
        ),
        data: (List<SearchStore> stores) {
          if (stores.isEmpty) {
            return Center(
              child: Text(
                'No shops available yet.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            );
          }

          final List<SearchStore> sorted = List<SearchStore>.from(stores)
            ..sort(
              (SearchStore a, SearchStore b) =>
                  b.rating.compareTo(a.rating),
            );

          return ListView.separated(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.xs,
              AppSpacing.md,
              bottomClearance,
            ),
            itemCount: sorted.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final SearchStore store = sorted[index];
              return MndShopCardCompact(
                store: store,
                onTap: () => openStoreDetails(context, store),
              );
            },
          );
        },
      ),
    );
  }
}
