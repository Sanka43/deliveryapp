import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';

/// Shown when this install (customer app) is opened by a non-customer role.
class WrongDedicatedAppPage extends StatelessWidget {
  const WrongDedicatedAppPage({
    required this.forRider,
    this.forAdmin = false,
    super.key,
  });

  final bool forRider;
  final bool forAdmin;

  @override
  Widget build(BuildContext context) {
    final String title;
    final IconData icon;
    final String body;
    final String nextStep;

    if (forAdmin) {
      title = 'Admin account';
      icon = Icons.admin_panel_settings_outlined;
      body =
          'This Play Store build is for customers only. Admin tools are not included here.';
      nextStep = 'Use the internal admin distribution, or sign out.';
    } else if (forRider) {
      title = 'Rider account';
      icon = Icons.delivery_dining_rounded;
      body =
          'This phone build is the customer app. Riders should sign in using the MND Rider app.';
      nextStep = 'Install and open: MND Rider';
    } else {
      title = 'Vendor account';
      icon = Icons.storefront_rounded;
      body =
          'This phone build is the customer app. Shop owners should sign in using the MND Vendor app.';
      nextStep = 'Install and open: MND Vendor';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Icon(
              icon,
              size: 56,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 20),
            Text(
              'Wrong app for your role',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              body,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            Text(
              nextStep,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 24),
            Text(
              'Use the menu (top right) to sign out.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.outline,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
