import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:mnd_delivery_app/core/constants/firebase_collections.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';

class JobsRepository {
  JobsRepository({
    required FirebaseFirestore firestore,
    required FirebaseAuth auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore,
        _auth = auth,
        _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  CollectionReference<Map<String, dynamic>> get _jobs =>
      _firestore.collection(FirebaseCollections.jobs);

  CollectionReference<Map<String, dynamic>> get _applications =>
      _firestore.collection(FirebaseCollections.jobApplications);

  CollectionReference<Map<String, dynamic>> get _savedJobs =>
      _firestore.collection(FirebaseCollections.savedJobs);

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection(FirebaseCollections.jobReports);

  String? get _uid => _auth.currentUser?.uid;

  /// Public approved jobs stream (guests can browse).
  Stream<List<JobListing>> watchActiveJobs({int limit = 80}) {
    return _jobs
        .where('status', isEqualTo: JobConstants.statusActive)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapJobs);
  }

  Stream<List<JobListing>> watchPendingJobs({int limit = 50}) {
    return _jobs
        .where('status', isEqualTo: JobConstants.statusPending)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapJobs);
  }

  Stream<List<JobListing>> watchJobsByStatus(String status, {int limit = 50}) {
    return _jobs
        .where('status', isEqualTo: status)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(_mapJobs);
  }

  Stream<JobListing?> watchJob(String jobId) {
    return _jobs.doc(jobId).snapshots().map(
      (DocumentSnapshot<Map<String, dynamic>> snap) {
        if (!snap.exists || snap.data() == null) {
          return null;
        }
        return JobListing.fromFirestore(snap.id, snap.data()!);
      },
    );
  }

