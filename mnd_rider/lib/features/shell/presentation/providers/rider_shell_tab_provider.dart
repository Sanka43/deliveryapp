import 'package:flutter_riverpod/flutter_riverpod.dart';

final StateProvider<int> riderShellTabIndexProvider =
    StateProvider<int>((Ref ref) => 0);

/// Hide bottom nav during offer overlays for full-focus driving UX.
final StateProvider<bool> riderShellNavVisibleProvider =
    StateProvider<bool>((Ref ref) => true);
