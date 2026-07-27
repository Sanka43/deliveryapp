import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';

class ShopPasswordResetRequestResult {
  const ShopPasswordResetRequestResult({this.debugOtp});

  final String? debugOtp;
}

class ShopPasswordResetRepository {
  ShopPasswordResetRepository(this._functions);

  final FirebaseFunctions _functions;

  Future<ShopPasswordResetRequestResult> requestOtp(String email) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('requestShopPasswordResetOtp')
          .call(<String, dynamic>{'email': email.trim()});
      final Object? data = result.data;
      String? debugOtp;
      if (data is Map) {
        final Object? raw = data['debugOtp'];
        if (raw is String && raw.isNotEmpty) {
          debugOtp = raw;
        }
      }
      return ShopPasswordResetRequestResult(debugOtp: debugOtp);
    } on FirebaseFunctionsException catch (e) {
      throw ShopPasswordResetException(_mapError(e));
    } catch (_) {
      throw const ShopPasswordResetException(
        'Could not send reset code. Check your connection and try again.',
      );
    }
  }

  Future<String> verifyOtp({
    required String email,
    required String otp,
  }) async {
    try {
      final HttpsCallableResult<dynamic> result = await _functions
          .httpsCallable('verifyShopPasswordResetOtp')
          .call(<String, dynamic>{
        'email': email.trim(),
        'otp': otp.trim(),
      });
      final Object? data = result.data;
      if (data is Map) {
        final Object? token = data['resetToken'];
        if (token is String && token.isNotEmpty) {
          return token;
        }
      }
      throw const ShopPasswordResetException(
        'Could not verify code. Try again.',
      );
    } on ShopPasswordResetException {
      rethrow;
    } on FirebaseFunctionsException catch (e) {
      throw ShopPasswordResetException(_mapError(e));
    } catch (_) {
      throw const ShopPasswordResetException(
        'Could not verify code. Try again.',
      );
    }
  }

  Future<void> confirmNewPassword({
    required String email,
    required String resetToken,
    required String newPassword,
  }) async {
    try {
      await _functions.httpsCallable('confirmShopPasswordReset').call(
        <String, dynamic>{
          'email': email.trim(),
          'resetToken': resetToken,
          'newPassword': newPassword,
        },
      );
    } on FirebaseFunctionsException catch (e) {
      throw ShopPasswordResetException(_mapError(e));
    } catch (_) {
      throw const ShopPasswordResetException(
        'Could not update password. Try again.',
      );
    }
  }

  String _mapError(FirebaseFunctionsException e) {
    final String? message = e.message?.trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }
    switch (e.code) {
      case 'not-found':
        return 'Invalid or expired code. Request a new one.';
      case 'deadline-exceeded':
        return 'Code expired. Request a new one.';
      case 'resource-exhausted':
        return 'Too many attempts. Please wait and try again.';
      case 'permission-denied':
        return 'Incorrect code. Try again.';
      case 'unavailable':
        return 'Service unavailable. Try again shortly.';
      default:
        if (kDebugMode) {
          return 'Password reset failed (${e.code}). Deploy shop password reset functions?';
        }
        return 'Something went wrong. Try again.';
    }
  }
}

class ShopPasswordResetException implements Exception {
  const ShopPasswordResetException(this.message);

  final String message;

  @override
  String toString() => message;
}

final Provider<ShopPasswordResetRepository> shopPasswordResetRepositoryProvider =
    Provider<ShopPasswordResetRepository>((Ref ref) {
  return ShopPasswordResetRepository(ref.watch(firebaseFunctionsProvider));
});
