import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
      appBar: AppBar(
        title: const Text('Rider approvals'),
      ),
      body: riders.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('$e')),
        data: (List<AdminRiderRow> list) {
          if (list.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No riders waiting for approval.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: list.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? '${widget.rider.fullName} approved'
                : '${widget.rider.fullName} rejected',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final AdminRiderRow rider = widget.rider;
    final ThemeData theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              rider.fullName.isEmpty ? 'Unnamed rider' : rider.fullName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text('Phone: ${rider.phone}'),
            Text('City: ${rider.city}'),
            Text('Vehicle: ${rider.vehicleType} · ${rider.vehicleNumber}'),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _setStatus('rejected'),
                    child: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
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
      ),
    );
  }
}
