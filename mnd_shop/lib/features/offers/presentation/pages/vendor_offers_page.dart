import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/offers/data/offer_image_storage.dart';
import 'package:mnd_shop/features/offers/data/vendor_offers_repository.dart';
import 'package:mnd_shop/features/offers/domain/vendor_offer.dart';
import 'package:mnd_shop/features/offers/presentation/pages/offer_form_page.dart';
import 'package:mnd_shop/features/offers/presentation/providers/vendor_offers_stream_provider.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';

class VendorOffersPage extends ConsumerWidget {
  const VendorOffersPage({super.key});

  String _vTxt(BuildContext context, {required String en, required String si}) {
    final String languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'si') {
      return si;
    }
    if (languageCode == 'ta') {
      return vendorTamilFallback(en);
    }
    return en;
  }

  Color _statusColor(String status) {
    switch (status) {
      case VendorOfferStatus.approved:
        return const Color(0xFF15803D);
      case VendorOfferStatus.rejected:
        return const Color(0xFFB91C1C);
      case 'expired':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFFB45309);
    }
  }

  String _statusLabel(BuildContext context, String status) {
    switch (status) {
      case VendorOfferStatus.approved:
        return _vTxt(context, en: 'Approved', si: 'අනුමත');
      case VendorOfferStatus.rejected:
        return _vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප');
      case 'expired':
        return _vTxt(context, en: 'Expired', si: 'කල් ඉකුත්');
      default:
        return _vTxt(context, en: 'Pending', si: 'රැඳී');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    VendorOffer offer,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(_vTxt(ctx, en: 'Delete offer?', si: 'Offer එක මකන්නද?')),
        content: Text(
          _vTxt(
            ctx,
            en: 'Only pending offers can be deleted.',
            si: 'රැඳී ඇති offers පමණක් මකන්න පුළුවන්.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_vTxt(ctx, en: 'Cancel', si: 'අවලංගු')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_vTxt(ctx, en: 'Delete', si: 'මකන්න')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(vendorOffersRepositoryProvider).deletePendingOffer(offer);
      await ref.read(offerImageStorageProvider).deleteOfferImage(offer.imageUrl);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_vTxt(context, en: 'Offer deleted', si: 'Offer මකන ලදී')),
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not delete offer. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<VendorOffer>> offersAsync =
        ref.watch(vendorOffersStreamProvider);

    return Scaffold(
      backgroundColor: VendorProductsTheme.canvas(context),
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Offers', si: 'Offers')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const OfferFormPage(offer: null),
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: Text(_vTxt(context, en: 'Add offer', si: 'Offer එකතු කරන්න')),
      ),
      body: VendorResponsiveContent(
        child: offersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${_vTxt(context, en: 'Could not load offers', si: 'Offers load කළ නොහැක')}\n${userFacingError(e, fallback: 'Please check your connection and try again.')}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (List<VendorOffer> offers) {
            if (offers.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _vTxt(
                      context,
                      en: 'No offers yet. Add one — it needs admin approval before customers see it.',
                      si: 'තවම offers නැත. එකක් එක් කරන්න — customer ට පෙනෙන්නට admin අනුමැතිය අවශ්‍යයි.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: offers.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final VendorOffer offer = offers[index];
                final String status = offer.displayStatus;
                final Color statusColor = _statusColor(status);
                return Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => OfferFormPage(offer: offer),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: SizedBox(
                              width: 72,
                              height: 72,
                              child: offer.imageUrl.isEmpty
                                  ? ColoredBox(
                                      color: VendorProductsTheme.thumbPlaceholderFill(context),
                                      child: const Icon(Icons.local_offer_outlined),
                                    )
                                  : Image.network(
                                      offer.imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.broken_image_outlined,
                                      ),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  offer.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Rs ${offer.priceLkr}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_vTxt(context, en: 'Ends', si: 'අවසන්')}: ${offer.endsAt.toLocal().toString().substring(0, 16)}',
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                                if (offer.status == VendorOfferStatus.rejected &&
                                    (offer.rejectionReason ?? '').isNotEmpty) ...<Widget>[
                                  const SizedBox(height: 4),
                                  Text(
                                    offer.rejectionReason!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: statusColor),
                                  ),
                                ],
                                const SizedBox(height: 8),
                                Row(
                                  children: <Widget>[
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color: statusColor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        _statusLabel(context, status),
                                        style: TextStyle(
                                          color: statusColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (offer.status == VendorOfferStatus.pending)
                                      IconButton(
                                        tooltip: _vTxt(
                                          context,
                                          en: 'Delete',
                                          si: 'මකන්න',
                                        ),
                                        onPressed: () =>
                                            _confirmDelete(context, ref, offer),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
