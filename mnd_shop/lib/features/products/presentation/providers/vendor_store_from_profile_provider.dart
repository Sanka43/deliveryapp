import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_id_provider.dart';

/// Keeps local prefs aligned with `vendors/{uid}.vendorStoreId` when the doc has it
/// (e.g. after Register on another device, or to undo a pasted wrong vendors/{id} in prefs).
final AutoDisposeFutureProvider<void> vendorStoreFromProfileProvider =
    FutureProvider.autoDispose<void>(
  (Ref ref) async {
    final User? user = ref.watch(firebaseAuthProvider).currentUser;
    if (user == null) {
      return;
    }
    final doc = await ref
        .read(firestoreProvider)
        .collection(FirebaseCollections.vendors)
        .doc(user.uid)
        .get();
    final String? vs = doc.data()?['vendorStoreId'] as String?;
    if (vs == null || vs.trim().isEmpty) {
      return;
    }
    final String t = vs.trim();
    final String local = (await ref.watch(vendorStoreIdProvider.future)).trim();
    if (local != t) {
      await ref.read(vendorStoreIdProvider.notifier).setStoreId(t);
    }
  },
);
