import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_photo_picker_tile.dart';
import 'package:mnd_rider/features/profile/data/rider_profile_repository.dart';
import 'package:mnd_rider/features/profile/domain/rider_compliance_doc.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

/// Lets a rider review and renew their license/insurance/revenue license —
/// each document shows its current status (valid / expiring / expired) and
/// an inline photo + expiry-date picker to renew it.
class RiderRenewDocumentsPage extends ConsumerWidget {
  const RiderRenewDocumentsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<RiderProfile?> profileAsync =
        ref.watch(riderProfileStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents')),
      body: profileAsync.when(
        data: (RiderProfile? profile) {
          if (profile == null) {
            return const Center(child: Text('Sign in required.'));
          }
          final List<RiderComplianceDocStatus> statuses =
              riderComplianceDocStatuses(
            licenseExpiresAt: profile.licenseExpiresAt,
            insuranceExpiresAt: profile.insuranceExpiresAt,
            revenueLicenseExpiresAt: profile.revenueLicenseExpiresAt,
          );
          final Map<RiderComplianceDocKind, String?> photoUrls =
              <RiderComplianceDocKind, String?>{
            RiderComplianceDocKind.license: profile.licensePhotoUrl,
            RiderComplianceDocKind.insurance: profile.insurancePhotoUrl,
            RiderComplianceDocKind.revenueLicense:
                profile.revenueLicensePhotoUrl,
          };
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.screenPadding,
              16,
              AppSpacing.screenPadding,
              32,
            ),
            itemCount: statuses.length,
            separatorBuilder: (_, _) => const SizedBox(height: 16),
            itemBuilder: (BuildContext context, int index) {
              final RiderComplianceDocStatus status = statuses[index];
              return _RenewDocCard(
                status: status,
                currentPhotoUrl: photoUrls[status.kind],
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) =>
            const Center(child: Text('Could not load your documents.')),
      ),
    );
  }
}

class _RenewDocCard extends ConsumerStatefulWidget {
  const _RenewDocCard({required this.status, required this.currentPhotoUrl});

  final RiderComplianceDocStatus status;
  final String? currentPhotoUrl;

  @override
  ConsumerState<_RenewDocCard> createState() => _RenewDocCardState();
}

class _RenewDocCardState extends ConsumerState<_RenewDocCard> {
  Uint8List? _newPhotoBytes;
  DateTime? _newExpiresAt;
  bool _submitting = false;

  Future<void> _pickExpiryDate() async {
    final DateTime now = DateTime.now();
    final DateTime initial = _newExpiresAt ?? now;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(now) ? now : initial,
      firstDate: now,
      lastDate: DateTime(now.year + 15),
    );
    if (picked != null) {
      setState(() => _newExpiresAt = picked);
    }
  }

  Future<void> _submit() async {
    if (_newPhotoBytes == null || _newExpiresAt == null || _submitting) {
      return;
    }
    setState(() => _submitting = true);
    final String? error =
        await ref.read(riderProfileRepositoryProvider).renewComplianceDocument(
              kind: widget.status.kind,
              photoBytes: _newPhotoBytes!,
              expiresAt: _newExpiresAt!,
            );
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (error != null) {
      showRiderSnackBar(context, error);
      return;
    }
    setState(() {
      _newPhotoBytes = null;
      _newExpiresAt = null;
    });
    showRiderSnackBar(
      context,
      '${widget.status.kind.label} renewed — awaiting admin review.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final RiderComplianceDocStatus status = widget.status;
    final bool canSubmit =
        _newPhotoBytes != null && _newExpiresAt != null && !_submitting;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppSpacing.cardRadius),
        side: BorderSide(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    status.kind.label,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                _StatusChip(status: status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              status.expiresAt == null
                  ? 'No expiry date on file'
                  : 'Expires ${DateFormat('dd MMM yyyy').format(status.expiresAt!)}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (widget.currentPhotoUrl != null && _newPhotoBytes == null) ...<Widget>[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  widget.currentPhotoUrl!,
                  height: 100,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            RiderPhotoPickerTile(
              label: 'New photo',
              hint: 'Upload a clear photo of the renewed document',
              bytes: _newPhotoBytes,
              icon: Icons.badge_outlined,
              onPicked: (Uint8List data) =>
                  setState(() => _newPhotoBytes = data),
            ),
            const SizedBox(height: 12),
            _DateField(
              value: _newExpiresAt,
              onTap: _submitting ? null : _pickExpiryDate,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSubmit ? _submit : null,
                child: _submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save renewal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final RiderComplianceDocStatus status;

  @override
  Widget build(BuildContext context) {
    final (String label, Color color) = status.isExpired
        ? ('Expired', AppColors.errorRed)
        : status.isExpiringSoon
            ? ('Expires in ${status.daysUntilExpiry}d', AppColors.warningAmber)
            : ('Valid', AppColors.onlineGreen);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({required this.value, required this.onTap});

  final DateTime? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.7)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.event_rounded, size: 18, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value == null
                      ? 'New expiry date'
                      : DateFormat('dd MMM yyyy').format(value!),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: value == null ? cs.onSurfaceVariant : cs.onSurface,
                  ),
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}
