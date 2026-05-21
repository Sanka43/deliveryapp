import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';

final StreamProvider<User?> riderAuthStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);

/// Notifies [GoRouter] when auth state changes.
final Provider<AuthRedirectNotifier> authRedirectNotifierProvider =
    Provider<AuthRedirectNotifier>((Ref ref) {
  final AuthRedirectNotifier notifier = AuthRedirectNotifier();
  ref.onDispose(notifier.dispose);
  ref.listen<AsyncValue<User?>>(riderAuthStateProvider, (_, __) {
    notifier.notify();
  });
  return notifier;
});

class AuthRedirectNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
