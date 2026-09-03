/// Job listing categories, types, and workflow statuses.
class JobConstants {
  JobConstants._();

  static const String statusPending = 'pending';
  static const String statusActive = 'active';
  static const String statusRejected = 'rejected';
  static const String statusExpired = 'expired';

  /// Work area — used by home browse chips and the post form Category field.
  static const List<String> quickCategories = <String>[
    'Delivery',
    'Event Jobs',
    'Internship',
    'Freelance',
    'Shop Staff',
    'Kitchen',
    'Driver',
    'Other',
  ];

  /// Employment schedule — used by filter sheet and the post form Job type field.
  static const List<String> jobTypes = <String>[
    'Part Time',
    'Full Time',
    'Temporary',
    'Weekend',
    'Remote',
  ];

  static const String defaultCategory = 'Delivery';
  static const String defaultJobType = 'Part Time';

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
