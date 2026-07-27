import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';

class VendorAccountDeletionRepository {
  VendorAccountDeletionRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<void> requestDeletion({String reason = ''}) async {
    try {
      await _functions.httpsCallable('requestVendorAccountDeletion').call(
        <String, dynamic>{'reason': reason.trim()},
      );
    } on FirebaseFunctionsException catch (e) {
      throw VendorAccountDeletionException(_mapError(e));
    } catch (_) {
      throw const VendorAccountDeletionException(
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
        return 'Vendor account not found. Contact support.';
      case 'permission-denied':
        return 'This shop account cannot be deleted from this login.';
      case 'unavailable':
        return 'Service unavailable. Try again shortly.';
      default:
        return 'Something went wrong. Try again.';
    }
  }
}

class VendorAccountDeletionException implements Exception {
  const VendorAccountDeletionException(this.message);

  final String message;

  @override
  String toString() => message;
}

final Provider<VendorAccountDeletionRepository>
    vendorAccountDeletionRepositoryProvider =
    Provider<VendorAccountDeletionRepository>((Ref ref) {
  return VendorAccountDeletionRepository(ref.watch(firebaseFunctionsProvider));
});
