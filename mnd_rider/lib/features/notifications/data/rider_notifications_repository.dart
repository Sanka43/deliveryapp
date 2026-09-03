import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/core/constants/firebase_collections.dart';

class RiderInboxNotification {
  const RiderInboxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.read,
    this.orderId,
    this.tripId,
    this.amountLkr,
    this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final bool read;
  final String? orderId;
  final String? tripId;
  final int? amountLkr;
  final DateTime? createdAt;

  factory RiderInboxNotification.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    final dynamic created = data['createdAt'];
    final dynamic amount = data['amountLkr'];
    return RiderInboxNotification(
      id: id,
      type: (data['type'] as String?)?.trim() ?? '',
      title: (data['title'] as String?)?.trim() ?? '',
      body: (data['body'] as String?)?.trim() ?? '',
      read: data['read'] == true,
      orderId: (data['orderId'] as String?)?.trim(),
      tripId: (data['tripId'] as String?)?.trim(),
      amountLkr: amount is int
          ? amount
          : (amount is num ? amount.round() : null),
      createdAt: created is Timestamp ? created.toDate() : null,
    );
  }
}

final Provider<RiderNotificationsRepository> riderNotificationsRepositoryProvider =
    Provider<RiderNotificationsRepository>((Ref ref) {
  return RiderNotificationsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class RiderNotificationsRepository {
  RiderNotificationsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  CollectionReference<Map<String, dynamic>>? get _inbox {
    final User? u = _auth.currentUser;
    if (u == null) {
      return null;
    }
    return _firestore
        .collection(FirebaseCollections.riders)
        .doc(u.uid)
        .collection(FirebaseCollections.riderNotifications);
  }

  Stream<List<RiderInboxNotification>> watchInbox({int limit = 60}) {
    final CollectionReference<Map<String, dynamic>>? col = _inbox;
    if (col == null) {
      return Stream<List<RiderInboxNotification>>.value(
        const <RiderInboxNotification>[],
      );
    }
    return col
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    RiderInboxNotification.fromDoc(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount() {
    final CollectionReference<Map<String, dynamic>>? col = _inbox;
    if (col == null) {
      return Stream<int>.value(0);
    }
    return col.where('read', isEqualTo: false).limit(40).snapshots().map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.size,
        );
  }

  Future<void> markRead(String notificationId) async {
    final CollectionReference<Map<String, dynamic>>? col = _inbox;
    if (col == null) {
      return;
    }
    final String id = notificationId.trim();
    if (id.isEmpty) {
      return;
    }
    await col.doc(id).update(<String, dynamic>{'read': true});
  }

  Future<void> markAllRead(List<String> ids) async {
    final CollectionReference<Map<String, dynamic>>? col = _inbox;
    if (col == null || ids.isEmpty) {
      return;
    }
    final WriteBatch batch = _firestore.batch();
    for (final String id in ids) {
      final String trimmed = id.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      batch.update(col.doc(trimmed), <String, dynamic>{'read': true});
    }
    await batch.commit();
  }
}

final StreamProvider<List<RiderInboxNotification>> riderInboxNotificationsProvider =
    StreamProvider<List<RiderInboxNotification>>((Ref ref) {
  return ref.watch(riderNotificationsRepositoryProvider).watchInbox();
});

final StreamProvider<int> riderUnreadNotificationCountProvider =
    StreamProvider<int>((Ref ref) {
  return ref.watch(riderNotificationsRepositoryProvider).watchUnreadCount();
});
