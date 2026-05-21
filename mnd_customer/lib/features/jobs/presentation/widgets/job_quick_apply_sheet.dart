import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_application.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_booked_badge.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:go_router/go_router.dart';

void showJobQuickApplySheet(
  BuildContext context,
  WidgetRef ref,
  JobListing job,
) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
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

  @override
  Widget build(BuildContext context) {
    final bool guest = ref.watch(guestBrowsingProvider);
    if (guest || ref.watch(firebaseAuthProvider).currentUser == null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: SignInRequiredBanner(
          message: 'Sign in to apply for "${widget.job.title}".',
        ),
      );
    }

    if (!widget.job.isActive || widget.job.isExpired) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(
          'This job is no longer accepting applications.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      );
    }

    final String? status =
        ref.watch(myApplicationStatusForJobProvider(widget.job.id));
    final profile = ref.watch(customerProfileStreamProvider).valueOrNull;
    if (profile != null && !profile.isProfileComplete) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Complete your profile before applying.',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Add: ${profile.missingProfileFields.join(', ')}.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
            const SizedBox(height: 16),
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
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (booked) const JobBookedBadge(),
            const SizedBox(height: 12),
            Text(
              booked
                  ? 'You are booked for this job.'
                  : 'You already applied (${JobApplicationStatus.label(status)}).',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              'Quick apply',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            Text(
              widget.job.title,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Your name *'),
              validator: (String? v) =>
                  (v == null || v.trim().length < 2) ? 'Enter your name' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone number *'),
              validator: (String? v) =>
                  (v == null || v.trim().length < 8) ? 'Enter a valid phone' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bio,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Short bio (optional)',
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _pickCv,
              icon: const Icon(Icons.upload_file_outlined),
              label: Text(_cvFile == null ? 'Attach CV (optional)' : 'CV selected'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _submitting ? null : _submit,
              child: _submitting
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application sent! The employer may contact you soon.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }
}
