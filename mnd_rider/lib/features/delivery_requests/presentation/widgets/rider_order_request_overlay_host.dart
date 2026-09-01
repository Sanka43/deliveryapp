import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_approval_provider.dart';
import 'package:mnd_rider/features/dashboard/presentation/providers/rider_dashboard_provider.dart';
import 'package:mnd_rider/features/delivery_requests/domain/delivery_request_config.dart';
import 'package:mnd_rider/features/delivery_requests/domain/rider_delivery_request.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/order_request_session_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_delivery_requests_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/providers/rider_order_accept_provider.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/widgets/rider_order_request_card.dart';
import 'package:mnd_rider/features/delivery_requests/presentation/widgets/rider_ride_request_card.dart';
import 'package:mnd_rider/features/earnings/presentation/providers/rider_cash_hold_provider.dart';
import 'package:mnd_rider/features/orders/presentation/providers/rider_active_order_provider.dart';
import 'package:mnd_rider/features/shell/presentation/providers/rider_shell_tab_provider.dart';
import 'package:mnd_rider/features/trips/data/rider_trips_repository.dart';

/// One pending offer of either kind — at most one is ever visible at a time.
sealed class _PendingOffer {
  const _PendingOffer();

  String get id;
}

class _DeliveryOffer extends _PendingOffer {
  const _DeliveryOffer(this.request);

  final RiderDeliveryRequest request;

  @override
  String get id => request.orderId;
}

class _RideOffer extends _PendingOffer {
  const _RideOffer(this.trip);

  final RiderPassengerTrip trip;

  @override
  String get id => trip.id;
}

