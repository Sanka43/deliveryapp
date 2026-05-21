import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// SharedPreferences key for optional manual store id on this device.
const String kVendorStoreIdPreferenceKey = 'vendor_store_id';

class VendorStoreIdNotifier extends AsyncNotifier<String> {

  @override
  Future<String> build() async {
    ref.listen<AsyncValue<User?>>(shopAuthStateProvider, (AsyncValue<User?>? previous, AsyncValue<User?> next) {
      final User? prevUser = previous?.valueOrNull;
      final User? nextUser = next.valueOrNull;
      if (nextUser == null) {
        if (prevUser != null) {
          _clearStoredId();
        }
        return;
      }
      if (prevUser != null && prevUser.uid != nextUser.uid) {
        _clearStoredId();
      }
    });

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString(kVendorStoreIdPreferenceKey)?.trim() ?? '';
  }

  Future<void> _clearStoredId() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(kVendorStoreIdPreferenceKey);
    state = const AsyncData<String>('');
  }

  Future<void> setStoreId(String value) async {
    final String v = value.trim();
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (v.isEmpty) {
      await prefs.remove(kVendorStoreIdPreferenceKey);
    } else {
      await prefs.setString(kVendorStoreIdPreferenceKey, v);
    }
    state = AsyncData(v);
  }
}

final vendorStoreIdProvider =
    AsyncNotifierProvider<VendorStoreIdNotifier, String>(VendorStoreIdNotifier.new);
