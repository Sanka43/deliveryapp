import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens the phone dialer for [phone] via `tel:`. Shows a snackbar if the
/// device has no dialer app or the number is empty.
Future<void> launchPhoneCall(BuildContext context, String phone) async {
  final String trimmed = phone.trim();
  if (trimmed.isEmpty) {
    return;
  }
  final Uri uri = Uri(scheme: 'tel', path: trimmed);
  try {
    final bool launched = await launchUrl(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the phone app. Call $trimmed.')),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open the phone app. Call $trimmed.')),
      );
    }
  }
}
