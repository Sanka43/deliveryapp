import 'package:cloud_firestore/cloud_firestore.dart';

/// Application workflow: submitted → shortlisted → booked | rejected
class JobApplication {
  const JobApplication({
    required this.id,
    required this.jobId,
    required this.applicantId,
    required this.applicantName,
    required this.applicantPhone,
    required this.status,
    required this.appliedAt,
    this.bio,
    this.cvUrl,
    this.jobTitle = '',
    this.companyName = '',
    this.bookedAt,
    this.updatedAt,
  });

  final String id;
  final String jobId;
  final String applicantId;
  final String applicantName;
  final String applicantPhone;
  final String status;
  final String? bio;
  final String? cvUrl;
  final String jobTitle;
  final String companyName;
  final DateTime appliedAt;
  final DateTime? bookedAt;
  final DateTime? updatedAt;

  bool get isBooked => status == JobApplicationStatus.booked;

  String get statusLabel => JobApplicationStatus.label(status);

  factory JobApplication.fromFirestore(String id, Map<String, dynamic> data) {
    return JobApplication(
      id: id,
      jobId: (data['jobId'] as String?)?.trim() ?? '',
      applicantId: (data['applicantId'] as String?)?.trim() ?? '',
      applicantName: (data['applicantName'] as String?)?.trim() ?? '',
      applicantPhone: (data['applicantPhone'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? JobApplicationStatus.submitted,
      bio: (data['bio'] as String?)?.trim(),
      cvUrl: (data['cvUrl'] as String?)?.trim(),
      jobTitle: (data['jobTitle'] as String?)?.trim() ?? '',
      companyName: (data['companyName'] as String?)?.trim() ?? '',
      appliedAt: _toDateTime(data['appliedAt']) ?? DateTime.now(),
      bookedAt: _toDateTime(data['bookedAt']),
      updatedAt: _toDateTime(data['updatedAt']),
    );
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

class JobApplicationStatus {
  JobApplicationStatus._();

  static const String submitted = 'submitted';
  static const String shortlisted = 'shortlisted';
  static const String booked = 'booked';
  static const String rejected = 'rejected';

  static const List<String> all = <String>[
    submitted,
    shortlisted,
    booked,
    rejected,
  ];

  static String label(String status) {
    switch (status) {
      case shortlisted:
        return 'Shortlisted';
      case booked:
        return 'Booked';
      case rejected:
        return 'Rejected';
      default:
        return 'Applied';
    }
  }
}
