import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/reports/domain/vendor_report_snapshot.dart';

/// Replace with a Future/Stream provider when wiring orders / analytics.
final Provider<VendorReportSnapshot> vendorReportsProvider =
    Provider<VendorReportSnapshot>((Ref ref) {
  return VendorReportSnapshot.demo();
});
