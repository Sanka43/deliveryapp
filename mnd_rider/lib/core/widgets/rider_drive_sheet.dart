import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';

/// Operational bottom sheet shell for map overlays and driving chrome.
class RiderDriveSheet extends StatelessWidget {
  const RiderDriveSheet({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 16),
    this.showHandle = true,
    this.deep = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool showHandle;
  /// Kept for call-site compatibility; sheet uses themed surface.
  final bool deep;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      elevation: dark ? 12 : 8,
      shadowColor: Colors.black.withValues(alpha: dark ? 0.4 : 0.12),
      color: cs.surface,
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppSpacing.sheetRadius),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (showHandle) ...<Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.outlineVariant,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              child,
            ],
          ),
        ),
      ),
    );
  }
}
