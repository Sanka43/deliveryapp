/// Job listing categories, types, and workflow statuses.
class JobConstants {
  JobConstants._();

  static const String statusPending = 'pending';
  static const String statusActive = 'active';
  static const String statusRejected = 'rejected';
  static const String statusExpired = 'expired';

  static const List<String> quickCategories = <String>[
    'Part Time',
    'Full Time',
    'Remote',
    'Weekend',
    'Internship',
    'Event Jobs',
    'Delivery',
    'Freelance',
  ];

  static const List<String> jobTypes = <String>[
    'Part Time',
    'Full Time',
    'Temporary',
    'Weekend',
    'Freelance',
    'Remote',
    'Internship',
    'Event Staff',
  ];

  static const List<String> searchHints = <String>[
    'Delivery rider',
    'Part time',
    'Graphic designer',
  ];

  static const Duration defaultListingDuration = Duration(days: 30);
  static const Duration duplicateWindow = Duration(hours: 24);

  /// How many workers can be booked for one job post.
  static const int defaultLaborCount = 1;
  static const int minLaborCount = 1;
  static const int maxLaborCount = 99;
}
