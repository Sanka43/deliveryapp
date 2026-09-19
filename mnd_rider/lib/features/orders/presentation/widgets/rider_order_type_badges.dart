import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

/// e.g. "Jan 5, 6:30 PM".
String formatScheduledFor(DateTime dt) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final String period = dt.hour < 12 ? 'AM' : 'PM';
  final String minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, $hour12:$minute $period';
}

/// Compact "⚡ Emergency" / "Scheduled …" pills for job list cards. Renders
/// nothing for a standard order so callers can drop it in unconditionally.
class RiderOrderTypeBadges extends StatelessWidget {
  const RiderOrderTypeBadges({
    super.key,
    required this.isEmergency,
    this.scheduledFor,
  });

  final bool isEmergency;
  final DateTime? scheduledFor;

  @override
  Widget build(BuildContext context) {
    if (!isEmergency && scheduledFor == null) {
      return const SizedBox.shrink();
    }
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: <Widget>[
        if (isEmergency)
          const _Pill(
            icon: Icons.bolt_rounded,
            label: 'Emergency',
            color: AppColors.warningAmber,
          ),
        if (scheduledFor != null)
          _Pill(
            icon: Icons.schedule_rounded,
            label: 'Scheduled ${formatScheduledFor(scheduledFor!)}',
            color: AppColors.primaryBlue,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
