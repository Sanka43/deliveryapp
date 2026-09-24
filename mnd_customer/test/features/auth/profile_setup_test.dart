import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mnd_delivery_app/app/router/profile_setup_redirect.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';

void main() {
  group('returningCustomerPatch', () {
    test('never overwrites a saved name/email with null Auth values', () {
      final Map<String, dynamic> patch = returningCustomerPatch(
        existing: <String, dynamic>{
          'displayName': 'Kamal',
          'email': 'kamal@example.lk',
        },
        authDisplayName: null,
        authEmail: null,
        phoneNumber: '+94771234567',
      );
      expect(patch.containsKey('displayName'), isFalse);
      expect(patch.containsKey('email'), isFalse);
      expect(patch['phoneNumber'], '+94771234567');
      expect(patch['updatedAt'], isA<FieldValue>());
    });

    test('does not replace a saved name with a different Auth name', () {
      final Map<String, dynamic> patch = returningCustomerPatch(
        existing: <String, dynamic>{'displayName': 'Kamal'},
        authDisplayName: 'Other',
        authEmail: null,
        phoneNumber: '+94771234567',
      );
      expect(patch.containsKey('displayName'), isFalse);
    });

    test('backfills blank doc fields from Auth when available', () {
      final Map<String, dynamic> patch = returningCustomerPatch(
        existing: <String, dynamic>{'displayName': '  ', 'email': null},
        authDisplayName: 'Kamal',
        authEmail: 'kamal@example.lk',
        phoneNumber: '+94771234567',
      );
      expect(patch['displayName'], 'Kamal');
      expect(patch['email'], 'kamal@example.lk');
    });
  });

  group('profileSetupRedirect', () {
    ProfileSetupRedirect decide({
      bool? setupRequired = true,
      String matched = AppRoutes.customer,
      String? location,
      bool authFlow = false,
      String? pending,
    }) {
      return profileSetupRedirect(
        setupRequired: setupRequired,
        matchedLocation: matched,
        location: location ?? matched,
        isAuthFlowRoute: authFlow,
        pendingRedirect: pending,
      );
    }

    test('unknown or complete profile never gates', () {
      expect(decide(setupRequired: null).redirectTo, isNull);
      expect(decide(setupRequired: false).redirectTo, isNull);
    });

    test('incomplete profile is sent to setup from home', () {
      final ProfileSetupRedirect r = decide();
      expect(r.redirectTo, AppRoutes.completeProfile);
      expect(r.pendingToSave, isNull, reason: 'home is the default target');
    });

    test('stays put on the setup page', () {
      expect(decide(matched: AppRoutes.completeProfile).redirectTo, isNull);
    });

    test('remembers a deep target like checkout to resume after setup', () {
      final ProfileSetupRedirect r = decide(
        matched: AppRoutes.customerCheckout,
        location: '${AppRoutes.customerCheckout}?store=s1',
      );
      expect(r.redirectTo, AppRoutes.completeProfile);
      expect(r.pendingToSave, '${AppRoutes.customerCheckout}?store=s1');
    });

    test('does not clobber an existing pending redirect', () {
      final ProfileSetupRedirect r = decide(
        matched: AppRoutes.customerOrders,
        pending: AppRoutes.customerCheckout,
      );
      expect(r.pendingToSave, isNull);
    });

    test('does not remember login/splash as a target', () {
      final ProfileSetupRedirect r =
          decide(matched: AppRoutes.login, authFlow: true);
      expect(r.redirectTo, AppRoutes.completeProfile);
      expect(r.pendingToSave, isNull);
    });
  });
}
