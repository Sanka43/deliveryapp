import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/ratings/domain/vendor_review.dart';

final Provider<VendorRatingsRepository> vendorRatingsRepositoryProvider =
    Provider<VendorRatingsRepository>((Ref ref) {
  return VendorRatingsRepository(firestore: ref.watch(firestoreProvider));
});

/// Reviews are public-visible-read by design (any signed-in user may read a
/// `visible` `store_ratings` doc — see firestore.rules), so no new rule was
/// needed to let vendors see their own; this repository just scopes the
/// query to the signed-in shop's store id.
class VendorRatingsRepository {
  VendorRatingsRepository({required FirebaseFirestore firestore}) : _firestore = firestore;

  final FirebaseFirestore _firestore;

  Stream<List<VendorReview>> watchReviews(String vendorId, {int limit = 100}) {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return Stream<List<VendorReview>>.value(const <VendorReview>[]);
    }
    // The `status` equality filter is required, not optional: firestore.rules
    // grants read only where `resource.data.status == 'visible'`, and
    // Firestore denies a whole list query unless it can prove every possible
    // match satisfies the rule — which it can only do when the query itself
    // filters on that same field. Needs the (vendorId, status, createdAt)
    // composite index declared in firestore.indexes.json.
    return _firestore
        .collection(FirebaseCollections.storeRatings)
        .where('vendorId', isEqualTo: id)
        .where('status', isEqualTo: 'visible')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      return snap.docs
          .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              VendorReview.fromFirestore(d.id, d.data()))
          .toList(growable: false);
    });
  }

  /// Adds or edits the signed-in shop's public reply to one of its own
  /// reviews. Firestore rules only allow this vendor to touch the
  /// `vendorReply`/`vendorReplyAt` fields on a doc it owns — nothing else.
  Future<String?> replyToReview({
    required String reviewId,
    required String reply,
  }) async {
    final String id = reviewId.trim();
    final String text = reply.trim();
    if (id.isEmpty) {
      return 'Missing review.';
    }
    if (text.isEmpty) {
      return 'Enter a reply before sending.';
    }
    if (text.length > 500) {
      return 'Reply is too long (max 500 characters).';
    }
    try {
      await _firestore.collection(FirebaseCollections.storeRatings).doc(id).update(
        <String, dynamic>{
          'vendorReply': text,
          'vendorReplyAt': FieldValue.serverTimestamp(),
        },
      );
      return null;
    } on FirebaseException {
      return 'Could not send your reply now. Please try again.';
    } catch (_) {
      return 'Could not send your reply now. Please try again.';
    }
  }

  Stream<VendorRatingSummary> watchSummary(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return Stream<VendorRatingSummary>.value(VendorRatingSummary.zero);
    }
    return _firestore
        .collection(FirebaseCollections.vendors)
        .doc(id)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> s) =>
            VendorRatingSummary.fromFirestore(s.data()));
  }
}
