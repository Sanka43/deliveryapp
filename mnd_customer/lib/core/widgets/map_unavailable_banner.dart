import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/services/google_maps_web_loader.dart';

/// Amber notice for when the web Google Maps JS script never loaded — the
/// build was compiled without `GOOGLE_MAPS_KEY`, or the key/network failed.
///
/// Without this the failure is invisible: `GoogleMap` just renders a blank
/// grey box, so a web build shipped without
/// `--dart-define-from-file=dart_defines.json` looks like a broken map
/// picker rather than a missing key. Only the rides booking page said so;
/// every other map surface stayed silent.
class MapUnavailableBanner extends StatelessWidget {
  const MapUnavailableBanner({super.key});

  /// True only on web, and only once the script load has actually failed.
  static bool get shouldShow => kIsWeb && googleMapsWebScriptFailed;

  static const String message =
      'Map unavailable — missing or invalid Google Maps key. '
      'See README.md (dart_defines.json).';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade100,
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.warning_amber_rounded, color: Colors.black87),
          SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }
}
