import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mnd_rider/features/reports/domain/rider_report_data.dart';
import 'package:mnd_rider/features/reports/pdf/rider_report_pdf_builder.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

/// Renders the report PDF on screen — with print/share built into the
/// preview's own action bar — before the rider decides to send it anywhere.
class RiderReportPreviewPage extends StatelessWidget {
  const RiderReportPreviewPage({super.key, required this.args});

  final RiderReportPreviewArgs args;

  String get _fileName {
    final DateFormat fmt = DateFormat('yyyyMMdd');
    return 'mnd-rider-report-${fmt.format(args.data.start)}-${fmt.format(args.data.end)}.pdf';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report preview')),
      body: PdfPreview(
        build: (PdfPageFormat format) => RiderReportPdfBuilder.build(
          data: args.data,
          riderName: args.riderName,
          riderPhone: args.riderPhone,
          vehicleNumber: args.vehicleNumber,
        ),
        pdfFileName: _fileName,
        canChangePageFormat: false,
        canChangeOrientation: false,
        canDebug: false,
        useActions: true,
      ),
    );
  }
}
