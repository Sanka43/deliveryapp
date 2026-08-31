import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/features/rides/data/ride_directions_service.dart';

// IMPORTANT: `flutter test` alone runs on the Dart VM and will NOT catch a
// regression here. The bug this guards against — dart2js's `~` (bitwise
// NOT) returning the unsigned 32-bit bit pattern instead of a proper
// negative Dart int (`~6` comes back as `4294967289`, not `-7`) — only
// manifests once compiled to JS. Run this file with:
//
//   flutter test --platform chrome test/features/rides/ride_directions_service_test.dart
//
// A plain VM run passes even on the old broken implementation.
void main() {
  group('decodePolyline', () {
    test('decodes the canonical Google polyline-algorithm example', () {
      // https://developers.google.com/maps/documentation/utilities/polylinealgorithm
      final points = decodePolyline(r'_p~iF~ps|U_ulLnnqC_mqNvxq`@');

      expect(points.length, 3);
      expect(points[0].latitude, closeTo(38.5, 1e-5));
      expect(points[0].longitude, closeTo(-120.2, 1e-5));
      expect(points[1].latitude, closeTo(40.7, 1e-5));
      expect(points[1].longitude, closeTo(-120.95, 1e-5));
      expect(points[2].latitude, closeTo(43.252, 1e-5));
      expect(points[2].longitude, closeTo(-126.453, 1e-5));
    });

    test(
        'decodes a real long route without desyncing '
        '(Badulla -> Hali-ela, the exact route that corrupted in production '
        'on 2026-08-31)', () {
      const String encoded =
          "s{ti@{`vmNL@NJHR@FGNOb@B`@rCE`EErCV@MHq@F_@^mANc@nAeCTy@AKF{@@i@AIJAtAUjAWTCR@`CCdBOLEdDUVBbAKh@E]cDBOJObEu@nB_@AKKoA@u@VeA@q@GAEAGI?MFILAHDDJ?FA@fBZp@HbAHdAHjAFj@Ct@Kf@CnAEb@?VGVQR]Tm@HOTMbC}@zCeAdA]~CuAnCcATELCpBBtBBrAW`EgAbAWhD{@`@Md@Y~AiA~CwB^WTOj@Yt@U`@Y|@q@`@O`A]`@M`@Cd@OZc@Na@RYRK~Aa@zEqAdD_A`@IF?~@Fj@@dA?dASjAO\\IrAk@j@OXKj@Yv@Mp@QlAq@nAcAr@WrAW^MZ]ZKn@KRGBc@JaAFk@Tg@RKd@_@t@o@\\Q`@Kb@I`@Q`A]d@Sz@[`@U`@g@LKb@M~ASTKPMHOH]V_@r@}@Zs@N_@\\i@l@g@f@c@T[\\e@`@S^Gb@A^QrAeAZU`@S~Ai@n@[j@_@n@Qx@OhAu@XMj@GTILM\\Sz@[`@Wj@w@\\e@f@a@tAo@rDsA`@Kf@MZCb@Af@Cl@Dv@L`@HP?l@Q`@Gh@Cn@Mv@GxAUT@ZFb@Cr@KdAQn@U\\Yf@w@V{@LQRGTEFGNOLIRG^@b@B\\EPIJSCYMc@@WJSLMVYFW@O@OM[MSMO]Su@WaASOGQ]?SHa@Hi@HORONMzAgAZ_@\\o@DMCc@UeA_@{BSo@?QFQf@]VIVA`@YLMLG^?^TZVt@j@n@b@VDXCLKT]JUBQ@]EKYYOIYQ_@UKOQc@M[Oe@?]Dc@@INY\\[|@YVQVYb@UZMVEl@SREf@BX?RGh@_@FOF_@@g@AcAFg@f@kA`@o@TULKbA]PEf@Ij@At@@b@DD?VGTe@^cBn@qAFc@Bq@Bg@LWRQRYd@gBDQ?IGSS[Sq@c@yBC_@@[DQH[FsDF{@ZB`AVR@BBNh@ZVLRD\\@NLNRT\\R`@PPDVBlAKx@Ix@Er@?`@BPF`@Jh@@bAFX?l@E`@IPMVi@Na@n@}@hAeAQ^Yp@}@zAW`@?HBPCL]b@CFc@JMBQNCHUt@M\\e@d@KZCFSNYHGJI^[T";

      final points = decodePolyline(encoded);

      // A corrupted decode (the production bug) produces points in the
      // billions or on the wrong continent — these guards fail loudly
      // instead of needing an exact-coordinate golden file.
      expect(points.length, 392);
      for (final point in points) {
        expect(point.latitude, inInclusiveRange(5.5, 10.0),
            reason: 'outside Sri Lanka — decode desynced');
        expect(point.longitude, inInclusiveRange(79.0, 82.0),
            reason: 'outside Sri Lanka — decode desynced');
      }

      // Consecutive polyline vertices on a real route never jump more than
      // a few km; a desynced decode produces a wild outlier.
      for (int i = 1; i < points.length; i++) {
        final double dLat =
            (points[i].latitude - points[i - 1].latitude).abs();
        final double dLng =
            (points[i].longitude - points[i - 1].longitude).abs();
        expect(dLat, lessThan(0.5));
        expect(dLng, lessThan(0.5));
      }

      expect(points.first.latitude, closeTo(6.99338, 1e-5));
      expect(points.first.longitude, closeTo(81.05502, 1e-5));
    });
  });
}
