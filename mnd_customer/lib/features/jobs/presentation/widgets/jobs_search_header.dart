import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_filter_sheet.dart';

/// Search, hints, and location/filter controls on a premium card.
class JobsSearchHeader extends ConsumerStatefulWidget {
  const JobsSearchHeader({super.key});

  @override
  ConsumerState<JobsSearchHeader> createState() => _JobsSearchHeaderState();
}

class _JobsSearchHeaderState extends ConsumerState<JobsSearchHeader> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: ref.read(jobsFilterProvider).query);
    _controller.addListener(_onTextChanged);
  }

  void _onTextChanged() => setState(() {});

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final JobsFilterState filter = ref.watch(jobsFilterProvider);

    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            onChanged: (String v) {
              ref.read(jobsFilterProvider.notifier).state =
                  filter.copyWith(query: v);
            },
            style: textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search title, company, skill…',
              hintStyle: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: AppColors.brandPrimary,
              ),
              suffixIcon: _controller.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: () {
                        _controller.clear();
                        ref.read(jobsFilterProvider.notifier).state =
                            filter.copyWith(query: '');
                      },
                    )
                  : null,
              filled: true,
              fillColor: AppColors.homeMutedFill,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 32,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: JobConstants.searchHints.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String hint = JobConstants.searchHints[index];
                return ActionChip(
                  label: Text(
                    hint,
                    style: textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: AppColors.homeMutedFill,
                  side: BorderSide.none,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    _controller.text = hint;
                    ref.read(jobsFilterProvider.notifier).state =
                        filter.copyWith(query: hint);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickLocation(context),
                  icon: const Icon(Icons.place_outlined, size: 18),
                  label: Text(
                    filter.locationLabel,
                    overflow: TextOverflow.ellipsis,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: AppColors.homeMutedFill,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppColors.buttonRadius),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                child: InkWell(
                  onTap: () => showJobsFilterSheet(context, ref),
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                  child: const SizedBox(
                    width: 48,
                    height: 48,
                    child: Icon(Icons.tune_rounded, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickLocation(BuildContext context) async {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final List<String> options = <String>[
      'Near you',
      'Colombo',
      'Kandy',
      'Galle',
      'Jaffna',
      'Remote only',
    ];
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: options
              .map(
                (String o) => ListTile(
                  title: Text(
                    o,
                    style: textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () => Navigator.pop(ctx, o),
                ),
              )
              .toList(),
        ),
      ),
    );
    if (picked != null) {
      ref.read(jobsFilterProvider.notifier).state = ref
          .read(jobsFilterProvider)
          .copyWith(
            locationLabel: picked,
            remoteOnly: picked == 'Remote only',
          );
    }
  }
}
