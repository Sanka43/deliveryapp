import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';

class RiderAccountDeletionRepository {
  RiderAccountDeletionRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<void> requestDeletion({String reason = ''}) async {
    try {
      await _functions.httpsCallable('requestRiderAccountDeletion').call(
        <String, dynamic>{'reason': reason.trim()},
      );
    } on FirebaseFunctionsException catch (e) {
      throw RiderAccountDeletionException(_mapError(e));
    } catch (_) {
      throw const RiderAccountDeletionException(
        'Could not submit the request. Check your connection and try again.',
      );
    }
  }

  String _mapError(FirebaseFunctionsException e) {
    final String? message = e.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (e.code) {
      case 'unauthenticated':
        return 'Sign in again to request account deletion.';
      case 'not-found':
        return 'Rider account not found. Contact support.';
      case 'permission-denied':
        return 'This rider account cannot be deleted from this login.';
      case 'failed-precondition':
        return 'Hand over your collected cash before deleting your account.';
      case 'unavailable':
        return 'Service unavailable. Try again shortly.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}

class RiderAccountDeletionException implements Exception {
  const RiderAccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

final Provider<RiderAccountDeletionRepository>
    riderAccountDeletionRepositoryProvider =
    Provider<RiderAccountDeletionRepository>((Ref ref) {
  return RiderAccountDeletionRepository(ref.watch(firebaseFunctionsProvider));
});
