import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Slide-to-confirm action — the rider drags the thumb across instead of a
/// plain tap, so a stray tap while riding/multitasking can't fire a
/// trip-ending action (picked up, delivered) by accident.
class RiderSlideToConfirm extends StatefulWidget {
  const RiderSlideToConfirm({
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.onConfirmed,
    this.busy = false,
    this.height = 64,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback? onConfirmed;
  final bool busy;
  final double height;

  @override
  State<RiderSlideToConfirm> createState() => _RiderSlideToConfirmState();
}

class _RiderSlideToConfirmState extends State<RiderSlideToConfirm>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  double _dragPixels = 0;
  double _trackWidth = 0;

  bool get _enabled => widget.onConfirmed != null && !widget.busy;

  double get _thumbSize => widget.height - 8;

  double get _maxDrag =>
      (_trackWidth - _thumbSize - 8).clamp(0, double.infinity);

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
          vsync: this,
          duration: const Duration(milliseconds: 220),
        )..addListener(() {
          setState(() => _dragPixels = _controller.value * _maxDrag);
        });
  }

  @override
  void didUpdateWidget(covariant RiderSlideToConfirm oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A busy call that just finished — success moves to a new label/phase
    // (this widget gets rebuilt fresh anyway); failure means the rider needs
    // to slide again, so the thumb must not still be sitting at the end.
    if (oldWidget.busy && !widget.busy) {
      _controller.value = 0;
      _dragPixels = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_enabled) {
      return;
    }
    setState(() {
      _dragPixels = (_dragPixels + details.delta.dx).clamp(0, _maxDrag);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    if (!_enabled || _maxDrag == 0) {
      return;
    }
    final double progress = _dragPixels / _maxDrag;
    _controller.value = progress;
    if (progress >= 0.7) {
      _controller.animateTo(1).then((_) {
        HapticFeedback.mediumImpact();
        widget.onConfirmed?.call();
      });
    } else {
      _controller.animateBack(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final Color trackColor = _enabled
        ? widget.color.withValues(alpha: 0.12)
        : cs.surfaceContainerHighest;
    final Color thumbColor = _enabled ? widget.color : cs.outlineVariant;
    final Color labelColor = _enabled ? widget.color : cs.onSurfaceVariant;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _trackWidth = constraints.maxWidth;
        final double progress = _maxDrag == 0 ? 0 : _dragPixels / _maxDrag;

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(widget.height / 2),
          ),
          child: Stack(
            alignment: Alignment.centerLeft,
            children: <Widget>[
              Positioned.fill(
                child: Opacity(
                  opacity: (1 - progress * 1.6).clamp(0, 1),
                  child: Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          widget.label,
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(
                                color: labelColor,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: labelColor,
                          size: 20,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: labelColor.withValues(alpha: 0.5),
                          size: 20,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 4 + _dragPixels,
                child: GestureDetector(
                  onHorizontalDragUpdate: _onPanUpdate,
                  onHorizontalDragEnd: _onPanEnd,
                  child: Container(
                    width: _thumbSize,
                    height: _thumbSize,
                    decoration: BoxDecoration(
                      color: thumbColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: widget.busy
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : Icon(widget.icon, color: Colors.white, size: 24),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
