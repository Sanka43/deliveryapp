import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/jobs/data/vendor_jobs_repository.dart';
import 'package:mnd_shop/features/jobs/domain/job_constants.dart';
import 'package:mnd_shop/features/jobs/domain/job_listing.dart';
import 'package:mnd_shop/features/jobs/presentation/pages/job_form_page.dart';
import 'package:mnd_shop/features/jobs/presentation/pages/vendor_job_applications_page.dart';
import 'package:mnd_shop/features/jobs/presentation/providers/vendor_jobs_providers.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';

class VendorJobsPage extends ConsumerWidget {
  const VendorJobsPage({super.key});

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

  Color _statusColor(String status) {
    switch (status) {
      case JobConstants.statusActive:
        return const Color(0xFF15803D);
      case JobConstants.statusRejected:
        return const Color(0xFFB91C1C);
      case JobConstants.statusExpired:
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFFB45309);
    }
  }

  String _statusLabel(BuildContext context, JobListing job) {
    if (job.isExpired && job.status != JobConstants.statusRejected) {
      return _vTxt(context, en: 'Expired', si: 'කල් ඉකුත්');
    }
    switch (job.status) {
      case JobConstants.statusActive:
        return _vTxt(context, en: 'Active', si: 'සක්‍රිය');
      case JobConstants.statusRejected:
        return _vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේප');
      case JobConstants.statusExpired:
        return _vTxt(context, en: 'Expired', si: 'කල් ඉකුත්');
      default:
        return _vTxt(context, en: 'Pending approval', si: 'අනුමැතිය බලාපොරොත්තු');
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    JobListing job,
  ) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: Text(_vTxt(ctx, en: 'Delete job?', si: 'රැකියාව මකන්නද?')),
        content: Text(
          _vTxt(
            ctx,
            en: 'Only pending jobs can be deleted.',
            si: 'රැඳී ඇති රැකියා පමණක් මකන්න පුළුවන්.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(_vTxt(ctx, en: 'Cancel', si: 'අවලංගු')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(_vTxt(ctx, en: 'Delete', si: 'මකන්න')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) {
      return;
    }
    try {
      await ref.read(vendorJobsRepositoryProvider).deletePendingJob(job.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _vTxt(context, en: 'Job deleted', si: 'රැකියාව මකන ලදී'),
            ),
          ),
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not delete job. Please try again.',
              ),
            ),
          ),
        );
      }
    }
  }

  void _openJob(BuildContext context, JobListing job) {
    if (job.status == JobConstants.statusActive) {
      Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => VendorJobApplicationsPage(jobId: job.id),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vTxt(
              context,
              en: job.status == JobConstants.statusPending
                  ? 'Waiting for admin approval before applicants appear.'
                  : 'This listing is not active.',
              si: job.status == JobConstants.statusPending
                  ? 'අයදුම්කරුවන්ට පෙනෙන්නට පෙර admin අනුමැතිය අවශ්‍යයි.'
                  : 'මෙම ලැයිස්තුව සක්‍රිය නොවේ.',
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<List<JobListing>> jobsAsync =
        ref.watch(vendorMyJobsStreamProvider);

    return Scaffold(
      backgroundColor: VendorProductsTheme.canvas(context),
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Jobs', si: 'රැකියා')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute<void>(
              builder: (_) => const JobFormPage(),
            ),
          );
        },
        icon: const Icon(Icons.post_add_rounded),
        label: Text(_vTxt(context, en: 'Post a job', si: 'රැකියාවක් පළ කරන්න')),
      ),
      body: VendorResponsiveContent(
        child: jobsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (Object e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                '${_vTxt(context, en: 'Could not load jobs', si: 'රැකියා load කළ නොහැක')}\n${userFacingError(e, fallback: 'Please check your connection and try again.')}',
                textAlign: TextAlign.center,
              ),
            ),
          ),
          data: (List<JobListing> jobs) {
            if (jobs.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _vTxt(
                      context,
                      en:
                          'No job posts yet. Add one — it needs admin approval before customers see it.',
                      si:
                          'තවම රැකියා නැත. එකක් එක් කරන්න — customer ට පෙනෙන්නට admin අනුමැතිය අවශ්‍යයි.',
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: jobs.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (BuildContext context, int index) {
                final JobListing job = jobs[index];
                final Color statusColor = _statusColor(
                  job.isExpired && job.status != JobConstants.statusRejected
                      ? JobConstants.statusExpired
                      : job.status,
                );
                final AsyncValue<int> countAsync =
                    ref.watch(vendorJobApplicationCountProvider(job.id));
                final AsyncValue<int> bookedAsync =
                    ref.watch(vendorJobBookedCountProvider(job.id));

                return Material(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(14),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: () => _openJob(context, job),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Expanded(
                                child: Text(
                                  job.title,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                              if (job.status == JobConstants.statusPending)
                                IconButton(
                                  tooltip: _vTxt(
                                    context,
                                    en: 'Delete',
                                    si: 'මකන්න',
                                  ),
                                  onPressed: () =>
                                      _confirmDelete(context, ref, job),
                                  icon: const Icon(Icons.delete_outline),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${job.category} · ${job.type}',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (job.salary.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 2),
                            Text(
                              job.salary,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Row(
                            children: <Widget>[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  _statusLabel(context, job),
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (job.status == JobConstants.statusActive) ...<
                                  Widget>[
                                const SizedBox(width: 10),
                                Text(
                                  '${countAsync.valueOrNull ?? 0} ${_vTxt(context, en: 'applicants', si: 'අයදුම්')}'
                                  ' · ${bookedAsync.valueOrNull ?? 0}/${job.availableLaborCount} '
                                  '${_vTxt(context, en: 'booked', si: 'booked')}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
