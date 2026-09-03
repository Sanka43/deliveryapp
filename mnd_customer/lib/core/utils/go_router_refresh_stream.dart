import 'dart:async';

import 'package:flutter/foundation.dart';

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream([Stream<dynamic>? stream]) {
    notifyListeners();
    if (stream != null) {
      _subscription = stream.asBroadcastStream().listen(
            (_) => notifyListeners(),
          );
    }
  }

  StreamSubscription<dynamic>? _subscription;

  /// Triggers a GoRouter redirect re-evaluation without recreating the router.
  void refresh() => notifyListeners();

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
