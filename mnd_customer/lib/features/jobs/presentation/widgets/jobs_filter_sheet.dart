import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';

void showJobsFilterSheet(BuildContext context, WidgetRef ref) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.paddingOf(ctx).bottom + 24,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          'Filter jobs',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 16),
        Text('Job type', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: JobConstants.jobTypes.map((String t) {
            final bool sel = local.jobType == t;
            return FilterChip(
              label: Text(t),
              selected: sel,
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
        const SizedBox(height: 12),
        SwitchListTile(
          title: const Text('Remote only'),
          value: local.remoteOnly,
          onChanged: (bool v) => setState(() => local = local.copyWith(remoteOnly: v)),
        ),
        SwitchListTile(
          title: const Text('Newest first'),
          value: local.sortNewest,
          onChanged: (bool v) => setState(() => local = local.copyWith(sortNewest: v)),
        ),
        const SizedBox(height: 16),
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
