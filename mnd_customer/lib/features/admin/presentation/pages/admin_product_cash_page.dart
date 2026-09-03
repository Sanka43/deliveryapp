import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/admin/data/admin_product_cash_repository.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';

final AutoDisposeStreamProviderFamily<List<AdminProductCashRow>, String>
    adminProductCashByStatusProvider = StreamProvider.autoDispose
        .family<List<AdminProductCashRow>, String>((Ref ref, String status) {
  final AsyncValue<String?> role = ref.watch(userRoleProvider);
  final bool isAdmin = role.maybeWhen(
    data: (String? r) => r?.trim().toLowerCase() == 'admin',
    orElse: () => false,
  );
  if (!isAdmin) {
    return Stream<List<AdminProductCashRow>>.value(const <AdminProductCashRow>[]);
  }
  return ref.watch(adminProductCashRepositoryProvider).watchByStatus(status);
});

/// Admin ledger: rider-held product cash → remitted → settled to shop.
class AdminProductCashPage extends ConsumerWidget {
  const AdminProductCashPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: AppColors.backgroundCanvas,
        appBar: AppBar(
          title: const Text('Product cash'),
          actions: const <Widget>[LogoutActionButton()],
          bottom: const TabBar(
            isScrollable: true,
            tabs: <Widget>[
              Tab(text: 'Owed'),
              Tab(text: 'Requested'),
              Tab(text: 'Remitted'),
              Tab(text: 'Settled'),
            ],
          ),
        ),
        body: const TabBarView(
          children: <Widget>[
            _CashTab(status: 'owed'),
            _CashTab(status: 'remittance_requested'),
            _CashTab(status: 'remitted_to_admin'),
            _CashTab(status: 'settled_to_shop'),
          ],
        ),
      ),
    );
  }
}

class _CashTab extends ConsumerWidget {
  const _CashTab({required this.status});

  final String status;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminProductCashRow>> async =
        ref.watch(adminProductCashByStatusProvider(status));

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator.adaptive()),
      error: (Object e, StackTrace _) => Center(child: Text('$e')),
      data: (List<AdminProductCashRow> rows) {
        if (rows.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
              child: Text(
                status == 'owed'
                    ? 'No product cash still held by riders.'
                    : status == 'remittance_requested'
                        ? 'No handover requests waiting for confirmation.'
                        : status == 'remitted_to_admin'
                            ? 'No remitted cash waiting to pay shops.'
                            : 'No settled product-cash rows yet.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
              ),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: rows.length,
          separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
          itemBuilder: (BuildContext context, int i) {
            final AdminProductCashRow row = rows[i];
            return _CashCard(row: row, status: status);
          },
        );
      },
    );
  }
}

class _CashCard extends ConsumerStatefulWidget {
  const _CashCard({required this.row, required this.status});

  final AdminProductCashRow row;
  final String status;

  @override
  ConsumerState<_CashCard> createState() => _CashCardState();
}

class _CashCardState extends ConsumerState<_CashCard> {
  bool _busy = false;

  Future<void> _run(Future<String?> Function() action, String okMsg) async {
    setState(() => _busy = true);
    final String? err = await action();
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
    final AdminProductCashRow row = widget.row;
    final ThemeData theme = Theme.of(context);
    final String delivered = row.deliveredAt == null
        ? '—'
        : '${row.deliveredAt!.year}-${row.deliveredAt!.month.toString().padLeft(2, '0')}-${row.deliveredAt!.day.toString().padLeft(2, '0')}';

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            row.referenceForDisplay,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            '${row.storeName} · Rs. ${row.productCashLkr}',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Rider: ${row.riderId.isEmpty ? '—' : row.riderId}\nDelivered: $delivered',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (widget.status == 'owed') ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Waiting for the rider to request a handover.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          if (widget.status == 'remittance_requested') ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref
                            .read(adminProductCashRepositoryProvider)
                            .markRemitted(row.id),
                        'Confirmed cash received from rider.',
                      ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Confirm received'),
            ),
          ],
          if (widget.status == 'remitted_to_admin') ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => _run(
                        () => ref
                            .read(adminProductCashRepositoryProvider)
                            .markSettledToShop(row.id),
                        'Marked settled to shop.',
                      ),
              child: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Paid to shop'),
            ),
          ],
        ],
      ),
    );
  }
}
