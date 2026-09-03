import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';

/// Floating map chrome: zoom in/out + live location.
class RidesMapControls extends StatelessWidget {
  const RidesMapControls({
    super.key,
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onMyLocation,
    this.locating = false,
    this.bottomInset = 280,
  });

  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onMyLocation;
  final bool locating;
  final double bottomInset;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 12,
      bottom: bottomInset,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: <Widget>[
          _MapControlStack(
            children: <Widget>[
              _MapRoundButton(
                icon: Icons.add,
                onTap: onZoomIn,
                tooltip: 'Zoom in',
              ),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2E8F0)),
              _MapRoundButton(
                icon: Icons.remove,
                onTap: onZoomOut,
                tooltip: 'Zoom out',
              ),
            ],
          ),
          const SizedBox(height: 10),
          _MapRoundButton(
            icon: Icons.my_location_rounded,
            onTap: locating ? null : onMyLocation,
            tooltip: 'Live location',
            loading: locating,
            accent: true,
          ),
        ],
      ),
    );
  }
}

class _MapControlStack extends StatelessWidget {
  const _MapControlStack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 44,
        child: Column(mainAxisSize: MainAxisSize.min, children: children),
      ),
    );
  }
}

class _MapRoundButton extends StatelessWidget {
  const _MapRoundButton({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.loading = false,
    this.accent = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  final bool loading;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: accent ? RidesColors.accentBlue : Colors.white,
      elevation: accent ? 3 : 0,
      shadowColor: Colors.black26,
      shape: accent ? const CircleBorder() : const RoundedRectangleBorder(),
      child: InkWell(
        customBorder:
            accent ? const CircleBorder() : const RoundedRectangleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: loading
              ? Padding(
                  padding: const EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent ? Colors.white : const Color(0xFF334155),
                  ),
                )
              : Icon(
                  icon,
                  color: accent ? Colors.white : const Color(0xFF334155),
                ),
        ),
      ),
    );
    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Center crosshair used while placing pickup / drop pins.
class RidesMapCenterPin extends StatelessWidget {
  const RidesMapCenterPin({super.key, this.mode});

  /// `pickup` | `dropoff` | `stop` | null (neutral).
  final String? mode;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (mode) {
      'pickup' => const Color(RidesColors.pickupGreen),
      'dropoff' => const Color(RidesColors.dropoffRed),
      'stop' => const Color(RidesColors.stopAmber),
      _ => RidesColors.accentBlue,
    };
    return IgnorePointer(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Offset so the pin tip sits on the true map center.
            Transform.translate(
              offset: const Offset(0, -18),
              child: Icon(Icons.location_on_rounded, size: 48, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
