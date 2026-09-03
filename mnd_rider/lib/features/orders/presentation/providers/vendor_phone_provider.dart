import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';

/// Shop contact phone from `vendors/{vendorId}` (public read).
final AutoDisposeStreamProviderFamily<String?, String> vendorPhoneProvider =
    StreamProvider.autoDispose.family<String?, String>((Ref ref, String vendorId) {
  final String id = vendorId.trim();
  if (id.isEmpty) {
    return Stream<String?>.value(null);
  }
  return ref
      .watch(firestoreProvider)
      .collection(FirebaseCollections.vendors)
      .doc(id)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snap) {
    final Map<String, dynamic>? data = snap.data();
    if (data == null) {
      return null;
    }
    final String phone = (data['phone'] as String?)?.trim() ??
        (data['phoneNumber'] as String?)?.trim() ??
        (data['whatsapp'] as String?)?.trim() ??
        '';
    return phone.isEmpty ? null : phone;
  });
});
