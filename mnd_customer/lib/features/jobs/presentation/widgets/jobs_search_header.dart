import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/jobs_filter_sheet.dart';

/// Search, hints, and location/filter controls on a white panel.
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
    final JobsFilterState filter = ref.watch(jobsFilterProvider);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          TextField(
            controller: _controller,
            onChanged: (String v) {
              ref.read(jobsFilterProvider.notifier).state =
                  filter.copyWith(query: v);
            },
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              hintText: 'Search title, company, skill…',
              hintStyle: GoogleFonts.plusJakartaSans(
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
              contentPadding: const EdgeInsets.symmetric(vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: JobConstants.searchHints.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (BuildContext context, int index) {
                final String hint = JobConstants.searchHints[index];
                return ActionChip(
                  label: Text(
                    hint,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
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
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimary,
                    backgroundColor: Colors.white,
                    side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Material(
                color: AppColors.brandPrimary,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: () => showJobsFilterSheet(context, ref),
                  borderRadius: BorderRadius.circular(12),
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
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600),
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
