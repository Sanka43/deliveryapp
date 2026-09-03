import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/create_order/presentation/pages/vendor_create_order_page.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_pill_bottom_nav.dart';
import 'package:mnd_shop/features/incoming_orders/presentation/pages/incoming_vendor_order_page.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/pages/vendor_order_history_page.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_orders_ui.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

/// Dedicated orders hub for the bottom navigation (incoming + pipeline snapshot).
class VendorOrdersTabPage extends ConsumerStatefulWidget {
  const VendorOrdersTabPage({super.key});

  @override
  ConsumerState<VendorOrdersTabPage> createState() =>
      _VendorOrdersTabPageState();
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
    final VendorOrdersRepository repo = ref.read(
      vendorOrdersRepositoryProvider,
    );
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
        _snack(
          context,
          '${_vTxt(context, en: 'Accepted', si: 'පිළිගත්තා')} · ${order.referenceForDisplay}',
        );
      }
    } else if (accepted == false) {
      final String? err = await repo.rejectOrder(orderId: order.id);
      if (!context.mounted) {
        return;
      }
      if (err != null) {
        _snack(context, err, error: true);
      } else {
        _snack(
          context,
          '${_vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප කළා')} · ${order.referenceForDisplay}',
        );
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

  void _openHistory() {
    HapticFeedback.selectionClick();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const VendorOrderHistoryPage(),
      ),
    );
  }

  Future<void> _openCreateOrder() async {
    HapticFeedback.selectionClick();
    final bool? created = await VendorCreateOrderPage.open(context);
    if (created == true && mounted) {
      ref.invalidate(vendorOrderBoardProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<VendorOrderBoard> board = ref.watch(
      vendorOrderBoardProvider,
    );
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final bool isGrocery = ref.watch(isGroceryShopProvider);

    final double topInset = MediaQuery.paddingOf(context).top;
    final double gutter = vendorResponsiveHorizontalPadding(context);
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: VendorOrdersTheme.canvas(context),
      body: VendorResponsiveContent(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(gutter, topInset + 12, gutter, 8),
              child: VendorPageHeader(
                title: _vTxt(context, en: 'Orders', si: 'ඇණවුම්'),
                titleColor: isDark ? cs.onSurface : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton.filledTonal(
                      tooltip: _vTxt(
                        context,
                        en: 'Order history',
                        si: 'Order history',
                      ),
                      onPressed: _openHistory,
                      icon: const Icon(Icons.history_rounded),
                    ),
                    if (storeId.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 8),
                      _CreateOrderActionButton(
                        compact: true,
                        onPressed: _openCreateOrder,
                        tooltip: _vTxt(
                          context,
                          en: 'New order',
                          si: 'නව ඇණවුම',
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            board.maybeWhen(
              data: (VendorOrderBoard b) {
                if (storeId.isEmpty || b.activeCount == 0) {
                  return const SizedBox.shrink();
                }
                return Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 8),
                  child: VendorOrdersPipelineBar(
                    incomingCount: b.incoming.length,
                    kitchenCount: b.kitchen.length,
                    readyCount: b.readyForPickup.length,
                    activeCount: b.activeCount,
                    selectedFilter: _filter,
                    onFilterSelected: _selectFilter,
                    kitchenLabel: isGrocery ? 'Preparing' : 'Kitchen',
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
                      child: CircularProgressIndicator.adaptive(
                        strokeWidth: 2.8,
                      ),
                    ),
                  ),
                  error: (Object e, StackTrace _) =>
                      _OrdersScrollBody(
                        child: _OrdersErrorPane(
                          message: userFacingError(
                            e,
                            fallback:
                                'Please check your connection and try again.',
                          ),
                        ),
                      ),
                  data: (VendorOrderBoard b) {
                    if (storeId.isEmpty) {
                      return _OrdersScrollBody(
                        child: _EmptyOrdersMessage(
                          icon: Icons.storefront_outlined,
                          title: _vTxt(
                            context,
                            en: 'Store not linked',
                            si: 'Store එක සම්බන්ධ කර නැත',
                          ),
                          subtitle: _vTxt(
                            context,
                            en: 'Complete shop setup so orders can appear here.',
                            si: 'ඇණවුම් පෙන්වීමට shop setup එක සම්පූර්ණ කරන්න.',
                          ),
                        ),
                      );
                    }

                    if (b.activeCount == 0) {
                      return _OrdersScrollBody(
                        child: _EmptyOrdersMessage(
                          icon: Icons.receipt_long_rounded,
                          title: _vTxt(
                            context,
                            en: 'No active orders',
                            si: 'සක්‍රීය ඇණවුම් නැත',
                          ),
                          subtitle: _vTxt(
                            context,
                            en:
                                'Create a phone order or wait for customers to place one.',
                            si:
                                'Phone order එකක් සාදන්න හෝ පාරිභෝගික ඇණවුම් එනතුරු රැඳෙන්න.',
                          ),
                        ),
                      );
                    }

                    final bool showAll =
                        _filter == VendorOrderPipelineFilter.active;
                    final bool showIncoming =
                        showAll ||
                        _filter == VendorOrderPipelineFilter.newOrders;
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
                          label: _vTxt(
                            context,
                            en: 'Needs attention',
                            si: 'අවධානය අවශ්‍යයි',
                          ),
                          count: b.incoming.length,
                          accent: VendorOrdersStageColors.newOrders,
                        ),
                        const SizedBox(height: 12),
                        ...b.incoming.map((VendorPendingOrder o) {
                          final int i = cardIndex++;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VendorOrdersFadeIn(
                              index: i,
                              child: VendorOrderListCard(
                                order: o,
                                stage: VendorOrderCardStage.urgent,
                                amountLabel: _money(o.shopTotal),
                                onOpen: () =>
                                    _openIncomingDetail(context, ref, o),
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
                                      _snack(
                                        context,
                                        '${_vTxt(context, en: 'Accepted', si: 'පිළිගත්තා')} · ${o.referenceForDisplay}',
                                      );
                                    }
                                  }
                                },
                                primaryLabel: _vTxt(
                                  context,
                                  en: 'Accept',
                                  si: 'පිළිගන්න',
                                ),
                                onSecondary: () async {
                                  final String? err = await ref
                                      .read(vendorOrdersRepositoryProvider)
                                      .rejectOrder(orderId: o.id);
                                  if (context.mounted) {
                                    if (err != null) {
                                      _snack(context, err, error: true);
                                    } else {
                                      _snack(
                                        context,
                                        '${_vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප කළා')} · ${o.referenceForDisplay}',
                                      );
                                    }
                                  }
                                },
                                secondaryLabel: _vTxt(
                                  context,
                                  en: 'Decline',
                                  si: 'ප්‍රතික්ෂේප කරන්න',
                                ),
                              ),
                            ),
                          );
                        }),
                      ]);
                    }

                    if (showKitchen && b.kitchen.isNotEmpty) {
                      listChildren.addAll(<Widget>[
                        const SizedBox(height: 22),
                        VendorOrdersSectionHeader(
                          icon: isGrocery
                              ? Icons.inventory_2_rounded
                              : Icons.restaurant_rounded,
                          label: _vTxt(
                            context,
                            en: isGrocery ? 'Preparing' : 'In kitchen',
                            si: isGrocery ? 'සකස් කරමින්' : 'මුළුතැන්ගෙයි',
                          ),
                          count: b.kitchen.length,
                          accent: VendorOrdersStageColors.kitchen,
                        ),
                        const SizedBox(height: 12),
                        ...b.kitchen.map((VendorPendingOrder o) {
                          final int i = cardIndex++;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VendorOrdersFadeIn(
                              index: i,
                              child: VendorOrderListCard(
                                order: o,
                                stage: VendorOrderCardStage.progress,
                                amountLabel: _money(o.shopTotal),
                                onOpen: () {},
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
                                primaryLabel: _vTxt(
                                  context,
                                  en: 'Mark ready',
                                  si: 'සූදානම් ලෙස සලකුණු කරන්න',
                                ),
                                onSecondary: null,
                                secondaryLabel: null,
                              ),
                            ),
                          );
                        }),
                      ]);
                    }

                    if (showReady && b.readyForPickup.isNotEmpty) {
                      listChildren.addAll(<Widget>[
                        const SizedBox(height: 22),
                        VendorOrdersSectionHeader(
                          icon: Icons.takeout_dining_rounded,
                          label: _vTxt(
                            context,
                            en: 'Ready for pickup',
                            si: 'රැගෙන යාමට සූදානම්',
                          ),
                          count: b.readyForPickup.length,
                          accent: VendorOrdersStageColors.ready,
                        ),
                        const SizedBox(height: 12),
                        ...b.readyForPickup.map((VendorPendingOrder o) {
                          final int i = cardIndex++;
                          final bool canComplete = o.isSelfPickup;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VendorOrdersFadeIn(
                              index: i,
                              child: VendorOrderListCard(
                                order: o,
                                stage: VendorOrderCardStage.ready,
                                amountLabel: _money(o.shopTotal),
                                onOpen: () {},
                                onPrimary: canComplete
                                    ? () async {
                                        final String? err = await ref
                                            .read(vendorOrdersRepositoryProvider)
                                            .updateOrderStatus(
                                              orderId: o.id,
                                              nextStatus: 'completed',
                                            );
                                        if (context.mounted && err != null) {
                                          _snack(context, err, error: true);
                                        }
                                      }
                                    : null,
                                primaryLabel: canComplete
                                    ? _vTxt(
                                        context,
                                        en: 'Mark collected',
                                        si: 'රැගෙන ගිය ලෙස සලකුණු කරන්න',
                                      )
                                    : '',
                                onSecondary: null,
                                secondaryLabel: null,
                              ),
                            ),
                          );
                        }),
                      ]);
                    }

                    if (showAll && b.outForDelivery.isNotEmpty) {
                      listChildren.addAll(<Widget>[
                        const SizedBox(height: 22),
                        VendorOrdersSectionHeader(
                          icon: Icons.delivery_dining_rounded,
                          label: _vTxt(
                            context,
                            en: 'With rider',
                            si: 'Rider සමඟ',
                          ),
                          count: b.outForDelivery.length,
                          accent: VendorOrdersStageColors.kitchen,
                        ),
                        const SizedBox(height: 12),
                        ...b.outForDelivery.map((VendorPendingOrder o) {
                          final int i = cardIndex++;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: VendorOrdersFadeIn(
                              index: i,
                              child: VendorOrderListCard(
                                order: o,
                                stage: VendorOrderCardStage.progress,
                                amountLabel: _money(o.shopTotal),
                                onOpen: () =>
                                    _openIncomingDetail(context, ref, o),
                                onPrimary: null,
                                primaryLabel: '',
                                onSecondary: null,
                                secondaryLabel: null,
                              ),
                            ),
                          );
                        }),
                      ]);
                    }

                    if (_filterEmptyForBoard(b)) {
                      listChildren.addAll(<Widget>[
                        const SizedBox(height: 28),
                        _EmptyOrdersMessage(
                          icon: _filterEmptyIcon(_filter, isGrocery: isGrocery),
                          title: _filterEmptyTitle(
                            context,
                            _filter,
                            isGrocery: isGrocery,
                          ),
                          subtitle: _filterEmptySubtitle(
                            context,
                            _filter,
                            isGrocery: isGrocery,
                          ),
                        ),
                      ]);
                    }

                    return _OrdersScrollBody(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 280),
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder:
                            (Widget child, Animation<double> animation) {
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

  static IconData _filterEmptyIcon(
    VendorOrderPipelineFilter filter, {
    bool isGrocery = false,
  }) {
    return switch (filter) {
      VendorOrderPipelineFilter.newOrders => Icons.notifications_none_rounded,
      VendorOrderPipelineFilter.kitchen =>
        isGrocery ? Icons.inventory_2_outlined : Icons.restaurant_outlined,
      VendorOrderPipelineFilter.ready => Icons.takeout_dining_outlined,
      VendorOrderPipelineFilter.active => Icons.receipt_long_rounded,
    };
  }

  static String _filterEmptyTitle(
    BuildContext context,
    VendorOrderPipelineFilter filter, {
    bool isGrocery = false,
  }) {
    return switch (filter) {
      VendorOrderPipelineFilter.newOrders => _vTxt(
        context,
        en: 'No new orders',
        si: 'නව ඇණවුම් නැත',
      ),
      VendorOrderPipelineFilter.kitchen => _vTxt(
        context,
        en: isGrocery ? 'Nothing preparing' : 'Nothing in kitchen',
        si: isGrocery ? 'සකස් වන ඇණවුම් නැත' : 'මුළුතැන්ගෙයි ඇණවුම් නැත',
      ),
      VendorOrderPipelineFilter.ready => _vTxt(
        context,
        en: 'Nothing ready yet',
        si: 'තවම සූදානම් ඇණවුම් නැත',
      ),
      VendorOrderPipelineFilter.active => _vTxt(
        context,
        en: 'No active orders',
        si: 'සක්‍රීය ඇණවුම් නැත',
      ),
    };
  }

  static String _filterEmptySubtitle(
    BuildContext context,
    VendorOrderPipelineFilter filter, {
    bool isGrocery = false,
  }) {
    return switch (filter) {
      VendorOrderPipelineFilter.newOrders => _vTxt(
        context,
        en: 'Incoming orders will appear here when customers place them.',
        si: 'පාරිභෝගිකයන් ඇණවුම් කළ විට එන ඇණවුම් මෙහි පෙනේ.',
      ),
      VendorOrderPipelineFilter.kitchen => _vTxt(
        context,
        en: isGrocery
            ? 'Accepted orders move here while you pack.'
            : 'Accepted orders move here while you prep.',
        si: isGrocery
            ? 'ඔබ pack කරන අතරතුර පිළිගත් ඇණවුම් මෙතැනට එයි.'
            : 'ඔබ සකස් කරන අතරතුර පිළිගත් ඇණවුම් මෙතැනට එයි.',
      ),
      VendorOrderPipelineFilter.ready => _vTxt(
        context,
        en: isGrocery
            ? 'Mark packing orders ready and they will show here.'
            : 'Mark kitchen orders ready and they will show here.',
        si: isGrocery
            ? 'Packing ඇණවුම් ready ලෙස සලකුණු කළ විට මෙහි පෙනේ.'
            : 'Kitchen ඇණවුම් ready ලෙස සලකුණු කළ විට මෙහි පෙනේ.',
      ),
      VendorOrderPipelineFilter.active => _vTxt(
        context,
        en: 'New orders show up here instantly when customers place them.',
        si: 'පාරිභෝගිකයන් ඇණවුම් කළ විගස නව ඇණවුම් මෙහි පෙනේ.',
      ),
    };
  }
}