  Stream<Set<String>> watchSavedJobIds() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<Set<String>>.value(<String>{});
    }
    return _savedJobs
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs
              .map((QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                  (d.data()['jobId'] as String?) ?? d.id)
              .toSet(),
        );
  }

  Stream<List<JobListing>> watchSavedJobs() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<JobListing>>.value(const <JobListing>[]);
    }
    return _savedJobs.where('userId', isEqualTo: uid).snapshots().asyncMap(
      (QuerySnapshot<Map<String, dynamic>> snap) async {
        final List<JobListing> jobs = <JobListing>[];
        for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
          final String jobId =
              (doc.data()['jobId'] as String?)?.trim() ?? doc.id;
          final DocumentSnapshot<Map<String, dynamic>> jobDoc =
              await _jobs.doc(jobId).get();
          if (jobDoc.exists && jobDoc.data() != null) {
            final JobListing job =
                JobListing.fromFirestore(jobDoc.id, jobDoc.data()!);
            if (job.isActive && !job.isExpired) {
              jobs.add(job);
            }
          }
        }
        jobs.sort(
          (JobListing a, JobListing b) => b.createdAt.compareTo(a.createdAt),
        );
        return jobs;
      },
    );
  }

  Future<void> incrementViewCount(String jobId) async {
    await _jobs.doc(jobId).update(<String, dynamic>{
      'viewCount': FieldValue.increment(1),
    });
  }

  Future<String> submitJob({
    required JobListing draft,
    File? imageFile,
    File? logoFile,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('Sign in to post a job.');
    }

    try {
      final bool duplicate = await _hasRecentDuplicate(uid, draft.title);
      if (duplicate) {
        throw StateError(
          'You already posted a similar job recently. Please wait 24 hours.',
        );
      }
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') {
        rethrow;
      }
      // Pre-check skipped when rules/index not ready; create still validated server-side.
    }

    final DateTime now = DateTime.now();
    final DateTime expiresAt = now.add(JobConstants.defaultListingDuration);
    final DocumentReference<Map<String, dynamic>> ref = _jobs.doc();

    final JobListing toSave = JobListing(
      id: ref.id,
      title: draft.title,
      category: draft.category,
      type: draft.type,
      salary: draft.salary,
      location: draft.location,
      description: draft.description,
      companyName: draft.companyName,
      contactPhone: draft.contactPhone,
      whatsapp: draft.whatsapp,
      responsibilities: draft.responsibilities,
      schedule: draft.schedule,
      skills: draft.skills,
      deadline: draft.deadline,
      expiresAt: expiresAt,
      userId: uid,
      status: JobConstants.statusPending,
      verified: false,
      urgent: draft.urgent,
      remote: draft.remote,
      city: draft.city,
      imageUrl: draft.imageUrl,
      logoUrl: draft.logoUrl,
      latitude: draft.latitude,
      longitude: draft.longitude,
      createdAt: now,
      availableLaborCount: draft.availableLaborCount,
    );

    await ref.set(toSave.toCreateMap(
      userId: uid,
      status: JobConstants.statusPending,
      createdAt: now,
      expiresAt: expiresAt,
    ));

    String? imageUrl;
    String? logoUrl;
    try {
      if (imageFile != null) {
        imageUrl = await _uploadJobAsset(ref.id, imageFile, 'banner');
      }
      if (logoFile != null) {
        logoUrl = await _uploadJobAsset(ref.id, logoFile, 'logo');
      }
      if (imageUrl != null || logoUrl != null) {
        await ref.update(<String, dynamic>{
          if (imageUrl != null) 'imageUrl': imageUrl,
          if (logoUrl != null) 'logoUrl': logoUrl,
        });
      }
    } on FirebaseException {
      // Listing saved; images optional if Storage rules lag behind deploy.
    }

    return ref.id;
  }

  Future<bool> _hasRecentDuplicate(String userId, String title) async {
    final String normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final DateTime since =
        DateTime.now().subtract(JobConstants.duplicateWindow);
    final QuerySnapshot<Map<String, dynamic>> snap = await _jobs
        .where('userId', isEqualTo: userId)
        .limit(10)
        .get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final String t = (doc.data()['title'] as String?)?.trim().toLowerCase() ?? '';
      final Timestamp? created = doc.data()['createdAt'] as Timestamp?;
      if (t == normalized &&
          created != null &&
          created.toDate().isAfter(since)) {
        return true;
      }
    }
    return false;
  }

  Future<String> _uploadJobAsset(String jobId, File file, String kind) async {
    final Reference ref = _storage.ref().child('jobs/$jobId/$kind.jpg');
    await ref.putFile(file);
    return ref.getDownloadURL();
  }

  /// Jobs posted by the signed-in user (any status).
  Stream<List<JobListing>> watchMyPostedJobs({int limit = 50}) {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<JobListing>>.value(const <JobListing>[]);
    }
    return _jobs
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snap) {
          final List<JobListing> list = snap.docs
              .map(
                (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
                    JobListing.fromFirestore(d.id, d.data()),
              )
              .toList();
          list.sort(
            (JobListing a, JobListing b) => b.createdAt.compareTo(a.createdAt),
          );
          return list.take(limit).toList();
        });
  }

  Stream<List<JobApplication>> watchApplicationsForJob(String jobId) {
    return _applications
        .where('jobId', isEqualTo: jobId)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(_mapApplications);
  }

  Stream<int> watchApplicationCountForJob(String jobId) {
    return watchApplicationsForJob(jobId).map((List<JobApplication> list) {
      return list
          .where((JobApplication a) => a.status != JobApplicationStatus.rejected)
          .length;
    });
  }

  Stream<int> watchBookedCountForJob(String jobId) {
    return watchApplicationsForJob(jobId).map(
      (List<JobApplication> list) =>
          list.where((JobApplication a) => a.isBooked).length,
    );
  }

  Future<int> countBookedForJob(String jobId) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _applications
        .where('jobId', isEqualTo: jobId)
        .where('status', isEqualTo: JobApplicationStatus.booked)
        .get();
    return snap.docs.length;
  }

  Stream<List<JobApplication>> watchMyApplications() {
    final String? uid = _uid;
    if (uid == null) {
      return Stream<List<JobApplication>>.value(const <JobApplication>[]);
    }
    return _applications
        .where('applicantId', isEqualTo: uid)
        .orderBy('appliedAt', descending: true)
        .snapshots()
        .map(_mapApplications);
  }

  Future<bool> hasAppliedToJob(String jobId) async {
    final String? uid = _uid;
    if (uid == null) {
      return false;
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await _applications
        .where('jobId', isEqualTo: jobId)
        .where('applicantId', isEqualTo: uid)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<void> applyToJob({
    required String jobId,
    required String applicantName,
    required String applicantPhone,
    String? bio,
    File? cvFile,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('Sign in to apply.');
    }

    if (await hasAppliedToJob(jobId)) {
      throw StateError('You already applied for this job.');
    }

    final DocumentSnapshot<Map<String, dynamic>> jobSnap =
        await _jobs.doc(jobId).get();
    if (!jobSnap.exists || jobSnap.data() == null) {
      throw StateError('Job not found.');
    }
    final JobListing job = JobListing.fromFirestore(jobSnap.id, jobSnap.data()!);
    if (job.userId == uid) {
      throw StateError('You cannot apply to your own job post.');
    }

    String? cvUrl;
    if (cvFile != null) {
      final Reference ref =
          _storage.ref().child('job_applications/$uid/${jobId}_cv.pdf');
      await ref.putFile(cvFile);
      cvUrl = await ref.getDownloadURL();
    }

    await _applications.add(<String, dynamic>{
      'jobId': jobId,
      'applicantId': uid,
      'applicantName': applicantName.trim(),
      'applicantPhone': applicantPhone.trim(),
      if (bio != null && bio.trim().isNotEmpty) 'bio': bio.trim(),
      if (cvUrl != null) 'cvUrl': cvUrl,
      'jobTitle': job.title,
      'companyName': job.companyName,
      'status': JobApplicationStatus.submitted,
      'appliedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    if (!JobApplicationStatus.all.contains(status)) {
      throw StateError('Invalid application status.');
    }

    final DocumentSnapshot<Map<String, dynamic>> appSnap =
        await _applications.doc(applicationId).get();
    if (!appSnap.exists || appSnap.data() == null) {
      throw StateError('Application not found.');
    }
    final Map<String, dynamic> appData = appSnap.data()!;
    final String jobId = (appData['jobId'] as String?)?.trim() ?? '';
    final String currentStatus =
        (appData['status'] as String?)?.trim() ?? JobApplicationStatus.submitted;

    if (status == JobApplicationStatus.booked &&
        currentStatus != JobApplicationStatus.booked) {
      if (jobId.isEmpty) {
        throw StateError('Invalid job on application.');
      }
      final DocumentSnapshot<Map<String, dynamic>> jobSnap =
          await _jobs.doc(jobId).get();
      if (!jobSnap.exists || jobSnap.data() == null) {
        throw StateError('Job not found.');
      }
      final int limit = JobListing.parseLaborCount(
        jobSnap.data()!['availableLaborCount'],
      );
      final int booked = await countBookedForJob(jobId);
      if (booked >= limit) {
        throw StateError(
          'All $limit worker slot${limit == 1 ? '' : 's'} are already booked.',
        );
      }
    }

    final Map<String, dynamic> patch = <String, dynamic>{
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (status == JobApplicationStatus.booked) {
      patch['bookedAt'] = FieldValue.serverTimestamp();
    }
    await _applications.doc(applicationId).update(patch);
  }

  List<JobApplication> _mapApplications(
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              JobApplication.fromFirestore(d.id, d.data()),
        )
        .toList();
  }

  Future<void> toggleSaveJob(String jobId) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('Sign in to save jobs.');
    }
    final String docId = '${uid}_$jobId';
    final DocumentReference<Map<String, dynamic>> ref = _savedJobs.doc(docId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    if (snap.exists) {
      await ref.delete();
    } else {
      await ref.set(<String, dynamic>{
        'userId': uid,
        'jobId': jobId,
        'savedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> reportJob({
    required String jobId,
    required String reason,
  }) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('Sign in to report a job.');
    }
    await _reports.add(<String, dynamic>{
      'jobId': jobId,
      'reporterId': uid,
      'reason': reason.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _jobs.doc(jobId).update(<String, dynamic>{
      'reportedCount': FieldValue.increment(1),
    });
  }

  // --- Admin ---

  Future<void> approveJob(String jobId) async {
    await _jobs.doc(jobId).update(<String, dynamic>{
      'status': JobConstants.statusActive,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectJob(String jobId, {String? note}) async {
    await _jobs.doc(jobId).update(<String, dynamic>{
      'status': JobConstants.statusRejected,
      if (note != null) 'rejectionNote': note,
    });
  }

  Future<void> deleteJob(String jobId) async {
    await _jobs.doc(jobId).delete();
  }

  Future<void> setJobVerified(String jobId, bool verified) async {
    await _jobs.doc(jobId).update(<String, dynamic>{'verified': verified});
  }

  Future<void> blockJobPoster(String userId) async {
    await _firestore.collection(FirebaseCollections.customers).doc(userId).set(
      <String, dynamic>{
        'jobsBlocked': true,
        'jobsBlockedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  List<JobListing> _mapJobs(QuerySnapshot<Map<String, dynamic>> snap) {
    return snap.docs
        .map(
          (QueryDocumentSnapshot<Map<String, dynamic>> d) =>
              JobListing.fromFirestore(d.id, d.data()),
        )
        .where((JobListing j) => !j.isExpired)
        .toList();
  }
}
