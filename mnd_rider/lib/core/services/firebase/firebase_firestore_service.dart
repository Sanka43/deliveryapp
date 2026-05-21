import 'package:cloud_firestore/cloud_firestore.dart';

/// Access layer for Cloud Firestore collections.
class FirebaseFirestoreService {
  FirebaseFirestoreService(this._firestore);

  final FirebaseFirestore _firestore;

  FirebaseFirestore get instance => _firestore;

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _firestore.collection(path);

  DocumentReference<Map<String, dynamic>> doc(String collection, String id) =>
      _firestore.collection(collection).doc(id);

  Future<void> runTransaction(
    Future<void> Function(Transaction transaction) action,
  ) =>
      _firestore.runTransaction(action);
}
