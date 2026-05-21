import 'package:mnd_delivery_app/core/usecases/usecase.dart';
import 'package:mnd_delivery_app/core/utils/result.dart';
import 'package:mnd_delivery_app/features/auth/domain/entities/user.dart';
import 'package:mnd_delivery_app/features/auth/domain/repositories/auth_repository.dart';

class SignInParams {
  const SignInParams({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class SignInUseCase implements UseCase<Result<User>, SignInParams> {
  SignInUseCase(this._repository);

  final AuthRepository _repository;

  @override
  Future<Result<User>> call(SignInParams params) {
    return _repository.signIn(
      email: params.email,
      password: params.password,
    );
  }
}
