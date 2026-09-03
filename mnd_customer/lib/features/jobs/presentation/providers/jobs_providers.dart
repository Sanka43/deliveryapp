import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/user_role_provider.dart';
import 'package:mnd_delivery_app/features/jobs/data/jobs_repository.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';

final Provider<JobsRepository> jobsRepositoryProvider =
    Provider<JobsRepository>((Ref ref) {
  return JobsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

bool _isAdminRole(Ref ref) {
  final AsyncValue<String?> role = ref.watch(userRoleProvider);
  return role.maybeWhen(
    data: (String? r) => r?.trim().toLowerCase() == 'admin',
    orElse: () => false,
  );
}

/// Remaining job-post credits on `customers/{uid}.jobPostCredits` (0 if missing).
///
/// Watches auth so the stream rebinds after sign-in / sign-out.
final StreamProvider<int> jobPostCreditsProvider = StreamProvider<int>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<int>.value(0);
  }
  return ref
      .watch(firestoreProvider)
      .collection(FirebaseCollections.customers)
      .doc(user.uid)
      .snapshots()
      .map((DocumentSnapshot<Map<String, dynamic>> snap) {
    final num? raw = snap.data()?['jobPostCredits'] as num?;
    if (raw == null) {
      return 0;
    }
    return raw.floor().clamp(0, 999999);
  });
});

/// How many active jobs to fetch — bumped by 80 each time the user taps
/// "Load more" on the jobs home page, so listings beyond the old hard cap
/// of 80 are reachable instead of permanently invisible.
final StateProvider<int> activeJobsLimitProvider = StateProvider<int>((Ref ref) => 80);

final StreamProvider<List<JobListing>> activeJobsStreamProvider =
    StreamProvider<List<JobListing>>((Ref ref) {
  final int limit = ref.watch(activeJobsLimitProvider);
  return ref.watch(jobsRepositoryProvider).watchActiveJobs(limit: limit);
});

/// Admin-only pending jobs. Empty when the caller is not an admin.
final pendingJobsAdminProvider = StreamProvider<List<JobListing>>((Ref ref) {
  if (!_isAdminRole(ref)) {
    return Stream<List<JobListing>>.value(const <JobListing>[]);
  }
  return ref.watch(jobsRepositoryProvider).watchPendingJobs();
});

final jobsByStatusAdminProvider =
    StreamProvider.family<List<JobListing>, String>((Ref ref, String status) {
  if (!_isAdminRole(ref)) {
    return Stream<List<JobListing>>.value(const <JobListing>[]);
  }
  return ref.watch(jobsRepositoryProvider).watchJobsByStatus(status);
});

final StreamProvider<Set<String>> savedJobIdsProvider =
    StreamProvider<Set<String>>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<Set<String>>.value(<String>{});
  }
  return ref.watch(jobsRepositoryProvider).watchSavedJobIds(userId: user.uid);
});

final StreamProvider<List<JobListing>> savedJobsStreamProvider =
    StreamProvider<List<JobListing>>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<List<JobListing>>.value(const <JobListing>[]);
  }
  return ref.watch(jobsRepositoryProvider).watchSavedJobs(userId: user.uid);
});

final jobDetailStreamProvider = StreamProvider.family<JobListing?, String>(
  (Ref ref, String jobId) {
    return ref.watch(jobsRepositoryProvider).watchJob(jobId);
  },
);

final myPostedJobsStreamProvider = StreamProvider<List<JobListing>>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<List<JobListing>>.value(const <JobListing>[]);
  }
  return ref
      .watch(jobsRepositoryProvider)
      .watchMyPostedJobs(userId: user.uid);
});

final myJobApplicationsStreamProvider =
    StreamProvider<List<JobApplication>>((Ref ref) {
  final User? user = resolveAuthUser(ref);
  if (user == null) {
    return Stream<List<JobApplication>>.value(const <JobApplication>[]);
  }
  return ref
      .watch(jobsRepositoryProvider)
      .watchMyApplications(userId: user.uid);
});

final jobApplicationsStreamProvider =
    StreamProvider.family<List<JobApplication>, String>((Ref ref, String jobId) {
  return ref.watch(jobsRepositoryProvider).watchApplicationsForJob(jobId);
});

final jobApplicationCountProvider =
    StreamProvider.family<int, String>((Ref ref, String jobId) {
  return ref.watch(jobsRepositoryProvider).watchApplicationCountForJob(jobId);
});

final jobBookedCountProvider = StreamProvider.family<int, String>(
  (Ref ref, String jobId) {
    return ref.watch(jobsRepositoryProvider).watchBookedCountForJob(jobId);
  },
);

final hasAppliedToJobProvider = FutureProvider.family<bool, String>(
  (Ref ref, String jobId) {
    return ref.watch(jobsRepositoryProvider).hasAppliedToJob(jobId);
  },
);

/// Live application status for a job (null = not applied).
final myApplicationStatusForJobProvider =
    Provider.family<String?, String>((Ref ref, String jobId) {
  return ref.watch(myApplicationStatusByJobIdProvider)[jobId];
});

/// Whether the user already applied — synced with [myJobApplicationsStreamProvider].
final hasAppliedToJobLiveProvider = Provider.family<bool, String>((Ref ref, String jobId) {
  return ref.watch(myApplicationStatusForJobProvider(jobId)) != null;
});

