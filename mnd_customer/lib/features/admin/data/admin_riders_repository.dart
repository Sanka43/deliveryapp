import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';

final Provider<AdminRidersRepository> adminRidersRepositoryProvider =
    Provider<AdminRidersRepository>((Ref ref) {
  return AdminRidersRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class AdminRiderRow {
  const AdminRiderRow({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.city,
    required this.vehicleType,
    required this.vehicleNumber,
    required this.status,
    this.profilePhotoUrl,
    this.licensePhotoUrl,
  });

  final String uid;
  final String fullName;
  final String phone;
  final String city;
  final String vehicleType;
  final String vehicleNumber;
  final String status;
  final String? profilePhotoUrl;
  final String? licensePhotoUrl;

  bool get isPending => status.toLowerCase() == 'pending';

  factory AdminRiderRow.fromDoc(String id, Map<String, dynamic> data) {
    return AdminRiderRow(
      uid: id,
      fullName: (data['fullName'] as String?)?.trim() ?? '',
      phone: (data['phone'] as String?)?.trim() ?? '',
      city: (data['city'] as String?)?.trim() ?? '',
      vehicleType: (data['vehicleType'] as String?)?.trim() ?? '',
      vehicleNumber: (data['vehicleNumber'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'pending',
      profilePhotoUrl: (data['profilePhotoUrl'] as String?)?.trim(),
      licensePhotoUrl: (data['licensePhotoUrl'] as String?)?.trim(),
    );
  }
}

class AdminRidersRepository {
  AdminRidersRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<AdminRiderRow>> watchRiders({String status = 'pending'}) {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<List<AdminRiderRow>>.value(const <AdminRiderRow>[]);
    }
    return _firestore
        .collection(FirebaseCollections.riders)
        .where('status', isEqualTo: status)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) {
            final List<AdminRiderRow> rows = snap.docs
                .map(
                  (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                      AdminRiderRow.fromDoc(d.id, d.data()),
                )
                .toList();
            rows.sort(
              (AdminRiderRow a, AdminRiderRow b) =>
                  a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()),
            );
            return rows;
          },
        );
  }

  Future<String?> setRiderStatus({
    required String riderId,
    required String status,
  }) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return 'Not signed in';
    }
    final String normalized = status.trim().toLowerCase();
    if (normalized != 'approved' &&
        normalized != 'rejected' &&
        normalized != 'pending') {
      return 'Invalid status';
    }
    try {
      await _firestore.collection(FirebaseCollections.riders).doc(riderId).set(
        <String, dynamic>{
          'status': normalized,
          'online': false,
          if (normalized == 'approved') 'approvedAt': FieldValue.serverTimestamp(),
          if (normalized == 'rejected') 'rejectedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
