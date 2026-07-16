import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/constants/support_constants.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

abstract final class VendorSettingsActions {
  static Future<void> sendPasswordResetEmail(
    BuildContext context, {
    required String email,
    required FirebaseAuth auth,
  }) async {
    final String trimmed = email.trim();
    if (trimmed.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No email on file. Contact support.')),
      );
      return;
    }
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Text(
          'Send a password reset link to $trimmed?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Send email'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await auth.sendPasswordResetEmail(email: trimmed);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent.')),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Could not send reset email.')),
        );
      }
    }
  }

  static Future<void> openHelpSupport(BuildContext context) {
    return launchSupportWhatsApp(context);
  }

  static Future<void> launchSupportPhone(BuildContext context) {
    return _launchUri(
      context,
      SupportConstants.supportTelUri,
      failureMessage:
          'Could not open the phone app. Call ${SupportConstants.supportPhoneDisplay}.',
    );
  }

  static Future<void> launchSupportWhatsApp(BuildContext context) async {
    final bool opened = await _launchUri(
      context,
      SupportConstants.supportWhatsAppUri,
      failureMessage: '',
      silent: true,
    );
    if (opened || !context.mounted) {
      return;
    }
    await _launchUri(
      context,
      SupportConstants.supportWhatsAppAppUri,
      failureMessage:
          'Could not open WhatsApp. Install WhatsApp or message ${SupportConstants.supportPhoneDisplay}.',
    );
  }

  static Future<void> launchSupportEmail(BuildContext context) {
    return _launchUri(
      context,
      SupportConstants.supportEmailUri,
      failureMessage:
          'Could not open your email app. Write to ${SupportConstants.supportEmail}.',
    );
  }

  static Future<void> showAboutDialog(BuildContext context) async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Row(
          children: <Widget>[
            Icon(Icons.storefront_rounded, color: AppColors.primaryBlue, size: 28),
            const SizedBox(width: 10),
            const Expanded(child: Text('MND Shop')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'The official vendor app for MND Delivery. Run your shop, '
                  'fulfil customer orders, and track performance from one place.',
                  style: Theme.of(ctx).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Text(
                  'What you can do',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                const _AboutBullet(
                  'Accept, prepare, and complete incoming orders in real time',
                ),
                const _AboutBullet(
                  'Manage products, stock levels, and pricing',
                ),
                const _AboutBullet(
                  'Open or close your store for new orders',
                ),
                const _AboutBullet(
                  'View sales reports and daily business insights',
                ),
                const _AboutBullet(
                  'Update shop location, category, and profile details',
                ),
                const _AboutBullet(
                  'Receive order alerts and notification preferences',
                ),
                const SizedBox(height: 16),
                Divider(color: Theme.of(ctx).colorScheme.outlineVariant),
                const SizedBox(height: 12),
                _AboutMetaRow(
                  label: 'Version',
                  value: '${info.version} (${info.buildNumber})',
                ),
                const SizedBox(height: 6),
                const _AboutMetaRow(label: 'Platform', value: 'MND Delivery — Vendor'),
                const SizedBox(height: 16),
                Text(
                  'Support',
                  style: Theme.of(ctx).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                _AboutLinkRow(
                  icon: Icons.email_outlined,
                  label: SupportConstants.supportEmail,
                  onTap: () => launchSupportEmail(ctx),
                ),
                const SizedBox(height: 6),
                _AboutLinkRow(
                  icon: Icons.phone_outlined,
                  label: SupportConstants.supportPhoneDisplay,
                  onTap: () => launchSupportPhone(ctx),
                ),
                const SizedBox(height: 6),
                _AboutLinkRow(
                  icon: Icons.chat_outlined,
                  label: 'WhatsApp support',
                  onTap: () => launchSupportWhatsApp(ctx),
                ),
                const SizedBox(height: 16),
                Text(
                  '© ${DateTime.now().year} MND Delivery. All rights reserved.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Built for registered shop partners on the MND marketplace.',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static Future<bool> _launchUri(
    BuildContext context,
    Uri uri, {
    required String failureMessage,
    bool silent = false,
  }) async {
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched && context.mounted && failureMessage.isNotEmpty && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
      return launched;
    } catch (_) {
      if (context.mounted && failureMessage.isNotEmpty && !silent) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failureMessage)),
        );
      }
      return false;
    }
  }

  static Future<bool?> confirmLogout(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Log out'),
        content: const Text('Do you want to log out of this shop account?'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }
}

class _AboutBullet extends StatelessWidget {
  const _AboutBullet(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(top: 7),
            child: Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: theme.textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _AboutMetaRow extends StatelessWidget {
  const _AboutMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color muted = theme.colorScheme.onSurfaceVariant;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 72,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: muted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _AboutLinkRow extends StatelessWidget {
  const _AboutLinkRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: <Widget>[
            Icon(icon, size: 18, color: AppColors.primaryBlue),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryBlue,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
