import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/saved_addresses_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/address_form_dialog.dart';

class SavedAddressesPage extends ConsumerWidget {
  const SavedAddressesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<SavedAddress>> async = ref.watch(savedAddressesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved addresses'),
      ),
      body: async.when(
        data: (List<SavedAddress> addresses) {
          if (addresses.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      'No saved addresses yet.',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Tap + to add your home or office.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.md),
            itemCount: addresses.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
            itemBuilder: (BuildContext context, int index) {
              final SavedAddress a = addresses[index];
              return Card(
                child: ListTile(
                  leading: Icon(
                    a.isDefault ? Icons.star_rounded : Icons.location_on_outlined,
                    color: a.isDefault ? Colors.amber.shade700 : null,
                  ),
                  title: Text(a.label),
                  subtitle: Text(
                    '${a.line1}${a.line2.isNotEmpty ? ', ${a.line2}' : ''}\n${a.city} · ${a.phone}',
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (String value) async {
                      final SavedAddressesActions actions =
                          ref.read(savedAddressesActionsProvider);
                      if (value == 'edit') {
                        final SavedAddress? result = await showDialog<SavedAddress>(
                          context: context,
                          builder: (BuildContext ctx) => AddressFormDialog(
                            title: 'Edit address',
                            initial: a,
                          ),
                        );
                        if (result != null && context.mounted) {
                          final String? err = await actions.updateAddress(
                            id: a.id,
                            label: result.label,
                            line1: result.line1,
                            line2: result.line2,
                            city: result.city,
                            phone: result.phone,
                            isDefault: result.isDefault,
                          );
                          if (context.mounted && err != null) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                          }
                        }
                      } else if (value == 'default') {
                        final String? err = await actions.setDefaultAddress(a.id);
                        if (context.mounted && err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      } else if (value == 'delete') {
                        final String? err = await actions.deleteAddress(a.id);
                        if (context.mounted && err != null) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
                        }
                      }
                    },
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                      const PopupMenuItem<String>(value: 'edit', child: Text('Edit')),
                      if (!a.isDefault)
                        const PopupMenuItem<String>(value: 'default', child: Text('Set as default')),
                      const PopupMenuItem<String>(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Could not load addresses.\n$e',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final SavedAddress? result = await showDialog<SavedAddress>(
            context: context,
            builder: (BuildContext ctx) => const AddressFormDialog(
              title: 'New address',
            ),
          );
          if (result != null && context.mounted) {
            final SavedAddressesActions actions = ref.read(savedAddressesActionsProvider);
            final String? err = await actions.addAddress(
              label: result.label,
              line1: result.line1,
              line2: result.line2,
              city: result.city,
              phone: result.phone,
              setAsDefault: result.isDefault,
            );
            if (context.mounted && err != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
            }
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
