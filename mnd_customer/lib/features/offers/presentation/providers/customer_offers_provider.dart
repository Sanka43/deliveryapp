import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/offers/domain/customer_offer.dart';

List<CustomerOffer> _liveOffers(List<CustomerOffer> all) {
  final DateTime now = DateTime.now();
  final List<CustomerOffer> live = all
      .where((CustomerOffer o) => o.endsAt.isAfter(now) && o.storeId.isNotEmpty)
      .toList(growable: false);
  live.sort((CustomerOffer a, CustomerOffer b) {
    final int byOrder = a.order.compareTo(b.order);
    if (byOrder != 0) {
      return byOrder;
    }
    return a.endsAt.compareTo(b.endsAt);
  });
  return live;
}

/// Approved offers still within [endsAt] — home banner carousel.
final StreamProvider<List<CustomerOffer>> customerLiveOffersProvider =
    StreamProvider<List<CustomerOffer>>((Ref ref) {
  final FirebaseFirestore firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.offers)
      .where('status', isEqualTo: 'approved')
      .orderBy('order')
      .orderBy('endsAt')
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => _liveOffers(
          snap.docs.map(CustomerOffer.fromDoc).toList(growable: false),
        ),
      );
});

/// Approved live offers for one store — store details page.
final StreamProviderFamily<List<CustomerOffer>, String>
    storeLiveOffersProvider =
    StreamProvider.family<List<CustomerOffer>, String>((Ref ref, String storeId) {
  final String id = storeId.trim();
  if (id.isEmpty) {
    return Stream<List<CustomerOffer>>.value(const <CustomerOffer>[]);
  }
  final FirebaseFirestore firestore = ref.watch(firestoreProvider);
  return firestore
      .collection(FirebaseCollections.offers)
      .where('storeId', isEqualTo: id)
      .where('status', isEqualTo: 'approved')
      .orderBy('endsAt')
      .snapshots()
      .map(
        (QuerySnapshot<Map<String, dynamic>> snap) => _liveOffers(
          snap.docs.map(CustomerOffer.fromDoc).toList(growable: false),
        ),
      );
});
