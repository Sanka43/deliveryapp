import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/features/support/domain/entities/support_message.dart';

final Provider<SupportRepository> supportRepositoryProvider =
    Provider<SupportRepository>((Ref ref) {
  return SupportRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

/// One support chat thread per customer: `support_threads/{uid}` with a
/// `messages` subcollection. Thread aggregate fields (last message, unread
/// counters) are owned by the `onSupportMessageCreated` Cloud Function so a
/// staff reply added directly from the Firebase console — there is no admin
/// app yet — still updates them correctly.
class SupportRepository {
  SupportRepository({
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
        .collection(FirebaseCollections.supportThreads)
        .doc(user.uid);
  }

  Stream<List<SupportMessage>> watchMessages({int limit = 200}) {
    final DocumentReference<Map<String, dynamic>>? thread = _thread;
    if (thread == null) {
      return Stream<List<SupportMessage>>.value(const <SupportMessage>[]);
    }
    return thread
        .collection(FirebaseCollections.supportMessages)
        .orderBy('createdAt')
        .limitToLast(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    SupportMessage.fromFirestore(d.id, d.data()),
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
      final dynamic count = snap.data()?['unreadByCustomer'];
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
          .collection(FirebaseCollections.supportThreads)
          .doc(user.uid)
          .collection(FirebaseCollections.supportMessages)
          .add(<String, dynamic>{
        'senderId': user.uid,
        'senderType': 'customer',
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
      await thread.update(<String, dynamic>{'unreadByCustomer': 0});
    } catch (_) {
      // Best-effort — thread may not exist yet, or a race with the trigger.
    }
  }
}

final StreamProvider<List<SupportMessage>> supportMessagesProvider =
    StreamProvider<List<SupportMessage>>((Ref ref) {
  ref.watch(authStateUserProvider);
  return ref.watch(supportRepositoryProvider).watchMessages();
});

final StreamProvider<int> supportUnreadCountProvider =
    StreamProvider<int>((Ref ref) {
  ref.watch(authStateUserProvider);
  return ref.watch(supportRepositoryProvider).watchUnreadCount();
});
