import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';

/// User-facing message for order stream/load failures.
String ordersLoadErrorMessage(Object error, {required String fallback}) {
  return userFacingError(error, fallback: fallback);
}
