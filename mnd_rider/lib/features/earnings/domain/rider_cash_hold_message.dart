import 'package:mnd_rider/core/utils/lkr_format.dart';

/// One wording for the cash-in-hand block, shared by the ride and delivery
/// claim paths so a rider never sees two different explanations for the same
/// rule (`riderCashHoldActive()` in firestore.rules).
String cashHoldClaimMessage(Map<String, dynamic>? riderData) {
  final num? owed = riderData?['cashOwedToAdminLkr'] as num?;
  if (owed == null || owed <= 0) {
    return 'You are over the cash limit. Hand your collected cash to admin '
        'to start accepting jobs again.';
  }
  return 'You are over the cash limit. Hand ${LkrFormat.money(owed.round())} '
      'to admin to start accepting jobs again.';
}
