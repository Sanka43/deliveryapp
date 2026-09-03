import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';

/// Clears guest mode and navigates to login, then resumes [redirectTo] after auth.
void navigateToSignIn(
  WidgetRef ref,
  BuildContext context, {
  String redirectTo = AppRoutes.customerCheckout,
}) {
  ref.read(guestBrowsingProvider.notifier).state = false;
  ref.read(postAuthRedirectProvider.notifier).state = redirectTo;
  context.go(AppRoutes.login);
}

/// Clears guest mode and navigates to login so the user can place orders.
void navigateToSignInForCheckout(WidgetRef ref, BuildContext context) {
  navigateToSignIn(ref, context, redirectTo: AppRoutes.customerCheckout);
}

/// Banner shown when an action requires authentication.
class SignInRequiredBanner extends ConsumerWidget {
  const SignInRequiredBanner({
    this.message = 'Sign in to place your order and track delivery.',
    this.redirectTo = AppRoutes.customerCheckout,
    super.key,
  });

  final String message;

  /// Route to open after a successful sign-in.
  final String redirectTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.lock_outline_rounded,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    message,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: () => navigateToSignIn(
                ref,
                context,
                redirectTo: redirectTo,
              ),
              child: const Text('Sign in'),
            ),
          ],
        ),
      ),
    );
  }
}
