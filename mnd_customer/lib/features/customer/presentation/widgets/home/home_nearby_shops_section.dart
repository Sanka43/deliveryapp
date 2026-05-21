import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/mnd_shop_card.dart';

class HomeNearbyShopsSection extends ConsumerWidget {
  const HomeNearbyShopsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SearchStore>> async = ref.watch(storesStreamProvider);

    return HomeSectionEntrance(
      delay: const Duration(milliseconds: 200),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (Object error, _) => Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(catalogLoadErrorMessage(error)),
            ),
            data: (List<SearchStore> stores) {
              if (stores.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(AppSpacing.md),
                  child: Text('No active shops nearby yet.'),
                );
              }
              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: stores.length,
                separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                itemBuilder: (BuildContext context, int index) {
                  final SearchStore store = stores[index];
                  return MndShopCard(
                    store: store,
                    onTap: () => openStoreDetails(context, store),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
