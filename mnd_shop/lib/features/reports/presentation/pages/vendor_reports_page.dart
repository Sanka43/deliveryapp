import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/constants/support_constants.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/widgets/shop_app_logo.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_catalog_metrics_snapshot.dart';
import 'package:mnd_shop/features/dashboard/presentation/providers/vendor_catalog_metrics_provider.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_dashboard_ui.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/products/domain/vendor_product.dart';
import 'package:mnd_shop/features/products/presentation/pages/product_list_page.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_products_stream_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/reports/data/vendor_stats_repository.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_pdf_builder.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';
import 'package:mnd_shop/features/reports/presentation/providers/vendor_reports_provider.dart';
import 'package:printing/printing.dart';

class VendorReportsPage extends ConsumerWidget {
  const VendorReportsPage({super.key});

  static const int _lowStockMax = vendorLowStockMax;
  static const Color _accent = AppColors.vendorHeroBlue;

  static String _compactLkr(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }

  static String _money(double v) => 'Rs. ${v.toStringAsFixed(2)}';

  Future<void> _pickCustomRange(BuildContext context, WidgetRef ref) async {
    final VendorAnalyticsRange current = ref.read(vendorAnalyticsRangeProvider);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      initialDateRange: DateTimeRange(
        start: current.start.toLocal(),
        end: current.end.toLocal(),
      ),
    );
    if (picked == null) {
      return;
    }
    ref.read(vendorAnalyticsRangeProvider.notifier).state = current.custom(
      picked.start,
      picked.end,
    );
  }

  ShopReportParty _shopParty(WidgetRef ref) {
    final Map<String, dynamic>? doc =
        ref.read(vendorAccountDocDataProvider).valueOrNull;
    final String name = ref.read(vendorShopDisplayNameProvider);
    return ShopReportParty(
      name: name,
      phone: (doc?['phone'] as String?)?.trim() ?? '',
      email: (doc?['email'] as String?)?.trim() ?? '',
      addressLine: (doc?['addressLine'] as String?)?.trim() ?? '',
      city: (doc?['city'] as String?)?.trim() ?? '',
    );
  }

  List<String> _insights({
    required VendorReportSnapshot data,
    required ProductSalesPoint? best,
    required VendorOrderBoard board,
    required VendorCatalogMetricsSnapshot catalog,
  }) {
    final List<String> out = <String>[];
    if (best != null) {
      out.add(
        '${best.productName} is leading this range with ${best.quantity} sold.',
      );
    }
    if (catalog.outCount > 0 || catalog.lowCount > 0) {
      out.add(
        '${catalog.outCount} out of stock and ${catalog.lowCount} low stock products need attention.',
      );
    }
    if (board.activeCount > 0) {
      out.add(
        '${board.activeCount} active orders are moving through the shop now.',
      );
    }
    if (data.cancellationRatePercent >= 15 && data.cancelledOrders >= 2) {
      out.add(
        'Cancellation rate is ${data.cancellationRatePercent.toStringAsFixed(1)}%; check rejected or delayed orders.',
      );
    }
    if (data.completedOrders > 0) {
      out.add(
        'Average order value is ${_money(data.averageOrderValueLkr)} for this range.',
      );
    }
    if (data.deliveryFeeLkr > 0) {
      out.add(
        'Delivery fees collected in this range: ${_money(data.deliveryFeeLkr)}.',
      );
    }
    if (out.isEmpty) {
      out.add(
        'Start completing orders and this page will show useful shop insights.',
      );
    }
    return out.take(4).toList(growable: false);
  }

  List<VendorProduct> _stockWatchProducts(List<VendorProduct> products) {
    final List<VendorProduct> rows = products
        .where((VendorProduct p) => p.stockQty <= _lowStockMax || !p.active)
        .toList(growable: false);
    rows.sort((VendorProduct a, VendorProduct b) {
      if (a.stockQty == 0 && b.stockQty != 0) {
        return -1;
      }
      if (a.stockQty != 0 && b.stockQty == 0) {
        return 1;
      }
      if (a.active != b.active) {
        return a.active ? 1 : -1;
      }
      return a.stockQty.compareTo(b.stockQty);
    });
    return rows.take(5).toList(growable: false);
  }

  Future<void> _downloadPdf(
    BuildContext context,
    WidgetRef ref,
    VendorReportSnapshot data,
    List<String> insights,
    VendorCatalogMetricsSnapshot catalog,
  ) async {
    Uint8List? logoBytes;
    try {
      final ByteData logoData = await rootBundle.load(ShopAppLogo.assetPath);
      logoBytes = logoData.buffer.asUint8List();
    } catch (_) {
      logoBytes = null;
    }

    final doc = VendorReportPdfBuilder.build(
      data: data,
      mnd: const MndReportParty(
        name: 'MND Delivery',
        tagline: 'Vendor platform · MND Shop',
        phone: SupportConstants.supportPhoneDisplay,
        email: SupportConstants.supportEmail,
      ),
      shop: _shopParty(ref),
      insights: insights,
      inventoryActive: catalog.activeCount,
      inventoryLow: catalog.lowCount,
      inventoryOut: catalog.outCount,
      logoBytes: logoBytes,
    );
    await Printing.layoutPdf(
      name:
          'mnd-shop-report-${data.rangeLabel.replaceAll(' ', '-').toLowerCase()}.pdf',
      onLayout: (_) async => doc.save(),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report PDF ready to save or share.')),
      );
    }
  }

  Future<void> _copyCsv(BuildContext context, VendorReportSnapshot data) async {
    final StringBuffer csv = StringBuffer()
      ..writeln('MND Shop Report')
      ..writeln('Range,${data.rangeLabel}')
      ..writeln('Gross Sales,${data.grossLkr.toStringAsFixed(2)}')
      ..writeln('Net Sales,${data.netSalesLkr.toStringAsFixed(2)}')
      ..writeln('Discounts,${data.discountLkr.toStringAsFixed(2)}')
      ..writeln('Delivery Fees,${data.deliveryFeeLkr.toStringAsFixed(2)}')
      ..writeln('Completed Orders,${data.completedOrders}')
      ..writeln('Cancelled Orders,${data.cancelledOrders}')
      ..writeln()
      ..writeln('Product,Quantity,Revenue,Completed Orders');
    for (final ProductSalesPoint row in data.productRows) {
      csv.writeln(
        '"${row.productName.replaceAll('"', '""')}",${row.quantity},${row.grossLkr.toStringAsFixed(2)},${row.completedOrders}',
      );
    }
    await Clipboard.setData(ClipboardData(text: csv.toString()));
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Report CSV copied.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final VendorAnalyticsRange range = ref.watch(vendorAnalyticsRangeProvider);
    final AsyncValue<VendorReportSnapshot> asyncData = ref.watch(
      vendorStatsReportsProvider,
    );
    final VendorReportSnapshot data = ref.watch(vendorReportsProvider);
    final VendorOrderBoard board =
        ref.watch(vendorOrderBoardProvider).valueOrNull ??
        VendorOrderBoard.empty;
    final VendorCatalogMetricsSnapshot catalogMetrics = ref.watch(
      vendorCatalogMetricsProvider,
    );
    final List<VendorProduct> products =
        ref.watch(vendorProductsStreamProvider).valueOrNull ??
        const <VendorProduct>[];
    final List<VendorProduct> stockWatch = _stockWatchProducts(products);
    final ProductSalesPoint? best = data.bestSellingProduct;
    final List<String> insights = _insights(
      data: data,
      best: best,
      board: board,
      catalog: catalogMetrics,
    );
    final List<DailySalesPoint> days = data.last7Days;
    final double maxGross = math.max(
      1,
      days.isEmpty
          ? 1
          : days.map((DailySalesPoint e) => e.grossLkr).reduce(math.max) * 1.12,
    );
    final int maxOrders = math.max(
      1,
      days.isEmpty
          ? 1
          : days.map((DailySalesPoint e) => e.orders).reduce(math.max) + 2,
    );
    final List<FlSpot> grossSpots = <FlSpot>[
      for (int i = 0; i < days.length; i++)
        FlSpot(i.toDouble(), days[i].grossLkr),
    ];
    final bool hourlyChart = days.length > 12;
    final int xLabelStep = hourlyChart
        ? 4
        : math.max(1, (days.length / 6).ceil());
    final List<Color> pieColors = <Color>[
      _accent,
      AppColors.vendorHeroViolet,
      AppColors.openGreen,
      AppColors.pendingAmber,
      AppColors.orderRejectRed,
      AppColors.workflowDeep,
    ];
    final double gutter = vendorResponsiveHorizontalPadding(context);
    final bool tablet = vendorUsesTabletLayout(context);

    return Scaffold(
      backgroundColor: VendorDashboardTheme.canvas(context),
      body: SafeArea(
        child: VendorResponsiveContent(
          child: RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(vendorStatsReportsProvider);
              ref.invalidate(vendorOrderBoardProvider);
              await Future<void>.delayed(const Duration(milliseconds: 350));
            },
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: <Widget>[
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(gutter, 2, gutter, 10),
                  sliver: SliverToBoxAdapter(
                    child: SizedBox(
                      height: 48,
                      child: Row(
                        children: <Widget>[
                          SizedBox(
                            width: 36,
                            child: IconButton(
                              tooltip: MaterialLocalizations.of(context)
                                  .backButtonTooltip,
                              onPressed: () =>
                                  Navigator.of(context).maybePop(),
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              alignment: Alignment.centerLeft,
                              icon: Icon(
                                Icons.arrow_back_rounded,
                                size: 24,
                                color: theme.brightness == Brightness.dark
                                    ? cs.onSurface
                                    : AppColors.textCharcoal,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Align(
                              alignment: const Alignment(-1, -0.08),
                              child: Text(
                                _vTxt(context, en: 'Reports', si: 'වාර්තා'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.bebasNeue(
                                  textStyle: theme.textTheme.headlineMedium,
                                  fontSize: 34,
                                  letterSpacing: 1.0,
                                  height: 1.0,
                                  color: theme.brightness == Brightness.dark
                                      ? cs.onSurface
                                      : AppColors.textCharcoal,
                                ).copyWith(
                                  fontFamilyFallback: const <String>[
                                    'Poppins',
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Builder(
                            builder: (BuildContext menuContext) {
                              return IconButton.filledTonal(
                                tooltip: 'Export report',
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  final RenderBox button = menuContext
                                      .findRenderObject()! as RenderBox;
                                  final RenderBox overlay = Overlay.of(
                                            menuContext,
                                          )
                                          .context
                                          .findRenderObject()!
                                      as RenderBox;
                                  final RelativeRect position =
                                      RelativeRect.fromRect(
                                    Rect.fromPoints(
                                      button.localToGlobal(
                                        button.size.bottomRight(Offset.zero),
                                        ancestor: overlay,
                                      ),
                                      button.localToGlobal(
                                        button.size.bottomRight(Offset.zero),
                                        ancestor: overlay,
                                      ),
                                    ),
                                    Offset.zero & overlay.size,
                                  );
                                  final String? value =
                                      await showMenu<String>(
                                    context: menuContext,
                                    position: position,
                                    items: const <PopupMenuEntry<String>>[
                                      PopupMenuItem<String>(
                                        value: 'pdf',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.picture_as_pdf_outlined,
                                          ),
                                          title: Text('Download PDF'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                      PopupMenuItem<String>(
                                        value: 'csv',
                                        child: ListTile(
                                          leading: Icon(
                                            Icons.content_copy_outlined,
                                          ),
                                          title: Text('Copy CSV'),
                                          contentPadding: EdgeInsets.zero,
                                        ),
                                      ),
                                    ],
                                  );
                                  if (!context.mounted) {
                                    return;
                                  }
                                  if (value == 'pdf') {
                                    _downloadPdf(
                                      context,
                                      ref,
                                      data,
                                      insights,
                                      catalogMetrics,
                                    );
                                  } else if (value == 'csv') {
                                    _copyCsv(context, data);
                                  }
                                },
                                icon: const Icon(
                                  Icons.file_download_outlined,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 14),
                sliver: SliverToBoxAdapter(
                  child: _RangeSelector(
                    selected: range.preset,
                    onPreset: (VendorAnalyticsPreset preset) {
                      ref.read(vendorAnalyticsRangeProvider.notifier).state =
                          VendorAnalyticsRange.forPreset(preset);
                    },
                    onCustom: () => _pickCustomRange(context, ref),
                  ),
                ),
              ),
              if (asyncData.isLoading)
                const SliverToBoxAdapter(
                  child: LinearProgressIndicator(minHeight: 2),
                ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                sliver: SliverToBoxAdapter(
                  child: _SalesTrendHero(
                    days: days,
                    spots: grossSpots,
                    maxGross: maxGross,
                    totalSales: data.grossLkr,
                    rangeLabel: data.rangeLabel,
                    completedOrders: data.completedOrders,
                    cancelledOrders: data.cancelledOrders,
                    best: best,
                    compactLkr: _compactLkr,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                sliver: SliverGrid.count(
                  crossAxisCount: tablet ? 3 : 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  childAspectRatio: tablet ? 2.2 : 2.45,
                  children: <Widget>[
                    _MetricTile(
                      label: 'Gross sales',
                      value: _money(data.grossLkr),
                      icon: Icons.payments_rounded,
                      color: _accent,
                    ),
                    _MetricTile(
                      label: 'Net sales',
                      value: _money(data.netSalesLkr),
                      icon: Icons.account_balance_wallet_rounded,
                      color: _accent,
                    ),
                    _MetricTile(
                      label: 'Avg order',
                      value: _money(data.averageOrderValueLkr),
                      icon: Icons.show_chart_rounded,
                      color: _accent,
                    ),
                    _MetricTile(
                      label: 'Discounts',
                      value: _money(data.discountLkr),
                      icon: Icons.local_offer_rounded,
                      color: _accent,
                    ),
                    _MetricTile(
                      label: 'Delivery fees',
                      value: _money(data.deliveryFeeLkr),
                      icon: Icons.delivery_dining_rounded,
                      color: _accent,
                    ),
                    _MetricTile(
                      label: 'Cancel rate',
                      value:
                          '${data.cancellationRatePercent.toStringAsFixed(1)}%',
                      icon: Icons.highlight_off_rounded,
                      color: _accent,
                    ),
                  ],
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                sliver: SliverToBoxAdapter(
                  child: _InsightsPanel(insights: insights),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                sliver: SliverToBoxAdapter(
                  child: _OrdersPerDayPanel(
                    days: days,
                    maxOrders: maxOrders,
                    hourlyChart: hourlyChart,
                    xLabelStep: xLabelStep,
                    rangeLabel: data.rangeLabel,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                sliver: SliverToBoxAdapter(
                  child: _InventoryHealthPanel(
                    metrics: catalogMetrics,
                    products: stockWatch,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 16),
                sliver: SliverToBoxAdapter(
                  child: _ProductRevenueSplitPanel(
                    labels: data.categoryLabels,
                    valuesLkr: data.categoryValuesLkr,
                    totalLkr: data.totalCategoryLkr,
                    pieColors: pieColors,
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(gutter, 0, gutter, 28),
                sliver: SliverToBoxAdapter(
                  child: _ProductWiseSalesPanel(
                    rows: data.productRows.take(20).toList(growable: false),
                    totalGross: data.grossLkr,
                  ),
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

class _OrdersPerDayPanel extends StatelessWidget {
  const _OrdersPerDayPanel({
    required this.days,
    required this.maxOrders,
    required this.hourlyChart,
    required this.xLabelStep,
    required this.rangeLabel,
  });

  final List<DailySalesPoint> days;
  final int maxOrders;
  final bool hourlyChart;
  final int xLabelStep;
  final String rangeLabel;

  static const Color _accent = AppColors.vendorHeroBlue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int totalOrders = days.fold<int>(
      0,
      (int sum, DailySalesPoint d) => sum + d.orders,
    );
    final int peakOrders = days.isEmpty
        ? 0
        : days.map((DailySalesPoint d) => d.orders).reduce(math.max);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Orders per day',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Completed orders · $rangeLabel',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$totalOrders total',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: _accent,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 188,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: maxOrders.toDouble(),
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xE6282C34),
                    tooltipRoundedRadius: 12,
                    getTooltipItem:
                        (
                          BarChartGroupData group,
                          int groupIndex,
                          BarChartRodData rod,
                          int rodIndex,
                        ) {
                      final int i = group.x;
                      if (i < 0 || i >= days.length) {
                        return null;
                      }
                      return BarTooltipItem(
                        '${days[i].shortLabel}\n${rod.toY.toInt()} orders',
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      );
                    },
                  ),
                ),
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: math.max(1, maxOrders / 4).toDouble(),
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: VendorDashboardTheme.sectionBorder(context),
                    strokeWidth: 1,
                    dashArray: const <int>[4, 4],
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
                      reservedSize: 28,
                      getTitlesWidget: (double value, TitleMeta meta) {
                        final int i = value.toInt();
                        String? label;
                        if (hourlyChart) {
                          if (i == 23) {
                            label = '24';
                          } else if (i >= 8 &&
                              i <= 20 &&
                              i % xLabelStep == 0) {
                            label = i.toString().padLeft(2, '0');
                          }
                        } else if (i >= 0 &&
                            i < days.length &&
                            (i == 0 ||
                                i == days.length - 1 ||
                                i % xLabelStep == 0)) {
                          label = days[i].shortLabel;
                        }
                        if (label == null) {
                          return const SizedBox.shrink();
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            label,
                            maxLines: 1,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: VendorDashboardTheme.mutedText(context),
                              fontWeight: FontWeight.w600,
                              fontSize: hourlyChart ? 10 : null,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: <BarChartGroupData>[
                  for (int i = 0; i < days.length; i++)
                    BarChartGroupData(
                      x: i,
                      barRods: <BarChartRodData>[
                        BarChartRodData(
                          toY: days[i].orders.toDouble(),
                          width: hourlyChart ? 8 : 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors:
                                days[i].orders >= peakOrders && peakOrders > 0
                                ? <Color>[
                                    _accent.withValues(alpha: 0.65),
                                    _accent,
                                  ]
                                : <Color>[
                                    _accent.withValues(alpha: 0.35),
                                    _accent.withValues(alpha: 0.85),
                                  ],
                          ),
                          backDrawRodData: BackgroundBarChartRodData(
                            show: true,
                            toY: maxOrders.toDouble(),
                            color: _accent.withValues(alpha: 0.06),
                          ),
                        ),
                      ],
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

class _ProductRevenueSplitPanel extends StatelessWidget {
  const _ProductRevenueSplitPanel({
    required this.labels,
    required this.valuesLkr,
    required this.totalLkr,
    required this.pieColors,
  });

  final List<String> labels;
  final List<double> valuesLkr;
  final double totalLkr;
  final List<Color> pieColors;

  static const Color _accent = AppColors.vendorHeroBlue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool empty = labels.isEmpty || totalLkr <= 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Product revenue split',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Top product contribution',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (!empty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${labels.length} items',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          if (empty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Text(
                  'No product revenue yet',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            )
          else ...<Widget>[
            SizedBox(
              height: 168,
              child: Stack(
                alignment: Alignment.center,
                children: <Widget>[
                  PieChart(
                    PieChartData(
                      sectionsSpace: 3,
                      centerSpaceRadius: 52,
                      startDegreeOffset: -90,
                      sections: <PieChartSectionData>[
                        for (int i = 0; i < labels.length; i++)
                          PieChartSectionData(
                            color: pieColors[i % pieColors.length],
                            value: valuesLkr[i],
                            title: '',
                            radius: 42,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        'Total',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: VendorDashboardTheme.mutedText(context),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        VendorReportsPage._money(totalLkr),
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: _accent,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < labels.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _RevenueLegendRow(
                label: labels[i],
                valueLkr: valuesLkr[i],
                totalLkr: totalLkr,
                color: pieColors[i % pieColors.length],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _RevenueLegendRow extends StatelessWidget {
  const _RevenueLegendRow({
    required this.label,
    required this.valueLkr,
    required this.totalLkr,
    required this.color,
  });

  final String label;
  final double valueLkr;
  final double totalLkr;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pct = totalLkr <= 0 ? 0 : (valueLkr / totalLkr) * 100;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${pct.toStringAsFixed(1)}% of revenue',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Text(
            VendorReportsPage._money(valueLkr),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _RangeSelector extends StatelessWidget {
  const _RangeSelector({
    required this.selected,
    required this.onPreset,
    required this.onCustom,
  });

  final VendorAnalyticsPreset selected;
  final ValueChanged<VendorAnalyticsPreset> onPreset;
  final VoidCallback onCustom;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool isCustom = selected == VendorAnalyticsPreset.custom;
    final List<(VendorAnalyticsPreset, String)> presets =
        <(VendorAnalyticsPreset, String)>[
          (VendorAnalyticsPreset.today, 'Day'),
          (VendorAnalyticsPreset.week, 'Week'),
          (VendorAnalyticsPreset.month, 'Month'),
          (VendorAnalyticsPreset.year, 'Year'),
        ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          for (final (VendorAnalyticsPreset, String) item in presets)
            Expanded(
              child: _RangePill(
                label: item.$2,
                selected: !isCustom && selected == item.$1,
                onTap: () => onPreset(item.$1),
              ),
            ),
          Material(
            color: isCustom ? cs.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              onTap: onCustom,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 10,
                ),
                child: Icon(
                  Icons.date_range_rounded,
                  size: 18,
                  color: isCustom ? cs.onPrimary : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RangePill extends StatelessWidget {
  const _RangePill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Material(
        color: selected
            ? VendorDashboardTheme.cardSurface(context)
            : Colors.transparent,
        elevation: selected ? 1.5 : 0,
        shadowColor: cs.shadow.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: Text(
                label,
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: selected ? cs.onSurface : cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalesTrendHero extends StatelessWidget {
  const _SalesTrendHero({
    required this.days,
    required this.spots,
    required this.maxGross,
    required this.totalSales,
    required this.rangeLabel,
    required this.completedOrders,
    required this.cancelledOrders,
    required this.best,
    required this.compactLkr,
  });

  final List<DailySalesPoint> days;
  final List<FlSpot> spots;
  final double maxGross;
  final double totalSales;
  final String rangeLabel;
  final int completedOrders;
  final int cancelledOrders;
  final ProductSalesPoint? best;
  final String Function(double) compactLkr;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    const Color onBlue = Colors.white;
    final Color onBlueMuted = Colors.white.withValues(alpha: 0.72);

    final int peakIndex = _peakIndex(days);
    final List<FlSpot> solidSpots = peakIndex < 0
        ? spots
        : spots.sublist(0, peakIndex + 1);
    final List<FlSpot> dashedSpots =
        peakIndex < 0 || peakIndex >= spots.length - 1
        ? const <FlSpot>[]
        : spots.sublist(peakIndex);
    final FlSpot? peakSpot = peakIndex >= 0 && peakIndex < spots.length
        ? spots[peakIndex]
        : null;
    final DailySalesPoint? peakDay =
        peakIndex >= 0 && peakIndex < days.length ? days[peakIndex] : null;

    final List<LineChartBarData> glowBars = <LineChartBarData>[
      _glowBar(
        spots: solidSpots,
        color: const Color(0xFF7EB6FF).withValues(alpha: 0.28),
        width: 16,
      ),
      _glowBar(
        spots: solidSpots,
        color: Colors.white.withValues(alpha: 0.32),
        width: 8,
      ),
      LineChartBarData(
        spots: solidSpots,
        isCurved: true,
        curveSmoothness: 0.4,
        color: onBlue,
        barWidth: 2.8,
        isStrokeCapRound: true,
        dotData: FlDotData(
          show: true,
          checkToShowDot: (FlSpot spot, LineChartBarData bar) {
            return peakSpot != null &&
                spot.x == peakSpot.x &&
                spot.y == peakSpot.y &&
                spot.y > 0;
          },
          getDotPainter:
              (FlSpot spot, double percent, LineChartBarData bar, int index) {
                return FlDotCirclePainter(
                  radius: 6.5,
                  color: onBlue,
                  strokeWidth: 3.5,
                  strokeColor: Colors.white.withValues(alpha: 0.4),
                );
              },
        ),
        belowBarData: BarAreaData(
          show: true,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[
              Colors.white.withValues(alpha: 0.18),
              Colors.white.withValues(alpha: 0),
            ],
          ),
        ),
      ),
      if (dashedSpots.length >= 2)
        LineChartBarData(
          spots: dashedSpots,
          isCurved: true,
          curveSmoothness: 0.4,
          color: Colors.white.withValues(alpha: 0.5),
          barWidth: 2,
          isStrokeCapRound: true,
          dashArray: const <int>[5, 6],
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
    ];

    final int solidBarIndex =
        glowBars.length - (dashedSpots.length >= 2 ? 2 : 1);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 14, 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.vendorHeroViolet,
            AppColors.vendorHeroBlue,
            AppColors.workflowDeep,
          ],
          stops: <double>[0.0, 0.5, 1.0],
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.heroShadow.withValues(alpha: 0.4),
            blurRadius: 28,
            offset: const Offset(0, 14),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Sales timeline',
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: onBlue,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      best == null
                          ? 'No product sales in this range yet'
                          : 'Best seller: ${best!.productName}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: onBlueMuted,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.24),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      'Gross',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: onBlueMuted,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      VendorReportsPage._money(totalSales),
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: onBlue,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              _TimelineChip(label: rangeLabel),
              _TimelineChip(label: '$completedOrders completed'),
              _TimelineChip(label: '$cancelledOrders cancelled'),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 176,
            child: LineChart(
              LineChartData(
                clipData: const FlClipData.all(),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                minX: 0,
                maxX: math
                    .max(1.0, (days.length - 1).toDouble())
                    .clamp(1.0, 365.0)
                    .toDouble(),
                minY: 0,
                maxY: maxGross,
                extraLinesData: peakSpot == null
                    ? const ExtraLinesData()
                    : ExtraLinesData(
                        verticalLines: <VerticalLine>[
                          VerticalLine(
                            x: peakSpot.x,
                            color: Colors.white.withValues(alpha: 0.2),
                            strokeWidth: 1,
                            dashArray: const <int>[3, 4],
                          ),
                        ],
                      ),
                showingTooltipIndicators: peakSpot == null || peakDay == null
                    ? const <ShowingTooltipIndicators>[]
                    : <ShowingTooltipIndicators>[
                        ShowingTooltipIndicators(<LineBarSpot>[
                          LineBarSpot(
                            glowBars[solidBarIndex],
                            solidBarIndex,
                            peakSpot,
                          ),
                        ]),
                      ],
                lineTouchData: LineTouchData(
                  enabled: true,
                  handleBuiltInTouches: true,
                  getTouchLineStart: (_, _) => 0,
                  getTouchLineEnd: (_, _) => double.infinity,
                  getTouchedSpotIndicator:
                      (LineChartBarData barData, List<int> spotIndexes) {
                    if (barData.barWidth > 3) {
                      return spotIndexes
                          .map((_) => null)
                          .toList(growable: false);
                    }
                    return spotIndexes.map((int index) {
                      return TouchedSpotIndicatorData(
                        FlLine(
                          color: Colors.white.withValues(alpha: 0.28),
                          strokeWidth: 1,
                        ),
                        FlDotData(
                          getDotPainter:
                              (
                                FlSpot spot,
                                double percent,
                                LineChartBarData bar,
                                int index,
                              ) {
                                return FlDotCirclePainter(
                                  radius: 6.5,
                                  color: onBlue,
                                  strokeWidth: 3,
                                  strokeColor: Colors.white.withValues(
                                    alpha: 0.4,
                                  ),
                                );
                              },
                        ),
                      );
                    }).toList(growable: false);
                  },
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (_) => const Color(0xE6282C34),
                    tooltipRoundedRadius: 14,
                    tooltipPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    tooltipMargin: 12,
                    fitInsideHorizontally: true,
                    fitInsideVertically: true,
                    getTooltipItems: (List<LineBarSpot> touched) {
                      return touched.map((LineBarSpot spot) {
                        if (spot.bar.barWidth > 3) {
                          return null;
                        }
                        final int i = spot.x.round().clamp(0, days.length - 1);
                        final DailySalesPoint day = days[i];
                        final String value = day.grossLkr >= 1000
                            ? '${compactLkr(day.grossLkr)} LKR'
                            : 'Rs. ${day.grossLkr.toStringAsFixed(0)}';
                        return LineTooltipItem(
                          '${day.shortLabel}\n$value',
                          const TextStyle(
                            color: onBlue,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            height: 1.35,
                            letterSpacing: -0.2,
                          ),
                        );
                      }).toList(growable: false);
                    },
                  ),
                ),
                lineBarsData: glowBars,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static int _peakIndex(List<DailySalesPoint> days) {
    if (days.isEmpty) {
      return -1;
    }
    int peak = 0;
    for (int i = 1; i < days.length; i++) {
      if (days[i].grossLkr > days[peak].grossLkr) {
        peak = i;
      }
    }
    if (days[peak].grossLkr <= 0) {
      return -1;
    }
    return peak;
  }

  static LineChartBarData _glowBar({
    required List<FlSpot> spots,
    required Color color,
    required double width,
  }) {
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.4,
      color: color,
      barWidth: width,
      isStrokeCapRound: true,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: false),
    );
  }
}

class _TimelineChip extends StatelessWidget {
  const _TimelineChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white.withValues(alpha: 0.88),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: VendorDashboardTheme.mutedText(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _InsightsPanel extends StatelessWidget {
  const _InsightsPanel({required this.insights});

  final List<String> insights;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return _Panel(
      title: 'Smart insights',
      subtitle: 'Quick actions from live shop data',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < insights.length; i++)
            _InsightRow(
              text: insights[i],
              icon: switch (i) {
                0 => Icons.insights_rounded,
                1 => Icons.inventory_2_rounded,
                2 => Icons.local_shipping_rounded,
                _ => Icons.bolt_rounded,
              },
              color: switch (i) {
                0 => cs.primary,
                1 => AppColors.pendingAmber,
                2 => AppColors.openGreen,
                _ => cs.tertiary,
              },
            ),
        ],
      ),
    );
  }
}

class _InsightRow extends StatelessWidget {
  const _InsightRow({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VendorDashboardTheme.primaryText(context),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryHealthPanel extends StatelessWidget {
  const _InventoryHealthPanel({
    required this.metrics,
    required this.products,
  });

  final VendorCatalogMetricsSnapshot metrics;
  final List<VendorProduct> products;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool healthy = products.isEmpty && metrics.total > 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Inventory health',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      healthy
                          ? 'All stock looks healthy'
                          : 'Stock issues that can affect today\'s orders',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (healthy)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.openGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Healthy',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: AppColors.openGreen,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: _MiniStat(
                  label: 'Active',
                  value: '${metrics.activeCount}',
                  icon: Icons.storefront_rounded,
                  color: AppColors.openGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Low',
                  value: '${metrics.lowCount}',
                  icon: Icons.battery_alert_rounded,
                  color: AppColors.pendingAmber,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniStat(
                  label: 'Out',
                  value: '${metrics.outCount}',
                  icon: Icons.production_quantity_limits_rounded,
                  color: AppColors.orderRejectRed,
                ),
              ),
            ],
          ),
          if (metrics.total == 0) ...<Widget>[
            const SizedBox(height: 12),
            Text(
              'Add products to start tracking stock health.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: VendorDashboardTheme.mutedText(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ] else if (products.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            for (int i = 0; i < products.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _InventoryProductRow(product: products[i]),
            ],
          ],
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    height: 1.1,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InventoryProductRow extends StatelessWidget {
  const _InventoryProductRow({required this.product});

  final VendorProduct product;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool out = product.stockQty == 0;
    final bool offline = !product.active;
    final Color color = out
        ? AppColors.orderRejectRed
        : offline
        ? theme.colorScheme.tertiary
        : AppColors.pendingAmber;
    final IconData icon = offline
        ? Icons.pause_circle_rounded
        : out
        ? Icons.error_outline_rounded
        : Icons.shopping_bag_rounded;
    final String status = offline
        ? 'Offline'
        : out
        ? 'Out of stock'
        : '${product.stockQty} left';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 17, color: Colors.white),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: VendorDashboardTheme.primaryText(context),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: theme.textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductWiseSalesPanel extends StatelessWidget {
  const _ProductWiseSalesPanel({
    required this.rows,
    required this.totalGross,
  });

  final List<ProductSalesPoint> rows;
  final double totalGross;

  static const Color _accent = AppColors.vendorHeroBlue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VendorDashboardTheme.sectionBorder(context)),
        boxShadow: VendorDashboardTheme.elevatedCardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Product-wise sales',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Revenue and quantity sold',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (rows.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${rows.length} products',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _accent,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Center(
                child: Column(
                  children: <Widget>[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: _accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_rounded,
                        color: _accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'No product sales yet',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: VendorDashboardTheme.mutedText(context),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            for (int i = 0; i < rows.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(height: 8),
              _ProductReportRow(
                row: rows[i],
                total: totalGross,
                index: i,
              ),
            ],
        ],
      ),
    );
  }
}

class _ProductReportRow extends StatelessWidget {
  const _ProductReportRow({
    required this.row,
    required this.total,
    required this.index,
  });

  final ProductSalesPoint row;
  final double total;
  final int index;

  static const Color _accent = AppColors.vendorHeroBlue;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double pct = total <= 0 ? 0 : (row.grossLkr / total).clamp(0.0, 1.0);
    final double pctLabel = pct * 100;

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 12, 10),
      decoration: BoxDecoration(
        color: VendorDashboardTheme.itemsBoxFill(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: index == 0 ? _accent : _accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${index + 1}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: index == 0 ? Colors.white : _accent,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 5,
                    backgroundColor: _accent.withValues(alpha: 0.1),
                    color: _accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${row.quantity} sold · ${pctLabel.toStringAsFixed(1)}%',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: VendorDashboardTheme.mutedText(context),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            VendorReportsPage._money(row.grossLkr),
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
              color: _accent,
              letterSpacing: -0.2,
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
