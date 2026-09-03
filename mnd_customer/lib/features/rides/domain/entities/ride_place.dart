class RidePlace {
  const RidePlace({
    required this.lat,
    required this.lng,
    required this.label,
  });

  final double lat;
  final double lng;
  final String label;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'lat': lat,
        'lng': lng,
        'label': label,
      };

  factory RidePlace.fromMap(Map<String, dynamic>? data) {
    final Map<String, dynamic> m = data ?? <String, dynamic>{};
    return RidePlace(
      lat: (m['lat'] as num?)?.toDouble() ?? 0,
      lng: (m['lng'] as num?)?.toDouble() ?? 0,
      label: (m['label'] as String?)?.trim() ?? '',
    );
  }
}

class RideFareQuote {
  const RideFareQuote({
    required this.quoteId,
    required this.vehicleType,
    required this.distanceKm,
    required this.fareLkr,
    required this.expiresAtMs,
    this.trafficLabel = 'Normal traffic',
  });

  final String quoteId;
  final String vehicleType;
  final double distanceKm;
  final int fareLkr;
  final int expiresAtMs;
  final String trafficLabel;

  factory RideFareQuote.fromCallable(Map<String, dynamic> data) {
    return RideFareQuote(
      quoteId: (data['quoteId'] as String?)?.trim() ?? '',
      vehicleType: (data['vehicleType'] as String?)?.trim() ?? '',
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      fareLkr: (data['fareLkr'] as num?)?.toInt() ?? 0,
      expiresAtMs: (data['expiresAtMs'] as num?)?.toInt() ?? 0,
      trafficLabel:
          (data['trafficLabel'] as String?)?.trim() ?? 'Normal traffic',
    );
  }
}
