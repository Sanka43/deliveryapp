import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/vendor_notification_prefs_provider.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';

/// Listens to [vendorOrderBoardProvider] and plays a short alert sound plus an
/// [AlertDialog] when a **new** `placed` order appears (not on first snapshot).
class VendorIncomingOrderSnackbarHost extends ConsumerStatefulWidget {
  const VendorIncomingOrderSnackbarHost({super.key});

  @override
  ConsumerState<VendorIncomingOrderSnackbarHost> createState() =>
      _VendorIncomingOrderSnackbarHostState();
}

class _VendorIncomingOrderSnackbarHostState extends ConsumerState<VendorIncomingOrderSnackbarHost> {
  final Set<String> _knownIncomingIds = <String>{};
  bool _hydrated = false;
  final AudioPlayer _orderAlertPlayer = AudioPlayer();

  Future<void> _playNewOrderSound() async {
    if (!ref.read(vendorOrderAlertSoundEnabledProvider)) {
      return;
    }
    try {
      await _orderAlertPlayer.stop();
      await _orderAlertPlayer.play(AssetSource('sounds/new_order.mp3'));
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  @override
  void dispose() {
    _orderAlertPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<VendorOrderBoard>>(vendorOrderBoardProvider, (_, AsyncValue<VendorOrderBoard> next) {
      final VendorOrderBoard? board = next.valueOrNull;
      if (board == null) {
        return;
      }
      if (!_hydrated) {
        _knownIncomingIds.addAll(board.incoming.map((VendorPendingOrder e) => e.id));
        _hydrated = true;
        return;
      }
      for (final VendorPendingOrder o in board.incoming) {
        if (_knownIncomingIds.contains(o.id)) {
          continue;
        }
        _knownIncomingIds.add(o.id);
        if (!context.mounted) {
          return;
        }
        final String money = 'Rs. ${o.total.toStringAsFixed(0)}';
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          unawaited(_playNewOrderSound());
          HapticFeedback.heavyImpact();
          if (!ref.read(vendorInAppOrderAlertsEnabledProvider)) {
            return;
          }
          final ThemeData theme = Theme.of(context);
          final ColorScheme cs = theme.colorScheme;
          showDialog<void>(
            context: context,
            barrierDismissible: true,
            useRootNavigator: true,
            builder: (BuildContext dialogContext) {
              return AlertDialog(
                icon: Icon(
                  Icons.notifications_active_rounded,
                  color: cs.primary,
                  size: 36,
                ),
                title: const Text('New order'),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        money,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        o.referenceForDisplay,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                        ),
                      ),
                      if (o.customerPhone.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 4),
                        Text(
                          o.customerPhone,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (o.itemsSummary.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 8),
                        Text(
                          o.itemsSummary,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                actions: <Widget>[
                  FilledButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    child: const Text('OK'),
                  ),
                ],
              );
            },
          );
        });
      }
    });
    return const SizedBox.shrink();
  }
}
