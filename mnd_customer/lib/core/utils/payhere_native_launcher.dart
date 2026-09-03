import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

enum PayHereNativeStatus { completed, dismissed, error, opened }

/// Outcome of a native PayHere payment sheet, distinguishing an actual
/// completed payment from the user dismissing it or an SDK/gateway error —
/// a distinction the old WebView-based flow could never make.
class PayHereNativeResult {
  const PayHereNativeResult._({
    required this.status,
    this.paymentId,
    this.errorMessage,
  });

  factory PayHereNativeResult.completed(String paymentId) =>
      PayHereNativeResult._(
        status: PayHereNativeStatus.completed,
        paymentId: paymentId,
      );

  factory PayHereNativeResult.dismissed() =>
      const PayHereNativeResult._(status: PayHereNativeStatus.dismissed);

  factory PayHereNativeResult.error(String message) => PayHereNativeResult._(
        status: PayHereNativeStatus.error,
        errorMessage: message,
      );

  /// Web only: the browser is navigating to the hosted checkout page (full
  /// page redirect, same tab). In practice the page unloads before callers
  /// see this — it only surfaces if the redirect is somehow interrupted.
  /// Unlike [completed], this does NOT mean payment succeeded; treat it as
  /// "pending" and rely on the order's live Firestore stream (which updates
  /// once `payHereNotify` confirms payment server-side).
  factory PayHereNativeResult.opened() =>
      const PayHereNativeResult._(status: PayHereNativeStatus.opened);

  final PayHereNativeStatus status;
  final String? paymentId;
  final String? errorMessage;
}

/// Starts a PayHere payment, choosing the right mechanism per platform:
/// the native in-app SDK sheet on Android/iOS, or a full-page redirect to
/// the server-hosted checkout page on web (the `payhere_mobilesdk_flutter`
/// plugin has no Flutter Web implementation, so [launchPayHereNativePayment]
/// alone throws a `MissingPluginException` there).
///
/// The web redirect uses `webOnlyWindowName: '_self'` (same tab), not a new
/// tab/window — opening a *new* window from code that has already crossed
/// an `await` (e.g. after the checkout-creation network call) is no longer
/// considered a direct response to the user's click, so browsers silently
/// block it as a popup. Navigating the current tab is never blocked.
Future<PayHereNativeResult> launchPayHerePayment({
  required Map<String, dynamic> fields,
  required bool sandbox,
  required String checkoutPageUrl,
}) async {
  if (!kIsWeb) {
    return launchPayHereNativePayment(fields: fields, sandbox: sandbox);
  }
  final Uri? uri = Uri.tryParse(checkoutPageUrl);
  if (uri == null || checkoutPageUrl.trim().isEmpty) {
    return PayHereNativeResult.error('Could not open the payment page.');
  }
  final bool opened = await launchUrl(uri, webOnlyWindowName: '_self');
  if (!opened) {
    return PayHereNativeResult.error('Could not open the payment page.');
  }
  return PayHereNativeResult.opened();
}

/// Opens PayHere's native in-app payment sheet (no WebView / no PayHere
/// website) via the `payhere_mobilesdk_flutter` SDK. Android/iOS only —
/// see [launchPayHerePayment] for a platform-aware entry point.
///
/// [fields] are the raw checkout parameters computed server-side by
/// `createPayHereCheckoutForOrder` (merchant_id, order_id, amount, currency,
/// customer/address fields, etc.) — the SDK does not use the `hash` field
/// that field-set also carries (that's only needed for the hosted web
/// checkout flow), so it's simply ignored.
Future<PayHereNativeResult> launchPayHereNativePayment({
  required Map<String, dynamic> fields,
  required bool sandbox,
}) {
  final Completer<PayHereNativeResult> completer =
      Completer<PayHereNativeResult>();
  final Map<String, dynamic> paymentObject = <String, dynamic>{
    ...fields,
    'sandbox': sandbox,
  };

  PayHere.startPayment(
    paymentObject,
    (String paymentId) {
      if (!completer.isCompleted) {
        completer.complete(PayHereNativeResult.completed(paymentId));
      }
    },
    (String error) {
      if (!completer.isCompleted) {
        completer.complete(PayHereNativeResult.error(error));
      }
    },
    () {
      if (!completer.isCompleted) {
        completer.complete(PayHereNativeResult.dismissed());
      }
    },
  );

  return completer.future;
}
