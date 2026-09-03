import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/rides_theme.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/rides_vehicle_icon.dart';

/// Equal-width vehicle tile — identity → ETA → price (scannable comparison).
class RidesVehicleCard extends StatelessWidget {
  const RidesVehicleCard({
    super.key,
    required this.type,
    required this.etaMinutes,
    required this.fareLkr,
    required this.selected,
    required this.onTap,
    this.isNew = false,
    this.fareConfirmed = true,
  });

  final RideVehicleType type;
  final int etaMinutes;
  final int fareLkr;
  final bool selected;
  final bool isNew;
  /// False while server quote is still loading — shows estimate prefix.
  final bool fareConfirmed;
  final VoidCallback onTap;

  /// Height of the vehicle row (3 equal cards, no horizontal scroll).
  static const double listHeight = 148;

  @override
  Widget build(BuildContext context) {
    const Color accent = RidesColors.accentBlue;
    const Color ink = Color(0xFF0F1C33);
    const Color muted = Color(0xFF6B7C99);
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: true,
      selected: selected,
      label: '${type.label}, $etaMinutes minutes, $fareLkr rupees, '
          '${type.capacity} seats',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(18),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            height: double.infinity,
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 10),
            decoration: BoxDecoration(
              color: selected ? const Color(0xFFEFF4FF) : Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: selected ? accent : const Color(0xFFE6ECF4),
                width: 2,
              ),
              boxShadow: selected
                  ? <BoxShadow>[
                      BoxShadow(
                        color: accent.withValues(alpha: 0.20),
                        blurRadius: 12,
                        offset: const Offset(0, 5),
                      ),
                    ]
                  : const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x0A0F1C33),
                        blurRadius: 6,
                        offset: Offset(0, 2),
                      ),
                    ],
            ),
            child: Column(
              children: <Widget>[
                SizedBox(
                  height: 22,
                  child: Align(
                    alignment: Alignment.topRight,
                    child: selected
                        ? const _SelectedMark(accent: accent)
                        : (isNew
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'NEW',
                                  style: textTheme.labelSmall?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.3,
                                    height: 1.1,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink()),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: RidesVehicleIcon(
                      type: type,
                      size: 40,
                      color: accent,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  type.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                    color: ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$etaMinutes min · ${type.capacity} '
                  '${type.capacity == 1 ? 'seat' : 'seats'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: textTheme.labelSmall?.copyWith(
                    height: 1.15,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
                const SizedBox(height: 6),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 180),
                  style: textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                    letterSpacing: -0.2,
                    color: selected
                        ? accent
                        : (fareConfirmed ? ink : muted),
                  ),
                  child: Text(
                    fareConfirmed ? 'LKR $fareLkr' : '~ LKR $fareLkr',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedMark extends StatelessWidget {
  const _SelectedMark({required this.accent});

  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        color: accent,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.check_rounded,
        size: 12,
        color: Colors.white,
      ),
    );
  }
}
