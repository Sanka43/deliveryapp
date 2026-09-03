import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';

/// A card with a tappable header that expands/collapses its body.
///
/// Used for optional or already-answered sections (promo codes, delivery
/// notes, order line items on checkout) so a filled-in or reviewed section
/// can collapse to a one-line summary instead of always taking up scroll
/// space.
class MndExpandableCard extends StatefulWidget {
  const MndExpandableCard({
    super.key,
    required this.icon,
    required this.title,
    required this.builder,
    this.summary,
    this.summaryColor,
    this.initiallyExpanded = false,
  });

  final IconData icon;
  final String title;
  final WidgetBuilder builder;
  final String? summary;
  final Color? summaryColor;
  final bool initiallyExpanded;

  @override
  State<MndExpandableCard> createState() => _MndExpandableCardState();
}

class _MndExpandableCardState extends State<MndExpandableCard> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusSm,
      padding: EdgeInsets.zero,
      child: Column(
        children: <Widget>[
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(AppColors.cardRadiusSm),
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.sm),
                child: Row(
                  children: <Widget>[
                    Icon(widget.icon, size: 20, color: AppColors.primaryBlue),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (widget.summary != null) ...<Widget>[
                      Flexible(
                        child: Text(
                          widget.summary!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: widget.summaryColor ?? AppColors.textSecondary,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                    ],
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 200),
            sizeCurve: Curves.easeInOut,
            crossFadeState:
                _expanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            firstChild: const SizedBox(width: double.infinity, height: 0),
            secondChild: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.sm,
                0,
                AppSpacing.sm,
                AppSpacing.sm,
              ),
              child: Builder(builder: widget.builder),
            ),
          ),
        ],
      ),
    );
  }
}
