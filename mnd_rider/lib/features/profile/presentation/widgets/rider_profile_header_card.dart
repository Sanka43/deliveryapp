import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

/// Open profile hero — avatar, identity, status (no nested card clutter).
class RiderProfileHeaderCard extends StatelessWidget {
  const RiderProfileHeaderCard({
    super.key,
    required this.profile,
  });

  final RiderProfile profile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool verified = profile.isApprovedToDrive;
    final bool showStatusChip = !verified;
    final String meta = _metaLine(profile);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        _Avatar(profile: profile),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Flexible(
                    child: Text(
                      _titleCase(profile.fullName),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        height: 1.2,
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  if (verified) ...<Widget>[
                    const SizedBox(width: 5),
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: RiderVerifiedBadge(size: 17),
                    ),
                  ],
                ],
              ),
              if (meta.isNotEmpty) ...<Widget>[
                const SizedBox(height: 5),
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    letterSpacing: 0,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  if (showStatusChip)
                    _StatusChip(
                      label: profile.approvalStatusLabel,
                      color: _approvalColor(profile.approvalStatusLabel),
                    ),
                  _VehicleChip(
                    icon: _vehicleIcon(profile.vehicleType),
                    label: profile.vehicleNumber.isEmpty
                        ? profile.vehicleType.label
                        : '${profile.vehicleType.label} · ${profile.vehicleNumber}',
                  ),
                  if (profile.ratingCount > 0)
                    _RatingChip(
                      rating: profile.rating,
                      count: profile.ratingCount,
                    ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static String _metaLine(RiderProfile profile) {
    final List<String> parts = <String>[];
    if (profile.phone.isNotEmpty) {
      parts.add(profile.phone);
    }
    if (profile.city.isNotEmpty) {
      parts.add(_titleCase(profile.city));
    }
    return parts.join(' · ');
  }

  static String _titleCase(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      return trimmed;
    }
    return trimmed
        .split(RegExp(r'\s+'))
        .map((String word) {
          if (word.isEmpty) {
            return word;
          }
          return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
        })
        .join(' ');
  }

  static Color _approvalColor(String label) {
    final String s = label.toLowerCase();
    if (s.contains('rejected')) {
      return AppColors.errorRed;
    }
    return AppColors.warningAmber;
  }

  static IconData _vehicleIcon(RiderVehicleType type) {
    return switch (type) {
      RiderVehicleType.bike => Icons.two_wheeler_rounded,
      RiderVehicleType.threeWheeler => Icons.electric_rickshaw_outlined,
      RiderVehicleType.car => Icons.directions_car_outlined,
      RiderVehicleType.van => Icons.local_shipping_outlined,
    };
  }
}

/// Drawn verify seal — scalloped blue badge + white check (no image asset).
class RiderVerifiedBadge extends StatelessWidget {
  const RiderVerifiedBadge({
    super.key,
    this.size = 20,
    this.color = AppColors.primaryBlue,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified',
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _VerifiedBadgePainter(color: color),
        ),
      ),
    );
  }
}

class _VerifiedBadgePainter extends CustomPainter {
  const _VerifiedBadgePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final Offset center = Offset(w / 2, h / 2);
    final double radius = math.min(w, h) / 2;

    final Path seal = Path();
    const int points = 12;
    final double outer = radius;
    final double inner = radius * 0.78;
    for (int i = 0; i < points * 2; i++) {
      final double r = i.isEven ? outer : inner;
      final double angle = (i * math.pi / points) - math.pi / 2;
      final Offset p = Offset(
        center.dx + r * math.cos(angle),
        center.dy + r * math.sin(angle),
      );
      if (i == 0) {
        seal.moveTo(p.dx, p.dy);
      } else {
        seal.lineTo(p.dx, p.dy);
      }
    }
    seal.close();

    canvas.drawPath(
      seal,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill
        ..isAntiAlias = true,
    );

    canvas.drawCircle(
      center,
      radius * 0.52,
      Paint()
        ..color = color
        ..style = PaintingStyle.fill,
    );

    final Path check = Path()
      ..moveTo(w * 0.28, h * 0.52)
      ..lineTo(w * 0.43, h * 0.66)
      ..lineTo(w * 0.72, h * 0.34);

    canvas.drawPath(
      check,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.6, w * 0.12)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
  }

  @override
  bool shouldRepaint(covariant _VerifiedBadgePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final RiderProfile profile;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;

    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.85),
        ),
        color: cs.surfaceContainerLow,
      ),
      clipBehavior: Clip.antiAlias,
      child: profile.profilePhotoUrl != null
          ? Image.network(
              profile.profilePhotoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (
                BuildContext context,
                Object error,
                StackTrace? stackTrace,
              ) {
                return Icon(
                  Icons.person_rounded,
                  size: 32,
                  color: cs.primary,
                );
              },
            )
          : Icon(Icons.person_rounded, size: 32, color: cs.primary),
    );
  }
}

class _VehicleChip extends StatelessWidget {
  const _VehicleChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: cs.onSurfaceVariant),
          const SizedBox(width: 5),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({required this.rating, required this.count});

  final double rating;
  final int count;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const Icon(Icons.star_rounded, size: 15, color: Color(0xFFF59E0B)),
          const SizedBox(width: 5),
          Text(
            '${rating.toStringAsFixed(1)} ($count)',
            style: theme.textTheme.labelMedium?.copyWith(
              color: cs.onSurface,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
      ),
    );
  }
}
