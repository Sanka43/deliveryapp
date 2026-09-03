import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';

class LogoutActionButton extends ConsumerWidget {
  const LogoutActionButton({super.key});

  Future<void> _confirmAndLogout(BuildContext context, WidgetRef ref) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Do you want to logout from this account?'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    await ref.read(phoneAuthControllerProvider.notifier).signOut();
    if (!context.mounted) {
      return;
    }

    final String? error = ref.read(phoneAuthControllerProvider).errorMessage;
    if (error != null) {
      showMndSnackBar(context, error, variant: MndSnackBarVariant.error);
      return;
    }

    ref.read(guestBrowsingProvider.notifier).state = false;
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool isLoading =
        ref.watch(phoneAuthControllerProvider.select((PhoneAuthState s) => s.isLoading));

    return IconButton(
      tooltip: 'Logout',
      onPressed: isLoading ? null : () => _confirmAndLogout(context, ref),
      icon: isLoading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.logout_rounded),
    );
  }
}
