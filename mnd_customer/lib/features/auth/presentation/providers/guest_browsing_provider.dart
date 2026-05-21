import 'package:flutter_riverpod/flutter_riverpod.dart';

/// When true, unauthenticated users may open customer routes (temporary browse / dev).
final StateProvider<bool> guestBrowsingProvider =
    StateProvider<bool>((Ref ref) => false);
