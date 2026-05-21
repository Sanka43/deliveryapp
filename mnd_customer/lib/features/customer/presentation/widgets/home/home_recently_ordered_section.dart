import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_section_entrance.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_pressable.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/customer_order_summary.dart';
import 'package:mnd_delivery_app/features/orders/presentation/providers/customer_orders_provider.dart';
import 'package:mnd_delivery_app/features/orders/presentation/utils/reorder_helper.dart';

class HomeRecentlyOrderedSection extends ConsumerWidget {
  const HomeRecentlyOrderedSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final User? user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return const SizedBox.shrink();
    }

    final AsyncValue<List<CustomerOrderSummary>> ordersAsync =
        ref.watch(customerOrdersStreamProvider);
    final List<SearchStore> stores =
        ref.watch(storesStreamProvider).asData?.value ?? const <SearchStore>[];

    return ordersAsync.maybeWhen(
      data: (List<CustomerOrderSummary> orders) {
        final List<CustomerOrderSummary> recent = orders
            .where(
              (CustomerOrderSummary o) =>
                  o.statusRaw.toLowerCase() == 'delivered',
            )
            .take(5)
            .toList();

        if (recent.isEmpty) {
          return const SizedBox.shrink();
        }

        return HomeSectionEntrance(
          delay: const Duration(milliseconds: 300),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                height: 150,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: recent.length,
                  separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.sm),
                  itemBuilder: (BuildContext context, int index) {
                    final CustomerOrderSummary order = recent[index];
                    final SearchStore? store = _matchStore(stores, order.storeName);

                    return _RecentOrderCard(
                      order: order,
                      store: store,
                      onReorder: () => reorderFromOrderId(context, ref, order.id),
                      onOpenStore: store != null
                          ? () => openStoreDetails(context, store)
                          : null,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  SearchStore? _matchStore(List<SearchStore> stores, String storeName) {
    final String key = storeName.toLowerCase().trim();
    for (final SearchStore s in stores) {
      if (s.name.toLowerCase().trim() == key) {
        return s;
      }
    }
    return null;
  }
}

class _RecentOrderCard extends StatelessWidget {
  const _RecentOrderCard({
    required this.order,
    required this.onReorder,
    this.store,
    this.onOpenStore,
  });

  final CustomerOrderSummary order;
  final SearchStore? store;
  final VoidCallback onReorder;
  final VoidCallback? onOpenStore;

  @override
  Widget build(BuildContext context) {
    return MndPressable(
      onTap: onOpenStore,
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: AppColors.surfaceElevated,
          borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
          boxShadow: AppColors.shadowElevated,
        ),
        child: Row(
          children: <Widget>[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 56,
                height: 56,
                child: store != null
                    ? MndNetworkImage(
                        imageUrl: store!.imageUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                      )
                    : _placeholder(order.storeName),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Text(
                    order.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'LKR ${order.totalLkr}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 32,
                    child: FilledButton(
                      onPressed: onReorder,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('Reorder'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(String name) {
    final String initial =
        name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : 'M';
    return ColoredBox(
      color: AppColors.brandPrimary.withValues(alpha: 0.12),
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            color: AppColors.brandPrimary,
          ),
        ),
      ),
    );
  }
}
