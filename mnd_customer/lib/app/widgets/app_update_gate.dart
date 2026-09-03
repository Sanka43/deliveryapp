import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/services/app_update_service.dart';

/// Fires the once-per-launch update check after the first frame, so it never
/// delays cold start or interferes with router redirects.
class AppUpdateGate extends StatefulWidget {
  const AppUpdateGate({required this.child, super.key});

  final Widget child;

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_checked) return;
      _checked = true;
      checkForAppUpdate();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
