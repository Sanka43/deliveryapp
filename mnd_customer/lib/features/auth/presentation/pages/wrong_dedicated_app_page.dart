import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';

/// Shown when this install (customer app) is opened by a rider or vendor account.
class WrongDedicatedAppPage extends StatelessWidget {
  const WrongDedicatedAppPage({
    required this.forRider,
    super.key,
  });

  final bool forRider;

  @override
  Widget build(BuildContext context) {
    final String title = forRider ? 'Rider account' : 'Vendor account';
    final String appName = forRider ? 'MND Rider' : 'MND Vendor';
    final String body = forRider
        ? 'This phone build is the customer app. Riders should sign in using the MND Rider app.'
        : 'This phone build is the customer app. Shop owners should sign in using the MND Vendor app.';

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
              forRider ? Icons.delivery_dining_rounded : Icons.storefront_rounded,
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
              'Install and open: $appName',
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
