import 'package:mnd_shop/features/products/domain/vendor_grocery_catalog.dart';

/// Middle-dot separator used in Type × Size combo labels (`Chicken · Full`).
const String kTypeSizeSeparator = ' · ';

const List<String> kFoodTypePresets = <String>[
  'Chicken',
  'Beef',
  'Egg',
  'Fish',
  'Veg',
];

bool isPresetFoodType(String type) {
  final String t = type.trim().toLowerCase();
  if (t.isEmpty) {
    return false;
  }
  return kFoodTypePresets.any((String p) => p.toLowerCase() == t);
}

/// Non-preset type labels from `{Type} · {Size}` option names (stable order).
List<String> customFoodTypesFromOptionNames(Iterable<String> optionNames) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final String name in optionNames) {
    final ({String type, String size})? parsed = parseTypeSizeComboLabel(name);
    if (parsed == null || isPresetFoodType(parsed.type)) {
      continue;
    }
    if (seen.add(parsed.type.toLowerCase())) {
      out.add(parsed.type.trim());
    }
  }
  return out;
}

/// Parses `vendors.customFoodTypes` (string list). Drops presets / blanks.
List<String> parseCustomFoodTypesField(dynamic raw) {
  if (raw is! List) {
    return const <String>[];
  }
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final dynamic row in raw) {
    if (row is! String) {
      continue;
    }
    final String t = row.trim();
    if (t.isEmpty || t.length > 40 || isPresetFoodType(t)) {
      continue;
    }
    if (seen.add(t.toLowerCase())) {
      out.add(t);
    }
  }
  return out;
}

/// Merges remembered type lists (case-insensitive, first spelling wins).
List<String> mergeCustomFoodTypeLists(Iterable<Iterable<String>> sources) {
  final List<String> out = <String>[];
  final Set<String> seen = <String>{};
  for (final Iterable<String> source in sources) {
    for (final String raw in source) {
      final String t = raw.trim();
      if (t.isEmpty || t.length > 40 || isPresetFoodType(t)) {
        continue;
      }
      if (seen.add(t.toLowerCase())) {
        out.add(t);
      }
    }
  }
  return out;
}

const List<String> kFoodSizeLabels = <String>['Small', 'Medium', 'Large'];

bool isKnownFoodSizeLabel(String raw) {
  final String t = raw.trim();
  if (kFoodSizeLabels.contains(t)) {
    return true;
  }
  if (t == 'Single portion') {
    return true;
  }
  if (RegExp(r'^\d+\s*person$').hasMatch(t)) {
    return true;
  }
  if (t == 'Half' ||
      t == 'Full' ||
      t == 'Half plate' ||
      t == 'Full plate') {
    return true;
  }
  return false;
}

/// Infers shop "Price by" kind from a size segment.
String? priceKindForSizeLabel(String sizeLabel) {
  final String t = sizeLabel.trim();
  if (kFoodSizeLabels.contains(t)) {
    return 'size';
  }
  if (t == 'Single portion' || RegExp(r'^\d+\s*person$').hasMatch(t)) {
    return 'portion';
  }
  if (t == 'Half' ||
      t == 'Full' ||
      t == 'Half plate' ||
      t == 'Full plate') {
    return 'half';
  }
  if (kGroceryPackLabels.contains(t)) {
    return 'pack';
  }
  return null;
}

String typeSizeComboLabel({required String type, required String size}) {
  return '${type.trim()}$kTypeSizeSeparator${size.trim()}';
}

/// Parses `{Type} · {Size}` where Size is a known food size/portion/half label.
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
  final String type = parts[0];
  final String size = parts[1];
  if (type.isEmpty || !isKnownFoodSizeLabel(size)) {
    return null;
  }
  return (type: type, size: size);
}

bool labelLooksLikePresetOption(String label) {
  final String t = label.trim();
  if (isKnownFoodSizeLabel(t)) {
    return true;
  }
  if (kGroceryPackLabels.contains(t)) {
    return true;
  }
  if (parseTypeSizeComboLabel(t) != null) {
    return true;
  }
  // Legacy 3-part combos: Size · Portion · Half
  final List<String> parts =
      t.split('·').map((String e) => e.trim()).toList();
  if (parts.length != 3) {
    return false;
  }
  if (!kFoodSizeLabels.contains(parts[0])) {
    return false;
  }
  final String p = parts[1];
  if (p != 'Single portion' && !RegExp(r'^\d+\s*person$').hasMatch(p)) {
    return false;
  }
  final String pl = parts[2];
  return pl == 'Half' ||
      pl == 'Full' ||
      pl == 'Half plate' ||
      pl == 'Full plate';
}
