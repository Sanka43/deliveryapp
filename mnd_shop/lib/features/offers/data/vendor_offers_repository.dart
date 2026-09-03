import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/offers/domain/vendor_offer.dart';

final Provider<VendorOffersRepository> vendorOffersRepositoryProvider =
    Provider<VendorOffersRepository>((Ref ref) {
  return VendorOffersRepository(ref.watch(firestoreProvider));
});

class VendorOffersRepository {
  VendorOffersRepository(this._firestore);

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _offers =>
      _firestore.collection(FirebaseCollections.offers);

  Stream<List<VendorOffer>> watchByStore(String storeId) {
    final String id = storeId.trim();
    if (id.isEmpty) {
      return Stream<List<VendorOffer>>.value(const <VendorOffer>[]);
    }
    return _offers
        .where('storeId', isEqualTo: id)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) =>
              snap.docs.map(VendorOffer.fromDoc).toList(growable: false),
        );
  }

  String allocateOfferId() => _offers.doc().id;

  Future<String> fetchVendorDisplayName(String storeId) async {
    final DocumentSnapshot<Map<String, dynamic>> doc = await _firestore
        .collection(FirebaseCollections.vendors)
        .doc(storeId)
        .get();
    final Map<String, dynamic>? data = doc.data();
    if (data == null) {
      return 'Store';
    }
    final String? name = (data['name'] as String?)?.trim();
    return name != null && name.isNotEmpty ? name : 'Store';
  }

  Future<void> createOffer({
    required String offerId,
    required String storeId,
    required String storeName,
    required String title,
    required String description,
    required String imageUrl,
    required int priceLkr,
    required DateTime endsAt,
    required String createdBy,
    int order = 0,
  }) async {
    final VendorOffer offer = VendorOffer(
      id: offerId,
      storeId: storeId,
      storeName: storeName,
      title: title,
      description: description,
      imageUrl: imageUrl,
      priceLkr: priceLkr,
      endsAt: endsAt,
      status: VendorOfferStatus.pending,
      order: order,
      createdBy: createdBy,
    );
    await _offers.doc(offerId).set(
          offer.toFirestoreCreate(
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp(),
          ),
        );
  }

  /// Any vendor edit resets status to pending (re-approval).
  Future<void> updateOffer({
    required VendorOffer existing,
    required String storeName,
    required String title,
    required String description,
    required String imageUrl,
    required int priceLkr,
    required DateTime endsAt,
    int? order,
  }) async {
    final VendorOffer next = VendorOffer(
      id: existing.id,
      storeId: existing.storeId,
      storeName: storeName,
      title: title,
      description: description,
      imageUrl: imageUrl,
      priceLkr: priceLkr,
      endsAt: endsAt,
      status: VendorOfferStatus.pending,
      order: order ?? existing.order,
      createdBy: existing.createdBy,
    );
    await _offers.doc(existing.id).update(
          next.toFirestoreUpdate(
            updatedAt: FieldValue.serverTimestamp(),
            status: VendorOfferStatus.pending,
          ),
        );
  }

  Future<void> deletePendingOffer(VendorOffer offer) async {
    if (offer.status != VendorOfferStatus.pending) {
      throw StateError('Only pending offers can be deleted by the shop.');
    }
    await _offers.doc(offer.id).delete();
  }
}