/// Applicant status per job id from [myJobApplicationsStreamProvider].
final myApplicationStatusByJobIdProvider = Provider<Map<String, String>>((Ref ref) {
  final AsyncValue<List<JobApplication>> apps =
      ref.watch(myJobApplicationsStreamProvider);
  return apps.maybeWhen(
    data: (List<JobApplication> list) => <String, String>{
      for (final JobApplication a in list) a.jobId: a.status,
    },
    orElse: () => const <String, String>{},
  );
});

final isJobBookedForMeProvider = Provider.family<bool, String>((Ref ref, String jobId) {
  final Map<String, String> statuses = ref.watch(myApplicationStatusByJobIdProvider);
  return statuses[jobId] == JobApplicationStatus.booked;
});

final isJobOwnerProvider = Provider.family<bool, JobListing>((Ref ref, JobListing job) {
  final User? user = resolveAuthUser(ref);
  return user != null && user.uid == job.userId;
});

/// Search, location label, and filter state for Jobs home.
class JobsFilterState {
  const JobsFilterState({
    this.query = '',
    this.locationLabel = 'Near you',
    this.category,
    this.jobType,
    this.remoteOnly = false,
    this.sortNewest = true,
  });

  final String query;
  final String locationLabel;
  final String? category;
  final String? jobType;
  final bool remoteOnly;
  final bool sortNewest;

  JobsFilterState copyWith({
    String? query,
    String? locationLabel,
    String? category,
    String? jobType,
    bool? remoteOnly,
    bool? sortNewest,
    bool clearCategory = false,
    bool clearJobType = false,
  }) {
    return JobsFilterState(
      query: query ?? this.query,
      locationLabel: locationLabel ?? this.locationLabel,
      category: clearCategory ? null : (category ?? this.category),
      jobType: clearJobType ? null : (jobType ?? this.jobType),
      remoteOnly: remoteOnly ?? this.remoteOnly,
      sortNewest: sortNewest ?? this.sortNewest,
    );
  }
}

final StateProvider<JobsFilterState> jobsFilterProvider =
    StateProvider<JobsFilterState>((Ref ref) => const JobsFilterState());

List<JobListing> filterJobs(List<JobListing> jobs, JobsFilterState filter) {
  Iterable<JobListing> result = jobs;

  final String q = filter.query.trim().toLowerCase();
  if (q.isNotEmpty) {
    result = result.where(
      (JobListing j) =>
          j.title.toLowerCase().contains(q) ||
          j.companyName.toLowerCase().contains(q) ||
          j.category.toLowerCase().contains(q) ||
          j.location.toLowerCase().contains(q) ||
          j.description.toLowerCase().contains(q),
    );
  }

  if (filter.category != null && filter.category!.isNotEmpty) {
    result = result.where(
      (JobListing j) =>
          j.category.toLowerCase() == filter.category!.toLowerCase() ||
          j.type.toLowerCase() == filter.category!.toLowerCase(),
    );
  }

  if (filter.jobType != null && filter.jobType!.isNotEmpty) {
    result = result.where(
      (JobListing j) => j.type.toLowerCase() == filter.jobType!.toLowerCase(),
    );
  }

  if (filter.remoteOnly) {
    result = result.where((JobListing j) => j.remote);
  } else if (filter.locationLabel != 'Near you') {
    final String loc = filter.locationLabel.trim().toLowerCase();
    result = result.where(
      (JobListing j) =>
          j.remote ||
          j.location.toLowerCase().contains(loc) ||
          j.city.toLowerCase().contains(loc),
    );
  }

  final List<JobListing> list = result.toList();
  if (filter.sortNewest) {
    list.sort((JobListing a, JobListing b) => b.createdAt.compareTo(a.createdAt));
  }
  return list;
}

final Provider<List<JobListing>> filteredJobsProvider =
    Provider<List<JobListing>>((Ref ref) {
  final AsyncValue<List<JobListing>> jobs = ref.watch(activeJobsStreamProvider);
  final JobsFilterState filter = ref.watch(jobsFilterProvider);
  return jobs.when(
    data: (List<JobListing> list) => filterJobs(list, filter),
    loading: () => const <JobListing>[],
    error: (_, __) => const <JobListing>[],
  );
});

List<JobListing> trendingJobs(List<JobListing> jobs, {int limit = 8}) {
  final List<JobListing> sorted = List<JobListing>.from(jobs)
    ..sort((JobListing a, JobListing b) => b.viewCount.compareTo(a.viewCount));
  return sorted.take(limit).toList();
}

List<JobListing> urgentJobs(List<JobListing> jobs, {int limit = 8}) {
  return jobs.where((JobListing j) => j.urgent).take(limit).toList();
}

List<JobListing> latestJobs(List<JobListing> jobs, {int limit = 10}) {
  final List<JobListing> sorted = List<JobListing>.from(jobs)
    ..sort((JobListing a, JobListing b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(limit).toList();
}

List<JobListing> recommendedJobs(List<JobListing> jobs, JobsFilterState filter) {
  if (filter.category != null) {
    final List<JobListing> match = jobs
        .where(
          (JobListing j) =>
              j.category.toLowerCase() == filter.category!.toLowerCase(),
        )
        .toList();
    if (match.isNotEmpty) {
      return match.take(8).toList();
    }
  }
  return jobs.take(8).toList();
}
