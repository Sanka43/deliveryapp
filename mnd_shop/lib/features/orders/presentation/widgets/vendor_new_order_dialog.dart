import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/phone_call_launcher.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_item_variant_chip.dart';

/// Polished "New order" popup shown when an order lands on the vendor board.
///
/// Shows the full item breakdown (name, size/variant, extras, quantity, line
/// price) plus customer contact details, and lets the shop **accept** or
/// **reject** the order straight from the alert without opening the board.
class VendorNewOrderDialog extends ConsumerStatefulWidget {
  const VendorNewOrderDialog({super.key, required this.order});

  final VendorPendingOrder order;

  static String _money(num v) => 'Rs. ${v.toStringAsFixed(0)}';

  @override
  ConsumerState<VendorNewOrderDialog> createState() =>
      _VendorNewOrderDialogState();
}

class _VendorNewOrderDialogState extends ConsumerState<VendorNewOrderDialog> {
  /// Which action is running (`accept` / `reject`), null while idle.
  String? _busyAction;

  bool get _busy => _busyAction != null;

  Future<void> _accept() async {
    if (_busy) {
      return;
    }
    setState(() => _busyAction = 'accept');
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String okMessage =
        '${_vTxt(context, en: 'Accepted', si: 'පිළිගත්තා')} · ${widget.order.referenceForDisplay}';
    final String? err = await ref
        .read(vendorOrdersRepositoryProvider)
        .updateOrderStatus(orderId: widget.order.id, nextStatus: 'confirmed');
    if (!mounted) {
      return;
    }
    setState(() => _busyAction = null);
    if (err != null) {
      _snack(messenger, err, error: true);
      return;
    }
    navigator.pop();
    _snack(messenger, okMessage);
  }

