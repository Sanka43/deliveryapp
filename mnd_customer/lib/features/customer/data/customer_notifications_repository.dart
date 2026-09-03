import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_notification.dart';

final Provider<CustomerNotificationsRepository>
    customerNotificationsRepositoryProvider =
    Provider<CustomerNotificationsRepository>((Ref ref) {
  return CustomerNotificationsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// Firestore top-level `notifications` filtered by `userId` (auth uid).
class CustomerNotificationsRepository {
  CustomerNotificationsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirebaseCollections.notifications);

  Stream<List<CustomerNotification>> watchNotifications() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<List<CustomerNotification>>.value(
        const <CustomerNotification>[],
      );
    }
    final String uid = user.uid.trim();
    if (uid.isEmpty) {
      return Stream<List<CustomerNotification>>.value(
        const <CustomerNotification>[],
      );
    }

    return _notifications
        .where('userId', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(80)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
      return snap.docs
          .map(
            (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                CustomerNotification.fromFirestore(d.id, d.data()),
          )
          .toList(growable: false);
    });
  }

  Stream<int> watchUnreadCount() {
    final User? user = _auth.currentUser;
    if (user == null) {
      return Stream<int>.value(0);
    }
    final String uid = user.uid.trim();
    if (uid.isEmpty) {
      return Stream<int>.value(0);
    }

    return _notifications
        .where('userId', isEqualTo: uid)
        .where('read', isEqualTo: false)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> s) => s.docs.length);
  }

  Future<String?> markRead(String notificationId) async {
    if (_auth.currentUser == null) {
      return 'Sign in first.';
    }
    final String nid = notificationId.trim();
    if (nid.isEmpty) {
      return 'Invalid notification.';
    }
    try {
      await _notifications.doc(nid).set(
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

  Future<String?> markAllRead() async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return 'Sign in first.';
    }
    final String uid = user.uid.trim();
    if (uid.isEmpty) {
      return 'Sign in first.';
    }
    try {
      final QuerySnapshot<Map<String, dynamic>> unread = await _notifications
          .where('userId', isEqualTo: uid)
          .where('read', isEqualTo: false)
          .limit(100)
          .get();
      if (unread.docs.isEmpty) {
        return null;
      }
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
