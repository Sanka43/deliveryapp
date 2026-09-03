import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Shared shape for `showModalBottomSheet(shape: ...)` calls — rounded top
/// corners matching the app's sheet radius. Pass this instead of hand-rolling
/// the same `RoundedRectangleBorder` at each call site.
const ShapeBorder riderSheetShape = RoundedRectangleBorder(
  borderRadius: BorderRadius.vertical(top: Radius.circular(AppSpacing.sheetRadius)),
);

/// Standard bottom-sheet chrome: drag handle + keyboard-aware bottom padding.
/// Wrap sheet content in this instead of hand-rolling the drag-handle
/// [Container] in each sheet (previously duplicated between the photo-source
/// picker and the withdraw sheet, each with a slightly different look).
class RiderSheetScaffold extends StatelessWidget {
  const RiderSheetScaffold({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 20),
    this.scrollable = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    final Widget content = Padding(
      padding: padding.add(EdgeInsets.only(bottom: bottomInset)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: cs.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );

    return SafeArea(
      top: false,
      child: scrollable ? SingleChildScrollView(child: content) : content,
    );
  }
}
