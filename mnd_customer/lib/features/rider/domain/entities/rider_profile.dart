import 'package:equatable/equatable.dart';

class RiderProfile extends Equatable {
  const RiderProfile({
    required this.id,
    required this.vehicleType,
    required this.online,
  });

  final String id;
  final String vehicleType;
  final bool online;

  @override
  List<Object?> get props => <Object?>[id, vehicleType, online];
}
