import 'package:equatable/equatable.dart';

class VendorProfile extends Equatable {
  const VendorProfile({
    required this.id,
    required this.storeName,
    required this.active,
  });

  final String id;
  final String storeName;
  final bool active;

  @override
  List<Object?> get props => <Object?>[id, storeName, active];
}
