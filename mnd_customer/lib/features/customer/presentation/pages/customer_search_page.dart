import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';

class CustomerSearchPage extends ConsumerStatefulWidget {
  const CustomerSearchPage({super.key});

  @override
  ConsumerState<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends ConsumerState<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String query = ref.read(customerSearchQueryProvider);
      if (query.isNotEmpty) {
        _searchController.text = query;
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    ref.read(customerSearchQueryProvider.notifier).state = value;
    setState(() {});
  }

  Future<void> _persistRecent(String value) async {
    final String trimmed = value.trim();
    if (trimmed.length >= 2) {
      await ref.read(homeRecentSearchesProvider.notifier).addSearch(trimmed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final storesState = ref.watch(storesStreamProvider);
    final productsState = ref.watch(productsStreamProvider);
    final List<SearchStore> filteredStores = ref.watch(filteredStoresProvider);
    final List<SearchProduct> filteredProducts = ref.watch(filteredProductsProvider);
    final bool isLoading = (storesState.isLoading && !storesState.hasValue) ||
        (productsState.isLoading && !productsState.hasValue);
    final bool hasError = storesState.hasError || productsState.hasError;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Search',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onQueryChanged,
                onSubmitted: _persistRecent,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search foods, groceries, pharmacies…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.trim().isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: Colors.black.withValues(alpha: 0.04),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : hasError
                    ? const _SearchPermissionError()
                    : ListView(
                        children: <Widget>[
                          _SearchSectionTitle(
                            title: 'Stores (${filteredStores.length})',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (filteredStores.isEmpty)
                            const _EmptyResult(text: 'No stores found')
                          else
                            ...filteredStores.map((item) => _StoreTile(item: item)),
                          const SizedBox(height: AppSpacing.lg),
                          _SearchSectionTitle(
                            title: 'Products (${filteredProducts.length})',
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          if (filteredProducts.isEmpty)
                            const _EmptyResult(text: 'No products found')
                          else
                            ...filteredProducts.map((item) => _ProductTile(item: item)),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchSectionTitle extends StatelessWidget {
  const _SearchSectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium,
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.item});

  final SearchStore item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.storefront_rounded, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  '${item.tag} • ${item.eta}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          Row(
            children: <Widget>[
              const Icon(Icons.star_rounded, size: 16, color: Colors.amber),
              Text(item.rating.toStringAsFixed(1)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item});

  final SearchProduct item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_rounded, color: AppColors.primaryBlue),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                Text(
                  item.storeName,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ],
            ),
          ),
          Text(
            item.price,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _EmptyResult extends StatelessWidget {
  const _EmptyResult({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text),
    );
  }
}

class _SearchPermissionError extends StatelessWidget {
  const _SearchPermissionError();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.md),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: const Text(
          'Cannot load search data right now.\nPlease check Firestore rules.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
