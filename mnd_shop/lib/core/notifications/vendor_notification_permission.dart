import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

/// Live OS-level notification permission status for this device.
///
/// [ShopFirebaseMessagingService.initialize] calls `requestPermission()`
/// once at startup but never inspects the result, so a vendor who denies
/// the prompt (or later revokes it from OS Settings) previously had no way
/// to know push alerts had stopped arriving. Watch this provider anywhere
/// that should surface that state.
///
/// Reports granted on web/desktop, where `permission_handler` doesn't back
/// this permission and push delivery isn't this check's concern anyway —
/// mirrors the existing platform guard in `battery_optimization_prompt.dart`.
final FutureProvider<PermissionStatus>
vendorNotificationPermissionStatusProvider = FutureProvider<PermissionStatus>((
  Ref ref,
) {
  if (kIsWeb ||
      !(defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS)) {
    return Future<PermissionStatus>.value(PermissionStatus.granted);
  }
  return Permission.notification.status;
});

/// Warning banner shown only when notification permission is off — silent
/// (renders nothing) while granted, loading, or on a check error, so it
/// never adds noise to a screen that's working normally.
///
/// Re-checks whenever the app resumes foreground, since the vendor may have
/// flipped the permission from OS Settings and come straight back.
class VendorNotificationPermissionBanner extends ConsumerStatefulWidget {
  const VendorNotificationPermissionBanner({super.key, this.bottomMargin = 0});

  /// Space to reserve below the banner — only applied while it's actually
  /// visible, so callers can inline it in a Column without a stray gap
  /// when notifications are enabled and it renders nothing.
  final double bottomMargin;

  @override
  ConsumerState<VendorNotificationPermissionBanner> createState() =>
      _VendorNotificationPermissionBannerState();
}

class _VendorNotificationPermissionBannerState
    extends ConsumerState<VendorNotificationPermissionBanner>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(vendorNotificationPermissionStatusProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<PermissionStatus> async = ref.watch(
      vendorNotificationPermissionStatusProvider,
    );
    final PermissionStatus? status = async.valueOrNull;
    if (status == null || status.isGranted || status.isLimited) {
      return const SizedBox.shrink();
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(bottom: widget.bottomMargin),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: openAppSettings,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: cs.errorContainer.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cs.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.notifications_off_rounded,
                  color: cs.error,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Notifications are off',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: cs.onErrorContainer,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'You will not be alerted about new orders. Tap to turn them back on.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: cs.onErrorContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: cs.error),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
