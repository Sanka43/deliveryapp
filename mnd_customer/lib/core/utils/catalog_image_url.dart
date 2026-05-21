/// Resolves product / vendor image URLs from Firestore document fields.
String? pickCatalogImageUrl(Map<String, dynamic> map) {
  const List<String> directKeys = <String>[
    'imageUrl',
    'image',
    'photoUrl',
    'coverImage',
    'thumbnailUrl',
    'thumbUrl',
  ];

  for (final String key in directKeys) {
    final dynamic raw = map[key];
    if (raw is String) {
      final String trimmed = raw.trim();
      if (trimmed.isNotEmpty) {
        return _normalizeUrl(trimmed);
      }
    }
  }

  for (final String key in <String>['galleryImageUrls', 'gallery', 'images', 'photos']) {
    final dynamic raw = map[key];
    if (raw is! List || raw.isEmpty) {
      continue;
    }
    for (final dynamic entry in raw) {
      if (entry is String) {
        final String trimmed = entry.trim();
        if (trimmed.isNotEmpty) {
          return _normalizeUrl(trimmed);
        }
      }
    }
  }

  return null;
}

String _normalizeUrl(String url) {
  if (url.startsWith('//')) {
    return 'https:$url';
  }
  return url;
}

String catalogImageUrlOrDefault(
  Map<String, dynamic> map, {
  required String defaultUrl,
}) {
  return pickCatalogImageUrl(map) ?? defaultUrl;
}
