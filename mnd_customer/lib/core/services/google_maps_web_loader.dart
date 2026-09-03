import 'package:mnd_delivery_app/core/services/google_maps_web_loader_stub.dart'
    if (dart.library.js_interop) 'package:mnd_delivery_app/core/services/google_maps_web_loader_web.dart';

/// Loads the Google Maps JavaScript API on web before the first [GoogleMap] widget.
Future<void> ensureGoogleMapsWebScript(String apiKey) =>
    loadGoogleMapsWebScript(apiKey);

/// True on web if the Maps JS script failed to load (missing/invalid key or
/// network error) — always false on non-web platforms.
bool get googleMapsWebScriptFailed => googleMapsWebLoadFailed;
