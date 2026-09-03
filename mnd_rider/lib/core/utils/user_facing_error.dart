import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Maps exceptions to short rider-safe copy (no Firebase codes).
String userFacingError(
  Object error, {
  String fallback = 'Something went wrong. Please try again.',
}) {
  if (kDebugMode) {
    debugPrint('userFacingError: $error');
  }

  if (error is FirebaseFunctionsException) {
    return _safeMessage(error.message) ??
        _firebaseCodeMessage(error.code) ??
        fallback;
  }
  if (error is FirebaseAuthException) {
    return _firebaseCodeMessage(error.code) ??
        _safeMessage(error.message) ??
        fallback;
  }
  if (error is FirebaseException) {
    return _firebaseCodeMessage(error.code) ??
        _safeMessage(error.message) ??
        fallback;
  }

  final String raw = error.toString();
  final String lower = raw.toLowerCase();
  if (lower.contains('permission-denied') ||
      lower.contains('permission_denied')) {
    return 'Could not load this right now. Pull to refresh, or sign in again.';
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

  return _safeMessage(raw) ?? fallback;
}

bool isFirestorePermissionDenied(Object error) {
  if (error is FirebaseException &&
      error.code == 'permission-denied') {
    return true;
  }
  final String lower = error.toString().toLowerCase();
  return lower.contains('permission-denied') ||
      lower.contains('permission_denied');
}

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
    '[cloud_firestore/',
    '[firebase_',
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
  if (RegExp(r'^[A-Za-z0-9_]+Exception\b').hasMatch(trimmed) ||
      RegExp(r'^[A-Za-z0-9_]+Error:').hasMatch(trimmed)) {
    return null;
  }
  return trimmed;
}

String? _firebaseCodeMessage(String code) {
  switch (code) {
    case 'permission-denied':
      return 'Could not load this right now. Pull to refresh, or sign in again.';
    case 'unauthenticated':
      return 'Please sign in again to continue.';
    case 'unavailable':
    case 'network-request-failed':
      return 'Network error. Check your connection and try again.';
    case 'deadline-exceeded':
      return 'This is taking longer than usual. Please try again.';
    case 'not-found':
      return 'We could not find what you were looking for.';
    case 'resource-exhausted':
    case 'too-many-requests':
      return 'Too many requests. Please try again later.';
    default:
      return null;
  }
}
