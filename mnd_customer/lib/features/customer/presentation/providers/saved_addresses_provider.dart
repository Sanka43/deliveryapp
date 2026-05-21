import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';

/// Live list of saved addresses for the signed-in user (empty if not signed in).
final StreamProvider<List<SavedAddress>> savedAddressesStreamProvider =
    StreamProvider<List<SavedAddress>>((Ref ref) {
  final FirebaseAuth auth = ref.watch(firebaseAuthProvider);
  final FirebaseFirestore db = ref.watch(firestoreProvider);

  return auth.authStateChanges().asyncExpand((User? user) {
    if (user == null) {
      return Stream<List<SavedAddress>>.value(const <SavedAddress>[]);
    }
    return db
        .collection(FirebaseCollections.customers)
        .doc(user.uid)
        .collection(FirebaseCollections.savedAddresses)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map(
      (QuerySnapshot<Map<String, dynamic>> snapshot) {
        return snapshot.docs.map(SavedAddress.fromFirestore).toList(growable: false);
      },
    );
  });
});

final Provider<SavedAddressesActions> savedAddressesActionsProvider =
    Provider<SavedAddressesActions>((Ref ref) {
  return SavedAddressesActions(ref);
});

class SavedAddressesActions {
  SavedAddressesActions(this._ref);

  final Ref _ref;

  String? get _uid => _ref.read(firebaseAuthProvider).currentUser?.uid;

  CollectionReference<Map<String, dynamic>>? get _col {
    final String? uid = _uid;
    if (uid == null) {
      return null;
    }
    return _ref.read(firestoreProvider).collection(FirebaseCollections.customers).doc(uid).collection(
          FirebaseCollections.savedAddresses,
        );
  }

  Future<String?> addAddress({
    required String label,
    required String line1,
    required String line2,
    required String city,
    required String phone,
    bool setAsDefault = false,
  }) async {
    final CollectionReference<Map<String, dynamic>>? col = _col;
    if (col == null) {
      return 'Sign in to save addresses.';
    }
    try {
      final DocumentReference<Map<String, dynamic>> doc = await col.add(
        SavedAddress(
          id: '',
          label: label,
          line1: line1,
          line2: line2,
          city: city,
          phone: phone,
          isDefault: setAsDefault,
        ).toFirestore(includeCreatedAt: true),
      );
      if (setAsDefault) {
        await setDefaultAddress(doc.id);
      }
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not save address.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> updateAddress({
    required String id,
    required String label,
    required String line1,
    required String line2,
    required String city,
    required String phone,
    required bool isDefault,
  }) async {
    final CollectionReference<Map<String, dynamic>>? col = _col;
    if (col == null) {
      return 'Sign in to update addresses.';
    }
    try {
      await col.doc(id).update(
            SavedAddress(
              id: id,
              label: label,
              line1: line1,
              line2: line2,
              city: city,
              phone: phone,
              isDefault: isDefault,
            ).toFirestore(includeCreatedAt: false),
          );
      if (isDefault) {
        await setDefaultAddress(id);
      }
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not update address.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> deleteAddress(String id) async {
    final CollectionReference<Map<String, dynamic>>? col = _col;
    if (col == null) {
      return 'Sign in to delete addresses.';
    }
    try {
      await col.doc(id).delete();
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not delete address.';
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> setDefaultAddress(String id) async {
    final CollectionReference<Map<String, dynamic>>? col = _col;
    if (col == null) {
      return 'Sign in to set default.';
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> snap = await col.get();
      final WriteBatch batch = _ref.read(firestoreProvider).batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
        batch.update(doc.reference, <String, dynamic>{
          'isDefault': doc.id == id,
        });
      }
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return e.message ?? 'Could not set default.';
    } catch (e) {
      return e.toString();
    }
  }
}
