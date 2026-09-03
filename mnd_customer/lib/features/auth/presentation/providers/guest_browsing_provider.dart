import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kGuestBrowsingPrefsKey = 'guest_browsing';

/// When true, unauthenticated users may open customer routes (browse mode).
final StateProvider<bool> guestBrowsingProvider =
    StateProvider<bool>((Ref ref) => false);

/// After guest signs in, resume this route (e.g. checkout). Cleared on use.
final StateProvider<String?> postAuthRedirectProvider =
    StateProvider<String?>((Ref ref) => null);

/// Persists guest browsing across process restarts.
final Provider<void> guestBrowsingPersistenceProvider = Provider<void>((Ref ref) {
  ref.listen<bool>(guestBrowsingProvider, (bool? previous, bool next) {
    SharedPreferences.getInstance().then((SharedPreferences prefs) {
      prefs.setBool(kGuestBrowsingPrefsKey, next);
    });
  });
});
