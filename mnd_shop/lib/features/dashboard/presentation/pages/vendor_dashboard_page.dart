import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/app/providers/vendor_shell_tab_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_open_hours.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_summary.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_catalog_metrics_snapshot.dart';
import 'package:mnd_shop/features/dashboard/presentation/providers/vendor_catalog_metrics_provider.dart';
import 'package:mnd_shop/features/dashboard/presentation/providers/vendor_dashboard_provider.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';
import 'package:mnd_shop/features/reports/presentation/providers/vendor_reports_provider.dart';
import 'package:mnd_shop/features/incoming_orders/presentation/pages/incoming_vendor_order_page.dart';
import 'package:mnd_shop/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:mnd_shop/features/notifications/presentation/providers/vendor_notifications_providers.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_order_items_list.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_dashboard_ui.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_pill_bottom_nav.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_from_profile_provider.dart';

class VendorDashboardPage extends ConsumerStatefulWidget {
  const VendorDashboardPage({super.key});

  /// Shared money formatter for dashboard widgets.
  static String formatMoney(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  @override
  ConsumerState<VendorDashboardPage> createState() =>
      _VendorDashboardPageState();
}

class _VendorDashboardPageState extends ConsumerState<VendorDashboardPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncOpenHoursFromSchedule();
    });
  }

  Future<void> _syncOpenHoursFromSchedule() async {
    final String storeId = ref.read(vendorEffectiveStoreIdProvider).trim();
    if (storeId.isEmpty) {
      return;
    }
    await ref
        .read(vendorOrdersRepositoryProvider)
        .syncVendorOpenStatusFromSchedule(storeId);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

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

  static Future<void> _openOrderDetailReadOnly(
    BuildContext context,
    VendorPendingOrder order,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext ctx) =>
            IncomingVendorOrderPage(order: order, readOnly: true),
      ),
    );
  }

  static String _greeting(BuildContext context, DateTime now) {
    final int h = now.hour;
    if (h < 12) {
      return _vTxt(context, en: 'Good Morning', si: 'සුභ උදෑසනක්');
    }
    if (h < 17) {
      return _vTxt(context, en: 'Good Afternoon', si: 'සුභ මධ්‍යාහ්නයක්');
    }
    return _vTxt(context, en: 'Good Evening', si: 'සුභ සන්ධ්‍යාවක්');
  }

  Future<void> _onRefresh() async {
    ref.invalidate(vendorStoreFromProfileProvider);
    ref.invalidate(vendorOrderBoardProvider);
    ref.invalidate(vendorStoreActiveProvider);
    ref.invalidate(vendorUnreadNotificationCountProvider);
    ref.invalidate(vendorNotificationsListProvider);
    ref.invalidate(vendorProductsStreamProvider);
    await _syncOpenHoursFromSchedule();
    await Future<void>.delayed(const Duration(milliseconds: 450));
  }

  @override
  Widget build(BuildContext context) {
    final VendorSalesSummary sales = ref.watch(vendorSalesSummaryProvider);
    final AsyncValue<VendorOrderBoard> board = ref.watch(
      vendorOrderBoardProvider,
    );
    final VendorOrderBoard orderBoard =
        board.valueOrNull ?? VendorOrderBoard.empty;
    final VendorCatalogMetricsSnapshot catalog = ref.watch(
      vendorCatalogMetricsProvider,
    );
    final AsyncValue<bool> activeAsync = ref.watch(vendorStoreActiveProvider);
    final AsyncValue<void> profileStoreSync = ref.watch(
      vendorStoreFromProfileProvider,
    );
    ref.watch(shopAuthStateProvider);
    ref.watch(vendorAccountDocDataProvider);
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final User? authUser = ref.watch(shopAuthStateProvider).valueOrNull;
    final String resolvedStoreId = storeId.isNotEmpty
        ? storeId
        : (authUser?.uid.trim() ?? '');
    final String? storeAccessError = ref.watch(vendorStoreAccessErrorProvider);
    final String shopName = ref.watch(vendorShopDisplayNameProvider);
    final int unreadNotifications =
        ref.watch(vendorUnreadNotificationCountProvider).valueOrNull ?? 0;

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final DateTime now = DateTime.now();
    final double gutter = vendorResponsiveHorizontalPadding(context);
    final double bottomScrollPadding = VendorPillBottomNav.scrollBottomPadding(
      context,
      extra: 0,
      includeOuterMargin: false,
    );

    final Map<String, dynamic>? vendorDoc = ref
        .watch(vendorAccountDocDataProvider)
        .valueOrNull;
    final String? approval = vendorDoc?['approvalStatus'] as String?;
    final bool pendingApproval = approval == 'pending';
    final bool rejected = approval == 'rejected';
    final bool canToggleLive =
        approval == null || approval.isEmpty || approval == 'approved';

    final bool liveFromFirestore = activeAsync.valueOrNull ?? true;
    final bool isOpen = liveFromFirestore && !pendingApproval && !rejected;

    final DateTime? openOverrideUntil = () {
      final Object? raw = vendorDoc?['openOverrideUntil'];
      if (raw is Timestamp) {
        return raw.toDate();
      }
      return null;
    }();
    final String scheduleSubtitle = localizeVendorOpenSubtitle(
      vendorOpenStatusSubtitle(
        isOpen: isOpen,
        now: now,
        openingHours: vendorDoc?['openingHours'],
        openOverrideUntil: openOverrideUntil,
        canToggle: canToggleLive,
      ),
      languageCode: Localizations.localeOf(context).languageCode,
    );

    return Scaffold(
      backgroundColor: VendorDashboardTheme.canvas(context),
      body: VendorResponsiveContent(
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    gutter,
                    MediaQuery.paddingOf(context).top + 12,
                    gutter,
                    12,
                  ),
                  child: VendorDashboardHeader(
                    greeting: _greeting(context, now),
                    shopName: shopName,
                    unreadCount: unreadNotifications,
                    onNotificationTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (BuildContext ctx) =>
                              const VendorNotificationsPage(),
                        ),
                      );
                    },
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: cs.primary,
                    edgeOffset: 8,
                    onRefresh: _onRefresh,
                    child: CustomScrollView(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      slivers: <Widget>[
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                if (profileStoreSync.isLoading)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _SyncBanner(theme: theme, cs: cs),
                                  ),
                                if (storeAccessError != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _DashboardWarningBanner(
                                      message: storeAccessError,
                                      theme: theme,
                                      cs: cs,
                                    ),
                                  ),
                                if (orderBoard.isTruncated)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _DashboardWarningBanner(
                                      message: _vTxt(
                                        context,
                                        en:
                                            'Showing recent orders only (last 30 days). Older orders are hidden.',
                                        si:
                                            'මෑත ඇණවුම් පමණක් පෙන්වයි (දින 30). පැරණි ඇණවුම් සඟවා ඇත.',
                                      ),
                                      theme: theme,
                                      cs: cs,
                                    ),
                                  ),
                                _StoreStatusHeroCard(
                                  isOpen: isOpen,
                                  scheduleSubtitle: scheduleSubtitle,
                                  pulseAnimation: _pulseController,
                                  sales: sales,
                                  board: orderBoard,
                                  catalog: catalog,
                                  canToggle: canToggleLive,
                                  storeId: resolvedStoreId,
                                  onToggle: (bool value) async {
                                    if (resolvedStoreId.isEmpty) {
                                      _snack(
                                        context,
                                        _vTxt(
                                          context,
                                          en: 'Set store ID first.',
                                          si: 'මුලින් store ID සකසන්න.',
                                        ),
                                        error: true,
                                      );
                                      return;
                                    }
                                    final String? err = await ref
                                        .read(vendorOrdersRepositoryProvider)
                                        .setVendorActive(resolvedStoreId, value);
                                    if (context.mounted && err != null) {
                                      _snack(context, err, error: true);
                                    }
                                  },
                                ),
                                const SizedBox(height: 12),
                                if (pendingApproval || rejected)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: _ApprovalBanner(
                                      pendingApproval: pendingApproval,
                                      theme: theme,
                                      cs: cs,
                                    ),
                                  ),
                                const SizedBox(height: 12),
                                _IncomingOrdersSection(
                                  storeId: resolvedStoreId,
                                  board: board,
                                  ref: ref,
                                  hasVendorProfile: vendorDoc != null,
                                ),
                                const SizedBox(height: 12),
                                board.when(
                                  data: (VendorOrderBoard b) => _WorkflowGrid(
                                    board: b,
                                    onOrderTap: (VendorPendingOrder o) =>
                                        _VendorDashboardPageState._openOrderDetailReadOnly(
                                          context,
                                          o,
                                        ),
                                    onViewAll: () {
                                      ref
                                              .read(
                                                vendorShellTabIndexProvider
                                                    .notifier,
                                              )
                                              .state =
                                          2;
                                    },
                                  ),
                                  loading: () => const SizedBox(height: 120),
                                  error: (Object e, StackTrace s) =>
                                      const SizedBox.shrink(),
                                ),
                                const SizedBox(height: 12),
                                const _SalesPreviewCard(),
                                SizedBox(height: bottomScrollPadding),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (pendingApproval)
              IgnorePointer(
                child: Center(
                  child: Transform.rotate(
                    angle: -0.28,
                    child: Text(
                      _vTxt(
                        context,
                        en: 'ADMIN STILL NOT APPROVED YOUR SHOP',
                        si: 'ඔබේ සාප්පුව තවම ADMIN අනුමත කර නැත',
                      ),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: cs.error.withValues(alpha: 0.14),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _IncomingOrdersSection extends StatelessWidget {
  const _IncomingOrdersSection({
    required this.storeId,
    required this.board,
    required this.ref,
    required this.hasVendorProfile,
  });

  final String storeId;
  final AsyncValue<VendorOrderBoard> board;
  final WidgetRef ref;
  final bool hasVendorProfile;

  static const int _homePreviewLimit = 3;

  void _openAllIncomingOrders() {
    ref.read(vendorShellTabIndexProvider.notifier).state = 2;
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final int? incomingCount = board.whenOrNull(
      data: (VendorOrderBoard b) => b.incoming.length,
    );
    final bool showViewAll =
        storeId.isNotEmpty &&
        incomingCount != null &&
        incomingCount > _homePreviewLimit;
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: VendorDashboardTheme.cardSurface(context),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Row(
              children: <Widget>[
                Icon(
                  Icons.inbox_rounded,
                  color: cs.primary.withValues(alpha: 0.9),
                  size: 22,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _vTxt(context, en: 'Incoming orders', si: 'එන ඇණවුම්'),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.45,
                      color: VendorDashboardTheme.primaryText(context),
                      height: 1.2,
                    ),
                  ),
                ),
                if (showViewAll)
                  TextButton(
                    onPressed: _openAllIncomingOrders,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: cs.primary,
                    ),
                    child: Text(
                      _vTxt(context, en: 'View all', si: 'සියල්ල බලන්න'),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: cs.outlineVariant.withValues(alpha: 0.22),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
            child: board.when(
              data: (VendorOrderBoard b) {
                if (storeId.isEmpty) {
                  return _EmptyOrdersPanel(
                    title: _vTxt(
                      context,
                      en: hasVendorProfile
                          ? 'No incoming orders yet'
                          : 'Setting up your shop',
                      si: hasVendorProfile
                          ? 'තවම එන ඇණවුම් නැත'
                          : 'ඔබේ සාප්පුව සකසමින්',
                    ),
                    subtitle: hasVendorProfile
                        ? null
                        : _vTxt(
                            context,
                            en: 'Your shop link is syncing. Pull to refresh in a moment.',
                            si: 'ඔබේ සාප්පු link එක sync වෙමින්. මොහොතකින් refresh කරන්න.',
                          ),
                    icon: hasVendorProfile
                        ? Icons.move_to_inbox_rounded
                        : Icons.storefront_outlined,
                    embeddedInSection: true,
                  );
                }
                if (b.incoming.isEmpty) {
                  return _EmptyOrdersPanel(
                    title: _vTxt(
                      context,
                      en: 'No incoming orders yet',
                      si: 'තවම එන ඇණවුම් නැත',
                    ),
                    icon: Icons.move_to_inbox_rounded,
                    embeddedInSection: true,
                  );
                }
                final List<VendorPendingOrder> visible = b.incoming
                    .take(_homePreviewLimit)
                    .toList();
                return Column(
                  children: List<Widget>.generate(visible.length, (int i) {
                    final VendorPendingOrder o = visible[i];
                    return Padding(
                      padding: EdgeInsets.only(
                        bottom: i < visible.length - 1 ? 12 : 0,
                      ),
                      child: _ModernIncomingOrderCard(
                        order: o,
                        moneyLabel: VendorDashboardPage.formatMoney(
                          o.shopTotal,
                        ),
                        onOpenDetail: () =>
                            _VendorDashboardPageState._openIncomingDetail(
                              context,
                              ref,
                              o,
                            ),
                        onAccept: () async {
                          final String? err = await ref
                              .read(vendorOrdersRepositoryProvider)
                              .updateOrderStatus(
                                orderId: o.id,
                                nextStatus: 'confirmed',
                              );
                          if (context.mounted) {
                            if (err != null) {
                              _VendorDashboardPageState._snack(
                                context,
                                err,
                                error: true,
                              );
                            } else {
                              _VendorDashboardPageState._snack(
                                context,
                                '${_vTxt(context, en: 'Accepted', si: 'පිළිගත්තා')} · ${o.referenceForDisplay}',
                              );
                            }
                          }
                        },
                        onReject: () async {
                          final String? err = await ref
                              .read(vendorOrdersRepositoryProvider)
                              .rejectOrder(orderId: o.id);
                          if (context.mounted) {
                            if (err != null) {
                              _VendorDashboardPageState._snack(
                                context,
                                err,
                                error: true,
                              );
                            } else {
                              _VendorDashboardPageState._snack(
                                context,
                                '${_vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප කළා')} · ${o.referenceForDisplay}',
                              );
                            }
                          }
                        },
                      ),
                    );
                  }),
                );
              },
              loading: () => const _OrdersLoadingSkeleton(),
              error: (Object e, _) => _EmptyOrdersPanel(
                title: _vTxt(
                  context,
                  en: 'No incoming orders yet',
                  si: 'තවම එන ඇණවුම් නැත',
                ),
                subtitle: _vTxt(
                  context,
                  en: 'Orders will appear here when customers place them.',
                  si: 'පාරිභෝගිකයන් ඇණවුම් දාන විට මෙතන පෙන්වයි.',
                ),
                icon: Icons.move_to_inbox_rounded,
                embeddedInSection: true,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SyncBanner extends StatelessWidget {
  const _SyncBanner({required this.theme, required this.cs});

  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _vTxt(
                context,
                en: 'Syncing store link from your account…',
                si: 'ඔබේ ගිණුමෙන් store link එක sync කරමින්…',
              ),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardWarningBanner extends StatelessWidget {
  const _DashboardWarningBanner({
    required this.message,
    required this.theme,
    required this.cs,
  });

  final String message;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: cs.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ApprovalBanner extends StatelessWidget {
  const _ApprovalBanner({
    required this.pendingApproval,
    required this.theme,
    required this.cs,
  });

  final bool pendingApproval;
  final ThemeData theme;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: pendingApproval
          ? cs.primaryContainer.withValues(alpha: 0.85)
          : cs.errorContainer.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              pendingApproval ? Icons.hourglass_top_outlined : Icons.block,
              color: cs.onPrimaryContainer,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                pendingApproval
                    ? _vTxt(
                        context,
                        en: 'Awaiting admin approval. Your shop is not visible to customers yet.',
                        si: 'Admin අනුමැතිය බලාපොරොත්තුයි. ඔබේ සාප්පුව තවම පාරිභෝගිකයන්ට නොපෙනේ.',
                      )
                    : _vTxt(
                        context,
                        en: 'This shop is not approved for the marketplace. Contact support.',
                        si: 'මෙම සාප්පුව marketplace සඳහා අනුමත කර නොමැත. support අමතන්න.',
                      ),
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoreStatusHeroCard extends StatelessWidget {
  const _StoreStatusHeroCard({
    required this.isOpen,
    required this.scheduleSubtitle,
    required this.pulseAnimation,
    required this.sales,
    required this.board,
    required this.catalog,
    required this.canToggle,
    required this.storeId,
    required this.onToggle,
  });

  final bool isOpen;
  final String scheduleSubtitle;
  final Animation<double> pulseAnimation;
  final VendorSalesSummary sales;
  final VendorOrderBoard board;
  final VendorCatalogMetricsSnapshot catalog;
  final bool canToggle;
  final String storeId;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color badgeTextColor = isOpen ? Colors.white : cs.error;

    final bool isDark = VendorDashboardTheme.isDark(context);
    final Color shadowTint = VendorDashboardTheme.heroShadowTint(context);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? <Color>[
                  AppColors.vendorHeroBlue.withValues(alpha: 0.92),
                  AppColors.vendorHeroViolet.withValues(alpha: 0.88),
                ]
              : AppColors.heroGradient,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.14)
              : Colors.white.withValues(alpha: 0.28),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: shadowTint,
            blurRadius: isDark ? 24 : 28,
            offset: const Offset(0, 12),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.12),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? Colors.black.withValues(alpha: 0.45)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      width: 1.25,
                      color: isOpen
                          ? Colors.white.withValues(alpha: 0.62)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                    boxShadow: isOpen
                        ? <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : <BoxShadow>[
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      FadeTransition(
                        opacity: Tween<double>(begin: 0.45, end: 1).animate(
                          CurvedAnimation(
                            parent: pulseAnimation,
                            curve: Curves.easeInOut,
                          ),
                        ),
                        child: Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isOpen
                                ? AppColors.pulseGreen
                                : AppColors.closedGrey,
                            boxShadow: isOpen
                                ? <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.pulseGreen.withValues(
                                        alpha: 0.75,
                                      ),
                                      blurRadius: 10,
                                      spreadRadius: 1,
                                    ),
                                  ]
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Text(
                        isOpen
                            ? _vTxt(context, en: 'Open', si: 'විවෘතයි')
                            : _vTxt(context, en: 'Close', si: 'වසා ඇත'),
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          color: badgeTextColor,
                          height: 1,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Theme(
                  data: theme.copyWith(
                    switchTheme: SwitchThemeData(
                      thumbColor: WidgetStateProperty.resolveWith((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white.withValues(alpha: 0.45);
                        }
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white;
                        }
                        return Colors.white;
                      }),
                      trackColor: WidgetStateProperty.resolveWith((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white.withValues(alpha: 0.2);
                        }
                        if (states.contains(WidgetState.selected)) {
                          return AppColors.openGreen;
                        }
                        return Colors.black.withValues(alpha: 0.28);
                      }),
                      trackOutlineColor: WidgetStateProperty.resolveWith((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return Colors.white.withValues(alpha: 0.35);
                        }
                        if (states.contains(WidgetState.selected)) {
                          return Colors.white.withValues(alpha: 0.55);
                        }
                        return Colors.white.withValues(alpha: 0.72);
                      }),
                      trackOutlineWidth: WidgetStateProperty.resolveWith((
                        Set<WidgetState> states,
                      ) {
                        if (states.contains(WidgetState.disabled)) {
                          return 1.0;
                        }
                        if (states.contains(WidgetState.selected)) {
                          return 1.25;
                        }
                        return 1.5;
                      }),
                      overlayColor: WidgetStateProperty.all<Color>(
                        Colors.transparent,
                      ),
                    ),
                  ),
                  child: Switch(
                    value: isOpen,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    onChanged: canToggle && storeId.isNotEmpty
                        ? onToggle
                        : null,
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                scheduleSubtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontWeight: FontWeight.w500,
                  height: 1.25,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withValues(alpha: 0.34),
              ),
            ),
            const SizedBox(height: 12),
            // IntrinsicHeight gives the Row a finite height inside the scroll view; without it,
            // SizedBox.expand + Spacer in stat cards see unbounded height and the layout fails (blank UI).
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    child: VendorStatMiniCard(
                      label: _vTxt(
                        context,
                        en: 'Today revenue',
                        si: 'අද ආදායම',
                      ),
                      value: VendorDashboardPage.formatMoney(sales.todayGross),
                      gradient: VendorDashboardTheme.heroStatGradient(context),
                      labelColor: VendorDashboardTheme.heroStatLabel(context),
                      valueColor: VendorDashboardTheme.heroStatValue(context),
                      borderColor: VendorDashboardTheme.heroStatBorder(context),
                      density: VendorStatMiniCardDensity.hero,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: VendorStatMiniCard(
                      label: _vTxt(
                        context,
                        en: 'Today orders',
                        si: 'අද ඇණවුම්',
                      ),
                      value: '${sales.ordersToday}',
                      gradient: VendorDashboardTheme.heroStatGradient(context),
                      labelColor: VendorDashboardTheme.heroStatLabel(context),
                      valueColor: VendorDashboardTheme.heroStatValue(context),
                      borderColor: VendorDashboardTheme.heroStatBorder(context),
                      density: VendorStatMiniCardDensity.hero,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: VendorHeroInsightChip(
                    expand: true,
                    icon: Icons.inbox_outlined,
                    label: _vTxt(
                      context,
                      en: 'Pending accept',
                      si: 'බලාපොරොත්තු',
                    ),
                    value: '${board.incoming.length}',
                    fillColor: board.incoming.isNotEmpty
                        ? Colors.white.withValues(alpha: 0.38)
                        : Colors.white.withValues(alpha: 0.28),
                    borderColor: Colors.white.withValues(alpha: 0.48),
                    iconColor: Colors.white,
                    labelColor: Colors.white.withValues(alpha: 0.95),
                    valueColor: Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VendorHeroInsightChip(
                    expand: true,
                    icon: Icons.local_fire_department_outlined,
                    label: _vTxt(
                      context,
                      en: 'Active orders',
                      si: 'සක්‍රීය ඇණවුම්',
                    ),
                    value: '${board.activeCount}',
                    fillColor: Colors.white.withValues(alpha: 0.28),
                    borderColor: Colors.white.withValues(alpha: 0.48),
                    iconColor: Colors.white,
                    labelColor: Colors.white.withValues(alpha: 0.95),
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: catalog.lowCount > 0
                      ? VendorHeroInsightChip(
                          expand: true,
                          icon: Icons.warning_amber_rounded,
                          label: _vTxt(context, en: 'Low stock', si: 'අඩු තොග'),
                          value: '${catalog.lowCount}',
                          fillColor: Colors.white.withValues(alpha: 0.38),
                          borderColor: Colors.white.withValues(alpha: 0.48),
                          iconColor: Colors.white,
                          labelColor: Colors.white.withValues(alpha: 0.95),
                          valueColor: Colors.white,
                        )
                      : VendorHeroInsightChip(
                          expand: true,
                          icon: Icons.receipt_long_outlined,
                          label: _vTxt(
                            context,
                            en: 'Avg order today',
                            si: 'අද සාමාන්‍ය ඇණවුම',
                          ),
                          value: VendorDashboardPage.formatMoney(
                            sales.ordersToday > 0
                                ? sales.todayGross / sales.ordersToday
                                : 0,
                          ),
                          fillColor: Colors.white.withValues(alpha: 0.28),
                          borderColor: Colors.white.withValues(alpha: 0.48),
                          iconColor: Colors.white,
                          labelColor: Colors.white.withValues(alpha: 0.95),
                          valueColor: Colors.white,
                        ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VendorHeroInsightChip(
                    expand: true,
                    icon: Icons.task_alt_rounded,
                    label: _vTxt(
                      context,
                      en: 'Completion today',
                      si: 'අද සම්පූර්ණ වීම',
                    ),
                    value: '${sales.completionRatePercent.toStringAsFixed(0)}%',
                    fillColor: Colors.white.withValues(alpha: 0.28),
                    borderColor: Colors.white.withValues(alpha: 0.48),
                    iconColor: Colors.white,
                    labelColor: Colors.white.withValues(alpha: 0.95),
                    valueColor: Colors.white,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyOrdersPanel extends StatelessWidget {
  const _EmptyOrdersPanel({
    required this.title,
    this.subtitle,
    this.icon = Icons.move_to_inbox_rounded,
    this.embeddedInSection = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final bool embeddedInSection;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool hasSubtitle = subtitle != null && subtitle!.isNotEmpty;
    final Widget body = Column(
      children: <Widget>[
        _EmptyOrdersIllustration(
          color: cs.primary.withValues(alpha: 0.85),
          icon: icon,
          colorScheme: cs,
        ),
        SizedBox(height: hasSubtitle ? (embeddedInSection ? 16 : 20) : 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.45,
            height: 1.15,
            color: VendorDashboardTheme.primaryText(context),
          ),
        ),
        if (hasSubtitle) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            subtitle!,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: VendorDashboardTheme.mutedText(context),
              height: 1.45,
            ),
          ),
        ],
      ],
    );
    if (embeddedInSection) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: body,
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
      decoration: BoxDecoration(
        color: cs.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.22)),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: cs.shadow.withValues(alpha: 0.045),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: body,
    );
  }
}

class _EmptyOrdersIllustration extends StatelessWidget {
  const _EmptyOrdersIllustration({
    required this.color,
    required this.icon,
    required this.colorScheme,
  });

  final Color color;
  final IconData icon;
  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 100,
      child: Center(
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              colors: <Color>[
                colorScheme.primary.withValues(alpha: 0.12),
                colorScheme.tertiary.withValues(alpha: 0.08),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(26),
            child: Icon(icon, size: 40, color: color),
          ),
        ),
      ),
    );
  }
}

class _OrdersLoadingSkeleton extends StatelessWidget {
  const _OrdersLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Column(
      children: List<Widget>.generate(2, (int i) {
        return Padding(
          padding: EdgeInsets.only(bottom: i == 0 ? 12 : 0),
          child: Container(
            height: 108,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.15),
              ),
              gradient: LinearGradient(
                colors: <Color>[
                  cs.outlineVariant.withValues(alpha: 0.2),
                  cs.outlineVariant.withValues(alpha: 0.08),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ModernIncomingOrderCard extends StatelessWidget {
  const _ModernIncomingOrderCard({
    required this.order,
    required this.moneyLabel,
    required this.onOpenDetail,
    required this.onAccept,
    required this.onReject,
  });

  final VendorPendingOrder order;
  final String moneyLabel;
  final VoidCallback onOpenDetail;
  final Future<void> Function() onAccept;
  final Future<void> Function() onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String itemsLabel = order.itemCount == 1
        ? _vTxt(context, en: '1 item', si: 'අයිතම 1')
        : _vTxt(
            context,
            en: '${order.itemCount} items',
            si: 'අයිතම ${order.itemCount}',
          );

    final Color primaryText = VendorDashboardTheme.primaryText(context);
    final Color mutedText = VendorDashboardTheme.mutedText(context);
    final bool isDark = VendorDashboardTheme.isDark(context);

    final TextStyle headlineStyle = theme.textTheme.titleMedium!.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: -0.35,
      color: primaryText,
      height: 1.25,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenDetail,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: VendorDashboardTheme.cardSurface(context),
            border: Border.all(
              color: VendorDashboardTheme.sectionBorder(context),
            ),
            boxShadow: VendorDashboardTheme.orderCardShadow(context),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      order.customerPhone.isNotEmpty
                          ? Icons.local_shipping_rounded
                          : Icons.shopping_bag_outlined,
                      size: 22,
                      color: primaryText,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            order.referenceForDisplay,
                            style: headlineStyle.copyWith(
                              fontFamily: 'monospace',
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (order.customerPhone.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 4),
                            Text(
                              order.customerPhone,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: mutedText,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: <Widget>[
                        Text(
                          moneyLabel,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: primaryText,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: VendorDashboardTheme.newBadgeBg(context),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _vTxt(context, en: 'NEW', si: 'නව'),
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: VendorDashboardTheme.newBadgeText(context),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Icon(Icons.schedule_rounded, size: 16, color: mutedText),
                    const SizedBox(width: 6),
                    Text(
                      order.placedAtLabel.isEmpty
                          ? _vTxt(context, en: 'Just now', si: 'දැන්ම')
                          : order.placedAtLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedText,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Icon(
                      Icons.shopping_bag_outlined,
                      size: 16,
                      color: mutedText,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      itemsLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: VendorDashboardTheme.itemsBoxFill(context),
                    borderRadius: BorderRadius.circular(12),
                    border: isDark
                        ? Border.all(
                            color: cs.outlineVariant.withValues(alpha: 0.45),
                          )
                        : null,
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: VendorOrderItemsList(
                      items: order.items,
                      primaryText: primaryText,
                      mutedText: mutedText,
                      maxRows: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton(
                        onPressed: () => onAccept(),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.vendorHeroBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(
                          _vTxt(context, en: 'Accept', si: 'පිළිගන්න'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => onReject(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.orderRejectRed,
                          backgroundColor: isDark
                              ? cs.surfaceContainerHigh
                              : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: const BorderSide(
                            color: AppColors.orderRejectRed,
                            width: 1.5,
                          ),
                          textStyle: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        child: Text(
                          _vTxt(context, en: 'Reject', si: 'ප්‍රතික්ෂේප කරන්න'),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WorkflowGrid extends StatelessWidget {
  const _WorkflowGrid({
    required this.board,
    required this.onOrderTap,
    required this.onViewAll,
  });

  final VendorOrderBoard board;
  final void Function(VendorPendingOrder order) onOrderTap;
  final VoidCallback onViewAll;

  static const Color _kTileBlue = AppColors.workflowTile;

  @override
  Widget build(BuildContext context) {
    final List<_WFSpec> specs = <_WFSpec>[
      _WFSpec(
        title: _vTxt(context, en: 'In Kitchen', si: 'මුළුතැන්ගෙයි'),
        count: board.kitchen.length,
        orders: board.kitchen,
        icon: Icons.restaurant_rounded,
        colors: <Color>[_kTileBlue],
        accent: Colors.white,
      ),
      _WFSpec(
        title: _vTxt(context, en: 'Ready', si: 'සූදානම්'),
        count: board.readyForPickup.length,
        orders: board.readyForPickup,
        icon: Icons.task_alt_rounded,
        colors: <Color>[_kTileBlue],
        accent: Colors.white,
      ),
    ];

    const double crossGap = 6;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (int i = 0; i < specs.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: crossGap),
          Expanded(
            child: _WorkflowCell(
              title: specs[i].title,
              count: specs[i].count,
              orders: specs[i].orders,
              icon: specs[i].icon,
              gradient: specs[i].colors,
              accent: specs[i].accent,
              onOrderTap: onOrderTap,
              onViewAll: onViewAll,
            ),
          ),
        ],
      ],
    );
  }
}

class _WFSpec {
  const _WFSpec({
    required this.title,
    required this.count,
    required this.orders,
    required this.icon,
    required this.colors,
    required this.accent,
  });

  final String title;
  final int count;
  final List<VendorPendingOrder> orders;
  final IconData icon;

  /// Solid fill uses [colors.first] (flat design — no gradient).
  final List<Color> colors;
  final Color accent;
}

class _WorkflowCell extends StatelessWidget {
  const _WorkflowCell({
    required this.title,
    required this.count,
    required this.orders,
    required this.icon,
    required this.gradient,
    required this.accent,
    required this.onOrderTap,
    required this.onViewAll,
  });

  final String title;
  final int count;
  final List<VendorPendingOrder> orders;
  final IconData icon;
  final List<Color> gradient;
  final Color accent;
  final void Function(VendorPendingOrder order) onOrderTap;
  final VoidCallback onViewAll;

  static const Color _kDeepBlue = AppColors.workflowDeep;
  static const Color _kMutedOnBlue = AppColors.workflowMutedOnBlue;
  static const Color _kDividerBlue = AppColors.workflowDivider;

  static const int _kMaxTrackingLines = 4;

  static const String _kEmptySlotLine = '-';

  static String _trackingHashLine(VendorPendingOrder o) {
    final String ref = o.referenceForDisplay.trim();
    if (ref.isEmpty || ref == '-') {
      final String tail = o.id.length > 6
          ? o.id.substring(o.id.length - 6)
          : o.id;
      return '#$tail';
    }
    return ref.startsWith('#') ? ref : '#$ref';
  }

  TextStyle? _trackingLineStyle(ThemeData theme, {required bool muted}) {
    return theme.textTheme.labelLarge?.copyWith(
      color: muted ? _kMutedOnBlue : Colors.white,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.12,
      height: 1.15,
      fontSize: 18,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color tile = gradient.first;
    final List<VendorPendingOrder> shown = orders
        .take(_kMaxTrackingLines)
        .toList(growable: false);
    final int hidden = count > _kMaxTrackingLines
        ? count - _kMaxTrackingLines
        : 0;
    final int emptySlotCount = count > 0 && hidden == 0
        ? (_kMaxTrackingLines - shown.length).clamp(0, _kMaxTrackingLines)
        : 0;
    final TextStyle? trackingStyle = _trackingLineStyle(theme, muted: false);
    final TextStyle? emptySlotStyle = _trackingLineStyle(theme, muted: true);

    final bool isDark = VendorDashboardTheme.isDark(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tile,
        borderRadius: BorderRadius.circular(14),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.45)
                : const Color(0x402B3C80),
            blurRadius: 14,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.25)
                : const Color(0x14000000),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _kDeepBlue,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(child: Icon(icon, color: accent, size: 18)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          title,
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.2,
                            height: 1.1,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            '$count',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                              height: 1,
                              fontSize: 22,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Container(
              height: 1,
              decoration: const BoxDecoration(
                color: _kDividerBlue,
                borderRadius: BorderRadius.all(Radius.circular(1)),
              ),
            ),
            const SizedBox(height: 4),
            if (count == 0)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  _vTxt(context, en: 'No orders', si: 'ඇණවුම් නැත'),
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: _kMutedOnBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              )
            else
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: <Widget>[
                  for (final VendorPendingOrder o in shown)
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => onOrderTap(o),
                        borderRadius: BorderRadius.circular(6),
                        splashColor: const Color(0x33FFFFFF),
                        highlightColor: const Color(0x1AFFFFFF),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 1,
                            horizontal: 2,
                          ),
                          child: Text(
                            _trackingHashLine(o),
                            textAlign: TextAlign.right,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: trackingStyle,
                          ),
                        ),
                      ),
                    ),
                  for (int i = 0; i < emptySlotCount; i++)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 1,
                        horizontal: 2,
                      ),
                      child: Text(
                        _kEmptySlotLine,
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        style: emptySlotStyle,
                      ),
                    ),
                  if (hidden > 0)
                    InkWell(
                      onTap: onViewAll,
                      borderRadius: BorderRadius.circular(6),
                      splashColor: const Color(0x33FFFFFF),
                      highlightColor: const Color(0x1AFFFFFF),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 1),
                        child: Text(
                          _vTxt(
                            context,
                            en: '+$hidden more',
                            si: 'තවත් $hidden',
                          ),
                          textAlign: TextAlign.right,
                          maxLines: 1,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: _kMutedOnBlue,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.05,
                            fontSize: 12,
                            height: 1.15,
                            decoration: TextDecoration.underline,
                            decorationColor: _kMutedOnBlue,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SalesPreviewCard extends ConsumerWidget {
  const _SalesPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final VendorSalesSummary sales = ref.watch(vendorSalesSummaryProvider);
    final List<DailySalesPoint> days = ref
        .watch(vendorReportsProvider)
        .last7Days;

    final bool growthPositive = sales.weekOverWeekGrowthPercent >= 0;
    final double priorWeekGross = sales.priorWeekGross;

    final List<FlSpot> currentSpots = <FlSpot>[
      for (int i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].grossLkr),
    ];

    final int lastIndex = days.isEmpty ? 0 : days.length - 1;
    final bool hourlyChart = days.length > 12;
    final int xLabelStep = hourlyChart
        ? 4
        : math.max(1, (days.length / 4).ceil());
    final double maxY =
        <double>[
          if (currentSpots.isNotEmpty) ...currentSpots.map((FlSpot e) => e.y),
        ].fold<double>(1, math.max) *
        1.12;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            _vTxt(context, en: 'Today revenue', si: 'අද ආදායම'),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: VendorDashboardTheme.mutedText(context),
              letterSpacing: 0.1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: <Widget>[
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    VendorDashboardPage.formatMoney(sales.todayGross),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.8,
                      color: VendorDashboardTheme.primaryText(context),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: growthPositive
                      ? AppColors.openGreen.withValues(alpha: 0.12)
                      : cs.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      growthPositive
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 16,
                      color: growthPositive ? AppColors.openGreen : cs.error,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${growthPositive ? '+' : ''}${sales.weekOverWeekGrowthPercent.toStringAsFixed(1)}%',
                      style: theme.textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: growthPositive ? AppColors.openGreen : cs.error,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            _vTxt(
              context,
              en: 'vs. ${VendorDashboardPage.formatMoney(priorWeekGross)} previous week',
              si: 'පසුගිය සතිය ${VendorDashboardPage.formatMoney(priorWeekGross)} සමඟ සසඳා',
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: VendorDashboardTheme.mutedText(context),
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 166,
            child: days.isEmpty
                ? const SizedBox.shrink()
                : LineChart(
                    LineChartData(
                      clipData: const FlClipData.all(),
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: maxY > 0 ? maxY / 4 : 1,
                        getDrawingHorizontalLine: (_) => FlLine(
                          color: cs.outlineVariant.withValues(alpha: 0.28),
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 34,
                            interval: xLabelStep.toDouble(),
                            getTitlesWidget: (double value, TitleMeta meta) {
                              final int i = value.round();
                              String? label;
                              if (hourlyChart) {
                                if (i >= 8 && i <= 24 && i % xLabelStep == 0) {
                                  label = i.toString().padLeft(2, '0');
                                }
                              } else {
                                if (i >= 0 &&
                                    i <= lastIndex &&
                                    (i == 0 ||
                                        i == lastIndex ||
                                        i % xLabelStep == 0)) {
                                  label = days[i].shortLabel;
                                }
                              }
                              if (label == null) return const SizedBox.shrink();
                              return Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  style: theme.textTheme.labelSmall?.copyWith(
                                    color: VendorDashboardTheme.mutedText(
                                      context,
                                    ),
                                    fontWeight: FontWeight.w500,
                                    fontSize: hourlyChart ? 10 : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: hourlyChart
                          ? 24
                          : lastIndex.toDouble().clamp(0, 100),
                      minY: 0,
                      maxY: maxY,
                      lineBarsData: <LineChartBarData>[
                        LineChartBarData(
                          spots: currentSpots,
                          isCurved: true,
                          curveSmoothness: 0.35,
                          color: cs.primary,
                          barWidth: 3,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: <Color>[
                                cs.primary.withValues(alpha: 0.12),
                                cs.primary.withValues(alpha: 0.02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
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
