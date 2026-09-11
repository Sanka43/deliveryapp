import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/ratings/data/vendor_ratings_repository.dart';
import 'package:mnd_shop/features/ratings/domain/vendor_review.dart';
import 'package:mnd_shop/features/ratings/presentation/providers/vendor_ratings_providers.dart';

/// Customer reviews for the signed-in shop (read-only) — `store_ratings`
/// filtered to this vendor. Previously vendors had no way to see individual
/// review comments or know why their rating moved, only the bare aggregate
/// number (and even that wasn't shown anywhere in the app).
class VendorReviewsPage extends ConsumerWidget {
  const VendorReviewsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final AsyncValue<List<VendorReview>> reviews = ref.watch(vendorReviewsListProvider);
    final AsyncValue<VendorRatingSummary> summary = ref.watch(vendorRatingSummaryProvider);

    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Reviews', si: 'ඇගයීම්')),
      ),
      body: storeId.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _vTxt(
                    context,
                    en: 'Link your store to view reviews.',
                    si: 'ඇගයීම් බැලීමට ඔබේ store එක link කරන්න.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                ),
              ),
            )
          : reviews.when(
              loading: () => const Center(child: CircularProgressIndicator.adaptive()),
              error: (Object e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    userFacingError(e, fallback: 'Could not load reviews.'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                  ),
                ),
              ),
              data: (List<VendorReview> list) {
                if (list.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                    children: <Widget>[
                      _SummaryCard(summary: summary.valueOrNull ?? VendorRatingSummary.zero),
                      const SizedBox(height: 60),
                      Center(
                        child: Column(
                          children: <Widget>[
                            Icon(
                              Icons.star_outline_rounded,
                              size: 48,
                              color: AppColors.textMuted.withValues(alpha: 0.7),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _vTxt(context, en: 'No reviews yet', si: 'තවම ඇගයීම් නැත'),
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: AppColors.textCharcoal,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _vTxt(
                                context,
                                en: 'Customer reviews will appear here after delivered orders.',
                                si: 'Delivered orders වලින් පස්සේ customer reviews මෙහි පෙන්වයි.',
                              ),
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(color: AppColors.textMuted),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: <Widget>[
                    _SummaryCard(
                      summary: summary.valueOrNull ?? VendorRatingSummary.zero,
                      distribution: _starDistribution(list),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      _vTxt(context, en: 'Recent reviews', si: 'මෑත ඇගයීම්'),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.textCharcoal,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...list.map(
                      (VendorReview r) => Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        // Keyed by review id: the reviews stream is live, so
                        // a new review landing mid-session can reorder this
                        // list — without a key, Flutter reconciles by
                        // position and an in-progress reply draft could
                        // reattach to the wrong review.
                        child: _ReviewTile(key: ValueKey<String>(r.id), review: r),
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  static Map<int, int> _starDistribution(List<VendorReview> reviews) {
    final Map<int, int> counts = <int, int>{5: 0, 4: 0, 3: 0, 2: 0, 1: 0};
    for (final VendorReview r in reviews) {
      if (r.stars >= 1 && r.stars <= 5) {
        counts[r.stars] = (counts[r.stars] ?? 0) + 1;
      }
    }
    return counts;
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary, this.distribution});

  final VendorRatingSummary summary;
  final Map<int, int>? distribution;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Map<int, int> dist = distribution ?? const <int, int>{};
    final int maxCount = dist.values.fold(0, (int a, int b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                summary.average > 0 ? summary.average.toStringAsFixed(1) : '—',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textCharcoal,
                ),
              ),
              const SizedBox(height: 4),
              _StarRow(filled: summary.average.round()),
              const SizedBox(height: 4),
              Text(
                '${summary.count} ${summary.count == 1 ? 'review' : 'reviews'}',
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          if (dist.isNotEmpty) ...<Widget>[
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <int>[5, 4, 3, 2, 1].map((int star) {
                  final int count = dist[star] ?? 0;
                  final double fraction = maxCount == 0 ? 0 : count / maxCount;
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: <Widget>[
                        Text(
                          '$star',
                          style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: fraction,
                              minHeight: 6,
                              backgroundColor: AppColors.borderLight,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.pendingAmber),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        SizedBox(
                          width: 18,
                          child: Text(
                            '$count',
                            style: theme.textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(growable: false),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StarRow extends StatelessWidget {
  const _StarRow({required this.filled});

  final int filled;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List<Widget>.generate(5, (int i) {
        return Icon(
          i < filled ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 16,
          color: AppColors.pendingAmber,
        );
      }),
    );
  }
}

class _ReviewTile extends ConsumerStatefulWidget {
  const _ReviewTile({super.key, required this.review});

  final VendorReview review;

  static String _formatDate(DateTime? d) {
    if (d == null) {
      return '';
    }
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  ConsumerState<_ReviewTile> createState() => _ReviewTileState();
}

class _ReviewTileState extends ConsumerState<_ReviewTile> {
  bool _composing = false;
  bool _sending = false;
  late final TextEditingController _replyCtrl =
      TextEditingController(text: widget.review.vendorReply);

  @override
  void dispose() {
    _replyCtrl.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_sending) return;
    setState(() => _sending = true);
    final String? error = await ref
        .read(vendorRatingsRepositoryProvider)
        .replyToReview(reviewId: widget.review.id, reply: _replyCtrl.text);
    if (!mounted) return;
    setState(() {
      _sending = false;
      if (error == null) {
        _composing = false;
      }
    });
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final VendorReview review = widget.review;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              _StarRow(filled: review.stars),
              const Spacer(),
              Text(
                _ReviewTile._formatDate(review.createdAt),
                style: theme.textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
          if (review.comment.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              review.comment,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.textCharcoal,
                height: 1.4,
              ),
            ),
          ],
          if (review.hasVendorReply && !_composing) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.canvas,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _vTxt(context, en: 'Your reply', si: 'ඔබේ පිළිතුර'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    review.vendorReply,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textCharcoal,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => setState(() => _composing = true),
                child: Text(_vTxt(context, en: 'Edit reply', si: 'පිළිතුර වෙනස් කරන්න')),
              ),
            ),
          ] else if (!_composing) ...<Widget>[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => setState(() => _composing = true),
                icon: const Icon(Icons.reply_rounded, size: 16),
                label: Text(_vTxt(context, en: 'Reply', si: 'පිළිතුරු දෙන්න')),
              ),
            ),
          ],
          if (_composing) ...<Widget>[
            const SizedBox(height: 10),
            TextField(
              controller: _replyCtrl,
              maxLines: 3,
              maxLength: 500,
              enabled: !_sending,
              decoration: InputDecoration(
                hintText: _vTxt(
                  context,
                  en: 'Write a public reply to this review…',
                  si: 'මෙම ඇගයීමට public පිළිතුරක් ලියන්න…',
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                TextButton(
                  onPressed: _sending
                      ? null
                      : () => setState(() {
                            _composing = false;
                            _replyCtrl.text = review.vendorReply;
                          }),
                  child: Text(_vTxt(context, en: 'Cancel', si: 'අවලංගු කරන්න')),
                ),
                const SizedBox(width: 6),
                FilledButton(
                  onPressed: _sending ? null : _send,
                  child: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_vTxt(context, en: 'Send', si: 'යවන්න')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') {
    return si;
  }
  if (languageCode == 'ta') {
    return ta ?? vendorTamilFallback(en);
  }
  return en;
}
