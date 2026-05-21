import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/rider_delivery_eta.dart';
import 'package:mnd_delivery_app/features/orders/domain/entities/rider_live_location.dart';

/// Live countdown to estimated arrival, recomputed when [rider] position updates.
class RiderEtaCountdown extends StatefulWidget {
  const RiderEtaCountdown({
    super.key,
    required this.rider,
    required this.dropLat,
    required this.dropLng,
  });

  final RiderLiveLocation? rider;
  final double? dropLat;
  final double? dropLng;

  @override
  State<RiderEtaCountdown> createState() => _RiderEtaCountdownState();
}

class _RiderEtaCountdownState extends State<RiderEtaCountdown> {
  Timer? _timer;
  DateTime? _etaArrival;

  @override
  void initState() {
    super.initState();
    _recomputeEta();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  @override
  void didUpdateWidget(RiderEtaCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.rider?.latitude != widget.rider?.latitude ||
        oldWidget.rider?.longitude != widget.rider?.longitude ||
        oldWidget.dropLat != widget.dropLat ||
        oldWidget.dropLng != widget.dropLng) {
      _recomputeEta();
    }
  }

  void _recomputeEta() {
    final RiderLiveLocation? r = widget.rider;
    final double? lat = widget.dropLat;
    final double? lng = widget.dropLng;
    if (r == null || lat == null || lng == null) {
      _etaArrival = null;
      return;
    }
    final Duration? travel = RiderDeliveryEta.travelDuration(
      riderLat: r.latitude,
      riderLng: r.longitude,
      dropLat: lat,
      dropLng: lng,
    );
    if (travel == null) {
      _etaArrival = null;
      return;
    }
    final DateTime now = DateTime.now();
    _etaArrival = now.add(travel);
  }

  void _tick() {
    if (_etaArrival == null || !mounted) {
      return;
    }
    setState(() {});
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final RiderLiveLocation? r = widget.rider;
    final double? lat = widget.dropLat;
    final double? lng = widget.dropLng;

    if (r == null || lat == null || lng == null) {
      return const SizedBox.shrink();
    }

    final Duration? travel = RiderDeliveryEta.travelDuration(
      riderLat: r.latitude,
      riderLng: r.longitude,
      dropLat: lat,
      dropLng: lng,
    );

    if (travel == null) {
      return const SizedBox.shrink();
    }

    final double km = RiderDeliveryEta.haversineKm(
      r.latitude,
      r.longitude,
      lat,
      lng,
    );

    if (km <= RiderDeliveryEta.arrivedThresholdKm) {
      return const _EtaCard(
        headline: 'Arriving soon',
        subline: 'Your rider is very close.',
      );
    }

    final DateTime? end = _etaArrival;
    if (end == null) {
      return const SizedBox.shrink();
    }

    final Duration left = end.difference(DateTime.now());
    final bool overdue = left <= Duration.zero;

    final String timeStr = overdue
        ? 'Less than a minute'
        : _formatDuration(left);

    return _EtaCard(
      label: overdue ? null : 'Arriving in',
      headline: overdue ? 'Almost there' : timeStr,
      subline: overdue
          ? 'Rider is nearby — watch for the doorbell.'
          : 'Est. from distance · ${_formatDistance(km)} · ~${RiderDeliveryEta.defaultAverageSpeedKmh.round()} km/h',
    );
  }

  static String _formatDuration(Duration d) {
    if (d.inHours >= 1) {
      final int h = d.inHours;
      final int m = d.inMinutes.remainder(60);
      return '${h}h ${m}m';
    }
    if (d.inMinutes >= 1) {
      final int m = d.inMinutes;
      final int s = d.inSeconds.remainder(60);
      return '${m}m ${s.toString().padLeft(2, '0')}s';
    }
    final int s = d.inSeconds.clamp(0, 59);
    return '${s}s';
  }

  static String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).round()} m';
    }
    return '${km.toStringAsFixed(1)} km';
  }
}

class _EtaCard extends StatelessWidget {
  const _EtaCard({
    this.label,
    required this.headline,
    required this.subline,
  });

  final String? label;
  final String headline;
  final String subline;

  @override
  Widget build(BuildContext context) {
    final TextTheme t = Theme.of(context).textTheme;
    final bool largeCountdown = label != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.22),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            Icons.schedule_rounded,
            color: AppColors.primaryBlue.withValues(alpha: 0.95),
            size: 24,
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (label != null) ...<Widget>[
                  Text(
                    label!,
                    style: t.labelLarge?.copyWith(
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  const SizedBox(height: 2),
                ],
                Text(
                  headline,
                  style: (largeCountdown ? t.headlineSmall : t.titleMedium)?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.primaryBlue,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  subline,
                  style: t.bodySmall?.copyWith(
                        color: Colors.black54,
                        height: 1.3,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
