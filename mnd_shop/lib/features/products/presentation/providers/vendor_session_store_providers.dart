import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_id_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Signed-in vendor's `vendors/{uid}` document (shop registration + storefront).
/// Self-serve shops do not use `customers/{uid}`.
final StreamProvider<Map<String, dynamic>?> vendorAccountDocDataProvider =
    StreamProvider<Map<String, dynamic>?>((Ref ref) {
  final FirebaseAuth auth = ref.watch(firebaseAuthProvider);
  return auth.authStateChanges().asyncExpand((User? user) {
    if (user == null) {
      return Stream<Map<String, dynamic>?>.value(null);
    }
    final FirebaseFirestore fs = ref.read(firestoreProvider);
    return fs
        .collection(FirebaseCollections.vendors)
        .doc(user.uid)
        .snapshots()
        .map((DocumentSnapshot<Map<String, dynamic>> s) => s.data());
  });
});

/// Resolves the Firestore **catalog / orders** store id for the signed-in vendor.
///
/// - Uses `vendors/{authUid}.vendorStoreId` only when `vendors/{thatId}.uid` matches this user
///   (prevents a bad or stale profile link like another shop's id, e.g. `Wvdlm…`).
/// - Then applies device prefs if they match [User.uid] or the resolved linked id.
final AsyncNotifierProvider<VendorCatalogStoreIdNotifier, String> vendorCatalogStoreIdProvider =
    AsyncNotifierProvider<VendorCatalogStoreIdNotifier, String>(VendorCatalogStoreIdNotifier.new);

class VendorCatalogStoreIdNotifier extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    ref.listen<AsyncValue<User?>>(shopAuthStateProvider, (AsyncValue<User?>? prev, AsyncValue<User?> next) => ref.invalidateSelf());
    ref.listen<AsyncValue<Map<String, dynamic>?>>(vendorAccountDocDataProvider,
        (AsyncValue<Map<String, dynamic>?>? prev, AsyncValue<Map<String, dynamic>?> next) => ref.invalidateSelf());
    ref.listen<AsyncValue<String>>(vendorStoreIdProvider, (AsyncValue<String>? prev, AsyncValue<String> next) => ref.invalidateSelf());

    final User? user = ref.watch(shopAuthStateProvider).valueOrNull;
    if (user == null) {
      return '';
    }
    final String uid = user.uid.trim();
    final Map<String, dynamic>? map = await ref.watch(vendorAccountDocDataProvider.future);

    String base = uid;
    final String? profileVs = (map?['vendorStoreId'] as String?)?.trim();
    if (profileVs != null && profileVs.isNotEmpty && profileVs != uid) {
      final DocumentSnapshot<Map<String, dynamic>> link = await ref
          .read(firestoreProvider)
          .collection(FirebaseCollections.vendors)
          .doc(profileVs)
          .get();
      final String? owner = (link.data()?['uid'] as String?)?.trim();
      if (link.exists && owner != null && owner == uid) {
        base = profileVs;
      }
    }

    final String prefs =
        (await SharedPreferences.getInstance()).getString(kVendorStoreIdPreferenceKey)?.trim() ?? '';
    if (prefs.isEmpty) {
      return base;
    }
    if (prefs == uid || prefs == base) {
      return prefs;
    }
    return base;
  }
}

/// **Product / inventory catalogue** in this app is always keyed by [User.uid] (same as
/// `vendors/{uid}` doc id and `products.storeId` from shop registration). Do not use for orders.
final Provider<String> vendorProductCatalogStoreIdProvider = Provider<String>((Ref ref) {
  final User? u = ref.watch(shopAuthStateProvider).valueOrNull;
  if (u == null) {
    return '';
  }
  return u.uid.trim();
});

/// Sync facade: store id for **orders**, vendor doc `active`, prefs — resolved + validated.
/// While the async resolver loads, falls back to [User.uid] (never another account's prefs id).
final Provider<String> vendorEffectiveStoreIdProvider = Provider<String>((Ref ref) {
  final User? user = ref.watch(shopAuthStateProvider).valueOrNull;
  final String uid = user?.uid.trim() ?? '';
  final AsyncValue<String> async = ref.watch(vendorCatalogStoreIdProvider);
  return async.when(
    data: (String id) => id,
    loading: () => uid,
    error: (_, StackTrace _) => uid,
  );
});

/// Dashboard / header label from `vendors/{uid}.name` (or legacy `displayName` if present).
final Provider<String> vendorShopDisplayNameProvider = Provider<String>((Ref ref) {
  ref.watch(shopAuthStateProvider);
  final Map<String, dynamic>? map = ref.watch(vendorAccountDocDataProvider).valueOrNull;
  final String name = (map?['name'] as String?)?.trim() ?? '';
  if (name.isNotEmpty) {
    return name;
  }
  final String dn = (map?['displayName'] as String?)?.trim() ?? '';
  if (dn.isNotEmpty) {
    return dn;
  }
  return 'Your shop';
});
