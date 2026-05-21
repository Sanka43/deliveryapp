import 'package:mnd_delivery_app/core/utils/result.dart';
import 'package:mnd_delivery_app/features/auth/domain/entities/user.dart';

abstract interface class AuthRepository {
  Future<Result<User>> signIn({
    required String email,
    required String password,
  });
}
