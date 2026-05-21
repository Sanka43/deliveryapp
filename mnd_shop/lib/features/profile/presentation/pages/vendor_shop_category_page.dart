import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/features/auth/presentation/providers/shop_registration_category_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/profile/data/vendor_profile_repository.dart';

class VendorShopCategoryPage extends ConsumerStatefulWidget {
  const VendorShopCategoryPage({super.key});

  @override
  ConsumerState<VendorShopCategoryPage> createState() => _VendorShopCategoryPageState();
}

class _VendorShopCategoryPageState extends ConsumerState<VendorShopCategoryPage> {
  String? _categoryId;
  String? _categoryLabel;
  String? _shopType;
  bool _hydrated = false;
  bool _saving = false;

  void _hydrate(Map<String, dynamic>? doc, List<ShopCategoryOption> categories) {
    if (_hydrated || doc == null) {
      return;
    }
    _hydrated = true;
    final String cat = (doc['category'] as String?)?.trim() ?? '';
    final String tag = (doc['tag'] as String?)?.trim() ?? '';
    _shopType = tag.isEmpty ? null : tag;
    for (final ShopCategoryOption o in categories) {
      if (o.label == cat) {
        _categoryId = o.id;
        _categoryLabel = o.label;
        break;
      }
    }
    if (_categoryLabel == null && cat.isNotEmpty) {
      _categoryLabel = cat;
      _categoryId = '__legacy_$cat';
    }
  }

  bool get _readOnly {
    final String? approval = ref.read(vendorAccountDocDataProvider).valueOrNull?['approvalStatus'] as String?;
    return approval == 'pending';
  }

  Future<void> _save() async {
    final String? cat = _categoryLabel;
    final String? type = _shopType;
    if (cat == null || cat.isEmpty || type == null || type.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select category and shop type.')),
      );
      return;
    }
    setState(() => _saving = true);
    final String? err = await ref.read(vendorProfileRepositoryProvider).updateCategoryTag(
          category: cat,
          tag: type,
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Category saved.')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<ShopCategoryOption>> categoriesAsync =
        ref.watch(shopRegistrationCategoriesProvider);
    final Map<String, dynamic>? doc = ref.watch(vendorAccountDocDataProvider).valueOrNull;
    final List<ShopCategoryOption> categories = categoriesAsync.valueOrNull ?? <ShopCategoryOption>[];
    _hydrate(doc, categories);

    final String categoryKey = _categoryId ?? '';
    final AsyncValue<List<String>> typesAsync =
        ref.watch(shopRegistrationShopTypeLabelsProvider(categoryKey));

    final bool readOnly = _readOnly;

    return Scaffold(
      appBar: AppBar(title: const Text('Category & type')),
      body: categoriesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (Object e, _) => Center(child: Text('Could not load categories.\n$e')),
        data: (_) {
          return AbsorbPointer(
            absorbing: _saving || readOnly,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
              children: <Widget>[
                if (readOnly)
                  Card(
                    color: Theme.of(context).colorScheme.errorContainer.withValues(alpha: 0.35),
                    child: const ListTile(
                      leading: Icon(Icons.info_outline),
                      title: Text('Pending approval'),
                      subtitle: Text(
                        'Category cannot be changed until your shop is approved.',
                      ),
                    ),
                  ),
                if (readOnly) const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _categoryId,
                  decoration: const InputDecoration(labelText: 'Category *'),
                  items: <DropdownMenuItem<String>>[
                    for (final ShopCategoryOption o in categories)
                      DropdownMenuItem<String>(
                        value: o.id,
                        child: Text(o.label),
                      ),
                  ],
                  onChanged: readOnly
                      ? null
                      : (String? id) {
                          if (id == null) {
                            return;
                          }
                          ShopCategoryOption? match;
                          for (final ShopCategoryOption o in categories) {
                            if (o.id == id) {
                              match = o;
                              break;
                            }
                          }
                          setState(() {
                            _categoryId = id;
                            _categoryLabel = match?.label;
                            _shopType = null;
                          });
                        },
                ),
                const SizedBox(height: 16),
                typesAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (_, _) => const SizedBox.shrink(),
                  data: (List<String> types) {
                    if (categoryKey.isEmpty) {
                      return const Text('Select a category first.');
                    }
                    return DropdownButtonFormField<String>(
                      value: _shopType != null && types.contains(_shopType)
                          ? _shopType
                          : null,
                      decoration: const InputDecoration(labelText: 'Shop type *'),
                      items: <DropdownMenuItem<String>>[
                        for (final String t in types)
                          DropdownMenuItem<String>(value: t, child: Text(t)),
                      ],
                      onChanged: readOnly
                          ? null
                          : (String? v) => setState(() => _shopType = v),
                    );
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_saving ? 'Saving…' : 'Save'),
            ),
    );
  }
}
