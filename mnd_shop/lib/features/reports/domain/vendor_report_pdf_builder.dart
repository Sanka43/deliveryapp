import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

/// Platform (MND) details printed on the PDF letterhead left side.
class MndReportParty {
  const MndReportParty({
    this.name = 'MND Delivery',
    this.tagline = 'Vendor platform',
    this.phone = '',
    this.email = '',
  });

  final String name;
  final String tagline;
  final String phone;
  final String email;
}

/// Shop details printed on the PDF letterhead right side.
class ShopReportParty {
  const ShopReportParty({
    this.name = 'Your shop',
    this.phone = '',
    this.email = '',
    this.addressLine = '',
    this.city = '',
  });

  final String name;
  final String phone;
  final String email;
  final String addressLine;
  final String city;

  String get addressBlock {
    final List<String> parts = <String>[
      if (addressLine.trim().isNotEmpty) addressLine.trim(),
      if (city.trim().isNotEmpty) city.trim(),
    ];
    return parts.join(', ');
  }
}

class VendorReportPdfBuilder {
  const VendorReportPdfBuilder._();

  static const PdfColor _brandBlue = PdfColor.fromInt(0xFF1565C0);
  static const PdfColor _softBlue = PdfColor.fromInt(0xFFE3F2FD);
  static const PdfColor _border = PdfColor.fromInt(0xFFCFD8DC);
  static const PdfColor _muted = PdfColor.fromInt(0xFF546E7A);

