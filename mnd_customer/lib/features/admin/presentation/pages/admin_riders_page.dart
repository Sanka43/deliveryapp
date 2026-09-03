import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/admin/data/admin_riders_repository.dart';

final AutoDisposeStreamProvider<List<AdminRiderRow>> adminPendingRidersProvider =
    StreamProvider.autoDispose<List<AdminRiderRow>>((Ref ref) {
  return ref.watch(adminRidersRepositoryProvider).watchRiders(status: 'pending');
});

class AdminRidersPage extends ConsumerWidget {
  const AdminRidersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminRiderRow>> riders =
        ref.watch(adminPendingRidersProvider);

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(title: 'Rider approvals'),
      body: riders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<AdminRiderRow> list) {
          if (list.isEmpty) {
            return const MndEmptyState(
              icon: Icons.delivery_dining_outlined,
              title: 'No riders waiting for approval',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final AdminRiderRow rider = list[index];
              return _RiderApprovalCard(rider: rider);
            },
          );
        },
      ),
    );
  }
}

class _RiderApprovalCard extends ConsumerStatefulWidget {
  const _RiderApprovalCard({required this.rider});

  final AdminRiderRow rider;

  @override
  ConsumerState<_RiderApprovalCard> createState() => _RiderApprovalCardState();
}

class _RiderApprovalCardState extends ConsumerState<_RiderApprovalCard> {
  bool _busy = false;

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    final String? err = await ref.read(adminRidersRepositoryProvider).setRiderStatus(
          riderId: widget.rider.uid,
          status: status,
        );
    if (!mounted) {
      return;
    }
    setState(() => _busy = false);
    if (err != null) {
      showMndSnackBar(context, err, variant: MndSnackBarVariant.error);
    } else {
      showMndSnackBar(
        context,
        status == 'approved'
            ? '${widget.rider.fullName} approved'
            : '${widget.rider.fullName} rejected',
        variant: MndSnackBarVariant.success,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminRiderRow rider = widget.rider;
    final ThemeData theme = Theme.of(context);

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusMd,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            rider.fullName.isEmpty ? 'Unnamed rider' : rider.fullName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Phone: ${rider.phone}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'City: ${rider.city}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          Text(
            'Vehicle: ${rider.vehicleType} · ${rider.vehicleNumber}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => _setStatus('rejected'),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : () => _setStatus('approved'),
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Approve'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