/// Listens for nearby open delivery jobs *and* passenger-ride offers, and
/// shows an animated bottom offer card for whichever is pending — from any
/// tab, since this host wraps the whole authenticated shell.
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

  Timer? _countdownTimer;
  _PendingOffer? _visibleOffer;
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

  void _startCountdown(_PendingOffer offer) {
    _cancelCountdown();
    ref.read(orderRequestSessionProvider.notifier).setActive(
          offer.id,
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
        _onReject(offer, timedOut: true);
      }
    });
  }

  void _setNavVisible(bool visible) {
    ref.read(riderShellNavVisibleProvider.notifier).state = visible;
  }

  void _showOffer(_PendingOffer offer) {
    if (_sheetVisible || _accepting) {
      return;
    }
    HapticFeedback.heavyImpact();
    _setNavVisible(false);
    setState(() {
      _visibleOffer = offer;
      _sheetVisible = true;
    });
    _startCountdown(offer);
  }

  void _hideOffer() {
    _cancelCountdown();
    ref.read(orderRequestSessionProvider.notifier).clearActive();
    _setNavVisible(true);
    if (mounted) {
      setState(() {
        _visibleOffer = null;
        _sheetVisible = false;
        _accepting = false;
      });
    }
  }

  void _onReject(_PendingOffer offer, {bool timedOut = false}) {
    ref.read(orderRequestSessionProvider.notifier).dismiss(offer.id);
    _hideOffer();
    if (timedOut && mounted) {
      showRiderSnackBar(
        context,
        'Offer expired — another rider may take it.',
      );
    }
    // Chain to the next pending job (dismissed ids are filtered upstream).
    _scheduleOfferNext();
  }

  void _onWentOffline() {
    ref.read(orderRequestSessionProvider.notifier).resetSession();
    if (_sheetVisible) {
      _hideOffer();
    }
  }

  bool get _canOffer {
    if (_sheetVisible || _accepting || !mounted) {
      return false;
    }
    if (!ref.read(riderDashboardProvider).isOnline ||
        !ref.read(riderIsApprovedToDriveProvider)) {
      return false;
    }
    // Holding too much collected cash — Firestore rules would reject the
    // claim, so don't pop an offer the rider can't accept.
    if (ref.read(riderCashHoldActiveProvider)) {
      return false;
    }
    // No new offers while a delivery is in progress.
    return ref.read(riderIsBusyProvider) == false;
  }

  /// Offers the first pending job (includes jobs that were already open when
  /// the rider came online — they must not be silently skipped). Delivery
  /// jobs take priority; a ride offer is only shown once no delivery job is
  /// pending.
  void _maybeOfferNext() {
    if (!_canOffer) {
      return;
    }
    final List<RiderDeliveryRequest> jobs =
        ref.read(matchedNearbyDeliveryRequestsProvider).valueOrNull ??
            const <RiderDeliveryRequest>[];
    if (jobs.isNotEmpty) {
      _showOffer(_DeliveryOffer(jobs.first));
      return;
    }

    // matchedOpenPassengerTripsProvider already excludes dismissed ids
    // (mirrors the delivery matcher).
    final List<RiderPassengerTrip> rides =
        ref.read(matchedOpenPassengerTripsProvider).valueOrNull ??
            const <RiderPassengerTrip>[];
    if (rides.isEmpty) {
      return;
    }
    _showOffer(_RideOffer(rides.first));
  }

  void _scheduleOfferNext() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _maybeOfferNext();
      }
    });
  }

  Future<void> _onAccept(_PendingOffer offer) {
    return switch (offer) {
      _DeliveryOffer(:final request) => _onAcceptDelivery(offer, request),
      _RideOffer(:final trip) => _onAcceptRide(offer, trip),
    };
  }

  Future<void> _onAcceptDelivery(
    _PendingOffer offer,
    RiderDeliveryRequest request,
  ) async {
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
      showRiderSnackBar(
        context,
        result.error ?? 'Could not accept order',
      );
      final String msg = (result.error ?? '').toLowerCase();
      final bool gone = msg.contains('no longer available') ||
          msg.contains('already claimed') ||
          msg.contains('not found');
      if (gone) {
        _hideOffer();
        _scheduleOfferNext();
      } else {
        _startCountdown(offer);
      }
      return;
    }

    _hideOffer();
    HapticFeedback.mediumImpact();

    final String tripId = result.tripOrderId ?? request.orderId;
    if (!context.mounted || tripId.isEmpty) {
      return;
    }
    context.push(
      '${RoutePaths.trip}/$tripId',
      extra: result.order,
    );
  }

  Future<void> _onAcceptRide(
    _PendingOffer offer,
    RiderPassengerTrip trip,
  ) async {
    if (_accepting) {
      return;
    }
    setState(() => _accepting = true);
    _cancelCountdown();

    final String? error =
        await ref.read(riderTripsRepositoryProvider).claimTrip(trip.id);

    if (!mounted) {
      return;
    }

    if (error != null) {
      setState(() => _accepting = false);
      showRiderSnackBar(context, error);
      final String msg = error.toLowerCase();
      final bool gone = msg.contains('no longer available') ||
          msg.contains('already claimed') ||
          msg.contains('not found');
      if (gone) {
        _hideOffer();
        _scheduleOfferNext();
      } else {
        _startCountdown(offer);
      }
      return;
    }

    _hideOffer();
    HapticFeedback.mediumImpact();

    if (!context.mounted) {
      return;
    }
    context.push('${RoutePaths.ride}/${trip.id}', extra: trip);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      riderDashboardProvider.select((RiderDashboardState s) => s.isOnline),
      (bool? wasOnline, bool isOnline) {
        if (wasOnline == true && !isOnline) {
          _onWentOffline();
        }
      },
    );

    // Delivery finished → resume offering pending jobs.
    ref.listen<String?>(activeRiderOrderIdProvider,
        (String? prev, String? next) {
      if (prev != null && next == null) {
        _scheduleOfferNext();
      }
    });

    final bool isOnline = ref.watch(riderDashboardProvider).isOnline;
    final bool approved = ref.watch(riderIsApprovedToDriveProvider);

    ref.listen<AsyncValue<List<RiderDeliveryRequest>>>(
      matchedNearbyDeliveryRequestsProvider,
      (AsyncValue<List<RiderDeliveryRequest>>? prev,
          AsyncValue<List<RiderDeliveryRequest>> next) {
        if (!isOnline || !approved) {
          return;
        }
        final List<RiderDeliveryRequest>? jobs = next.valueOrNull;
        if (jobs == null) {
          return;
        }

        final _PendingOffer? visible = _visibleOffer;
        if (_sheetVisible &&
            visible is _DeliveryOffer &&
            !jobs.any((RiderDeliveryRequest j) => j.orderId == visible.id)) {
          if (!_accepting) {
            _hideOffer();
            _scheduleOfferNext();
          }
          return;
        }
        if (_sheetVisible && visible is _RideOffer) {
          // A delivery-list update never interrupts a ride card already
          // showing.
          return;
        }

        _scheduleOfferNext();
      },
    );

    ref.listen<AsyncValue<List<RiderPassengerTrip>>>(
      matchedOpenPassengerTripsProvider,
      (AsyncValue<List<RiderPassengerTrip>>? prev,
          AsyncValue<List<RiderPassengerTrip>> next) {
        if (!isOnline || !approved) {
          return;
        }
        final List<RiderPassengerTrip>? rides = next.valueOrNull;
        if (rides == null) {
          return;
        }

        final _PendingOffer? visible = _visibleOffer;
        if (_sheetVisible &&
            visible is _RideOffer &&
            !rides.any((RiderPassengerTrip t) => t.id == visible.id)) {
          if (!_accepting) {
            _hideOffer();
            _scheduleOfferNext();
          }
          return;
        }
        if (_sheetVisible && visible is _DeliveryOffer) {
          // A ride-list update never interrupts a delivery card already
          // showing.
          return;
        }

        _scheduleOfferNext();
      },
    );

    final int secondsRemaining =
        ref.watch(orderRequestSessionProvider).secondsRemaining;
    final _PendingOffer? offer = _visibleOffer;

    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        widget.child,
        if (_sheetVisible && offer != null)
          Positioned.fill(
            child: AbsorbPointer(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                color: Colors.black.withValues(alpha: _sheetVisible ? 0.62 : 0),
              ),
            ),
          ),
        if (_sheetVisible && offer != null)
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
              child: switch (offer) {
                _DeliveryOffer(:final request) => RiderOrderRequestCard(
                    request: request,
                    secondsRemaining: secondsRemaining > 0
                        ? secondsRemaining
                        : _config.offerTimeoutSeconds,
                    totalSeconds: _config.offerTimeoutSeconds,
                    accepting: _accepting,
                    onAccept: () => _onAccept(offer),
                    onReject: () => _onReject(offer),
                  ),
                _RideOffer(:final trip) => RiderRideRequestCard(
                    trip: trip,
                    secondsRemaining: secondsRemaining > 0
                        ? secondsRemaining
                        : _config.offerTimeoutSeconds,
                    totalSeconds: _config.offerTimeoutSeconds,
                    accepting: _accepting,
                    onAccept: () => _onAccept(offer),
                    onReject: () => _onReject(offer),
                  ),
              },
            ),
          ),
      ],
    );
  }
}
