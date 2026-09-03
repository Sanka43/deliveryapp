import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/phone_call_launcher.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/incoming_orders/presentation/pages/incoming_vendor_order_page.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_orders_ui.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

class VendorOrderHistoryPage extends ConsumerWidget {
  const VendorOrderHistoryPage({super.key});

  static String _money(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  static void _openDetail(BuildContext context, VendorPendingOrder order) {
    Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (BuildContext ctx) =>
            IncomingVendorOrderPage(order: order, readOnly: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<VendorOrderBoard> board = ref.watch(
      vendorOrderBoardProvider,
    );
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final double topInset = MediaQuery.paddingOf(context).top;
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: VendorOrdersTheme.canvas(context),
      body: Column(
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
              title: _vTxt(context, en: 'History', si: 'History'),
              titleColor: isDark ? cs.onSurface : null,
              trailing: IconButton.filledTonal(
                tooltip: _vTxt(context, en: 'Back', si: 'Back'),
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
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
                loading: () => const _HistoryScrollBody(
                  child: Center(
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2.8),
                  ),
                ),
                error: (Object e, StackTrace _) => _HistoryScrollBody(
                  child: _HistoryMessage(
                    icon: Icons.cloud_off_outlined,
                    title: _vTxt(
                      context,
                      en: 'Could not load history',
                      si: 'Could not load history',
                    ),
                    subtitle: userFacingError(
                      e,
                      fallback: 'Please check your connection and try again.',
                    ),
                  ),
                ),
                data: (VendorOrderBoard value) {
                  if (storeId.isEmpty) {
                    return _HistoryScrollBody(
                      child: _HistoryMessage(
                        icon: Icons.storefront_outlined,
                        title: _vTxt(
                          context,
                          en: 'Store not linked',
                          si: 'Store not linked',
                        ),
                        subtitle: _vTxt(
                          context,
                          en: 'Complete shop setup so completed orders can appear here.',
                          si: 'Complete shop setup so completed orders can appear here.',
                        ),
                      ),
                    );
                  }

                  final List<VendorPendingOrder> completed = value.completed;
                  final List<VendorPendingOrder> cancelled = value.cancelled;
                  if (completed.isEmpty && cancelled.isEmpty) {
                    return _HistoryScrollBody(
                      child: _HistoryMessage(
                        icon: Icons.history_rounded,
                        title: _vTxt(
                          context,
                          en: 'No order history yet',
                          si: 'No order history yet',
                        ),
                        subtitle: _vTxt(
                          context,
                          en: 'Completed orders will appear here.',
                          si: 'Completed orders will appear here.',
                        ),
                      ),
                    );
                  }

                  return _HistoryScrollBody(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        if (completed.isNotEmpty) ...<Widget>[
                          VendorOrdersSectionHeader(
                            icon: Icons.check_circle_outline_rounded,
                            label: _vTxt(
                              context,
                              en: 'Completed orders',
                              si: 'Completed orders',
                            ),
                            count: completed.length,
                            accent: VendorOrdersStageColors.ready,
                          ),
                          const SizedBox(height: 12),
                          ...completed.map(
                            (VendorPendingOrder order) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _VendorOrderHistoryCard(
                                order: order,
                                moneyLabel: _money(order.shopTotal),
                                onOpen: () => _openDetail(context, order),
                              ),
                            ),
                          ),
                        ],
                        if (cancelled.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 18),
                          VendorOrdersSectionHeader(
                            icon: Icons.cancel_outlined,
                            label: _vTxt(
                              context,
                              en: 'Cancelled orders',
                              si: 'Cancelled orders',
                            ),
                            count: cancelled.length,
                            accent: AppColors.orderRejectRed,
                          ),
                          const SizedBox(height: 12),
                          ...cancelled.map(
                            (VendorPendingOrder order) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _VendorOrderHistoryCard(
                                order: order,
                                moneyLabel: _money(order.shopTotal),
                                onOpen: () => _openDetail(context, order),
                              ),
                            ),
                          ),
                        ],
                      ],
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
}

/// Minimal history row — tracking number, time, price, name, phone. No
/// items list or status badges; tap opens the full read-only order detail.
class _VendorOrderHistoryCard extends StatelessWidget {
  const _VendorOrderHistoryCard({
    required this.order,
    required this.moneyLabel,
    required this.onOpen,
  });

  final VendorPendingOrder order;
  final String moneyLabel;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color cardBg = VendorOrdersTheme.cardSurface(context);
    final Color titleColor = VendorOrdersTheme.primaryText(context);
    final Color mutedColor = VendorOrdersTheme.mutedText(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: VendorOrdersTheme.cardShadow(context),
      ),
      child: Material(
        color: cardBg,
        elevation: 0,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        order.referenceForDisplay,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                          color: titleColor,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (order.placedAtLabel.isNotEmpty) ...<Widget>[
                      const SizedBox(width: 10),
                      Icon(Icons.schedule_rounded, size: 13, color: mutedColor),
                      const SizedBox(width: 4),
                      Text(
                        order.placedAtLabel,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: mutedColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
                if (order.customerName.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    order.customerName,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: titleColor,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    if (order.customerPhone.isNotEmpty)
                      Expanded(
                        child: InkWell(
                          onTap: () => launchPhoneCall(context, order.customerPhone),
                          borderRadius: BorderRadius.circular(8),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(Icons.call_rounded, size: 13, color: AppColors.openGreen),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  order.customerPhone,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: mutedColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      const Spacer(),
                    Text(
                      moneyLabel,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.vendorHeroBlue,
                        letterSpacing: -0.2,
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

class _HistoryScrollBody extends StatelessWidget {
  const _HistoryScrollBody({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.fromLTRB(
        kVendorScreenPadding,
        14,
        kVendorScreenPadding,
        32,
      ),
      children: <Widget>[child],
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
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
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 90),
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
