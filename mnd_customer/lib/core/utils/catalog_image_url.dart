/// Resolves product / vendor image URLs from Firestore document fields.
String? pickCatalogImageUrl(Map<String, dynamic> map) {
  const List<String> directKeys = <String>[
    'imageUrl',
    'imageURL',
    'image',
    'photoUrl',
    'photoURL',
    'coverImage',
    'thumbnailUrl',
    'thumbUrl',
    'logoUrl',
  ];

  for (final String key in directKeys) {
    final String? url = _asImageUrl(map[key]);
    if (url != null) {
      return url;
    }
  }

  for (final String key in <String>['galleryImageUrls', 'gallery', 'images', 'photos']) {
    final dynamic raw = map[key];
    if (raw is! List || raw.isEmpty) {
      continue;
    }
    for (final dynamic entry in raw) {
      final String? url = _asImageUrl(entry);
      if (url != null) {
        return url;
      }
    }
  }

  return null;
}

String catalogImageUrlOrDefault(
  Map<String, dynamic> map, {
  required String defaultUrl,
}) {
  return pickCatalogImageUrl(map) ?? defaultUrl;
}

/// Returns a loadable URL candidate, or null if the value is empty / junk.
String? _asImageUrl(dynamic raw) {
  if (raw is String) {
    return _normalizeUrl(raw);
  }
  if (raw is Map) {
    for (final String key in <String>[
      'url',
      'imageUrl',
      'imageURL',
      'src',
      'downloadUrl',
      'downloadURL',
      'href',
    ]) {
      final dynamic nested = raw[key];
      if (nested is String) {
        final String? url = _normalizeUrl(nested);
        if (url != null) {
          return url;
        }
      }
    }
  }
  return null;
}

String? _normalizeUrl(String raw) {
  final String url = raw.trim();
  if (url.isEmpty) {
    return null;
  }

  if (url.startsWith('//')) {
    return 'https:$url';
  }

  final String lower = url.toLowerCase();
  if (lower.startsWith('https://') ||
      lower.startsWith('http://') ||
      lower.startsWith('gs://')) {
    return url;
  }

  // Relative Firebase Storage object path, e.g. vendor_products/{id}/x.jpg
  if (!url.contains('://') &&
      (url.startsWith('vendor_products/') ||
          url.startsWith('vendor_storefront/') ||
          url.startsWith('jobs/') ||
          url.startsWith('riders/'))) {
    return url;
  }

  return null;
}
