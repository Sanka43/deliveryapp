import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persisted after role resolves so the next cold start can leave splash instantly.
const String kLastUserRolePrefsKey = 'mnd_last_user_role';

/// Seeded at bootstrap from SharedPreferences; updated when [userRoleProvider] emits.
final StateProvider<String?> cachedUserRoleProvider =
    StateProvider<String?>((Ref ref) => null);

/// Writes resolved roles to disk + [cachedUserRoleProvider].
final Provider<void> userRolePersistenceProvider = Provider<void>((Ref ref) {
  ref.listen<AsyncValue<String?>>(userRoleProvider, (
    AsyncValue<String?>? previous,
    AsyncValue<String?> next,
  ) {
    final String? role = next.valueOrNull?.trim().toLowerCase();
    if (role == null || role.isEmpty) {
      return;
    }
    if (ref.read(cachedUserRoleProvider) != role) {
      ref.read(cachedUserRoleProvider.notifier).state = role;
    }
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setString(kLastUserRolePrefsKey, role);
    });
  });
});

/// Resolves role from `customers/{uid}`, then `vendors/{uid}`, then `riders/{uid}`.
///
/// Watches [authStateUserProvider] so the stream rebinds after sign-in / sign-out.
final StreamProvider<String?> userRoleProvider =
    StreamProvider<String?>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<String?>.value(null);
  }

  final FirebaseFirestore firestore = ref.watch(firestoreProvider);

  return firestore
      .collection(FirebaseCollections.customers)
      .doc(user.uid)
      .snapshots()
      .asyncExpand((DocumentSnapshot<Map<String, dynamic>> userSnap) {
    final String? roleFromUser =
        (userSnap.data()?['role'] as String?)?.trim().toLowerCase();
    if (roleFromUser != null && roleFromUser.isNotEmpty) {
      return Stream<String?>.value(roleFromUser);
    }
    return firestore
        .collection(FirebaseCollections.vendors)
        .doc(user.uid)
        .snapshots()
        .asyncExpand((DocumentSnapshot<Map<String, dynamic>> vSnap) {
      final String? roleFromVendor =
          (vSnap.data()?['role'] as String?)?.trim().toLowerCase();
      if (roleFromVendor != null && roleFromVendor.isNotEmpty) {
        return Stream<String?>.value(roleFromVendor);
      }
      if (vSnap.exists) {
        return Stream<String?>.value('vendor');
      }
      return firestore
          .collection(FirebaseCollections.riders)
          .doc(user.uid)
          .snapshots()
          .map((DocumentSnapshot<Map<String, dynamic>> rSnap) {
        if (!rSnap.exists) {
          return null;
        }
        final String? roleFromRider =
            (rSnap.data()?['role'] as String?)?.trim().toLowerCase();
        if (roleFromRider != null && roleFromRider.isNotEmpty) {
          return roleFromRider;
        }
        return 'rider';
      });
    });
  });
});
