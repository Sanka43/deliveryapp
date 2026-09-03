import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/admin/data/admin_withdrawals_repository.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';

final AutoDisposeStreamProvider<List<AdminWithdrawalRow>>
    adminPendingWithdrawalsProvider =
    StreamProvider.autoDispose<List<AdminWithdrawalRow>>((Ref ref) {
  final AsyncValue<String?> role = ref.watch(userRoleProvider);
  final bool isAdmin = role.maybeWhen(
    data: (String? r) => r?.trim().toLowerCase() == 'admin',
    orElse: () => false,
  );
  if (!isAdmin) {
    return Stream<List<AdminWithdrawalRow>>.value(const <AdminWithdrawalRow>[]);
  }
  return ref.watch(adminWithdrawalsRepositoryProvider).watchPending();
});

class AdminWithdrawalsPage extends ConsumerWidget {
  const AdminWithdrawalsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminWithdrawalRow>> async =
        ref.watch(adminPendingWithdrawalsProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Rider withdrawals',
        actions: const <Widget>[LogoutActionButton()],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator.adaptive()),
        error: (Object e, StackTrace _) => Center(child: Text('$e')),
        data: (List<AdminWithdrawalRow> rows) {
          if (rows.isEmpty) {
            return const MndEmptyState(
              icon: Icons.payments_outlined,
              title: 'No pending rider payout requests',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: rows.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int i) {
              return _WithdrawalCard(row: rows[i]);
            },
          );
        },
      ),
    );
  }
}

class _WithdrawalCard extends ConsumerStatefulWidget {
  const _WithdrawalCard({required this.row});

  final AdminWithdrawalRow row;

  @override
  ConsumerState<_WithdrawalCard> createState() => _WithdrawalCardState();
}

class _WithdrawalCardState extends ConsumerState<_WithdrawalCard> {
  bool _busy = false;

  Future<void> _settle(String action, String okMsg) async {
    setState(() => _busy = true);
    final String? err = await ref.read(adminWithdrawalsRepositoryProvider).settle(
          riderId: widget.row.riderId,
          withdrawalId: widget.row.id,
          action: action,
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      showMndSnackBar(context, err, variant: MndSnackBarVariant.error);
    } else {
      showMndSnackBar(context, okMsg, variant: MndSnackBarVariant.success);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminWithdrawalRow row = widget.row;
    final ThemeData theme = Theme.of(context);
    final String created = row.createdAt == null
        ? '—'
        : '${row.createdAt!.year}-${row.createdAt!.month.toString().padLeft(2, '0')}-${row.createdAt!.day.toString().padLeft(2, '0')}';

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            'Rs. ${row.amountLkr}',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${row.payoutMethod} · ${row.payoutAccount}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Rider: ${row.riderId.isEmpty ? '—' : row.riderId}\n'
            'Status: ${row.status} · Requested: $created',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (row.note != null && row.note!.isNotEmpty) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              row.note!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton(
                  onPressed: _busy
                      ? null
                      : () => _settle('paid', 'Marked paid.'),
                  child: const Text('Mark paid'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy
                      ? null
                      : () => _settle('rejected', 'Rejected and refunded.'),
                  child: const Text('Reject'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
