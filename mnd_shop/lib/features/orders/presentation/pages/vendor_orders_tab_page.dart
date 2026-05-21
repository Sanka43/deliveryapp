import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/incoming_orders/presentation/pages/incoming_vendor_order_page.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_orders_ui.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

/// Dedicated orders hub for the bottom navigation (incoming + pipeline snapshot).
class VendorOrdersTabPage extends ConsumerStatefulWidget {
  const VendorOrdersTabPage({super.key});

  @override
  ConsumerState<VendorOrdersTabPage> createState() => _VendorOrdersTabPageState();
}

class _VendorOrdersTabPageState extends ConsumerState<VendorOrdersTabPage> {
  VendorOrderPipelineFilter _filter = VendorOrderPipelineFilter.active;

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  static void _snack(BuildContext context, String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  static Future<void> _openIncomingDetail(
    BuildContext context,
    WidgetRef ref,
    VendorPendingOrder order,
  ) async {
    final VendorOrdersRepository repo = ref.read(vendorOrdersRepositoryProvider);
    final bool? accepted = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        fullscreenDialog: true,
        builder: (BuildContext ctx) => IncomingVendorOrderPage(order: order),
      ),
    );
    if (!context.mounted) {
      return;
    }
    if (accepted == true) {
      final String? err = await repo.updateOrderStatus(
        orderId: order.id,
        nextStatus: 'confirmed',
      );
      if (!context.mounted) {
        return;
      }
      if (err != null) {
        _snack(context, err, error: true);
      } else {
        _snack(context, 'Accepted · ${order.referenceForDisplay}');
      }
    } else if (accepted == false) {
      final String? err = await repo.rejectOrder(orderId: order.id);
      if (!context.mounted) {
        return;
      }
      if (err != null) {
        _snack(context, err, error: true);
      } else {
        _snack(context, 'Rejected · ${order.referenceForDisplay}');
      }
    }
  }

  void _selectFilter(VendorOrderPipelineFilter next) {
    if (_filter == next) {
      return;
    }
    HapticFeedback.selectionClick();
    setState(() => _filter = next);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VendorOrderBoard> board = ref.watch(vendorOrderBoardProvider);
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();

    final double topInset = MediaQuery.paddingOf(context).top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Material(
      color: VendorOrdersTheme.canvas(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.fromLTRB(
              kVendorScreenPadding,
              topInset + 12,
              kVendorScreenPadding,
              8,
            ),
            child: VendorPageHeader(
              title: 'Orders',
              titleColor: isDark ? cs.onSurface : null,
            ),
          ),
          board.maybeWhen(
            data: (VendorOrderBoard b) {
              if (storeId.isEmpty || b.activeCount == 0) {
                return const SizedBox.shrink();
              }
              return Padding(
                padding: const EdgeInsets.fromLTRB(
                  kVendorScreenPadding,
                  0,
                  kVendorScreenPadding,
                  8,
                ),
                child: VendorOrdersPipelineBar(
                  incomingCount: b.incoming.length,
                  kitchenCount: b.kitchen.length,
                  readyCount: b.readyForPickup.length,
                  activeCount: b.activeCount,
                  selectedFilter: _filter,
                  onFilterSelected: _selectFilter,
                ),
              );
            },
            orElse: () => const SizedBox.shrink(),
          ),
          Expanded(
            child: RefreshIndicator(
              edgeOffset: topInset + 72,
              color: AppColors.vendorHeroBlue,
              onRefresh: () async {
                ref.invalidate(vendorOrderBoardProvider);
                await Future<void>.delayed(const Duration(milliseconds: 450));
              },
              child: board.when(
                loading: () => const _OrdersScrollBody(
                  child: Center(
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2.8),
                  ),
                ),
                error: (Object e, StackTrace _) => _OrdersScrollBody(
                  child: _OrdersErrorPane(message: '$e'),
                ),
                data: (VendorOrderBoard b) {
                  if (storeId.isEmpty) {
                    return const _OrdersScrollBody(
                      child: _EmptyOrdersMessage(
                        icon: Icons.storefront_outlined,
                        title: 'Store not linked',
                        subtitle: 'Complete shop setup so orders can appear here.',
                      ),
                    );
                  }

                  if (b.activeCount == 0) {
                    return const _OrdersScrollBody(
                      child: _EmptyOrdersMessage(
                        icon: Icons.receipt_long_rounded,
                        title: 'No active orders',
                        subtitle: 'New orders show up here instantly when customers place them.',
                      ),
                    );
                  }

                  final bool showAll = _filter == VendorOrderPipelineFilter.active;
                  final bool showIncoming =
                      showAll || _filter == VendorOrderPipelineFilter.newOrders;
                  final bool showKitchen =
                      showAll || _filter == VendorOrderPipelineFilter.kitchen;
                  final bool showReady =
                      showAll || _filter == VendorOrderPipelineFilter.ready;

                  int cardIndex = 0;
                  final List<Widget> listChildren = <Widget>[];

                  if (showIncoming && b.incoming.isNotEmpty) {
                  listChildren.addAll(<Widget>[
                    const SizedBox(height: 22),
                    VendorOrdersSectionHeader(
                      icon: Icons.notifications_active_rounded,
                      label: 'Needs attention',
                      count: b.incoming.length,
                      accent: VendorOrdersStageColors.newOrders,
                    ),
                    const SizedBox(height: 12),
                    ...b.incoming.map(
                      (VendorPendingOrder o) {
                        final int i = cardIndex++;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VendorOrdersFadeIn(
                            index: i,
                            child: VendorOrderListCard(
                              order: o,
                              stage: VendorOrderCardStage.urgent,
                              amountLabel: _money(o.total),
                              onOpen: () => _openIncomingDetail(context, ref, o),
                              onPrimary: () async {
                                final String? err = await ref
                                    .read(vendorOrdersRepositoryProvider)
                                    .updateOrderStatus(
                                      orderId: o.id,
                                      nextStatus: 'confirmed',
                                    );
                                if (context.mounted) {
                                  if (err != null) {
                                    _snack(context, err, error: true);
                                  } else {
                                    _snack(context, 'Accepted · ${o.referenceForDisplay}');
                                  }
                                }
                              },
                              primaryLabel: 'Accept',
                              onSecondary: () async {
                                final String? err = await ref
                                    .read(vendorOrdersRepositoryProvider)
                                    .rejectOrder(orderId: o.id);
                                if (context.mounted) {
                                  if (err != null) {
                                    _snack(context, err, error: true);
                                  } else {
                                    _snack(context, 'Rejected · ${o.referenceForDisplay}');
                                  }
                                }
                              },
                              secondaryLabel: 'Decline',
                            ),
                          ),
                        );
                      },
                    ),
                  ]);
                }

                if (showKitchen && b.kitchen.isNotEmpty) {
                  listChildren.addAll(<Widget>[
                    const SizedBox(height: 22),
                    VendorOrdersSectionHeader(
                      icon: Icons.restaurant_rounded,
                      label: 'In kitchen',
                      count: b.kitchen.length,
                      accent: VendorOrdersStageColors.kitchen,
                    ),
                    const SizedBox(height: 12),
                    ...b.kitchen.map(
                      (VendorPendingOrder o) {
                        final int i = cardIndex++;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VendorOrdersFadeIn(
                            index: i,
                            child: VendorOrderListCard(
                              order: o,
                              stage: VendorOrderCardStage.progress,
                              amountLabel: _money(o.total),
                              onOpen: () => _openIncomingDetail(context, ref, o),
                              onPrimary: () async {
                                final String? err = await ref
                                    .read(vendorOrdersRepositoryProvider)
                                    .updateOrderStatus(
                                      orderId: o.id,
                                      nextStatus: 'ready',
                                    );
                                if (context.mounted && err != null) {
                                  _snack(context, err, error: true);
                                }
                              },
                              primaryLabel: 'Mark ready',
                              onSecondary: null,
                              secondaryLabel: null,
                            ),
                          ),
                        );
                      },
                    ),
                  ]);
                }

                if (showReady && b.readyForPickup.isNotEmpty) {
                  listChildren.addAll(<Widget>[
                    const SizedBox(height: 22),
                    VendorOrdersSectionHeader(
                      icon: Icons.takeout_dining_rounded,
                      label: 'Ready for pickup',
                      count: b.readyForPickup.length,
                      accent: VendorOrdersStageColors.ready,
                    ),
                    const SizedBox(height: 12),
                    ...b.readyForPickup.map(
                      (VendorPendingOrder o) {
                        final int i = cardIndex++;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VendorOrdersFadeIn(
                            index: i,
                            child: VendorOrderListCard(
                              order: o,
                              stage: VendorOrderCardStage.ready,
                              amountLabel: _money(o.total),
                              onOpen: () => _openIncomingDetail(context, ref, o),
                              onPrimary: () async {
                                final String? err = await ref
                                    .read(vendorOrdersRepositoryProvider)
                                    .updateOrderStatus(
                                      orderId: o.id,
                                      nextStatus: 'completed',
                                    );
                                if (context.mounted && err != null) {
                                  _snack(context, err, error: true);
                                }
                              },
                              primaryLabel: 'Complete',
                              onSecondary: null,
                              secondaryLabel: null,
                            ),
                          ),
                        );
                      },
                    ),
                  ]);
                }

                if (_filterEmptyForBoard(b)) {
                  listChildren.addAll(<Widget>[
                    const SizedBox(height: 28),
                    _EmptyOrdersMessage(
                      icon: _filterEmptyIcon(_filter),
                      title: _filterEmptyTitle(_filter),
                      subtitle: _filterEmptySubtitle(_filter),
                    ),
                  ]);
                }

                  return _OrdersScrollBody(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      switchInCurve: Curves.easeOutCubic,
                      switchOutCurve: Curves.easeInCubic,
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        final Animation<double> fade = CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOut,
                        );
                        return FadeTransition(
                          opacity: fade,
                          child: SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(0, 0.018),
                              end: Offset.zero,
                            ).animate(fade),
                            child: child,
                          ),
                        );
                      },
                      child: KeyedSubtree(
                        key: ValueKey<VendorOrderPipelineFilter>(_filter),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: listChildren,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _filterEmptyForBoard(VendorOrderBoard b) {
    return switch (_filter) {
      VendorOrderPipelineFilter.newOrders => b.incoming.isEmpty,
      VendorOrderPipelineFilter.kitchen => b.kitchen.isEmpty,
      VendorOrderPipelineFilter.ready => b.readyForPickup.isEmpty,
      VendorOrderPipelineFilter.active => false,
    };
  }

  static IconData _filterEmptyIcon(VendorOrderPipelineFilter filter) {
    return switch (filter) {
      VendorOrderPipelineFilter.newOrders => Icons.notifications_none_rounded,
      VendorOrderPipelineFilter.kitchen => Icons.restaurant_outlined,
      VendorOrderPipelineFilter.ready => Icons.takeout_dining_outlined,
      VendorOrderPipelineFilter.active => Icons.receipt_long_rounded,
    };
  }

  static String _filterEmptyTitle(VendorOrderPipelineFilter filter) {
    return switch (filter) {
      VendorOrderPipelineFilter.newOrders => 'No new orders',
      VendorOrderPipelineFilter.kitchen => 'Nothing in kitchen',
      VendorOrderPipelineFilter.ready => 'Nothing ready yet',
      VendorOrderPipelineFilter.active => 'No active orders',
    };
  }

  static String _filterEmptySubtitle(VendorOrderPipelineFilter filter) {
    return switch (filter) {
      VendorOrderPipelineFilter.newOrders =>
        'Incoming orders will appear here when customers place them.',
      VendorOrderPipelineFilter.kitchen =>
        'Accepted orders move here while you prep.',
      VendorOrderPipelineFilter.ready =>
        'Mark kitchen orders ready and they will show here.',
      VendorOrderPipelineFilter.active =>
        'New orders show up here instantly when customers place them.',
    };
  }
}

