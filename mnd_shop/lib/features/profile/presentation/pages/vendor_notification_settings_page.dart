import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/vendor_notification_prefs_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_audio_context.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/profile/presentation/widgets/vendor_settings_tiles.dart';
import 'package:permission_handler/permission_handler.dart';

class VendorNotificationSettingsPage extends ConsumerStatefulWidget {
  const VendorNotificationSettingsPage({super.key});

  @override
  ConsumerState<VendorNotificationSettingsPage> createState() =>
      _VendorNotificationSettingsPageState();
}

class _VendorNotificationSettingsPageState
    extends ConsumerState<VendorNotificationSettingsPage> {
  final AudioPlayer _previewPlayer = AudioPlayer();

  @override
  void initState() {
    super.initState();
    unawaited(
      _previewPlayer.setAudioContext(vendorAlertAudioContext()),
    );
  }

  @override
  void dispose() {
    _previewPlayer.dispose();
    super.dispose();
  }

  Future<void> _previewTone(VendorAlertSound sound) async {
    try {
      await _previewPlayer.stop();
      await _previewPlayer.play(AssetSource(sound.assetPath));
    } catch (_) {
      // Preview is best-effort.
    }
  }

  Future<void> _showTonePicker(VendorAlertSound current) async {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.brightness == Brightness.dark
          ? cs.surfaceContainerLow
          : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Notification sound',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurface
                        : AppColors.textCharcoal,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose the tone for new order push alerts.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? cs.onSurfaceVariant
                        : AppColors.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                for (final VendorAlertSound sound in VendorAlertSound.values)
                  _ToneOptionTile(
                    sound: sound,
                    selected: sound == current,
                    onPreview: () => _previewTone(sound),
                    onSelect: () async {
                      try {
                        await ref
                            .read(vendorNotificationPrefsProvider.notifier)
                            .setAlertTone(sound);
                        if (sheetContext.mounted) {
                          Navigator.of(sheetContext).pop();
                        }
                      } catch (e) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                userFacingError(
                                  e,
                                  fallback: 'Could not save. Please try again.',
                                ),
                              ),
                            ),
                          );
                        }
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _setBoolPref({
    required Future<void> Function() save,
  }) async {
    try {
      await save();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not save. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final AsyncValue<VendorNotificationPrefs> prefsAsync =
        ref.watch(vendorNotificationPrefsProvider);
    final double gutter = vendorResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? cs.surface
          : AppColors.canvas,
      appBar: AppBar(
        title: const Text('Notification preferences'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: theme.brightness == Brightness.dark
              ? cs.onSurface
              : AppColors.textCharcoal,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: VendorResponsiveContent(
        child: prefsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(
            child: Text(
              'Could not load settings.\n${userFacingError(e, fallback: 'Please try again.')}',
            ),
          ),
          data: (VendorNotificationPrefs prefs) {
            return ListView(
              padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 32),
              children: <Widget>[
                const VendorSettingsSectionTitle(label: 'Device'),
                const SizedBox(height: 10),
                VendorSettingsNavTile(
                  icon: Icons.settings_outlined,
                  label: 'System notification settings',
                  subtitle:
                      'Allow notifications and unrestricted battery so alerts '
                      'still ring when the app is closed. Do not force-stop the app.',
                  onTap: openAppSettings,
                ),
                const SizedBox(height: 8),
                const VendorSettingsSectionTitle(label: 'In this app'),
                const SizedBox(height: 10),
                VendorSettingsSwitchTile(
                  icon: Icons.volume_up_rounded,
                  label: 'Order alert sound',
                  subtitle: 'Play a sound when a new order arrives.',
                  value: prefs.orderAlertSound,
                  onChanged: (bool v) => _setBoolPref(
                    save: () => ref
                        .read(vendorNotificationPrefsProvider.notifier)
                        .setOrderAlertSound(v),
                  ),
                ),
                VendorSettingsSwitchTile(
                  icon: Icons.notifications_active_outlined,
                  label: 'In-app order alerts',
                  subtitle: 'Show a popup when a new order comes in.',
                  value: prefs.inAppOrderAlerts,
                  onChanged: (bool v) => _setBoolPref(
                    save: () => ref
                        .read(vendorNotificationPrefsProvider.notifier)
                        .setInAppOrderAlerts(v),
                  ),
                ),
                const SizedBox(height: 8),
                const VendorSettingsSectionTitle(label: 'Notification sound'),
                const SizedBox(height: 10),
                VendorSettingsNavTile(
                  icon: Icons.music_note_rounded,
                  label: 'Notification sound',
                  subtitle: prefs.alertTone.label,
                  onTap: () => _showTonePicker(prefs.alertTone),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ToneOptionTile extends StatelessWidget {
  const _ToneOptionTile({
    required this.sound,
    required this.selected,
    required this.onPreview,
    required this.onSelect,
  });

  final VendorAlertSound sound;
  final bool selected;
  final VoidCallback onPreview;
  final VoidCallback onSelect;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onSelect,
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? AppColors.primaryBlue.withValues(alpha: 0.65)
                    : cs.outlineVariant.withValues(alpha: 0.5),
                width: selected ? 2 : 1,
              ),
              color: selected
                  ? AppColors.primaryBlue.withValues(alpha: 0.06)
                  : Colors.transparent,
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected ? AppColors.primaryBlue : cs.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    sound.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.brightness == Brightness.dark
                          ? cs.onSurface
                          : AppColors.textCharcoal,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Preview',
                  onPressed: onPreview,
                  icon: Icon(
                    Icons.play_circle_outline_rounded,
                    color: AppColors.primaryBlue,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: AppColors.primaryBlue),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
