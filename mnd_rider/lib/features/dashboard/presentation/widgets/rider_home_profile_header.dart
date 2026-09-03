import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/widgets/rider_map_chrome.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';

/// Top-of-map chrome: online trigger · today's earnings.
class RiderHomeProfileHeader extends ConsumerWidget {
  const RiderHomeProfileHeader({
    super.key,
    required this.isOnline,
    required this.todayEarningsLkr,
    this.onOnlineChanged,
  });

  final bool isOnline;
  final double todayEarningsLkr;

  /// When null, the online button is display-only (e.g. pending approval).
  final ValueChanged<bool>? onOnlineChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Row(
      children: <Widget>[
        _OnlineTriggerButton(
          isOnline: isOnline,
          onPressed: onOnlineChanged == null
              ? null
              : () {
                  HapticFeedback.mediumImpact();
                  onOnlineChanged!(!isOnline);
                },
        ),
        const Spacer(),
        RiderMapChrome(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          onTap: () {
            ref.read(riderShellTabIndexProvider.notifier).state = 2;
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Text(
                'TODAY',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.4,
                  color: cs.onSurfaceVariant,
                  fontSize: 8.5,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                LkrFormat.moneyDecimal(todayEarningsLkr),
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: cs.onSurface,
                  letterSpacing: 0,
                  height: 1.05,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Sliding pill trigger: Offline ←→ Online.
class _OnlineTriggerButton extends StatelessWidget {
  const _OnlineTriggerButton({
    required this.isOnline,
    required this.onPressed,
  });

  final bool isOnline;
  final VoidCallback? onPressed;

  static const double _width = 80;
  static const double _height = 32;
  static const double _pad = 2;
  static const double _thumb = 24;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool enabled = onPressed != null;
    final Color track = isOnline
        ? AppColors.onlineGreen
        : cs.surface.withValues(alpha: 0.94);
    final Color border =
        isOnline ? AppColors.onlineGreen : cs.outlineVariant;
    final Color labelColor =
        isOnline ? Colors.white.withValues(alpha: 0.95) : cs.onSurfaceVariant;

    final Widget thumb = Container(
      width: _thumb,
      height: _thumb,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isOnline ? Colors.white : cs.surfaceContainerLow,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Icon(
        isOnline
            ? Icons.power_settings_new_rounded
            : Icons.power_off_rounded,
        size: 14,
        color: isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
      ),
    );

    final Widget label = Expanded(
      child: Padding(
        padding: EdgeInsets.only(
          left: isOnline ? 5 : 3,
          right: isOnline ? 3 : 5,
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: isOnline ? Alignment.centerLeft : Alignment.centerRight,
          child: Text(
            isOnline ? 'ONLINE' : 'OFFLINE',
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.15,
              color: labelColor,
              height: 1,
            ),
          ),
        ),
      ),
    );

    return Tooltip(
      message: enabled
          ? (isOnline
              ? 'Online — tap to go offline'
              : 'Offline — tap to go online')
          : 'Waiting for approval',
      child: Material(
        color: Colors.transparent,
        elevation: 1,
        shadowColor: Colors.black26,
        borderRadius: BorderRadius.circular(_height / 2),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(_height / 2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: enabled ? 1 : 0.55,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              width: _width,
              height: _height,
              padding: const EdgeInsets.all(_pad),
              decoration: BoxDecoration(
                color: track,
                borderRadius: BorderRadius.circular(_height / 2),
                border: Border.all(color: border, width: 1.5),
              ),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (Widget child, Animation<double> anim) {
                  return FadeTransition(opacity: anim, child: child);
                },
                child: Row(
                  key: ValueKey<bool>(isOnline),
                  children: isOnline
                      ? <Widget>[label, thumb]
                      : <Widget>[thumb, label],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
