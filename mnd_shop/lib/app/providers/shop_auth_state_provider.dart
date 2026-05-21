import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';

final StreamProvider<User?> shopAuthStateProvider = StreamProvider<User?>(
  (Ref ref) => ref.watch(firebaseAuthProvider).authStateChanges(),
);