/// Scrollable order list area — header and pipeline bar stay fixed above.
class _OrdersScrollBody extends StatelessWidget {
  const _OrdersScrollBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double gutter = vendorResponsiveHorizontalPadding(context);
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        gutter,
        4,
        gutter,
        VendorPillBottomNav.scrollBottomPadding(context, extra: 0),
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
                  _vTxt(
                    context,
                    en: 'Could not load orders',
                    si: 'ඇණවුම් පූරණය කළ නොහැක',
                  ),
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
    final Color accent = isDark
        ? const Color(0xFF8B7EFF)
        : AppColors.vendorHeroBlue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(kVendorCardRadius),
              color: accent.withValues(alpha: isDark ? 0.16 : 0.1),
              border: Border.all(
                color: accent.withValues(alpha: isDark ? 0.35 : 0.2),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Icon(
                icon,
                size: 48,
                color: accent.withValues(alpha: 0.95),
              ),
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

/// Brand gradient add button for manual order creation.
class _CreateOrderActionButton extends StatelessWidget {
  const _CreateOrderActionButton({
    required this.onPressed,
    required this.tooltip,
    this.compact = false,
  });

  final VoidCallback onPressed;
  final String tooltip;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final double size = compact ? 40 : 52;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(compact ? 14 : 16),
          child: Ink(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(compact ? 14 : 16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: AppColors.heroGradient,
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.heroShadow.withValues(
                    alpha: isDark ? 0.35 : 0.28,
                  ),
                  blurRadius: compact ? 12 : 18,
                  offset: Offset(0, compact ? 4 : 8),
                ),
              ],
            ),
            child: Icon(
              Icons.add_rounded,
              size: compact ? 22 : 26,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return ta ?? vendorTamilFallback(en);
  return en;
}
