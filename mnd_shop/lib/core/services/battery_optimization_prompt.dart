import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mnd_shop/app/navigation/root_navigator_key.dart';
import 'package:mnd_shop/core/widgets/battery_optimization_dialog.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _kPromptShownKey = 'mnd_vendor_battery_opt_prompt_shown';

/// Shows a one-time dialog asking the vendor to exempt the app from battery
/// optimization, so new-order push notifications survive OEM background
/// restrictions (common on Xiaomi/Oppo/Vivo/Realme) once the app is closed.
///
/// Android only; any failure here must never block app startup or login.
Future<void> maybeShowBatteryOptimizationPrompt() async {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
    return;
  }
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kPromptShownKey) ?? false) {
      return;
    }

    final PermissionStatus status = await Permission.ignoreBatteryOptimizations.status;
    if (status.isGranted) {
      await prefs.setBool(_kPromptShownKey, true);
      return;
    }

    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) {
      return;
    }

    // Mark shown regardless of outcome — this is a one-time nudge, not a
    // gate, so a vendor who declines isn't asked again on every launch.
    await prefs.setBool(_kPromptShownKey, true);
    if (!context.mounted) {
      return;
    }

    final bool allow = await BatteryOptimizationDialog.show(context);
    if (allow) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('maybeShowBatteryOptimizationPrompt: skipped → $e\n$st');
    }
  }
}
