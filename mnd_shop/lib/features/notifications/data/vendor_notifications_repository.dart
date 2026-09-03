import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/notifications/domain/vendor_notification.dart';

/// Firestore: `vendors/{vendorId}/notifications/{notificationId}`.
///
/// **Creates**: Prefer Cloud Functions / Admin SDK when orders or approvals occur.
/// Example document:
/// ```json
/// {
///   "title": "New order",
///   "body": "Order #abc · Rs. 1200",
///   "type": "order_new",
///   "read": false,
///   "createdAt": <Timestamp>,
///   "orderId": "<optional order doc id>"
/// }
/// ```
///
/// **Security rules** (sketch — validate against your project):
/// ```
/// match /vendors/{vendorId}/notifications/{nid} {
///   allow read: if request.auth != null &&
///     get(/databases/$(database)/documents/vendors/$(vendorId)).data.uid == request.auth.uid;
///   allow update: if request.auth != null &&
///     get(/databases/$(database)/documents/vendors/$(vendorId)).data.uid == request.auth.uid &&
///     request.resource.data.diff(resource.data).affectedKeys().hasOnly(['read','readAt']);
///   allow create, delete: if false;
/// }
/// ```
final Provider<VendorNotificationsRepository> vendorNotificationsRepositoryProvider =
    Provider<VendorNotificationsRepository>((Ref ref) {
  return VendorNotificationsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class VendorNotificationsRepository {
  VendorNotificationsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _vendors =>
      _firestore.collection(FirebaseCollections.vendors);

  CollectionReference<Map<String, dynamic>> _notifications(String vendorId) {
    return _vendors.doc(vendorId.trim()).collection(FirebaseCollections.vendorNotifications);
  }

  Future<bool> _isAuthorizedVendorId(String vendorId) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return false;
    }
    final String uid = user.uid.trim();
    final String id = vendorId.trim();
    if (id.isEmpty) {
      return false;
    }
    if (id == uid) {
      return true;
    }
    final DocumentSnapshot<Map<String, dynamic>> snap = await _vendors.doc(id).get();
    final String owner = (snap.data()?['uid'] as String?)?.trim() ?? '';
    return snap.exists && owner == uid;
  }

  /// Latest notifications (newest first).
  Stream<List<VendorNotification>> watchNotifications(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty || _auth.currentUser == null) {
      return Stream<List<VendorNotification>>.value(<VendorNotification>[]);
    }
    return _notifications(id)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      return snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                VendorNotification.fromFirestore(d.id, d.data()),
          )
          .toList();
    });
  }

  /// Count of documents with `read != true`.
  Stream<int> watchUnreadCount(String vendorId) {
    final String id = vendorId.trim();
    if (id.isEmpty || _auth.currentUser == null) {
      return Stream<int>.value(0);
    }
    return _notifications(id)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) => s.docs.length);
  }

  Future<String?> markRead({
    required String vendorId,
    required String notificationId,
  }) async {
    if (_auth.currentUser == null) {
      return 'Sign in first.';
    }
    final String v = vendorId.trim();
    final String nid = notificationId.trim();
    if (v.isEmpty || nid.isEmpty) {
      return 'Invalid notification.';
    }
    try {
      final bool ok = await _isAuthorizedVendorId(v);
      if (!ok) {
        return 'Not allowed.';
      }
      await _notifications(v).doc(nid).set(
        <String, dynamic>{
          'read': true,
          'readAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update notification.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update notification.');
    }
  }

  Future<String?> markAllRead(String vendorId) async {
    if (_auth.currentUser == null) {
      return 'Sign in first.';
    }
    final String v = vendorId.trim();
    if (v.isEmpty) {
      return 'No store linked.';
    }
    try {
      final bool ok = await _isAuthorizedVendorId(v);
      if (!ok) {
        return 'Not allowed.';
      }
      final QuerySnapshot<Map<String, dynamic>> unread = await _notifications(v)
          .where('read', isEqualTo: false)
          .limit(100)
          .get();
      final WriteBatch batch = _firestore.batch();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> d in unread.docs) {
        batch.set(
          d.reference,
          <String, dynamic>{
            'read': true,
            'readAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      await batch.commit();
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not update notifications.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not update notifications.');
    }
  }
}
