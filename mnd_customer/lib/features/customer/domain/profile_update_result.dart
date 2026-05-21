class ProfileUpdateResult {
  const ProfileUpdateResult._({required this.success, this.errorMessage});

  const ProfileUpdateResult.success() : this._(success: true, errorMessage: null);

  factory ProfileUpdateResult.failure(String message) {
    return ProfileUpdateResult._(success: false, errorMessage: message);
  }

  final bool success;
  final String? errorMessage;
}