/// Scrollable order list area — header and pipeline bar stay fixed above.
class _OrdersScrollBody extends StatelessWidget {
  const _OrdersScrollBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        kVendorScreenPadding,
        4,
        kVendorScreenPadding,
        120,
      ),
      children: <Widget>[child],
    );
  }
}

class _OrdersErrorPane extends StatelessWidget {
  const _OrdersErrorPane({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.all(kVendorScreenPadding),
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: cs.errorContainer.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(kVendorCardRadius),
            border: Border.all(color: cs.error.withValues(alpha: 0.25)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(Icons.cloud_off_outlined, color: cs.error, size: 36),
                const SizedBox(height: 12),
                VendorSectionTitle(
                  'Could not load orders',
                  color: VendorOrdersTheme.isDark(context)
                      ? theme.colorScheme.onSurface
                      : null,
                ),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: VendorOrdersTheme.mutedText(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyOrdersMessage extends StatelessWidget {
  const _EmptyOrdersMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isDark = VendorOrdersTheme.isDark(context);
    final Color accent = isDark ? const Color(0xFF8B7EFF) : AppColors.vendorHeroBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kVendorCardRadius),
              color: accent.withValues(alpha: isDark ? 0.16 : 0.1),
              border: Border.all(color: accent.withValues(alpha: isDark ? 0.35 : 0.2)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Icon(icon, size: 48, color: accent.withValues(alpha: 0.95)),
            ),
          ),
          const SizedBox(height: 22),
          VendorSectionTitle(
            title,
            color: isDark ? theme.colorScheme.onSurface : null,
          ),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: VendorOrdersTheme.mutedText(context),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

