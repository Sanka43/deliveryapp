import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/utils/lkr_format.dart';
import 'package:mnd_rider/core/utils/user_facing_error.dart';
import 'package:mnd_rider/core/widgets/rider_error_state.dart';
import 'package:mnd_rider/core/widgets/rider_large_card.dart';
import 'package:mnd_rider/core/widgets/rider_skeleton.dart';
import 'package:mnd_rider/core/widgets/rider_stat_tile.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';
import 'package:mnd_rider/features/reports/domain/rider_report_data.dart';
import 'package:mnd_rider/features/reports/presentation/providers/rider_report_provider.dart';

class RiderReportPage extends ConsumerStatefulWidget {
  const RiderReportPage({super.key});

  @override
  ConsumerState<RiderReportPage> createState() => _RiderReportPageState();
}

class _RiderReportPageState extends ConsumerState<RiderReportPage> {
  Future<void> _pickCustomRange() async {
    final DateTime now = DateTime.now();
    final RiderReportRange current = ref.read(riderReportRangeProvider);
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.end.isAfter(now) ? now : current.end,
      ),
    );
    if (picked == null) {
      return;
    }
    final DateTime start = DateTime(
      picked.start.year,
      picked.start.month,
      picked.start.day,
    );
    final DateTime end = DateTime(
      picked.end.year,
      picked.end.month,
      picked.end.day,
      23,
      59,
      59,
      999,
    );
    ref.read(riderReportRangeProvider.notifier).state = RiderReportRange(
      preset: RiderReportPreset.custom,
      start: start,
      end: end,
    );
  }

  void _openPreview(RiderReportData data) {
    final RiderProfile? profile =
        ref.read(riderProfileStreamProvider).valueOrNull;
    context.push(
      RoutePaths.reportPreview,
      extra: RiderReportPreviewArgs(
        data: data,
        riderName: profile?.fullName ?? '',
        riderPhone: profile?.phone ?? '',
        vehicleNumber: profile?.vehicleNumber ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final RiderReportRange range = ref.watch(riderReportRangeProvider);
    final AsyncValue<RiderReportData> reportAsync =
        ref.watch(riderReportDataProvider(range));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('Report')),
      body: RefreshIndicator(
        color: AppColors.primaryBlue,
        onRefresh: () async {
          ref.invalidate(riderReportDataProvider(range));
        },
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            AppSpacing.screenPadding,
            8,
            AppSpacing.screenPadding,
            24,
          ),
          children: <Widget>[
            _PresetSwitcher(
              value: range.preset,
              onChanged: (RiderReportPreset preset) {
                if (preset == RiderReportPreset.custom) {
                  _pickCustomRange();
                  return;
                }
                ref.read(riderReportRangeProvider.notifier).state =
                    RiderReportRange.forPreset(preset);
              },
            ),
            const SizedBox(height: AppSpacing.sm),
            _RangeLabel(range: range, onTapCustom: _pickCustomRange),
            const SizedBox(height: AppSpacing.md),
            reportAsync.when(
              loading: () => const RiderSkeletonList(
                count: 4,
                padding: EdgeInsets.zero,
              ),
              error: (Object e, _) => RiderErrorState(
                message: userFacingError(
                  e,
                  fallback: 'Could not load this report.',
                ),
                onRetry: () => ref.invalidate(riderReportDataProvider(range)),
              ),
              data: (RiderReportData data) => _ReportPreview(data: data),
            ),
            const SizedBox(height: AppSpacing.lg),
            reportAsync.maybeWhen(
              data: (RiderReportData data) => SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: data.isEmpty ? null : () => _openPreview(data),
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: Text(
                    data.isEmpty ? 'Nothing to export' : 'Preview & export PDF',
                  ),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppSpacing.buttonRadius,
                      ),
                    ),
                  ),
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _PresetSwitcher extends StatelessWidget {
  const _PresetSwitcher({required this.value, required this.onChanged});

  final RiderReportPreset value;
  final ValueChanged<RiderReportPreset> onChanged;

  String _label(RiderReportPreset p) {
    switch (p) {
      case RiderReportPreset.today:
        return 'Today';
      case RiderReportPreset.thisWeek:
        return 'Week';
      case RiderReportPreset.thisMonth:
        return 'Month';
      case RiderReportPreset.custom:
        return 'Custom';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: <Widget>[
            for (final RiderReportPreset p in RiderReportPreset.values)
              Expanded(
                child: _PresetChip(
                  label: _label(p),
                  selected: value == p,
                  onTap: () => onChanged(p),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: selected ? AppColors.primaryBlue : Colors.transparent,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius - 2),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius - 2),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _RangeLabel extends StatelessWidget {
  const _RangeLabel({required this.range, required this.onTapCustom});

  final RiderReportRange range;
  final VoidCallback onTapCustom;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final DateFormat fmt = DateFormat('d MMM yyyy');
    final bool sameDay =
        range.start.year == range.end.year &&
        range.start.month == range.end.month &&
        range.start.day == range.end.day;
    final String label = sameDay
        ? fmt.format(range.start)
        : '${fmt.format(range.start)} — ${fmt.format(range.end)}';
    return Row(
      children: <Widget>[
        Icon(Icons.date_range_outlined, size: 16, color: cs.onSurfaceVariant),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
        TextButton(
          onPressed: onTapCustom,
          child: const Text('Change'),
        ),
      ],
    );
  }
}

class _ReportPreview extends StatelessWidget {
  const _ReportPreview({required this.data});

  final RiderReportData data;

  static const int _recentItemsShown = 5;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    if (data.isEmpty) {
      return RiderLargeCard(
        child: Column(
          children: <Widget>[
            Icon(
              Icons.receipt_long_outlined,
              size: 40,
              color: cs.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'No activity in this period.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    final List<RiderReportHistoryEntry> recent = data.historyEntries;
    final int extraCount = recent.length - _recentItemsShown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: RiderStatTile(
                label: 'Total earnings',
                value: LkrFormat.moneyDecimal(data.totalEarningsLkr),
                icon: Icons.payments_outlined,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RiderStatTile(
                label: 'Total jobs',
                value: '${data.totalJobCount}',
                icon: Icons.local_shipping_outlined,
                accent: AppColors.onlineGreen,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: <Widget>[
            Expanded(
              child: RiderStatTile(
                label: 'Cash collected',
                value: LkrFormat.money(data.cashCollectedLkr),
                icon: Icons.payments_rounded,
                accent: AppColors.warningAmber,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: RiderStatTile(
                label: 'Owed to admin',
                value: LkrFormat.money(data.cashOwedLkr),
                icon: Icons.account_balance_wallet_outlined,
                accent: AppColors.errorRed,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        RiderLargeCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'In this report',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              _ReportRow(
                label: 'Deliveries completed',
                value: '${data.deliveryCount}',
              ),
              _ReportRow(
                label: 'Rides completed',
                value: '${data.tripCount}',
              ),
              _ReportRow(
                label: 'Kept from cash',
                value: LkrFormat.money(data.keptCashEarningLkr),
              ),
              _ReportRow(
                label: 'Withdrawn',
                value: LkrFormat.moneyDecimal(data.withdrawnLkr),
              ),
              if (data.pendingWithdrawalLkr > 0)
                _ReportRow(
                  label: 'Pending withdrawal',
                  value: LkrFormat.moneyDecimal(data.pendingWithdrawalLkr),
                ),
              _ReportRow(
                label: 'Wallet transactions',
                value: '${data.transactions.length}',
              ),
            ],
          ),
        ),
        if (recent.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Recent activity',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          ...recent
              .take(_recentItemsShown)
              .map(
                (RiderReportHistoryEntry e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _HistoryTile(entry: e),
                ),
              ),
          if (extraCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '+ $extraCount more in the full PDF',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry});

  final RiderReportHistoryEntry entry;

  String _when(DateTime? at) {
    if (at == null) {
      return '—';
    }
    final int hour12 = at.hour > 12 ? at.hour - 12 : (at.hour == 0 ? 12 : at.hour);
    final String ampm = at.hour >= 12 ? 'pm' : 'am';
    final String m = at.minute.toString().padLeft(2, '0');
    const List<String> months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${at.day} ${months[at.month - 1]} · $hour12:$m $ampm';
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Color accent = entry.isRide
        ? AppColors.brandSecondary
        : AppColors.primaryBlue;

    return RiderLargeCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              entry.isRide
                  ? Icons.two_wheeler_outlined
                  : Icons.local_shipping_outlined,
              size: 20,
              color: accent,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _when(entry.at),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            LkrFormat.moneyDecimal(entry.amountLkr),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: cs.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
