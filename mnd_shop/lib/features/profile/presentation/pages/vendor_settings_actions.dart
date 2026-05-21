import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
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

  static Future<void> openHelpSupport(BuildContext context) async {
    final Uri whatsapp = Uri.parse(
      'https://wa.me/${SupportConstants.supportWhatsAppDigits}?text=${Uri.encodeComponent('Hi, I need help with my MND Shop account.')}',
    );
    if (await canLaunchUrl(whatsapp)) {
      await launchUrl(whatsapp, mode: LaunchMode.externalApplication);
      return;
    }
    final Uri phone = Uri(scheme: 'tel', path: SupportConstants.supportPhoneE164);
    if (await canLaunchUrl(phone)) {
      await launchUrl(phone);
      return;
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Call ${SupportConstants.supportPhoneE164} or email ${SupportConstants.supportEmail}',
          ),
        ),
      );
    }
  }

  static Future<void> showAboutDialog(BuildContext context) async {
    final PackageInfo info = await PackageInfo.fromPlatform();
    if (!context.mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AboutDialog(
        applicationName: 'MND Shop',
        applicationVersion: info.version,
        applicationLegalese: '© MND Delivery',
        children: <Widget>[
          const SizedBox(height: 8),
          Text(
            'Manage your shop, orders, and sales from one place.',
            style: Theme.of(ctx).textTheme.bodyMedium,
          ),
        ],
      ),
    );
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
