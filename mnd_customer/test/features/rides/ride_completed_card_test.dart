import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_place.dart';
import 'package:mnd_delivery_app/features/rides/domain/entities/ride_trip.dart';
import 'package:mnd_delivery_app/features/rides/domain/ride_constants.dart';
import 'package:mnd_delivery_app/features/rides/presentation/widgets/ride_completed_card.dart';

RideTrip _trip({
  String paymentMethod = RideConstants.paymentCash,
  String paymentStatus = 'paid',
  List<RidePlace> stops = const <RidePlace>[],
}) {
  return RideTrip(
    id: 't1',
    customerId: 'c1',
    contactPhone: '0770000000',
    pickup: const RidePlace(lat: 6.98, lng: 81.05, label: 'Badulla Bus Stand'),
    dropoff: const RidePlace(lat: 6.99, lng: 81.06, label: 'Muthiyangana Road'),
    stops: stops,
    vehicleType: RideConstants.vehicleBike,
    distanceKm: 4.25,
    estimatedFareLkr: 403,
    status: RideConstants.statusCompleted,
    paymentMethod: paymentMethod,
    paymentStatus: paymentStatus,
    openForRiders: false,
  );
}

Future<void> _pump(WidgetTester tester, RideTrip trip) {
  return tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: RideCompletedCard(
          trip: trip,
          payingOnline: false,
          onPayOnline: () {},
          onDone: () {},
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('shows both addresses, distance, vehicle and fare', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _trip());

    expect(find.text('Ride completed'), findsOneWidget);
    expect(find.text('Pick-up'), findsOneWidget);
    expect(find.text('Badulla Bus Stand'), findsOneWidget);
    expect(find.text('Drop-off'), findsOneWidget);
    expect(find.text('Muthiyangana Road'), findsOneWidget);
    expect(find.text('4.3 km'), findsOneWidget);
    expect(find.text('Bike'), findsOneWidget);
    expect(find.text('LKR 403'), findsOneWidget);
    expect(find.text('Paid in cash to the driver'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('lists every stop between pick-up and drop-off', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _trip(
        stops: const <RidePlace>[
          RidePlace(lat: 6.985, lng: 81.055, label: 'Hospital Junction'),
        ],
      ),
    );

    expect(find.text('Stop 1'), findsOneWidget);
    expect(find.text('Hospital Junction'), findsOneWidget);
    expect(find.text('Stops'), findsOneWidget);
  });

  testWidgets('unpaid online ride offers the pay button', (
    WidgetTester tester,
  ) async {
    await _pump(
      tester,
      _trip(
        paymentMethod: RideConstants.paymentPayHere,
        paymentStatus: 'pending',
      ),
    );

    expect(find.text('Pay LKR 403 now'), findsOneWidget);
    expect(
      find.text('Payment pending — pay online to settle this ride'),
      findsOneWidget,
    );
  });

  testWidgets('cash ride the driver has not confirmed still reads pending', (
    WidgetTester tester,
  ) async {
    await _pump(tester, _trip(paymentStatus: 'pending'));

    expect(find.text('Pay LKR 403 now'), findsNothing);
    expect(
      find.text('Waiting for the driver to confirm cash payment'),
      findsOneWidget,
    );
  });
}
