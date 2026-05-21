import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/delivery_requests/domain/delivery_request_config.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/order_request_session_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_delivery_requests_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_order_accept_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/widgets/rider_order_request_card.dart';

/// Listens for nearby open orders and shows an animated bottom offer card.
class RiderOrderRequestOverlayHost extends ConsumerStatefulWidget {
  const RiderOrderRequestOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<RiderOrderRequestOverlayHost> createState() =>
      _RiderOrderRequestOverlayHostState();
}

class _RiderOrderRequestOverlayHostState
    extends ConsumerState<RiderOrderRequestOverlayHost> {
  static const DeliveryRequestConfig _config = DeliveryRequestConfig.defaults;

  final Set<String> _hydratedIds = <String>{};
  bool _hydrated = false;
  Timer? _countdownTimer;
  RiderDeliveryRequest? _visibleRequest;
  bool _accepting = false;
  bool _sheetVisible = false;

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _cancelCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
  }

  void _startCountdown(RiderDeliveryRequest request) {
    _cancelCountdown();
    ref.read(orderRequestSessionProvider.notifier).setActive(
          request.orderId,
          _config.offerTimeoutSeconds,
        );

    int remaining = _config.offerTimeoutSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer t) {
      remaining -= 1;
      if (!mounted) {
        t.cancel();
        return;
      }
      ref.read(orderRequestSessionProvider.notifier).tickCountdown(remaining);
      if (remaining <= 0) {
        t.cancel();
        _onReject(request, timedOut: true);
      }
    });
  }

  void _showOffer(RiderDeliveryRequest request) {
    if (_sheetVisible || _accepting) {
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _visibleRequest = request;
      _sheetVisible = true;
    });
    _startCountdown(request);
  }

  void _hideOffer() {
    _cancelCountdown();
    ref.read(orderRequestSessionProvider.notifier).clearActive();
    if (mounted) {
      setState(() {
        _visibleRequest = null;
        _sheetVisible = false;
        _accepting = false;
      });
    }
  }

  void _onReject(RiderDeliveryRequest request, {bool timedOut = false}) {
    ref.read(orderRequestSessionProvider.notifier).dismiss(request.orderId);
    _hideOffer();
    if (timedOut && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Offer expired — another rider may take it.')),
      );
    }
  }

  void _onWentOffline() {
    _hydrated = false;
    _hydratedIds.clear();
    ref.read(orderRequestSessionProvider.notifier).resetSession();
    if (_sheetVisible) {
      _hideOffer();
    }
  }

  Future<void> _onAccept(RiderDeliveryRequest request) async {
    if (_accepting) {
      return;
    }
    setState(() => _accepting = true);
    _cancelCountdown();

    final RiderOrderAcceptResult result =
        await ref.read(riderOrderAcceptProvider)(request);

    if (!mounted) {
      return;
    }

    if (!result.isSuccess) {
      setState(() => _accepting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'Could not accept order')),
      );
      _hideOffer();
      return;
    }

    _hideOffer();
    HapticFeedback.mediumImpact();

    if (!context.mounted || result.order == null) {
      return;
    }
    context.push(
      '${RoutePaths.trip}/${result.order!.id}',
      extra: result.order,
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      riderDashboardProvider.select((RiderDashboardState s) => s.isOnline),
      (bool? wasOnline, bool isOnline) {
        if (wasOnline == true && !isOnline) {
          _onWentOffline();
        }
        if (wasOnline == false && isOnline) {
          _hydrated = false;
          _hydratedIds.clear();
        }
      },
    );

    final bool isOnline = ref.watch(riderDashboardProvider).isOnline;
    final bool approved = ref.watch(riderIsApprovedToDriveProvider);

    if (isOnline && approved) {
      ref.listen<AsyncValue<List<RiderDeliveryRequest>>>(
        matchedNearbyDeliveryRequestsProvider,
        (AsyncValue<List<RiderDeliveryRequest>>? prev,
            AsyncValue<List<RiderDeliveryRequest>> next) {
          final List<RiderDeliveryRequest>? jobs = next.valueOrNull;
          if (jobs == null) {
            return;
          }

          if (!_hydrated) {
            _hydratedIds.addAll(jobs.map((RiderDeliveryRequest j) => j.orderId));
            _hydrated = true;
            return;
          }

          if (_sheetVisible || _accepting) {
            return;
          }

          for (final RiderDeliveryRequest job in jobs) {
            if (_hydratedIds.contains(job.orderId)) {
              continue;
            }
            _hydratedIds.add(job.orderId);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_sheetVisible) {
                _showOffer(job);
              }
            });
            break;
          }
        },
      );
    }

    final int secondsRemaining =
        ref.watch(orderRequestSessionProvider).secondsRemaining;
    final RiderDeliveryRequest? request = _visibleRequest;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (_sheetVisible && request != null)
          Positioned.fill(
            child: GestureDetector(
              onTap: () => _onReject(request),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                color: Colors.black.withValues(alpha: _sheetVisible ? 0.45 : 0),
              ),
            ),
          ),
        if (_sheetVisible && request != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 1, end: 0),
              duration: const Duration(milliseconds: 380),
              curve: Curves.easeOutCubic,
              builder: (BuildContext context, double slide, Widget? child) {
                return Transform.translate(
                  offset: Offset(0, slide * 120),
                  child: child,
                );
              },
              child: RiderOrderRequestCard(
                request: request,
                secondsRemaining: secondsRemaining > 0
                    ? secondsRemaining
                    : _config.offerTimeoutSeconds,
                totalSeconds: _config.offerTimeoutSeconds,
                accepting: _accepting,
                onAccept: () => _onAccept(request),
                onReject: () => _onReject(request),
              ),
            ),
          ),
      ],
    );
  }
}
