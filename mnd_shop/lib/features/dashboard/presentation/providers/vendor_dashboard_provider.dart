import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_sales_summary.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';

/// Live sales KPIs derived from the vendor order board Firestore snapshot.
final Provider<VendorSalesSummary> vendorSalesSummaryProvider =
    Provider<VendorSalesSummary>((Ref ref) {
  return ref.watch(vendorOrderBoardProvider).maybeWhen(
        data: (board) => board.salesSummary,
        orElse: () => VendorSalesSummary.zero,
      );
});
