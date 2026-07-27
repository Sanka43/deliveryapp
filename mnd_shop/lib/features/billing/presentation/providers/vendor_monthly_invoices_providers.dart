import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/billing/data/vendor_monthly_invoices_repository.dart';
import 'package:mnd_shop/features/billing/domain/vendor_monthly_invoice.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';

final StreamProvider<List<VendorMonthlyInvoice>>
    vendorMonthlyInvoicesListProvider =
    StreamProvider<List<VendorMonthlyInvoice>>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<List<VendorMonthlyInvoice>>.value(
      const <VendorMonthlyInvoice>[],
    );
  }
  return ref
      .watch(vendorMonthlyInvoicesRepositoryProvider)
      .watchInvoices(storeId);
});
