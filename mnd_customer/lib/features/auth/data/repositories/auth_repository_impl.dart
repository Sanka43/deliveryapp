import 'package:mnd_delivery_app/core/network/api_client.dart';
import 'package:mnd_delivery_app/core/utils/result.dart';
import 'package:mnd_delivery_app/features/auth/domain/entities/user.dart';
import 'package:mnd_delivery_app/features/auth/domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._apiClient);

  final ApiClient _apiClient;

  @override
  Future<Result<User>> signIn({
    required String email,
    required String password,
  }) async {
    final _ = _apiClient.instance;
    return const Success<User>(
      User(
        id: 'seed-user-id',
        email: 'admin@mnddelivery.com',
        role: 'admin',
      ),
    );
  }
}
