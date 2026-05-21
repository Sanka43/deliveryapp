import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

class CustomerProfile extends Equatable {
  const CustomerProfile({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String phone;
  final String? email;
  final String? photoUrl;

  /// Prefers Firestore [customers] fields when set, otherwise Firebase Auth.
  factory CustomerProfile.merge(
    firebase_auth.User authUser,
    Map<String, dynamic>? doc,
  ) {
    String? trim(String? s) {
      if (s == null) {
        return null;
      }
      final String t = s.trim();
      return t.isEmpty ? null : t;
    }

    final String? docName = trim(doc?['displayName'] as String?);
    final String? docPhone = trim(doc?['phoneNumber'] as String?);
    final String? docEmail = trim(doc?['email'] as String?);
    final String? docPhoto = trim(doc?['photoUrl'] as String?);

    final String name =
        docName ?? trim(authUser.displayName) ?? 'Customer';
    final String phone =
        docPhone ?? trim(authUser.phoneNumber) ?? '';
    final String? email = docEmail ?? trim(authUser.email);
    final String? photoUrl = docPhoto ?? trim(authUser.photoURL);

    return CustomerProfile(
      id: authUser.uid,
      name: name,
      phone: phone,
      email: email,
      photoUrl: photoUrl,
    );
  }

  /// True when name and phone are set for job applications and orders.
  bool get isProfileComplete {
    final String n = name.trim();
    final bool nameOk =
        n.isNotEmpty && n.toLowerCase() != 'customer' && n.length >= 2;
    final bool phoneOk = phone.replaceAll(RegExp(r'\D'), '').length >= 8;
    return nameOk && phoneOk;
  }

  /// 0–100 for profile setup progress (email optional).
  int get profileCompletionPercent {
    int score = 0;
    if (name.trim().isNotEmpty && name.trim().toLowerCase() != 'customer') {
      score += 40;
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length >= 8) {
      score += 40;
    }
    if (email != null && email!.trim().isNotEmpty) {
      score += 20;
    }
    return score;
  }

  List<String> get missingProfileFields {
    final List<String> missing = <String>[];
    if (name.trim().isEmpty || name.trim().toLowerCase() == 'customer') {
      missing.add('Full name');
    }
    if (phone.replaceAll(RegExp(r'\D'), '').length < 8) {
      missing.add('Phone number');
    }
    if (email == null || email!.trim().isEmpty) {
      missing.add('Email (recommended)');
    }
    return missing;
  }

  String get initials {
    final List<String> parts =
        name.trim().split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.length >= 2
          ? parts.first.substring(0, 2).toUpperCase()
          : parts.first.toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  @override
  List<Object?> get props => <Object?>[id, name, phone, email, photoUrl];
}
