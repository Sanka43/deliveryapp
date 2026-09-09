import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_branded_dialog.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/data/rider_session_actions.dart';
import 'package:mnd_rider/features/profile/data/rider_account_deletion_repository.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

/// Lets a rider permanently close their account: removes sign-in and
/// compliance photos, but keeps earnings/cash-ledger/payout records for
/// audit — mirrors the vendor app's "close shop account" flow.
class RiderDeleteAccountPage extends ConsumerStatefulWidget {
  const RiderDeleteAccountPage({super.key});

  @override
  ConsumerState<RiderDeleteAccountPage> createState() =>
      _RiderDeleteAccountPageState();
}

class _RiderDeleteAccountPageState
    extends ConsumerState<RiderDeleteAccountPage> {
  final TextEditingController _reasonController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDelete(RiderProfile profile) async {
    final bool confirm = await showRiderConfirmDialog(
      context,
      title: 'Delete account?',
      message:
          'This permanently removes your MND Rider sign-in and compliance '
          'photos. Earnings, cash-ledger, and payout records are kept for '
          'audit purposes. This cannot be undone.',
      confirmLabel: 'Delete',
      isDestructive: true,
    );
    if (!confirm || !mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(riderAccountDeletionRepositoryProvider)
          .requestDeletion(reason: _reasonController.text);
      if (!mounted) {
        return;
      }
      await riderSignOutAndClear(ref);
    } on RiderAccountDeletionException catch (e) {
      if (mounted) {
        showRiderSnackBar(context, e.message);
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final RiderProfile? profile =
        ref.watch(riderProfileStreamProvider).valueOrNull;

    final bool cashBlocked = profile != null &&
        (profile.cashOwedToAdminLkr > 0 || profile.cashPendingSettlementLkr > 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Delete account')),
      body: profile == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.screenPadding,
                AppSpacing.md,
                AppSpacing.screenPadding,
                32 + MediaQuery.paddingOf(context).bottom,
              ),
              children: <Widget>[
                Icon(Icons.delete_forever_rounded, size: 56, color: cs.error),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'What happens when you delete your account',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.sm),
                _Bullet(
                  text:
                      'Your sign-in and profile/compliance photos (license, '
                      'insurance, vehicle, revenue license) are removed.',
                ),
                const _Bullet(
                  text: 'You immediately go offline and stop receiving jobs.',
                ),
                const _Bullet(
                  text:
                      'Earnings, cash-ledger, and payout records are kept '
                      'for audit and tax purposes, as required by law.',
                ),
                const _Bullet(
                  text: 'This action cannot be undone from the app.',
                ),
                if (cashBlocked) ...<Widget>[
                  const SizedBox(height: AppSpacing.lg),
                  _WarningCard(
                    message: profile.cashPendingSettlementLkr > 0
                        ? 'A cash handover is awaiting admin confirmation. '
                            'Wait for it to be confirmed before deleting your '
                            'account.'
                        : 'You are holding LKR ${profile.cashOwedToAdminLkr} '
                            'owed to admin. Hand it over before deleting your '
                            'account.',
                    actionLabel: 'Go to transactions',
                    onAction: () => context.push(RoutePaths.transactions),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Reason (optional)',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                TextField(
                  controller: _reasonController,
                  enabled: !cashBlocked && !_submitting,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    hintText: 'Tell us why you\'re leaving…',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: cashBlocked || _submitting
                        ? null
                        : () => _confirmAndDelete(profile),
                    style: FilledButton.styleFrom(
                      backgroundColor: cs.error,
                      foregroundColor: cs.onError,
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppSpacing.buttonRadius),
                      ),
                    ),
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Delete account'),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.circle, size: 6, color: cs.onSurfaceVariant),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: cs.onSurfaceVariant, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        border: Border.all(color: cs.error.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(Icons.error_outline_rounded, color: cs.error, size: 20),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: cs.onSurface, height: 1.35),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: onAction, child: Text(actionLabel)),
          ),
        ],
      ),
    );
  }
}
