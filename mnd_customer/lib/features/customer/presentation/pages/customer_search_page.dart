import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_section_header.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_empty_state.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_search_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/home_recent_searches_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/home/home_navigation_helpers.dart';

class CustomerSearchPage extends ConsumerStatefulWidget {
  const CustomerSearchPage({this.initialQuery, super.key});

  final String? initialQuery;

  @override
  ConsumerState<CustomerSearchPage> createState() => _CustomerSearchPageState();
}

class _CustomerSearchPageState extends ConsumerState<CustomerSearchPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final String fromRoute = (widget.initialQuery ?? '').trim();
      final String fromProvider = ref.read(customerSearchQueryProvider);
      final String query = fromRoute.isNotEmpty ? fromRoute : fromProvider;
      if (query.isNotEmpty) {
        _searchController.text = query;
        if (fromRoute.isNotEmpty) {
          ref.read(customerSearchQueryProvider.notifier).state = fromRoute;
        }
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
    final List<SearchProduct> filteredProducts =
        ref.watch(filteredProductsProvider);
    final bool isLoading = (storesState.isLoading && !storesState.hasValue) ||
        (productsState.isLoading && !productsState.hasValue);
    final bool hasError = storesState.hasError || productsState.hasError;
    final String query = _searchController.text.trim();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'Search'),
      body: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              TextField(
                controller: _searchController,
                autofocus: true,
                onChanged: _onQueryChanged,
                onSubmitted: _persistRecent,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search foods, groceries, pharmacies…',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            _onQueryChanged('');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                  filled: true,
                  fillColor: AppColors.surfaceElevated,
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.cardRadiusSm),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppColors.cardRadiusSm),
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
                              MndSectionHeader(
                                title: 'Stores (${filteredStores.length})',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (filteredStores.isEmpty)
                                _EmptyResult(
                                  text: query.isEmpty
                                      ? 'Start typing to find stores'
                                      : 'No stores found',
                                )
                              else
                                ...filteredStores.map(
                                  (SearchStore item) => _StoreTile(
                                    item: item,
                                    onTap: () =>
                                        openStoreDetails(context, item),
                                  ),
                                ),
                              const SizedBox(height: AppSpacing.lg),
                              MndSectionHeader(
                                title:
                                    'Products (${filteredProducts.length})',
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              if (filteredProducts.isEmpty)
                                _EmptyResult(
                                  text: query.isEmpty
                                      ? 'Start typing to find products'
                                      : 'No products found',
                                )
                              else
                                ...filteredProducts.map(
                                  (SearchProduct item) => _ProductTile(
                                    item: item,
                                    onTap: () => openStoreMenuForProductChoice(
                                      context,
                                      ref,
                                      item,
                                    ),
                                  ),
                                ),
                            ],
                          ),
              ),
            ],
          ),
      ),
    );
  }
}

class _StoreTile extends StatelessWidget {
  const _StoreTile({required this.item, required this.onTap});

  final SearchStore item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MndPremiumCard(
        onTap: onTap,
        borderRadius: AppColors.cardRadiusSm,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.storefront_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    '${item.tag} • ${item.eta}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Row(
              children: <Widget>[
                const Icon(Icons.star_rounded, size: 16, color: AppColors.warning),
                Text(item.rating.toStringAsFixed(1)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.item, required this.onTap});

  final SearchProduct item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: MndPremiumCard(
        onTap: onTap,
        borderRadius: AppColors.cardRadiusSm,
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: <Widget>[
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.brandPrimary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppColors.buttonRadius),
              ),
              child: const Icon(
                Icons.inventory_2_rounded,
                color: AppColors.brandPrimary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(item.name, style: Theme.of(context).textTheme.titleSmall),
                  Text(
                    item.storeName,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                ],
              ),
            ),
            Text(
              item.price,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.brandPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
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
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.homeMutedFill,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
            ),
      ),
    );
  }
}

class _SearchPermissionError extends StatelessWidget {
  const _SearchPermissionError();

  @override
  Widget build(BuildContext context) {
    return MndEmptyState(
      icon: Icons.cloud_off_rounded,
      title: 'Search unavailable',
      subtitle: 'We could not load stores right now. Please try again shortly.',
      actionLabel: 'Retry',
      onAction: () {
        // Providers auto-refresh on rebuild; pop-and-push is unnecessary.
      },
    );
  }
}
