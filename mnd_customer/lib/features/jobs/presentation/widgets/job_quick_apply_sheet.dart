import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_booked_badge.dart';

void showJobQuickApplySheet(
  BuildContext context,
  WidgetRef ref,
  JobListing job,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (BuildContext ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(ctx).bottom,
      ),
      child: _QuickApplyForm(job: job),
    ),
  );
}

class _QuickApplyForm extends ConsumerStatefulWidget {
  const _QuickApplyForm({required this.job});

  final JobListing job;

  @override
  ConsumerState<_QuickApplyForm> createState() => _QuickApplyFormState();
}

class _QuickApplyFormState extends ConsumerState<_QuickApplyForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _name = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _bio = TextEditingController();
  File? _cvFile;
  bool _submitting = false;
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _prefillFromProfile());
  }

  void _prefillFromProfile() {
    if (_prefilled) {
      return;
    }
    final profile = ref.read(customerProfileStreamProvider).valueOrNull;
    if (profile != null) {
      if (_name.text.isEmpty && profile.name.trim().isNotEmpty) {
        _name.text = profile.name.trim();
      }
      if (_phone.text.isEmpty && profile.phone.trim().isNotEmpty) {
        _phone.text = profile.phone.trim();
      }
    }
    _prefilled = true;
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _bio.dispose();
    super.dispose();
  }

  Widget _sheetPad({required Widget child}) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.sm,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool guest = ref.watch(guestBrowsingProvider);
    if (guest || ref.watch(firebaseAuthProvider).currentUser == null) {
      return _sheetPad(
        child: SignInRequiredBanner(
          message: 'Sign in to apply for "${widget.job.title}".',
          redirectTo: '${AppRoutes.customerJobs}/${widget.job.id}',
        ),
      );
    }

    if (!widget.job.isActive || widget.job.isExpired) {
      return _sheetPad(
        child: Text(
          'This job is no longer accepting applications.',
          style: textTheme.bodyMedium?.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }

    final String? status =
        ref.watch(myApplicationStatusForJobProvider(widget.job.id));
    final profile = ref.watch(customerProfileStreamProvider).valueOrNull;
    if (profile != null && !profile.isProfileComplete) {
      return _sheetPad(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Complete your profile',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add: ${profile.missingProfileFields.join(', ')}.',
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                context.push(AppRoutes.customerEditProfile);
              },
              child: const Text('Edit profile'),
            ),
          ],
        ),
      );
    }

    if (status != null) {
      final bool booked = status == JobApplicationStatus.booked;
      return _sheetPad(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (booked) const JobBookedBadge(),
            if (booked) const SizedBox(height: 12),
            Text(
              booked
                  ? 'You are booked for this job.'
                  : 'You already applied (${JobApplicationStatus.label(status)}).',
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return _sheetPad(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Quick apply',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.job.title,
              style: textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Your name *',
                prefixIcon: Icon(Icons.person_outline_rounded),
              ),
              validator: (String? v) =>
                  (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number *',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              validator: (String? v) => (v == null || v.trim().length < 8)
                  ? 'Enter a valid phone'
                  : null,
            ),
            const SizedBox(height: AppSpacing.md),
            TextFormField(
              controller: _bio,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Short bio (optional)',
                prefixIcon: Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: _pickCv,
              icon: Icon(
                _cvFile == null
                    ? Icons.upload_file_outlined
                    : Icons.check_circle_outline_rounded,
              ),
              label: Text(
                _cvFile == null ? 'Attach CV (optional)' : 'CV selected',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: Colors.black.withValues(alpha: 0.1)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text('Submit application'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCv() async {
    final FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: <String>['pdf', 'doc', 'docx'],
    );
    if (result != null && result.files.single.path != null) {
      setState(() => _cvFile = File(result.files.single.path!));
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(jobsRepositoryProvider).applyToJob(
            jobId: widget.job.id,
            applicantName: _name.text,
            applicantPhone: _phone.text,
            bio: _bio.text,
            cvFile: _cvFile,
          );
      if (mounted) {
        Navigator.pop(context);
        showMndSnackBar(context, 'Application sent! The employer may contact you soon.', variant: MndSnackBarVariant.success);
      }
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not send your application.'),
          variant: MndSnackBarVariant.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
