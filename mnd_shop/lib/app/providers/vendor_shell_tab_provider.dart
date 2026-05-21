import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Selected tab for [VendorShellPage]: 0 Home, 1 Product, 2 Orders, 3 Analytics, 4 Setting.
final vendorShellTabIndexProvider = StateProvider<int>((Ref ref) => 0);
