/// Firestore `vendors/{uid}.accountDeletionStatus` values.
abstract final class VendorDeletionStatus {
  static const String pending = 'pending';
  static const String authDeleted = 'auth_deleted';
  static const String completed = 'completed';

  /// Blocks the shell while a deletion request is still being processed.
  static bool blocksAppAccess(Map<String, dynamic>? vendorDoc) {
    return read(vendorDoc) == pending;
  }

  /// Previous shop was closed; vendor may register again with the same login.
  static bool needsReRegistration(Map<String, dynamic>? vendorDoc) {
    final String status = read(vendorDoc);
    return status == authDeleted || status == completed;
  }

  static bool canRequestDeletion(Map<String, dynamic>? vendorDoc) {
    final String status = read(vendorDoc);
    return status.isEmpty;
  }

  static String read(Map<String, dynamic>? vendorDoc) {
    return (vendorDoc?['accountDeletionStatus'] as String?)
            ?.trim()
            .toLowerCase() ??
        '';
  }
}
