import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/support/domain/vendor_support_message.dart';

final Provider<VendorSupportRepository> vendorSupportRepositoryProvider =
    Provider<VendorSupportRepository>((Ref ref) {
  return VendorSupportRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// One support chat thread per shop: `vendor_support_threads/{uid}` with a
/// `messages` subcollection. Thread aggregate fields (last message, unread
/// counters) are owned by the `onVendorSupportMessageCreated` Cloud Function,
/// same pattern as the customer app's `SupportRepository`.
class VendorSupportRepository {
  VendorSupportRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
  })  : _firestore = firestore,
        _auth = auth;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  DocumentReference<Map<String, dynamic>>? get _thread {
    final User? user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    return _firestore
        .collection(FirebaseCollections.vendorSupportThreads)
        .doc(user.uid);
  }

  Stream<List<VendorSupportMessage>> watchMessages({int limit = 200}) {
    final DocumentReference<Map<String, dynamic>>? thread = _thread;
    if (thread == null) {
      return Stream<List<VendorSupportMessage>>.value(const <VendorSupportMessage>[]);
    }
    return thread
        .collection(FirebaseCollections.vendorSupportMessages)
        .orderBy('createdAt')
        .limitToLast(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    VendorSupportMessage.fromFirestore(d.id, d.data()),
              )
              .toList(growable: false),
        );
  }

  Stream<int> watchUnreadCount() {
    final DocumentReference<Map<String, dynamic>>? thread = _thread;
    if (thread == null) {
      return Stream<int>.value(0);
    }
    return thread.snapshots().map((DocumentSnapshot<Map<String, dynamic>> snap) {
      final dynamic count = snap.data()?['unreadByVendor'];
      return count is int ? count : 0;
    });
  }

  Future<String?> sendMessage(String text) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return 'Sign in first.';
    }
    final String trimmed = text.trim();
    if (trimmed.isEmpty) {
      return null;
    }
    if (trimmed.length > 2000) {
      return 'Message is too long.';
    }
    try {
      await _firestore
          .collection(FirebaseCollections.vendorSupportThreads)
          .doc(user.uid)
          .collection(FirebaseCollections.vendorSupportMessages)
          .add(<String, dynamic>{
        'senderId': user.uid,
        'senderType': 'vendor',
        'text': trimmed,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return null;
    } on FirebaseException catch (e) {
      return userFacingError(e, fallback: 'Could not send message.');
    } catch (e) {
      return userFacingError(e, fallback: 'Could not send message.');
    }
  }

  /// Clears the staff-reply unread badge. No-op (silently) before the thread
  /// doc exists — nothing to clear yet.
  Future<void> markThreadRead() async {
    final DocumentReference<Map<String, dynamic>>? thread = _thread;
    if (thread == null) {
      return;
    }
    try {
      await thread.update(<String, dynamic>{'unreadByVendor': 0});
    } catch (_) {
      // Best-effort — thread may not exist yet, or a race with the trigger.
    }
  }
}
