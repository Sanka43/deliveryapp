import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mnd_shop/features/jobs/domain/job_constants.dart';

class JobListing {
  const JobListing({
    required this.id,
    required this.title,
    required this.category,
    required this.type,
    required this.salary,
    required this.location,
    required this.description,
    required this.companyName,
    required this.contactPhone,
    required this.userId,
    required this.status,
    required this.createdAt,
    this.whatsapp,
    this.responsibilities = '',
    this.schedule = '',
    this.skills = const <String>[],
    this.deadline,
    this.expiresAt,
    this.verified = false,
    this.urgent = false,
    this.remote = false,
    this.city = '',
    this.imageUrl,
    this.logoUrl,
    this.viewCount = 0,
    this.reportedCount = 0,
    this.latitude,
    this.longitude,
    this.availableLaborCount = JobConstants.defaultLaborCount,
  });

  final String id;
  final String title;
  final String category;
  final String type;
  final String salary;
  final String location;
  final String description;
  final String companyName;
  final String contactPhone;
  final String? whatsapp;
  final String responsibilities;
  final String schedule;
  final List<String> skills;
  final DateTime? deadline;
  final DateTime? expiresAt;
  final String userId;
  final String status;
  final bool verified;
  final bool urgent;
  final bool remote;
  final String city;
  final String? imageUrl;
  final String? logoUrl;
  final int viewCount;
  final int reportedCount;
  final double? latitude;
  final double? longitude;
  final DateTime createdAt;

  /// Max workers that can be booked for this post.
  final int availableLaborCount;

  bool get isActive => status == JobConstants.statusActive;

  bool hasBookingSlotsOpen(int bookedCount) =>
      bookedCount < availableLaborCount;

  String bookingSlotsLabel(int bookedCount) =>
      '$bookedCount / $availableLaborCount booked';

  static int parseLaborCount(dynamic raw) {
    final int n = (raw as num?)?.toInt() ?? JobConstants.defaultLaborCount;
    if (n < JobConstants.minLaborCount) {
      return JobConstants.minLaborCount;
    }
    if (n > JobConstants.maxLaborCount) {
      return JobConstants.maxLaborCount;
    }
    return n;
  }

  bool get isExpired {
    if (status == JobConstants.statusExpired) {
      return true;
    }
    final DateTime? exp = expiresAt;
    if (exp == null) {
      return false;
    }
    return DateTime.now().isAfter(exp);
  }

  factory JobListing.fromFirestore(String id, Map<String, dynamic> data) {
    return JobListing(
      id: id,
      title: (data['title'] as String?)?.trim() ?? '',
      category: (data['category'] as String?)?.trim() ?? '',
      type: (data['type'] as String?)?.trim() ?? '',
      salary: (data['salary'] as String?)?.trim() ?? '',
      location: (data['location'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      companyName: (data['companyName'] as String?)?.trim() ?? 'Employer',
      contactPhone: (data['contactPhone'] as String?)?.trim() ?? '',
      whatsapp: (data['whatsapp'] as String?)?.trim(),
      responsibilities: (data['responsibilities'] as String?)?.trim() ?? '',
      schedule: (data['schedule'] as String?)?.trim() ?? '',
      skills: _parseSkills(data['skills']),
      deadline: _toDateTime(data['deadline']),
      expiresAt: _toDateTime(data['expiresAt']),
      userId: (data['userId'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? JobConstants.statusPending,
      verified: data['verified'] == true,
      urgent: data['urgent'] == true,
      remote: data['remote'] == true,
      city: (data['city'] as String?)?.trim() ?? '',
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      logoUrl: (data['logoUrl'] as String?)?.trim(),
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      reportedCount: (data['reportedCount'] as num?)?.toInt() ?? 0,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      createdAt: _toDateTime(data['createdAt']) ?? DateTime.now(),
      availableLaborCount: parseLaborCount(data['availableLaborCount']),
    );
  }

  static List<String> _parseSkills(dynamic raw) {
    if (raw is List) {
      return raw
          .whereType<String>()
          .map((String s) => s.trim())
          .where((String s) => s.isNotEmpty)
          .toList();
    }
    return const <String>[];
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

  Map<String, dynamic> toCreateMap({
    required String userId,
    required String status,
    required DateTime createdAt,
    required DateTime expiresAt,
  }) {
    return <String, dynamic>{
      'title': title,
      'category': category,
      'type': type,
      'salary': salary,
      'location': location,
      'description': description,
      'companyName': companyName,
      'contactPhone': contactPhone,
      if (whatsapp != null && whatsapp!.isNotEmpty) 'whatsapp': whatsapp,
      'responsibilities': responsibilities,
      'schedule': schedule,
      'skills': skills,
      if (deadline != null) 'deadline': Timestamp.fromDate(deadline!),
      'expiresAt': Timestamp.fromDate(expiresAt),
      'userId': userId,
      'status': status,
      'verified': verified,
      'urgent': urgent,
      'remote': remote,
      'city': city,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (logoUrl != null) 'logoUrl': logoUrl,
      'viewCount': 0,
      'reportedCount': 0,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      'createdAt': Timestamp.fromDate(createdAt),
      'availableLaborCount': availableLaborCount,
    };
  }
}
