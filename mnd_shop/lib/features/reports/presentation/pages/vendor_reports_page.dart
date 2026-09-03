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
import 'package:mnd_shop/features/reports/presentation/widgets/vendor_analytics_widgets.dart';
import 'package:printing/printing.dart';

class VendorReportsPage extends ConsumerWidget {
  const VendorReportsPage({super.key});

  static const int _lowStockMax = vendorLowStockMax;
  static const Color _accent = AppColors.vendorHeroBlue;

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
        'Average order value is ${vendorAnalyticsFormatMoney(data.averageOrderValueLkr)} for this range.',
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
        .where(
          (VendorProduct p) =>
              !p.active ||
              (p.manageStock && p.stockQty <= _lowStockMax),
        )
        .toList(growable: false);
    rows.sort((VendorProduct a, VendorProduct b) {
      final bool aOut = a.manageStock && a.stockQty == 0;
      final bool bOut = b.manageStock && b.stockQty == 0;
      if (aOut && !bOut) {
        return -1;
      }
      if (!aOut && bOut) {
        return 1;
      }
      if (a.active != b.active) {
        return a.active ? 1 : -1;
      }
      if (!a.manageStock && b.manageStock) {
        return 1;
      }
      if (a.manageStock && !b.manageStock) {
        return -1;
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
                  child: VendorAnalyticsRangeSelector(
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
                  child: VendorAnalyticsSalesTrendHero(
                    days: days,
                    spots: grossSpots,
                    maxGross: maxGross,
                    totalSales: data.grossLkr,
                    best: best,
                    compactLkr: vendorAnalyticsFormatLkr,
                    formatMoney: vendorAnalyticsFormatMoney,
                    timelineChips: <String>[
                      data.rangeLabel,
                      '${data.completedOrders} completed',
                      '${data.cancelledOrders} cancelled',
                    ],
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
                    VendorAnalyticsMetricTile(
                      label: 'Gross sales',
                      value: vendorAnalyticsFormatMoney(data.grossLkr),
                      icon: Icons.payments_rounded,
                      color: _accent,
                    ),
                    VendorAnalyticsMetricTile(
                      label: 'Net sales',
                      value: vendorAnalyticsFormatMoney(data.netSalesLkr),
                      icon: Icons.account_balance_wallet_rounded,
                      color: _accent,
                    ),
                    VendorAnalyticsMetricTile(
                      label: 'Avg order',
                      value: vendorAnalyticsFormatMoney(data.averageOrderValueLkr),
                      icon: Icons.show_chart_rounded,
                      color: _accent,
                    ),
                    VendorAnalyticsMetricTile(
                      label: 'Discounts',
                      value: vendorAnalyticsFormatMoney(data.discountLkr),
                      icon: Icons.local_offer_rounded,
                      color: _accent,
                    ),
                    VendorAnalyticsMetricTile(
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
                  child: VendorAnalyticsInsightsPanel(insights: insights),
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
                  child: VendorAnalyticsInventoryHealthPanel(
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
                        vendorAnalyticsFormatMoney(totalLkr),
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
            vendorAnalyticsFormatMoney(valueLkr),
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
            vendorAnalyticsFormatMoney(row.grossLkr),
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
