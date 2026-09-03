import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Set to true if the web Maps script failed to load (missing/invalid key),
/// so the UI can surface a visible banner instead of a silently blank map.
bool googleMapsWebLoadFailed = false;

Future<void> loadGoogleMapsWebScript(String apiKey) async {
  final String trimmed = apiKey.trim();
  if (trimmed.isEmpty) {
    googleMapsWebLoadFailed = true;
    debugPrint(
      'Google Maps JS API key is empty — maps will not render on web. '
      'Copy mnd_customer/dart_defines.example.json to dart_defines.json, '
      'fill in GOOGLE_MAPS_KEY, and run with '
      '--dart-define-from-file=dart_defines.json (see README.md).',
    );
    return;
  }

  if (web.document.querySelector('script[data-mnd-google-maps]') != null) {
    return;
  }

  final Completer<void> completer = Completer<void>();
  final web.HTMLScriptElement script =
      web.document.createElement('script') as web.HTMLScriptElement;
  script.setAttribute('data-mnd-google-maps', 'true');
  script.src =
      'https://maps.googleapis.com/maps/api/js?key=${Uri.encodeComponent(trimmed)}';
  script.async = true;

  script.onload = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.complete();
    }
  }).toJS;

  script.onerror = ((web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(
        StateError('Failed to load Google Maps JavaScript API'),
      );
    }
  }).toJS;

  web.document.head!.appendChild(script);

  try {
    await completer.future.timeout(const Duration(seconds: 20));
  } on TimeoutException {
    // Do not block cold start if the CDN is slow.
    googleMapsWebLoadFailed = true;
    debugPrint('Google Maps JS API script load timed out.');
  } catch (e) {
    // Map tiles may fail; the rest of the app should still load.
    googleMapsWebLoadFailed = true;
    debugPrint('Google Maps JS API script failed to load: $e');
  }
}
