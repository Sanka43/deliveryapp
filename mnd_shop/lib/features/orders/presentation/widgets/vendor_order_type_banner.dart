import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';

/// e.g. "Sep 20, 6:30 PM" — the date matters, a scheduled order can be for
/// tomorrow or the day after.
String vendorScheduledForLabel(DateTime dt) {
  const List<String> months = <String>[
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec', //
  ];
  final int hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final String period = dt.hour < 12 ? 'AM' : 'PM';
  final String minute = dt.minute.toString().padLeft(2, '0');
  return '${months[dt.month - 1]} ${dt.day}, $hour12:$minute $period';
}

/// Full-width strip that makes an Emergency or Scheduled order impossible to
/// mistake for a normal one. Renders nothing for a standard order, so callers
/// can place it unconditionally.
class VendorOrderTypeBanner extends StatelessWidget {
  const VendorOrderTypeBanner({super.key, required this.order});

  final VendorPendingOrder order;

  @override
  Widget build(BuildContext context) {
    if (!order.isEmergency && !order.isScheduled) {
      return const SizedBox.shrink();
    }
    final ThemeData theme = Theme.of(context);
    final bool emergency = order.isEmergency;
    final Color color =
        emergency ? AppColors.orderRejectRed : AppColors.primaryBlue;
    final String title = emergency
        ? _txt(
            context,
            en: 'EMERGENCY ORDER',
            si: 'හදිසි ඇණවුම',
          )
        : _txt(
            context,
            en: 'SCHEDULED ORDER',
            si: 'කාලසටහන්ගත ඇණවුම',
          );
    final String detail = emergency
        ? _txt(
            context,
            en: 'Rush order — prepare this one first.',
            si: 'හදිසි ඇණවුමකි — මෙය මුලින්ම සූදානම් කරන්න.',
          )
        : _txt(
            context,
            en: 'Needed at ${vendorScheduledForLabel(order.scheduledFor!)} — '
                'have it ready for then.',
            si: '${vendorScheduledForLabel(order.scheduledFor!)} සඳහා — '
                'එවේලාවට සූදානම් කරන්න.',
          );

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.55)),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            emergency ? Icons.bolt_rounded : Icons.schedule_rounded,
            color: color,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detail,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
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

String _txt(BuildContext context, {required String en, required String si}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return vendorTamilFallback(en);
  return en;
}