  static pw.Document build({
    required VendorReportSnapshot data,
    MndReportParty mnd = const MndReportParty(),
    ShopReportParty shop = const ShopReportParty(),
    List<String> insights = const <String>[],
    int inventoryActive = 0,
    int inventoryLow = 0,
    int inventoryOut = 0,
    Uint8List? logoBytes,
  }) {
    final pw.Document doc = pw.Document();
    final String generatedAt =
        DateTime.now().toLocal().toString().split('.').first;
    final pw.MemoryImage? logo =
        logoBytes == null ? null : pw.MemoryImage(logoBytes);

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(36, 36, 36, 40),
        header: (pw.Context context) => _letterhead(
          mnd: mnd,
          shop: shop,
          logo: logo,
          rangeLabel: data.rangeLabel,
          generatedAt: generatedAt,
          isFirstPage: context.pageNumber == 1,
        ),
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(top: 8),
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}  ·  Confidential shop report',
            style: const pw.TextStyle(fontSize: 8, color: _muted),
          ),
        ),
        build: (pw.Context context) => <pw.Widget>[
          pw.SizedBox(height: 8),
          pw.Row(
            children: <pw.Widget>[
              _metricBox('Gross sales', _money(data.grossLkr)),
              pw.SizedBox(width: 8),
              _metricBox('Net sales', _money(data.netSalesLkr)),
              pw.SizedBox(width: 8),
              _metricBox('Avg order', _money(data.averageOrderValueLkr)),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Row(
            children: <pw.Widget>[
              _metricBox('Discounts', _money(data.discountLkr)),
              pw.SizedBox(width: 8),
              _metricBox('Delivery fees', _money(data.deliveryFeeLkr)),
              pw.SizedBox(width: 8),
              _metricBox(
                'Cancel rate',
                '${data.cancellationRatePercent.toStringAsFixed(1)}%',
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: _softBlue,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Text(
              '${data.completedOrders} completed  ·  ${data.cancelledOrders} cancelled  ·  '
              'Inventory: $inventoryActive active / $inventoryLow low / $inventoryOut out',
              style: const pw.TextStyle(fontSize: 10, color: _muted),
            ),
          ),
          if (insights.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 18),
            _sectionTitle('Smart insights'),
            pw.SizedBox(height: 6),
            for (final String line in insights.take(4))
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    pw.Text('•  ', style: const pw.TextStyle(color: _brandBlue)),
                    pw.Expanded(
                      child: pw.Text(
                        line,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          pw.SizedBox(height: 18),
          _sectionTitle('Sales timeline'),
          pw.SizedBox(height: 8),
          if (_salesTimelineRows(data).isEmpty)
            pw.Text('No sales data for this period.')
          else
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'Date',
                'Sales (LKR)',
                'Orders',
                'Cancelled',
              ],
              data: <List<String>>[
                for (final DailySalesPoint day in _salesTimelineRows(data))
                  <String>[
                    _pdfDate(day),
                    day.grossLkr.toStringAsFixed(2),
                    day.orders.toString(),
                    day.cancelledOrders.toString(),
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: _brandBlue),
              border: pw.TableBorder.all(color: _border, width: 0.5),
              cellHeight: 22,
            ),
          pw.SizedBox(height: 18),
          _sectionTitle('Product-wise sales'),
          pw.SizedBox(height: 8),
          if (data.productRows.isEmpty)
            pw.Text('No product sales yet.')
          else
            pw.TableHelper.fromTextArray(
              headers: <String>[
                'Product',
                'Qty',
                'Revenue (LKR)',
                'Orders',
                'Share',
              ],
              data: <List<String>>[
                for (final ProductSalesPoint row in data.productRows.take(50))
                  <String>[
                    row.productName,
                    row.quantity.toString(),
                    row.grossLkr.toStringAsFixed(2),
                    row.completedOrders.toString(),
                    data.grossLkr <= 0
                        ? '0%'
                        : '${(100 * row.grossLkr / data.grossLkr).toStringAsFixed(1)}%',
                  ],
              ],
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
                fontSize: 9,
              ),
              cellStyle: const pw.TextStyle(fontSize: 9),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(color: _brandBlue),
              border: pw.TableBorder.all(color: _border, width: 0.5),
              cellHeight: 22,
            ),
          pw.SizedBox(height: 18),
          _sectionTitle('Revenue split'),
          pw.SizedBox(height: 8),
          pw.TableHelper.fromTextArray(
            headers: <String>['Product', 'Revenue (LKR)', 'Share'],
            data: <List<String>>[
              for (int i = 0; i < data.categoryLabels.length; i++)
                <String>[
                  data.categoryLabels[i],
                  data.categoryValuesLkr[i].toStringAsFixed(2),
                  data.totalCategoryLkr <= 0
                      ? '0%'
                      : '${(100 * data.categoryValuesLkr[i] / data.totalCategoryLkr).toStringAsFixed(1)}%',
                ],
            ],
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
              fontSize: 9,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            cellAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: _brandBlue),
            border: pw.TableBorder.all(color: _border, width: 0.5),
            cellHeight: 22,
          ),
        ],
      ),
    );

    return doc;
  }

  static pw.Widget _letterhead({
    required MndReportParty mnd,
    required ShopReportParty shop,
    required pw.MemoryImage? logo,
    required String rangeLabel,
    required String generatedAt,
    required bool isFirstPage,
  }) {
    if (!isFirstPage) {
      return pw.Container(
        margin: const pw.EdgeInsets.only(bottom: 12),
        padding: const pw.EdgeInsets.only(bottom: 6),
        decoration: const pw.BoxDecoration(
          border: pw.Border(bottom: pw.BorderSide(color: _border, width: 0.8)),
        ),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: <pw.Widget>[
            pw.Text(
              mnd.name,
              style: pw.TextStyle(
                fontSize: 9,
                fontWeight: pw.FontWeight.bold,
                color: _brandBlue,
              ),
            ),
            pw.Text(
              shop.name,
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: _border),
            borderRadius: pw.BorderRadius.circular(8),
            color: PdfColors.grey100,
          ),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    if (logo != null) ...<pw.Widget>[
                      pw.Container(
                        width: 42,
                        height: 42,
                        child: pw.Image(logo, fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 10),
                    ],
                    pw.Expanded(
                      child: _partyBlock(
                        title: mnd.name,
                        subtitle: mnd.tagline,
                        lines: <String>[
                          if (mnd.phone.trim().isNotEmpty) mnd.phone.trim(),
                          if (mnd.email.trim().isNotEmpty) mnd.email.trim(),
                        ],
                        alignEnd: false,
                        accent: true,
                      ),
                    ),
                  ],
                ),
              ),
              pw.Container(
                width: 1,
                height: 58,
                margin: const pw.EdgeInsets.symmetric(horizontal: 12),
                color: _border,
              ),
              pw.Expanded(
                child: _partyBlock(
                  title: shop.name,
                  subtitle: shop.addressBlock.isEmpty
                      ? 'Partner shop'
                      : shop.addressBlock,
                  lines: <String>[
                    if (shop.phone.trim().isNotEmpty) shop.phone.trim(),
                    if (shop.email.trim().isNotEmpty) shop.email.trim(),
                  ],
                  alignEnd: true,
                  accent: false,
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Sales Report — $rangeLabel',
          style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 2),
        pw.Text(
          'Generated: $generatedAt',
          style: const pw.TextStyle(fontSize: 9, color: _muted),
        ),
        pw.SizedBox(height: 4),
        pw.Divider(color: _brandBlue, thickness: 1.5),
      ],
    );
  }

  static pw.Widget _partyBlock({
    required String title,
    required String subtitle,
    required List<String> lines,
    required bool alignEnd,
    required bool accent,
  }) {
    final pw.CrossAxisAlignment cross = alignEnd
        ? pw.CrossAxisAlignment.end
        : pw.CrossAxisAlignment.start;
    final pw.TextAlign textAlign =
        alignEnd ? pw.TextAlign.right : pw.TextAlign.left;
    return pw.Column(
      crossAxisAlignment: cross,
      children: <pw.Widget>[
        pw.Text(
          title,
          textAlign: textAlign,
          style: pw.TextStyle(
            fontSize: 13,
            fontWeight: pw.FontWeight.bold,
            color: accent ? _brandBlue : PdfColors.black,
          ),
        ),
        if (subtitle.isNotEmpty) ...<pw.Widget>[
          pw.SizedBox(height: 2),
          pw.Text(
            subtitle,
            textAlign: textAlign,
            style: const pw.TextStyle(fontSize: 9, color: _muted),
          ),
        ],
        for (final String line in lines)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text(
              line,
              textAlign: textAlign,
              style: const pw.TextStyle(fontSize: 9),
            ),
          ),
      ],
    );
  }

  static pw.Widget _sectionTitle(String title) {
    return pw.Text(
      title,
      style: pw.TextStyle(
        fontSize: 12,
        fontWeight: pw.FontWeight.bold,
        color: _brandBlue,
      ),
    );
  }

  static pw.Widget _metricBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: _border),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: <pw.Widget>[
            pw.Text(
              label,
              style: const pw.TextStyle(fontSize: 8, color: _muted),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _money(double value) => 'Rs. ${value.toStringAsFixed(2)}';

  /// Today analytics is hourly in-app; PDF should show one day total row only.
  static List<DailySalesPoint> _salesTimelineRows(VendorReportSnapshot data) {
    final List<DailySalesPoint> days = data.last7Days;
    final bool isToday = data.rangeLabel == 'Today';
    final bool hourly = days.any(
      (DailySalesPoint d) => d.dateKey.trim().contains(' '),
    );
    if (!isToday && !hourly) {
      return days;
    }

    String dateKey = '';
    for (final DailySalesPoint day in days) {
      final String key = day.dateKey.trim();
      if (key.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(key)) {
        dateKey = key.substring(0, 10);
        break;
      }
    }
    if (dateKey.isEmpty) {
      final DateTime now = DateTime.now().toUtc();
      dateKey =
          '${now.year.toString().padLeft(4, '0')}-'
          '${now.month.toString().padLeft(2, '0')}-'
          '${now.day.toString().padLeft(2, '0')}';
    }

    return <DailySalesPoint>[
      DailySalesPoint(
        shortLabel: dateKey,
        dateKey: dateKey,
        grossLkr: data.grossLkr,
        orders: data.completedOrders,
        cancelledOrders: data.cancelledOrders,
      ),
    ];
  }

  /// Prefer `YYYY-MM-DD`.
  static String _pdfDate(DailySalesPoint day) {
    final String key = day.dateKey.trim();
    if (key.length >= 10 && RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(key)) {
      return key.substring(0, 10);
    }
    return day.shortLabel;
  }
}
