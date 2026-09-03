import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_application_card.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_flow_widgets.dart';

class MyJobApplicationsPage extends ConsumerStatefulWidget {
  const MyJobApplicationsPage({super.key});

  @override
  ConsumerState<MyJobApplicationsPage> createState() =>
      _MyJobApplicationsPageState();
}

class _MyJobApplicationsPageState extends ConsumerState<MyJobApplicationsPage> {
  Future<void> _refresh() async {
    ref.invalidate(myJobApplicationsStreamProvider);
    await ref.read(myJobApplicationsStreamProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final AsyncValue<List<JobApplication>> apps =
        ref.watch(myJobApplicationsStreamProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'My applications'),
      body: RefreshIndicator(
        onRefresh: _refresh,
        color: AppColors.brandPrimary,
        child: JobsAsyncBody<List<JobApplication>>(
          async: apps,
          onRetry: _refresh,
          errorMessage: 'Could not load applications',
          data: (List<JobApplication> list) {
            if (list.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: <Widget>[
                  SizedBox(
                    height: MediaQuery.sizeOf(context).height * 0.45,
                    child: JobsEmptyState(
                      message:
                          'You have not applied to any jobs yet.\nBrowse jobs to find work.',
                      actionLabel: 'Browse jobs',
                      onAction: () => context.go(AppRoutes.customerJobs),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(AppSpacing.md),
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: AppSpacing.sm),
              itemBuilder: (_, int i) {
                final JobApplication app = list[i];
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(
                      AppColors.cardRadiusMd,
                    ),
                    onTap: () => context.push(
                      '${AppRoutes.customerJobs}/${app.jobId}',
                    ),
                    child: JobApplicationCard(
                      application: app,
                      showEmployerActions: false,
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