  Future<void> _reject() async {
    if (_busy) {
      return;
    }
    final bool confirmed = await _confirmReject();
    if (!mounted || !confirmed) {
      return;
    }
    setState(() => _busyAction = 'reject');
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final String okMessage =
        '${_vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප කළා')} · ${widget.order.referenceForDisplay}';
    final String? err = await ref
        .read(vendorOrdersRepositoryProvider)
        .rejectOrder(orderId: widget.order.id);
    if (!mounted) {
      return;
    }
    setState(() => _busyAction = null);
    if (err != null) {
      _snack(messenger, err, error: true);
      return;
    }
    navigator.pop();
    _snack(messenger, okMessage);
  }

  /// Guards against a mis-tap on a popup that appears without warning.
  Future<bool> _confirmReject() async {
    final bool? ok = await showDialog<bool>(
      context: context,
      useRootNavigator: true,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(
          _vTxt(
            ctx,
            en: 'Reject this order?',
            si: 'මෙම ඇණවුම ප්‍රතික්ෂේප කරන්නද?',
          ),
        ),
        content: Text(
          _vTxt(
            ctx,
            en: 'The customer is told the shop could not take this order. '
                'This cannot be undone.',
            si: 'ඇණවුම භාර ගත නොහැකි බව පාරිභෝගිකයාට දැනුම් දෙනු ලැබේ. '
                'මෙය නැවත වෙනස් කළ නොහැක.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(_vTxt(ctx, en: 'Keep order', si: 'ඇණවුම තබාගන්න')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.orderRejectRed,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(_vTxt(ctx, en: 'Reject', si: 'ප්‍රතික්ෂේප කරන්න')),
          ),
        ],
      ),
    );
    return ok == true;
  }

  static void _snack(
    ScaffoldMessengerState messenger,
    String msg, {
    bool error = false,
  }) {
    messenger.showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.orderRejectRed : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final VendorPendingOrder order = widget.order;
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final Color cardColor = isDark ? cs.surfaceContainerHigh : Colors.white;

    final String customerLabel = order.customerName.isNotEmpty
        ? order.customerName
        : (order.isGuestCustomer
            ? _vTxt(context, en: 'Guest customer', si: 'අමුත්තා')
            : _vTxt(context, en: 'Customer', si: 'පාරිභෝගිකයා'));

    return PopScope(
      // Don't let a stray back gesture close the popup mid-request.
      canPop: !_busy,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(26),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 40,
                  offset: const Offset(0, 20),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _Header(
                  order: order,
                  // Product sales only — the shop's own take. Delivery fee and
                  // platform commission belong to the customer's bill, not to
                  // what the kitchen is being paid for.
                  money: VendorNewOrderDialog._money(order.shopTotal),
                  onClose: _busy ? null : () => Navigator.of(context).pop(),
                ),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        _SectionLabel(
                          text: _vTxt(
                            context,
                            en: 'Order items · ${order.itemCount}',
                            si: 'ඇණවුම් අයිතම · ${order.itemCount}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (order.items.isEmpty)
                          Text(
                            order.itemsSummary,
                            style: theme.textTheme.bodyLarge,
                          )
                        else
                          Column(
                            children: <Widget>[
                              for (int i = 0; i < order.items.length; i++) ...<Widget>[
                                _ItemRow(item: order.items[i]),
                                if (i != order.items.length - 1)
                                  Divider(
                                    height: 18,
                                    color: cs.outlineVariant.withValues(alpha: 0.4),
                                  ),
                              ],
                            ],
                          ),
                        const SizedBox(height: 18),
                        _SectionLabel(
                          text: _vTxt(context, en: 'Customer', si: 'පාරිභෝගිකයා'),
                        ),
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: Icons.person_rounded,
                          text: customerLabel,
                        ),
                        if (order.customerPhone.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 10),
                          _CallRow(phone: order.customerPhone),
                        ],
                        const SizedBox(height: 10),
                        _InfoRow(
                          icon: order.isSelfPickup
                              ? Icons.storefront_rounded
                              : Icons.delivery_dining_rounded,
                          text: order.isSelfPickup
                              ? _vTxt(context, en: 'Self pickup', si: 'තමන්ම රැගෙන යාම')
                              : (order.deliveryAddressLabel.isNotEmpty
                                  ? order.deliveryAddressLabel
                                  : _vTxt(context, en: 'Delivery', si: 'බෙදාහැරීම')),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _ActionBar(
                  busyAction: _busyAction,
                  onAccept: _accept,
                  onReject: _reject,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Accept / reject footer. Accept is the wide primary action; reject stays a
/// bordered secondary so it is harder to hit by muscle memory.
class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.busyAction,
    required this.onAccept,
    required this.onReject,
  });

  final String? busyAction;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool isDark = theme.brightness == Brightness.dark;
    final bool busy = busyAction != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Row(
        children: <Widget>[
          Expanded(
            child: OutlinedButton(
              onPressed: busy ? null : onReject,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.orderRejectRed,
                backgroundColor:
                    isDark ? cs.surfaceContainerHighest : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(
                  color: busy
                      ? AppColors.orderRejectRed.withValues(alpha: 0.35)
                      : AppColors.orderRejectRed,
                  width: 1.5,
                ),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              child: busyAction == 'reject'
                  ? const _ButtonSpinner(color: AppColors.orderRejectRed)
                  : Text(_vTxt(context, en: 'Reject', si: 'ප්‍රතික්ෂේප')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: FilledButton.icon(
              onPressed: busy ? null : onAccept,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.openGreen,
                foregroundColor: Colors.white,
                disabledBackgroundColor:
                    AppColors.openGreen.withValues(alpha: 0.5),
                disabledForegroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              icon: busyAction == 'accept'
                  ? const _ButtonSpinner(color: Colors.white)
                  : const Icon(Icons.check_rounded, size: 20),
              label: Text(
                busyAction == 'accept'
                    ? _vTxt(context, en: 'Accepting…', si: 'පිළිගනිමින්…')
                    : _vTxt(context, en: 'Accept order', si: 'ඇණවුම පිළිගන්න'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.order, required this.money, this.onClose});

  final VendorPendingOrder order;
  final String money;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(26)),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[AppColors.vendorHeroBlue, AppColors.vendorHeroViolet],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const _PulsingBell(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        _vTxt(context, en: 'New order', si: 'නව ඇණවුම'),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        order.isSelfPickup
                            ? _vTxt(
                                context,
                                en: 'Self pickup',
                                si: 'තමන්ම රැගෙන යාම',
                              )
                            : _vTxt(context, en: 'Delivery', si: 'බෙදාහැරීම'),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: onClose,
                  tooltip: _vTxt(context, en: 'Close', si: 'වසන්න'),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white.withValues(alpha: 0.9),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          _vTxt(
                            context,
                            en: 'Items total',
                            si: 'භාණ්ඩ එකතුව',
                          ).toUpperCase(),
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            money,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      _HeaderChip(
                        text: order.referenceForDisplay,
                        monospace: true,
                      ),
                      if (order.placedAtLabel.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 6),
                        _HeaderChip(text: order.placedAtLabel),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Softly breathing halo behind the bell so the alert reads as "live".
class _PulsingBell extends StatefulWidget {
  const _PulsingBell();

  @override
  State<_PulsingBell> createState() => _PulsingBellState();
}

class _PulsingBellState extends State<_PulsingBell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (BuildContext context, Widget? child) {
        final double t = Curves.easeInOut.transform(_controller.value);
        return Container(
          width: 46,
          height: 46,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.14 + (0.12 * t)),
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.15 + (0.35 * t)),
              width: 1.5,
            ),
          ),
          child: child,
        );
      },
      child: const Icon(
        Icons.notifications_active_rounded,
        color: Colors.white,
        size: 24,
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.text, this.monospace = false});

  final String text;
  final bool monospace;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontWeight: FontWeight.w700,
          fontSize: 12,
          fontFamily: monospace ? 'monospace' : null,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.4,
          ),
    );
  }
}

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});

  final VendorOrderLineItem item;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.primaryBlue.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            '${item.quantity}×',
            style: theme.textTheme.labelLarge?.copyWith(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                item.productName,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (item.selectedSize.isNotEmpty || item.extras.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    if (item.selectedSize.isNotEmpty)
                      VendorItemVariantChip.variant(text: item.selectedSize),
                    for (final String extra in item.extras)
                      VendorItemVariantChip.extra(text: extra),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          VendorNewOrderDialog._money(item.lineTotal),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: cs.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: 19, color: cs.onSurfaceVariant),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => launchPhoneCall(context, phone),
        borderRadius: BorderRadius.circular(10),
        child: Row(
          children: <Widget>[
            Icon(Icons.call_rounded, size: 19, color: cs.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                phone,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Icon(Icons.call_rounded, size: 16, color: AppColors.openGreen),
          ],
        ),
      ),
    );
  }
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return ta ?? vendorTamilFallback(en);
  return en;
}
