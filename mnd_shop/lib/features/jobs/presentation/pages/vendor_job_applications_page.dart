import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/jobs/data/vendor_jobs_repository.dart';
import 'package:mnd_shop/features/jobs/domain/job_application.dart';
import 'package:mnd_shop/features/jobs/domain/job_listing.dart';
import 'package:mnd_shop/features/jobs/presentation/providers/vendor_jobs_providers.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';
import 'package:url_launcher/url_launcher.dart';

class VendorJobApplicationsPage extends ConsumerWidget {
  const VendorJobApplicationsPage({required this.jobId, super.key});

  final String jobId;

  String _vTxt(BuildContext context, {required String en, required String si}) {
    final String languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'si') {
      return si;
    }
    if (languageCode == 'ta') {
      return vendorTamilFallback(en);
    }
    return en;
  }

  Future<void> _setStatus(
    WidgetRef ref,
    BuildContext context,
    String applicationId,
    String status,
    String message,
  ) async {
    try {
      await ref.read(vendorJobsRepositoryProvider).updateApplicationStatus(
            applicationId: applicationId,
            status: status,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not update application. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _call(String phone) async {
    final String cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) {
      return;
    }
    final Uri uri = Uri(scheme: 'tel', path: cleaned);
    await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<JobListing?> jobAsync =
        ref.watch(vendorJobDetailStreamProvider(jobId));
    final AsyncValue<List<JobApplication>> appsAsync =
        ref.watch(vendorJobApplicationsStreamProvider(jobId));

    return Scaffold(
      backgroundColor: VendorProductsTheme.canvas(context),
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Applicants', si: 'අයදුම්කරුවන්')),
      ),
      body: VendorResponsiveContent(
        child: jobAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(
            child: Text(
              userFacingError(
                e,
                fallback: 'Could not load job. Please try again.',
              ),
            ),
          ),
          data: (JobListing? job) {
            if (job == null) {
              return Center(
                child: Text(
                  _vTxt(context, en: 'Job not found', si: 'රැකියාව හමු නොවීය'),
                ),
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    job.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
                  child: Text(
                    _vTxt(
                      context,
                      en:
                          'Book up to ${job.availableLaborCount} worker${job.availableLaborCount == 1 ? '' : 's'}.',
                      si:
                          'කම්කරුවන් ${job.availableLaborCount} දෙනෙකු දක්වා book කරන්න.',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
                Expanded(
                  child: appsAsync.when(
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (Object e, _) => Center(
                      child: Text(
                        userFacingError(
                          e,
                          fallback:
                              'Could not load applications. Please try again.',
                        ),
                      ),
                    ),
                    data: (List<JobApplication> apps) {
                      if (apps.isEmpty) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              _vTxt(
                                context,
                                en:
                                    'No applications yet.\nShare your job to get applicants.',
                                si:
                                    'තවම අයදුම් නැත.\nඅයදුම්කරුවන් ලබා ගැනීමට රැකියාව බෙදා ගන්න.',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      }
                      final List<JobApplication> booked = apps
                          .where((JobApplication a) => a.isBooked)
                          .toList();
                      final List<JobApplication> rest = apps
                          .where((JobApplication a) => !a.isBooked)
                          .toList();
                      final bool canBookMore =
                          job.hasBookingSlotsOpen(booked.length);

                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              job.bookingSlotsLabel(booked.length) +
                                  (canBookMore
                                      ? ''
                                      : ' · ${_vTxt(context, en: 'Full', si: 'පිරී ඇත')}'),
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (booked.isNotEmpty) ...<Widget>[
                            Text(
                              '${_vTxt(context, en: 'Booked', si: 'Booked')} (${booked.length})',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...booked.map(
                              (JobApplication a) => _ApplicantTile(
                                application: a,
                                onCall: () => _call(a.applicantPhone),
                              ),
                            ),
                            const SizedBox(height: 16),
                          ],
                          if (rest.isNotEmpty) ...<Widget>[
                            Text(
                              _vTxt(
                                context,
                                en: 'Applications',
                                si: 'අයදුම්',
                              ),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 8),
                            ...rest.map(
                              (JobApplication a) => _ApplicantTile(
                                application: a,
                                onCall: () => _call(a.applicantPhone),
                                actions: a.status ==
                                        JobApplicationStatus.rejected
                                    ? null
                                    : <Widget>[
                                        TextButton(
                                          onPressed: () => _setStatus(
                                            ref,
                                            context,
                                            a.id,
                                            JobApplicationStatus.shortlisted,
                                            _vTxt(
                                              context,
                                              en: 'Shortlisted',
                                              si: 'Shortlisted',
                                            ),
                                          ),
                                          child: Text(
                                            _vTxt(
                                              context,
                                              en: 'Shortlist',
                                              si: 'Shortlist',
                                            ),
                                          ),
                                        ),
                                        if (canBookMore)
                                          TextButton(
                                            onPressed: () => _setStatus(
                                              ref,
                                              context,
                                              a.id,
                                              JobApplicationStatus.booked,
                                              _vTxt(
                                                context,
                                                en: 'Worker booked',
                                                si: 'Booked',
                                              ),
                                            ),
                                            child: Text(
                                              _vTxt(
                                                context,
                                                en: 'Book',
                                                si: 'Book',
                                              ),
                                            ),
                                          ),
                                        TextButton(
                                          onPressed: () => _setStatus(
                                            ref,
                                            context,
                                            a.id,
                                            JobApplicationStatus.rejected,
                                            _vTxt(
                                              context,
                                              en: 'Rejected',
                                              si: 'ප්‍රතික්ෂේප',
                                            ),
                                          ),
                                          child: Text(
                                            _vTxt(
                                              context,
                                              en: 'Reject',
                                              si: 'ප්‍රතික්ෂේප',
                                            ),
                                          ),
                                        ),
                                      ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ApplicantTile extends StatelessWidget {
  const _ApplicantTile({
    required this.application,
    required this.onCall,
    this.actions,
  });

  final JobApplication application;
  final VoidCallback onCall;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    application.applicantName.isEmpty
                        ? 'Applicant'
                        : application.applicantName,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    application.statusLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (application.applicantPhone.isNotEmpty)
              InkWell(
                onTap: onCall,
                child: Text(
                  application.applicantPhone,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            if ((application.bio ?? '').isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                application.bio!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            if (actions != null && actions!.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Wrap(spacing: 4, children: actions!),
            ],
          ],
        ),
      ),
    );
  }
}
