import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Maps exceptions to short customer-safe copy.
///
/// Never returns stack traces, exception types, or ops-facing text.
/// Full details are [debugPrint]ed in debug builds only.
String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (kDebugMode) {
    debugPrint('userFacingError: $error');
  }

  // Runtime bugs (null check operator, type cast failures, RangeError, …)
  // are never safe to show verbatim — they're implementation details, not
  // exception subtypes caught by the specific branches below.
  if (error is Error) {
    return fallback;
  }

  if (error is FirebaseAuthException) {
    return _authMessage(error.code) ??
        _safeMessage(error.message) ??
        fallback;
  }
  if (error is FirebaseFunctionsException) {
    // Callable HttpsError messages are often written for end users.
    return _safeMessage(error.message) ??
        _functionsMessage(error.code) ??
        fallback;
  }
  if (error is StateError) {
    return _safeMessage(error.message) ?? fallback;
  }
  if (error is Exception) {
    final String asText = error.toString();
    const String prefix = 'Exception: ';
    final String candidate = asText.startsWith(prefix)
        ? asText.substring(prefix.length)
        : asText;
    final String? safe = _safeMessage(candidate);
    if (safe != null) {
      return safe;
    }
  }

  final String raw = error.toString();
  final String lower = raw.toLowerCase();
  if (lower.contains('permission-denied') ||
      lower.contains('permission_denied')) {
    return 'You do not have access to this. Sign in again and try once more.';
  }
  if (lower.contains('unauthenticated') ||
      lower.contains('not authenticated')) {
    return 'Please sign in again to continue.';
  }
  if (lower.contains('unavailable') ||
      lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('failed host lookup') ||
      lower.contains('connection')) {
    return 'Network error. Check your connection and try again.';
  }
  if (lower.contains('deadline') || lower.contains('timeout')) {
    return 'This is taking longer than usual. Please try again.';
  }
  if (lower.contains('not-found') || lower.contains('not_found')) {
    return 'We could not find what you were looking for.';
  }
  if (lower.contains('already-exists') || lower.contains('already_exists')) {
    return 'This already exists. Please refresh and try again.';
  }
  if (lower.contains('resource-exhausted') ||
      lower.contains('resource_exhausted') ||
      lower.contains('quota')) {
    return 'Too many requests. Please try again later.';
  }
  if (lower.contains('cancelled') || lower.contains('canceled')) {
    return 'That request was cancelled.';
  }

  return _safeMessage(raw) ?? fallback;
}

/// Returns [message] only when it looks safe to show customers.
String? _safeMessage(String? message) {
  if (message == null) {
    return null;
  }
  final String trimmed = message.trim();
  if (trimmed.isEmpty || trimmed.length > 180) {
    return null;
  }
  final String lower = trimmed.toLowerCase();
  const List<String> blocked = <String>[
    'exception',
    'firebase',
    'stack trace',
    'firestore',
    'cloud function',
    'deploy',
    '[cloud_firestore/',
    '[firebase_',
    'httpscallable',
    'permission-denied',
    'unauthenticated',
    'deadline-exceeded',
    'resource-exhausted',
  ];
  for (final String token in blocked) {
    if (lower.contains(token)) {
      return null;
    }
  }
  // Raw Dart exception dumps: "FooException: ..."
  if (RegExp(r'^[A-Za-z0-9_]+Exception\b').hasMatch(trimmed) ||
      RegExp(r'^[A-Za-z0-9_]+Error:').hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

String? _authMessage(String code) {
  switch (code) {
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please try again later.';
    case 'user-disabled':
      return 'This account is disabled. Please contact support.';
    case 'user-not-found':
    case 'wrong-password':
    case 'invalid-credential':
      return 'Sign-in failed. Please try again.';
    case 'requires-recent-login':
      return 'For security, sign out, sign in again, then retry.';
    default:
      return null;
  }
}

String? _functionsMessage(String code) {
  switch (code) {
    case 'unauthenticated':
      return 'Please sign in again to continue.';
    case 'permission-denied':
      return 'You do not have permission to do that.';
    case 'invalid-argument':
      return 'Some details look invalid. Please check and try again.';
    case 'not-found':
      return 'We could not find what you were looking for.';
    case 'already-exists':
      return 'This already exists. Please refresh and try again.';
    case 'resource-exhausted':
      return 'Too many requests. Please try again later.';
    case 'failed-precondition':
      return 'That action is not available right now.';
    case 'aborted':
    case 'cancelled':
      return 'That request was cancelled. Please try again.';
    case 'deadline-exceeded':
    case 'unavailable':
      return 'Service is busy. Please try again in a moment.';
    case 'internal':
      return 'Something went wrong on our side. Please try again.';
    default:
      return null;
  }
}
