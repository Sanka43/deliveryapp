import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/vendor_notification_prefs_provider.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_audio_context.dart';
import 'package:mnd_shop/core/notifications/vendor_alert_sound.dart';
import 'package:mnd_shop/features/dashboard/domain/vendor_pending_order.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/orders/presentation/widgets/vendor_new_order_dialog.dart';

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

  @override
  void initState() {
    super.initState();
    unawaited(
      _orderAlertPlayer.setAudioContext(vendorAlertAudioContext()),
    );
  }

  Future<void> _playNewOrderSound() async {
    if (!ref.read(vendorOrderAlertSoundEnabledProvider)) {
      return;
    }
    final VendorAlertSound tone = ref.read(vendorAlertToneProvider);
    try {
      await _orderAlertPlayer.stop();
      await _orderAlertPlayer.play(AssetSource(tone.assetPath));
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!context.mounted) {
            return;
          }
          unawaited(_playNewOrderSound());
          HapticFeedback.heavyImpact();
          if (!ref.read(vendorInAppOrderAlertsEnabledProvider)) {
            return;
          }
          showDialog<void>(
            context: context,
            barrierDismissible: false,
            useRootNavigator: true,
            builder: (BuildContext dialogContext) => VendorNewOrderDialog(order: o),
          );
        });
      }
    });
    return const SizedBox.shrink();
  }
}
