import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/app/router/app_router.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/core/widgets/app_update_dialog.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

/// Doc id for this app inside the shared `app_config` collection —
/// mnd_rider and mnd_shop each own their own doc id in the same collection.
const String _kAppConfigDocId = 'customer';
const String _kUpdateDismissedVersionKey = 'app_update_dismissed_version';

/// Compares dotted version strings (`1.2.10` vs `1.3.0`), ignoring any
/// build metadata after `+` or `-`. Returns <0, 0, >0 like [Comparable].
@visibleForTesting
int compareAppVersions(String a, String b) {
  List<int> parse(String v) => v
      .split('+')
      .first
      .split('-')
      .first
      .split('.')
      .map((String s) => int.tryParse(s.trim()) ?? 0)
      .toList();

  final List<int> pa = parse(a);
  final List<int> pb = parse(b);
  final int len = pa.length > pb.length ? pa.length : pb.length;
  for (int i = 0; i < len; i++) {
    final int x = i < pa.length ? pa[i] : 0;
    final int y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}

/// Reads the `app_config/customer` doc and, if the installed build is behind,
/// shows a blocking (forced) or dismissible (optional) update dialog.
///
/// Web has no app-store update flow (it always serves the latest deploy), and
/// any Firestore/PackageInfo failure here must never block app startup.
Future<void> checkForAppUpdate() async {
  if (kIsWeb) return;
  try {
    final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
        .instance
        .collection(FirebaseCollections.appConfig)
        .doc(_kAppConfigDocId)
        .get();
    final Map<String, dynamic>? data = doc.data();
    if (data == null) return;

    final String latest = (data['latestVersion'] as String? ?? '').trim();
    if (latest.isEmpty) return;

    final String minSupported =
        (data['minSupportedVersion'] as String? ?? '').trim();
    final String? message = (data['updateMessage'] as String?)?.trim();
    final String? androidUrl = (data['androidUrl'] as String?)?.trim();
    final String? iosUrl = (data['iosUrl'] as String?)?.trim();

    final PackageInfo info = await PackageInfo.fromPlatform();
    final String current = info.version;

    final bool isForced = minSupported.isNotEmpty &&
        compareAppVersions(current, minSupported) < 0;
    final bool hasUpdate = compareAppVersions(current, latest) < 0;
    if (!isForced && !hasUpdate) return;

    if (!isForced) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      if (prefs.getString(_kUpdateDismissedVersionKey) == latest) return;
    }

    final BuildContext? context = rootNavigatorKey.currentContext;
    if (context == null || !context.mounted) return;

    await AppUpdateDialog.show(
      context,
      forced: isForced,
      message: message,
      onUpdate: () => _openStore(
        androidUrl: androidUrl,
        iosUrl: iosUrl,
        packageName: info.packageName,
      ),
      onLater: isForced
          ? null
          : () async {
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setString(_kUpdateDismissedVersionKey, latest);
            },
    );
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('checkForAppUpdate: skipped → $e\n$st');
    }
  }
}

Future<void> _openStore({
  String? androidUrl,
  String? iosUrl,
  required String packageName,
}) async {
  String? url;
  if (defaultTargetPlatform == TargetPlatform.android) {
    url = (androidUrl != null && androidUrl.isNotEmpty)
        ? androidUrl
        : 'https://play.google.com/store/apps/details?id=$packageName';
  } else if (defaultTargetPlatform == TargetPlatform.iOS) {
    url = iosUrl;
  }
  if (url == null || url.isEmpty) return;

  final Uri uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
