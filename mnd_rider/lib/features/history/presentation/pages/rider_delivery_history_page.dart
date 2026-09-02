import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_empty_state.dart';
import 'package:mnd_rider/core/widgets/rider_skeleton.dart';
import 'package:mnd_rider/features/history/domain/rider_delivery_history_item.dart';
import 'package:mnd_rider/features/history/presentation/providers/rider_delivery_history_provider.dart';

class RiderDeliveryHistoryPage extends ConsumerWidget {
  const RiderDeliveryHistoryPage({super.key});

  static String _money(double v) => LkrFormat.moneyDecimal(v);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final List<RiderDeliveryHistoryItem> allItems =
        ref.watch(riderDeliveryHistoryProvider);
    final RiderHistoryFilter filter = ref.watch(riderHistoryFilterProvider);
    final List<RiderDeliveryHistoryItem> items = switch (filter) {
      RiderHistoryFilter.all => allItems,
      RiderHistoryFilter.delivery => allItems
          .where((RiderDeliveryHistoryItem i) =>
              i.kind == RiderHistoryKind.delivery)
          .toList(growable: false),
      RiderHistoryFilter.ride => allItems
          .where(
              (RiderDeliveryHistoryItem i) => i.kind == RiderHistoryKind.ride)
          .toList(growable: false),
    };
    final bool hasMore = ref.watch(riderDeliveryHistoryHasMoreProvider);
    final bool loadingMore = ref
            .watch(riderDeliveredHistoryPagedProvider)
            .isLoading ||
        ref.watch(riderCompletedTripsProvider).isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trip history'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: _HistoryFilterBar(
              selected: filter,
              onChanged: (RiderHistoryFilter f) =>
                  ref.read(riderHistoryFilterProvider.notifier).state = f,
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? (loadingMore
                    ? const RiderSkeletonList(count: 5)
                    : RiderEmptyState(
                        icon: switch (filter) {
                          RiderHistoryFilter.ride => Icons.two_wheeler_rounded,
                          RiderHistoryFilter.delivery =>
                            Icons.delivery_dining_rounded,
                          RiderHistoryFilter.all =>
                            Icons.local_shipping_outlined,
                        },
                        title: switch (filter) {
                          RiderHistoryFilter.ride => 'No rides yet',
                          RiderHistoryFilter.delivery => 'No deliveries yet',
                          RiderHistoryFilter.all => 'No deliveries or rides yet',
                        },
                        subtitle: 'Completed trips and rides will show up here.',
                      ))
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                    itemCount: items.length + (hasMore ? 1 : 0),
                    separatorBuilder: (BuildContext context, int index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (BuildContext context, int index) {
                      if (index >= items.length) {
                        return _LoadMoreRow(
                          loading: loadingMore,
                          onTap: loadingMore
                              ? null
                              : () => ref
                                  .read(riderHistoryPageMultiplierProvider
                                      .notifier)
                                  .state++,
                        );
                      }
                      return _HistoryCard(
                        item: items[index],
                        formatMoney: _money,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryFilterBar extends StatelessWidget {
  const _HistoryFilterBar({
    required this.selected,
    required this.onChanged,
  });

  final RiderHistoryFilter selected;
  final ValueChanged<RiderHistoryFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<RiderHistoryFilter>(
      style: SegmentedButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        textStyle: Theme.of(context).textTheme.labelMedium,
      ),
      segments: const <ButtonSegment<RiderHistoryFilter>>[
        ButtonSegment<RiderHistoryFilter>(
          value: RiderHistoryFilter.all,
          label: Text('All'),
        ),
        ButtonSegment<RiderHistoryFilter>(
          value: RiderHistoryFilter.delivery,
          label: Text('Delivery'),
          icon: Icon(Icons.delivery_dining_rounded, size: 15),
        ),
        ButtonSegment<RiderHistoryFilter>(
          value: RiderHistoryFilter.ride,
          label: Text('Rides'),
          icon: Icon(Icons.two_wheeler_rounded, size: 15),
        ),
      ],
      selected: <RiderHistoryFilter>{selected},
      showSelectedIcon: false,
      onSelectionChanged: (Set<RiderHistoryFilter> v) => onChanged(v.first),
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: loading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : TextButton(
                onPressed: onTap,
                child: const Text('Load more'),
              ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({
    required this.item,
    required this.formatMoney,
  });

  final RiderDeliveryHistoryItem item;
  final String Function(double) formatMoney;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color statusColor =
        item.completed ? AppColors.onlineGreen : cs.error;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _KindIcon(kind: item.kind),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.routeSummary,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.completedAtLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      item.completed
                          ? formatMoney(item.payout)
                          : formatMoney(0),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: item.completed
                            ? AppColors.primaryBlue
                            : theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.completed
                          ? (item.kind == RiderHistoryKind.ride
                              ? 'Ride · Completed'
                              : 'Delivery · Completed')
                          : (item.kind == RiderHistoryKind.ride
                              ? 'Ride · Cancelled'
                              : 'Delivery · Cancelled'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Divider(
              height: 1,
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.6),
            ),
            const SizedBox(height: 10),
            _MiniRow(
              icon: Icons.store_mall_directory_outlined,
              text: item.pickupLabel,
            ),
            const SizedBox(height: 6),
            _MiniRow(
              icon: Icons.location_on_outlined,
              text: item.dropoffLabel,
            ),
            const SizedBox(height: 8),
            Text(
              item.referenceForDisplay,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.2,
                fontFamily: 'monospace',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Round icon badge telling a passenger ride apart from a food delivery
/// at a glance, since both kinds share this list.
class _KindIcon extends StatelessWidget {
  const _KindIcon({required this.kind});

  final RiderHistoryKind kind;

  @override
  Widget build(BuildContext context) {
    final bool isRide = kind == RiderHistoryKind.ride;
    final Color tint = isRide ? AppColors.primaryBlue : AppColors.onlineGreen;
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Icon(
        isRide ? Icons.two_wheeler_rounded : Icons.delivery_dining_rounded,
        color: tint,
        size: 20,
      ),
    );
  }
}

class _MiniRow extends StatelessWidget {
  const _MiniRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 18, color: AppColors.offlineGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
