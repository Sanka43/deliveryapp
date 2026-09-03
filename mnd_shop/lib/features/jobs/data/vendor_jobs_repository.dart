import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/firebase_collections.dart';
import 'package:mnd_shop/features/jobs/domain/job_application.dart';
import 'package:mnd_shop/features/jobs/domain/job_constants.dart';
import 'package:mnd_shop/features/jobs/domain/job_listing.dart';

final Provider<VendorJobsRepository> vendorJobsRepositoryProvider =
    Provider<VendorJobsRepository>((Ref ref) {
  return VendorJobsRepository(
    firestore: ref.watch(firestoreProvider),
    auth: ref.watch(firebaseAuthProvider),
  );
});

class VendorJobsRepository {
  VendorJobsRepository({
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

  String? get _uid => _auth.currentUser?.uid;

  /// Jobs posted by the signed-in vendor (any status).
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

    await ref.set(
      toSave.toCreateMap(
        userId: uid,
        status: JobConstants.statusPending,
        createdAt: now,
        expiresAt: expiresAt,
      ),
    );

    try {
      String? imageUrl;
      String? logoUrl;
      if (imageFile != null) {
        imageUrl = await _uploadJobAsset(ref.id, imageFile, 'banner');
      }
      if (logoFile != null) {
        logoUrl = await _uploadJobAsset(ref.id, logoFile, 'logo');
      }
      if (imageUrl != null || logoUrl != null) {
        await ref.update(<String, dynamic>{
          'imageUrl': ?imageUrl,
          'logoUrl': ?logoUrl,
        });
      }
    } on FirebaseException {
      // Listing saved; images optional if Storage rules lag behind deploy.
    }

    return ref.id;
  }

  Future<void> deletePendingJob(String jobId) async {
    final String? uid = _uid;
    if (uid == null) {
      throw StateError('Sign in required.');
    }
    final DocumentSnapshot<Map<String, dynamic>> snap =
        await _jobs.doc(jobId).get();
    if (!snap.exists || snap.data() == null) {
      throw StateError('Job not found.');
    }
    final JobListing job = JobListing.fromFirestore(snap.id, snap.data()!);
    if (job.userId != uid) {
      throw StateError('You can only delete your own job posts.');
    }
    if (job.status != JobConstants.statusPending) {
      throw StateError('Only pending jobs can be deleted.');
    }
    await _jobs.doc(jobId).delete();
  }

  Future<void> updateApplicationStatus({
    required String applicationId,
    required String status,
  }) async {
    if (!JobApplicationStatus.all.contains(status)) {
      throw StateError('Invalid application status.');
    }

    final String? uid = _uid;
    if (uid == null) {
      throw StateError('Sign in to update applications.');
    }

    final DocumentReference<Map<String, dynamic>> appRef =
        _applications.doc(applicationId);

    await _firestore.runTransaction((Transaction tx) async {
      final DocumentSnapshot<Map<String, dynamic>> appSnap = await tx.get(appRef);
      if (!appSnap.exists || appSnap.data() == null) {
        throw StateError('Application not found.');
      }
      final Map<String, dynamic> appData = appSnap.data()!;
      final String jobId = (appData['jobId'] as String?)?.trim() ?? '';
      final String currentStatus = (appData['status'] as String?)?.trim() ??
          JobApplicationStatus.submitted;

      if (status == currentStatus) {
        return;
      }

      final Map<String, dynamic> patch = <String, dynamic>{
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (status == JobApplicationStatus.booked &&
          currentStatus != JobApplicationStatus.booked) {
        if (jobId.isEmpty) {
          throw StateError('Invalid job on application.');
        }
        final DocumentReference<Map<String, dynamic>> jobRef = _jobs.doc(jobId);
        final DocumentSnapshot<Map<String, dynamic>> jobSnap = await tx.get(jobRef);
        if (!jobSnap.exists || jobSnap.data() == null) {
          throw StateError('Job not found.');
        }
        final String ownerId =
            (jobSnap.data()!['userId'] as String?)?.trim() ?? '';
        if (ownerId != uid) {
          throw StateError('Only the job poster can book applicants.');
        }
        final int limit = JobListing.parseLaborCount(
          jobSnap.data()!['availableLaborCount'],
        );
        final int booked =
            (jobSnap.data()!['bookedLaborCount'] as num?)?.toInt() ?? 0;
        if (booked >= limit) {
          throw StateError(
            'All $limit worker slot${limit == 1 ? '' : 's'} are already booked.',
          );
        }
        patch['bookedAt'] = FieldValue.serverTimestamp();
        tx.update(jobRef, <String, dynamic>{
          'bookedLaborCount': booked + 1,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (currentStatus == JobApplicationStatus.booked &&
          status != JobApplicationStatus.booked &&
          jobId.isNotEmpty) {
        final DocumentReference<Map<String, dynamic>> jobRef = _jobs.doc(jobId);
        final DocumentSnapshot<Map<String, dynamic>> jobSnap = await tx.get(jobRef);
        if (jobSnap.exists && jobSnap.data() != null) {
          final int booked =
              (jobSnap.data()!['bookedLaborCount'] as num?)?.toInt() ?? 0;
          tx.update(jobRef, <String, dynamic>{
            'bookedLaborCount': booked > 0 ? booked - 1 : 0,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      tx.update(appRef, patch);
    });
  }

  Future<bool> _hasRecentDuplicate(String userId, String title) async {
    final String normalized = title.trim().toLowerCase();
    if (normalized.isEmpty) {
      return false;
    }
    final DateTime since =
        DateTime.now().subtract(JobConstants.duplicateWindow);
    final QuerySnapshot<Map<String, dynamic>> snap =
        await _jobs.where('userId', isEqualTo: userId).limit(10).get();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      final String t =
          (doc.data()['title'] as String?)?.trim().toLowerCase() ?? '';
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
}
