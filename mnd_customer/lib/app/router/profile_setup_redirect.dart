import 'package:mnd_delivery_app/core/constants/app_routes.dart';

/// Router decision for the mandatory complete-profile step.
class ProfileSetupRedirect {
  const ProfileSetupRedirect({this.redirectTo, this.pendingToSave});

  /// Where to send the user, or null to fall through to the other rules.
  final String? redirectTo;

  /// Deep target to remember so setup can resume it (e.g. checkout).
  final String? pendingToSave;
}

/// Customers with [setupRequired] == true are held on
/// [AppRoutes.completeProfile]. Null (unknown) never gates, so existing users
/// aren't bounced while their profile loads.
ProfileSetupRedirect profileSetupRedirect({
  required bool? setupRequired,
  required String matchedLocation,
  required String location,
  required bool isAuthFlowRoute,
  required String? pendingRedirect,
}) {
  if (setupRequired != true) {
    return const ProfileSetupRedirect();
  }
  if (matchedLocation == AppRoutes.completeProfile) {
    return const ProfileSetupRedirect();
  }
  final bool rememberTarget = !isAuthFlowRoute &&
      matchedLocation != AppRoutes.customer &&
      (pendingRedirect ?? '').isEmpty;
  return ProfileSetupRedirect(
    redirectTo: AppRoutes.completeProfile,
    pendingToSave: rememberTarget ? location : null,
  );
}
