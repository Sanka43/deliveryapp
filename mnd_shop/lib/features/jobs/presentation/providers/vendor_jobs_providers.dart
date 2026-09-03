import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/shop_auth_state_provider.dart';
import 'package:mnd_shop/features/jobs/data/vendor_jobs_repository.dart';
import 'package:mnd_shop/features/jobs/domain/job_application.dart';
import 'package:mnd_shop/features/jobs/domain/job_listing.dart';

final StreamProvider<List<JobListing>> vendorMyJobsStreamProvider =
    StreamProvider<List<JobListing>>((Ref ref) {
  final User? user = ref.watch(shopAuthStateProvider).valueOrNull;
  if (user == null) {
    return Stream<List<JobListing>>.value(const <JobListing>[]);
  }
  return ref.watch(vendorJobsRepositoryProvider).watchMyPostedJobs();
});

final StreamProviderFamily<JobListing?, String> vendorJobDetailStreamProvider =
    StreamProvider.family<JobListing?, String>((Ref ref, String jobId) {
  return ref.watch(vendorJobsRepositoryProvider).watchJob(jobId);
});

final StreamProviderFamily<List<JobApplication>, String>
    vendorJobApplicationsStreamProvider =
    StreamProvider.family<List<JobApplication>, String>((Ref ref, String jobId) {
  return ref.watch(vendorJobsRepositoryProvider).watchApplicationsForJob(jobId);
});

final StreamProviderFamily<int, String> vendorJobApplicationCountProvider =
    StreamProvider.family<int, String>((Ref ref, String jobId) {
  return ref
      .watch(vendorJobsRepositoryProvider)
      .watchApplicationCountForJob(jobId);
});

final StreamProviderFamily<int, String> vendorJobBookedCountProvider =
    StreamProvider.family<int, String>((Ref ref, String jobId) {
  return ref.watch(vendorJobsRepositoryProvider).watchBookedCountForJob(jobId);
});
