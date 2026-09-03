import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

void showJobsFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.sm,
          bottom: MediaQuery.paddingOf(ctx).bottom + AppSpacing.lg,
        ),
        child: _JobsFilterSheetBody(parentRef: ref),
      );
    },
  );
}

class _JobsFilterSheetBody extends ConsumerStatefulWidget {
  const _JobsFilterSheetBody({required this.parentRef});

  final WidgetRef parentRef;

  @override
  ConsumerState<_JobsFilterSheetBody> createState() =>
      _JobsFilterSheetBodyState();
}

class _JobsFilterSheetBodyState extends ConsumerState<_JobsFilterSheetBody> {
  late JobsFilterState local;

  @override
  void initState() {
    super.initState();
    local = widget.parentRef.read(jobsFilterProvider);
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Filter jobs',
          style: textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(
          'Job type',
          style: textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: JobConstants.jobTypes.map((String t) {
            final bool sel = local.jobType == t;
            return FilterChip(
              label: Text(t),
              selected: sel,
              showCheckmark: false,
              backgroundColor: AppColors.homeMutedFill,
              selectedColor: AppColors.brandPrimary,
              labelStyle: textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : AppColors.textPrimary,
              ),
              side: BorderSide.none,
              onSelected: (_) {
                setState(() {
                  local = sel
                      ? local.copyWith(clearJobType: true)
                      : local.copyWith(jobType: t);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: AppSpacing.sm),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Remote only',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          value: local.remoteOnly,
          activeThumbColor: AppColors.brandPrimary,
          onChanged: (bool v) =>
              setState(() => local = local.copyWith(remoteOnly: v)),
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(
            'Newest first',
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
          value: local.sortNewest,
          activeThumbColor: AppColors.brandPrimary,
          onChanged: (bool v) =>
              setState(() => local = local.copyWith(sortNewest: v)),
        ),
        const SizedBox(height: AppSpacing.md),
        FilledButton(
          onPressed: () {
            widget.parentRef.read(jobsFilterProvider.notifier).state = local;
            Navigator.pop(context);
          },
          child: const Text('Apply filters'),
        ),
        TextButton(
          onPressed: () {
            widget.parentRef.read(jobsFilterProvider.notifier).state =
                const JobsFilterState();
            Navigator.pop(context);
          },
          child: const Text('Clear all'),
        ),
      ],
    );
  }
}
