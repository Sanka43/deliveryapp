import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Pulsing placeholder block for loading states. Flat/no elevation, sized
/// like the content it stands in for.
class RiderSkeletonBox extends StatefulWidget {
  const RiderSkeletonBox({
    super.key,
    this.width,
    this.height = 16,
    this.borderRadius,
  });

  final double? width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  State<RiderSkeletonBox> createState() => _RiderSkeletonBoxState();
}

class _RiderSkeletonBoxState extends State<RiderSkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: Color.lerp(
              cs.surfaceContainerHighest,
              cs.surfaceContainerHigh,
              _controller.value,
            ),
            borderRadius:
                widget.borderRadius ?? BorderRadius.circular(AppSpacing.xs),
          ),
        );
      },
    );
  }
}

/// Avatar + two lines, sized like a typical list row. Compose these to build
/// a screen-shaped loading placeholder (Transactions, History, job lists)
/// instead of a bare centered spinner.
class RiderSkeletonListTile extends StatelessWidget {
  const RiderSkeletonListTile({super.key, this.showLeading = true});

  final bool showLeading;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: <Widget>[
          if (showLeading) ...<Widget>[
            const RiderSkeletonBox(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const RiderSkeletonBox(width: double.infinity, height: 14),
                const SizedBox(height: AppSpacing.xs),
                RiderSkeletonBox(
                  width: MediaQuery.sizeOf(context).width * 0.4,
                  height: 12,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A list of [count] skeleton rows, for screens loading a list of records.
class RiderSkeletonList extends StatelessWidget {
  const RiderSkeletonList({
    super.key,
    this.count = 4,
    this.showLeading = true,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppSpacing.screenPadding,
      vertical: AppSpacing.md,
    ),
  });

  final int count;
  final bool showLeading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: List<Widget>.generate(
          count,
          (int i) => RiderSkeletonListTile(showLeading: showLeading),
        ),
      ),
    );
  }
}
