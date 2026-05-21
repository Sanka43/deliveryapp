import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/widgets/logout_action_button.dart';
import 'package:mnd_delivery_app/features/admin/data/admin_orders_repository.dart';

final AutoDisposeStreamProvider<List<AdminOrderRow>> adminOrdersListProvider =
    StreamProvider.autoDispose<List<AdminOrderRow>>((Ref ref) {
  return ref.watch(adminOrdersRepositoryProvider).watchRecentOrders();
});

class AdminOrdersPage extends ConsumerWidget {
  const AdminOrdersPage({super.key});

  static Future<void> _promptAssign(
    BuildContext context,
    WidgetRef ref,
    AdminOrderRow row,
  ) async {
    final TextEditingController c = TextEditingController(text: row.riderId ?? '');
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text('Assign rider · ${row.referenceForDisplay}', maxLines: 1, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            labelText: 'Rider Firebase UID',
            border: OutlineInputBorder(),
          ),
          autocorrect: false,
        ),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    final String? err = await ref.read(adminOrdersRepositoryProvider).assignRider(
          orderId: row.id,
          riderUid: c.text,
        );
    if (!context.mounted) {
      return;
    }
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rider assigned.')),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<AdminOrderRow>> orders = ref.watch(adminOrdersListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orders (admin)'),
        actions: const <Widget>[
          LogoutActionButton(),
        ],
      ),
      body: orders.when(
        data: (List<AdminOrderRow> list) {
          if (list.isEmpty) {
            return const Center(child: Text('No orders found.'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int i) {
              final AdminOrderRow row = list[i];
              return ListTile(
                title: Text(
                  row.referenceForDisplay,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: row.trackingNumber?.trim().isNotEmpty == true
                      ? Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w600,
                          )
                      : null,
                ),
                subtitle: Text(
                  'status: ${row.status}\nstore: ${row.vendorId}\ncustomer: ${row.customerId}\n'
                  'rider: ${row.riderId ?? '—'}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                isThreeLine: true,
                trailing: IconButton(
                  tooltip: 'Assign rider',
                  icon: const Icon(Icons.delivery_dining_outlined),
                  onPressed: () => _promptAssign(context, ref, row),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
