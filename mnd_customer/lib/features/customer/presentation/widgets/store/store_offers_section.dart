import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/offers/domain/customer_offer.dart';
import 'package:mnd_delivery_app/features/offers/presentation/offer_order_helpers.dart';
import 'package:mnd_delivery_app/features/offers/presentation/providers/customer_offers_provider.dart';

/// Horizontal live offers strip on store details.
class StoreOffersSection extends ConsumerWidget {
  const StoreOffersSection({
    required this.storeId,
    this.insetHorizontal = true,
    super.key,
  });

  final String storeId;
  final bool insetHorizontal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<CustomerOffer>> offersAsync =
        ref.watch(storeLiveOffersProvider(storeId));

    return offersAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (List<CustomerOffer> offers) {
        if (offers.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(
                insetHorizontal ? AppSpacing.md : 0,
                AppSpacing.sm,
                insetHorizontal ? AppSpacing.md : 0,
                8,
              ),
              child: Text(
                'Offers',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
              ),
            ),
            SizedBox(
              height: 168,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: insetHorizontal ? AppSpacing.md : 0,
                ),
                itemCount: offers.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (BuildContext context, int index) {
                  return _StoreOfferCard(offer: offers[index]);
                },
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Divider(
              height: 1,
              thickness: 1,
              indent: insetHorizontal ? 0 : 0,
              color: AppColors.homeMutedFill.withValues(alpha: 0.9),
            ),
          ],
        );
      },
    );
  }
}

class _StoreOfferCard extends ConsumerWidget {
  const _StoreOfferCard({required this.offer});

  final CustomerOffer offer;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: 220,
      child: Material(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
          side: BorderSide(
            color: AppColors.homeMutedFill.withValues(alpha: 0.95),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              height: 78,
              child: MndNetworkImage(
                imageUrl: offer.imageUrl,
                width: double.infinity,
                height: 78,
                fit: BoxFit.cover,
                showWatermarkOnError: false,
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      offer.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    Text(
                      formatOfferPrice(offer.priceLkr),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: AppColors.brandPrimary,
                          ),
                    ),
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Text(
                            formatOfferEndsLabel(offer.endsAt),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              orderCustomerOffer(context, ref, offer),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            foregroundColor: AppColors.brandPrimary,
                          ),
                          child: Text(
                            'Order',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
