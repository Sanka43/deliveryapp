import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/ratings/data/vendor_ratings_repository.dart';
import 'package:mnd_shop/features/ratings/domain/vendor_review.dart';

final StreamProvider<List<VendorReview>> vendorReviewsListProvider =
    StreamProvider<List<VendorReview>>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<List<VendorReview>>.value(const <VendorReview>[]);
  }
  return ref.watch(vendorRatingsRepositoryProvider).watchReviews(storeId);
});

final StreamProvider<VendorRatingSummary> vendorRatingSummaryProvider =
    StreamProvider<VendorRatingSummary>((Ref ref) {
  final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
  if (storeId.isEmpty) {
    return Stream<VendorRatingSummary>.value(VendorRatingSummary.zero);
  }
  return ref.watch(vendorRatingsRepositoryProvider).watchSummary(storeId);
});
