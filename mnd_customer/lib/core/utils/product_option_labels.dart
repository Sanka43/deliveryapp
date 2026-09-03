/// Middle-dot separator used in Type × Size combo labels (`Chicken · Full`).
const String kTypeSizeSeparator = ' · ';

/// Parses `{Type} · {Size}` (exactly two non-empty segments).
({String type, String size})? parseTypeSizeComboLabel(String label) {
  final String t = label.trim();
  if (!t.contains('·')) {
    return null;
  }
  final List<String> parts =
      t.split('·').map((String e) => e.trim()).where((String e) => e.isNotEmpty).toList();
  if (parts.length != 2) {
    return null;
  }
  if (parts[0].isEmpty || parts[1].isEmpty) {
    return null;
  }
  return (type: parts[0], size: parts[1]);
}

/// One selectable size (or the implicit sole size) under a [ProductTypeGroup].
class ProductTypeSizeEntry {
  const ProductTypeSizeEntry({
    required this.size,
    required this.optionIndex,
  });

  /// Empty when the source option name had no `Type · Size` split — the
  /// group then has exactly one entry and no size picker is shown for it.
  final String size;
  final int optionIndex;
}

/// One selectable "type" (e.g. `Chicken`, or a standalone item like
/// `Batu Moju`) with the sizes available under it.
class ProductTypeGroup {
  const ProductTypeGroup({
    required this.type,
    required this.sizes,
  });

  final String type;
  final List<ProductTypeSizeEntry> sizes;

  bool get hasSizeChoice => sizes.length > 1;
}

/// Groups every option name by its `Type` (the part before `·`, or the
/// whole name when there's no `·`), preserving first-seen order. Options
/// that share a type become that type's selectable sizes, so a product can
/// freely mix real Type × Size combos with standalone items — each type is
/// then independently selectable with its own size and quantity.
List<ProductTypeGroup> buildProductTypeGroups(List<String> optionNames) {
  final List<String> order = <String>[];
  final Map<String, List<ProductTypeSizeEntry>> byType =
      <String, List<ProductTypeSizeEntry>>{};
  final Map<String, String> displayName = <String, String>{};

  for (int i = 0; i < optionNames.length; i++) {
    final String raw = optionNames[i];
    final ({String type, String size})? parsed = parseTypeSizeComboLabel(raw);
    final String type = parsed?.type ?? raw;
    final String size = parsed?.size ?? '';
    final String key = type.toLowerCase();
    if (!byType.containsKey(key)) {
      order.add(key);
      displayName[key] = type;
      byType[key] = <ProductTypeSizeEntry>[];
    }
    byType[key]!.add(ProductTypeSizeEntry(size: size, optionIndex: i));
  }

  return order
      .map(
        (String key) => ProductTypeGroup(
          type: displayName[key]!,
          sizes: byType[key]!,
        ),
      )
      .toList(growable: false);
}
