import 'package:equatable/equatable.dart';

class AdminProfile extends Equatable {
  const AdminProfile({
    required this.id,
    required this.email,
  });

  final String id;
  final String email;

  @override
  List<Object?> get props => <Object?>[id, email];
}
