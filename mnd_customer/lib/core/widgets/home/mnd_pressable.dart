import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Scale-on-tap wrapper with light haptic feedback.
class MndPressable extends StatefulWidget {
  const MndPressable({
    required this.child,
    required this.onTap,
    this.scale = 0.97,
    this.borderRadius,
    super.key,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scale;
  final BorderRadius? borderRadius;

  @override
  State<MndPressable> createState() => _MndPressableState();
}

class _MndPressableState extends State<MndPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onTap != null;
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return GestureDetector(
      onTapDown: enabled
          ? (_) => setState(() => _pressed = true)
          : null,
      onTapUp: enabled
          ? (_) => setState(() => _pressed = false)
          : null,
      onTapCancel: enabled
          ? () => setState(() => _pressed = false)
          : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: !enabled || reduceMotion
            ? 1
            : _pressed
                ? widget.scale
                : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
