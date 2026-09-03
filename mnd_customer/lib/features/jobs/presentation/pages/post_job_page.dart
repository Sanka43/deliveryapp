import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/widgets/job_membership_gate.dart';
import 'package:mnd_delivery_app/app/providers/firebase_providers.dart';

class PostJobPage extends ConsumerStatefulWidget {
  const PostJobPage({super.key});

  @override
  ConsumerState<PostJobPage> createState() => _PostJobPageState();
}

class _PostJobPageState extends ConsumerState<PostJobPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _title = TextEditingController();
  final TextEditingController _company = TextEditingController();
  final TextEditingController _salary = TextEditingController();
  final TextEditingController _location = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _description = TextEditingController();
  final TextEditingController _responsibilities = TextEditingController();
  final TextEditingController _schedule = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _whatsapp = TextEditingController();
  final TextEditingController _laborCount = TextEditingController(text: '1');
  String _category = JobConstants.defaultCategory;
  String _type = JobConstants.defaultJobType;
  bool _remote = false;
  bool _urgent = false;
  DateTime? _deadline;
  File? _imageFile;
  File? _logoFile;
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _company.dispose();
    _salary.dispose();
    _location.dispose();
    _city.dispose();
    _description.dispose();
    _responsibilities.dispose();
    _schedule.dispose();
    _phone.dispose();
    _whatsapp.dispose();
    _laborCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool guest = ref.watch(guestBrowsingProvider);
    final bool signedOut = ref.watch(firebaseAuthProvider).currentUser == null;
    final bool authLocked = guest || signedOut;
    final AsyncValue<int> creditsAsync = ref.watch(jobPostCreditsProvider);
    final bool creditsLoading =
        creditsAsync.isLoading && !creditsAsync.hasValue;
    final int credits = creditsAsync.valueOrNull ?? 0;
    final bool membershipLocked =
        !authLocked && !creditsLoading && credits <= 0;
    final bool locked = authLocked || membershipLocked || creditsLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: mndPageAppBar(title: 'Post a job'),
      body: Column(
        children: <Widget>[
          Expanded(
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                locked ? AppSpacing.xl : AppSpacing.lg,
              ),
              children: <Widget>[
                if (authLocked)
                  const SignInRequiredBanner(
                    message:
                        'Sign in to post a job vacancy. Listings require admin approval.',
                    redirectTo: AppRoutes.customerPostJob,
                  )
                else if (creditsLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.xl),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (membershipLocked) ...<Widget>[
                  const JobMembershipRequiredBanner(),
                  const SizedBox(height: AppSpacing.md),
                  const JobCreditsChip(credits: 0),
                ] else ...<Widget>[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: JobCreditsChip(credits: credits),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const _ReviewBanner(),
                        const SizedBox(height: AppSpacing.md),
                        _FormSection(
                                      title: 'Basics',
                                      subtitle:
                                          'Title and how applicants should filter this role',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          TextFormField(
                                            controller: _title,
                                            textCapitalization:
                                                TextCapitalization.sentences,
                                            decoration: const InputDecoration(
                                              labelText: 'Job title *',
                                              hintText: 'e.g. Delivery rider',
                                              prefixIcon: Icon(
                                                Icons.work_outline_rounded,
                                              ),
                                            ),
                                            validator: (String? v) =>
                                                (v == null ||
                                                        v.trim().length < 3)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          _FieldLabel(label: 'Category'),
                                          const SizedBox(height: 2),
                                          Text(
                                            'What kind of work',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          _ChoiceChipWrap(
                                            options:
                                                JobConstants.quickCategories,
                                            selected: _category,
                                            onSelected: (String v) =>
                                                setState(() => _category = v),
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          _FieldLabel(label: 'Job type'),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Schedule / commitment',
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      AppColors.textSecondary,
                                                ),
                                          ),
                                          const SizedBox(height: 8),
                                          _ChoiceChipWrap(
                                            options: JobConstants.jobTypes,
                                            selected: _type,
                                            onSelected: (String v) =>
                                                setState(() => _type = v),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _FormSection(
                                      title: 'Company & hiring',
                                      subtitle:
                                          'Who is hiring and how many people you need',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          TextFormField(
                                            controller: _company,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Company / shop name *',
                                              hintText: 'Your business name',
                                              prefixIcon: Icon(
                                                Icons.storefront_outlined,
                                              ),
                                            ),
                                            validator: (String? v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _laborCount,
                                            keyboardType:
                                                TextInputType.number,
                                            decoration: const InputDecoration(
                                              labelText: 'Workers needed *',
                                              hintText: '1',
                                              prefixIcon: Icon(
                                                Icons.groups_outlined,
                                              ),
                                              helperText:
                                                  'You can book up to this many applicants',
                                            ),
                                            validator: (String? v) {
                                              final int? n = int.tryParse(
                                                v?.trim() ?? '',
                                              );
                                              if (n == null) {
                                                return 'Enter a number';
                                              }
                                              if (n <
                                                      JobConstants
                                                          .minLaborCount ||
                                                  n >
                                                      JobConstants
                                                          .maxLaborCount) {
                                                return '${JobConstants.minLaborCount}–${JobConstants.maxLaborCount} only';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _FormSection(
                                      title: 'Pay & location',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          TextFormField(
                                            controller: _salary,
                                            decoration: const InputDecoration(
                                              labelText: 'Salary / rate *',
                                              hintText: 'e.g. LKR 25,000 / month',
                                              prefixIcon: Icon(
                                                Icons.payments_outlined,
                                              ),
                                            ),
                                            validator: (String? v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _location,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            decoration: const InputDecoration(
                                              labelText: 'Location *',
                                              hintText: 'Area or landmark',
                                              prefixIcon: Icon(
                                                Icons.place_outlined,
                                              ),
                                            ),
                                            validator: (String? v) =>
                                                (v == null || v.trim().isEmpty)
                                                    ? 'Required'
                                                    : null,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _city,
                                            textCapitalization:
                                                TextCapitalization.words,
                                            decoration: const InputDecoration(
                                              labelText: 'City',
                                              hintText: 'e.g. Colombo',
                                              prefixIcon: Icon(
                                                Icons.location_city_outlined,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          _OptionTile(
                                            icon: Icons.wifi_tethering_rounded,
                                            title: 'Remote job',
                                            subtitle:
                                                'Work can be done from anywhere',
                                            value: _remote,
                                            onChanged: (bool v) =>
                                                setState(() => _remote = v),
                                          ),
                                          _OptionTile(
                                            icon: Icons.bolt_rounded,
                                            title: 'Urgent hiring',
                                            subtitle:
                                                'Highlight this listing as urgent',
                                            value: _urgent,
                                            accent: AppColors.offerOrange,
                                            onChanged: (bool v) =>
                                                setState(() => _urgent = v),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _FormSection(
                                      title: 'Description',
                                      subtitle:
                                          'Tell applicants what the role involves',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          TextFormField(
                                            controller: _description,
                                            maxLines: 5,
                                            textCapitalization:
                                                TextCapitalization.sentences,
                                            decoration: const InputDecoration(
                                              labelText: 'Description *',
                                              hintText:
                                                  'Day-to-day work, requirements, and perks',
                                              alignLabelWithHint: true,
                                            ),
                                            validator: (String? v) =>
                                                (v == null ||
                                                        v.trim().length < 10)
                                                    ? 'Min 10 characters'
                                                    : null,
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _responsibilities,
                                            maxLines: 3,
                                            textCapitalization:
                                                TextCapitalization.sentences,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Responsibilities (optional)',
                                              alignLabelWithHint: true,
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _schedule,
                                            decoration: const InputDecoration(
                                              labelText:
                                                  'Work schedule (optional)',
                                              hintText: 'e.g. Mon–Fri, 9am–5pm',
                                              prefixIcon: Icon(
                                                Icons.schedule_outlined,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _FormSection(
                                      title: 'Contact',
                                      subtitle:
                                          'How applicants can reach you',
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: <Widget>[
                                          TextFormField(
                                            controller: _phone,
                                            keyboardType: TextInputType.phone,
                                            decoration: const InputDecoration(
                                              labelText: 'Contact phone *',
                                              hintText: '07x xxx xxxx',
                                              prefixIcon: Icon(
                                                Icons.phone_outlined,
                                              ),
                                            ),
                                            validator: (String? v) {
                                              final String digits =
                                                  (v ?? '').replaceAll(
                                                      RegExp(r'\D'), '');
                                              return digits.length < 8
                                                  ? 'Enter a valid phone number'
                                                  : null;
                                            },
                                          ),
                                          const SizedBox(height: AppSpacing.md),
                                          TextFormField(
                                            controller: _whatsapp,
                                            keyboardType: TextInputType.phone,
                                            decoration: const InputDecoration(
                                              labelText: 'WhatsApp (optional)',
                                              hintText: 'Same as phone is fine',
                                              prefixIcon: Icon(
                                                Icons.chat_outlined,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: AppSpacing.sm),
                                          _DeadlineTile(
                                            deadline: _deadline,
                                            onPick: _pickDeadline,
                                            onClear: _deadline == null
                                                ? null
                                                : () => setState(
                                                      () => _deadline = null,
                                                    ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: AppSpacing.md),
                                    _FormSection(
                                      title: 'Photos',
                                      subtitle:
                                          'Optional banner and company logo',
                                      child: Row(
                                        children: <Widget>[
                                          Expanded(
                                            child: _MediaPickCard(
                                              label: 'Banner',
                                              icon: Icons.image_outlined,
                                              file: _imageFile,
                                              onPick: () =>
                                                  _pickImage(isLogo: false),
                                              onClear: _imageFile == null
                                                  ? null
                                                  : () => setState(
                                                        () =>
                                                            _imageFile = null,
                                                      ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: _MediaPickCard(
                                              label: 'Logo',
                                              icon: Icons.business_outlined,
                                              file: _logoFile,
                                              square: true,
                                              onPick: () =>
                                                  _pickImage(isLogo: true),
                                              onClear: _logoFile == null
                                                  ? null
                                                  : () => setState(
                                                        () => _logoFile = null,
                                                      ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (!locked) _SubmitBar(submitting: _submitting, onSubmit: _submit),
        ],
      ),
    );
  }

  Future<void> _pickDeadline() async {
    final DateTime? d = await showDatePicker(
      context: context,
      initialDate: _deadline ?? DateTime.now().add(const Duration(days: 14)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) {
      setState(() => _deadline = d);
    }
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file != null) {
      setState(() {
        if (isLogo) {
          _logoFile = File(file.path);
        } else {
          _imageFile = File(file.path);
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _submitting = true);
    try {
      final int laborCount = JobListing.parseLaborCount(
        int.tryParse(_laborCount.text.trim()),
      );
      final JobListing draft = JobListing(
        id: '',
        title: _title.text.trim(),
        category: _category,
        type: _type,
        salary: _salary.text.trim(),
        location: _location.text.trim(),
        description: _description.text.trim(),
        companyName: _company.text.trim(),
        contactPhone: _phone.text.trim(),
        whatsapp: _whatsapp.text.trim().isEmpty ? null : _whatsapp.text.trim(),
        responsibilities: _responsibilities.text.trim(),
        schedule: _schedule.text.trim(),
        deadline: _deadline,
        userId: '',
        status: 'pending',
        remote: _remote,
        urgent: _urgent,
        city: _city.text.trim(),
        createdAt: DateTime.now(),
        availableLaborCount: laborCount,
      );
      await ref.read(jobsRepositoryProvider).submitJob(
            draft: draft,
            imageFile: _imageFile,
            logoFile: _logoFile,
          );
      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (BuildContext ctx) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
            ),
            title: const Text('Pending approval'),
            content: const Text(
              'Your job was submitted. An admin will review it before it appears publicly.',
            ),
            actions: <Widget>[
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        showMndSnackBar(
          context,
          userFacingError(e, fallback: 'Could not post this job.'),
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

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner();

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            AppColors.serviceJobs,
            AppColors.serviceJobs.withValues(alpha: 0.55),
            Colors.white,
          ],
        ),
        borderRadius: BorderRadius.circular(AppColors.cardRadiusLg),
        border: Border.all(color: AppColors.accentPurple.withValues(alpha: 0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.verified_user_outlined,
              color: AppColors.accentPurple,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Admin review required',
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Your listing will be checked before it goes live on Jobs.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return MndPremiumCard(
      borderRadius: AppColors.cardRadiusLg,
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.15,
              color: AppColors.textPrimary,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
    );
  }
}

class _ChoiceChipWrap extends StatelessWidget {
  const _ChoiceChipWrap({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((String label) {
        final bool isSelected = selected == label;
        return FilterChip(
          label: Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(label),
          backgroundColor: AppColors.homeMutedFill,
          selectedColor: AppColors.brandPrimary,
          side: BorderSide.none,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          visualDensity: VisualDensity.compact,
        );
      }).toList(),
    );
  }
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color tint = accent ?? AppColors.brandPrimary;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: value
            ? tint.withValues(alpha: 0.08)
            : AppColors.homeMutedFill.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppColors.buttonRadius),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: tint),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: textTheme.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  activeTrackColor: tint,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DeadlineTile extends StatelessWidget {
  const _DeadlineTile({
    required this.deadline,
    required this.onPick,
    this.onClear,
  });

  final DateTime? deadline;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasDate = deadline != null;

    return Material(
      color: AppColors.homeMutedFill.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(AppColors.buttonRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: hasDate
                      ? AppColors.brandPrimary
                      : AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      hasDate ? 'Application deadline' : 'Deadline (optional)',
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hasDate
                          ? '${deadline!.day}/${deadline!.month}/${deadline!.year}'
                          : 'Tap to choose a closing date',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClear != null)
                IconButton(
                  tooltip: 'Clear',
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded, size: 20),
                  color: AppColors.textSecondary,
                )
              else
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColors.textSecondary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MediaPickCard extends StatelessWidget {
  const _MediaPickCard({
    required this.label,
    required this.icon,
    required this.onPick,
    this.file,
    this.onClear,
    this.square = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPick;
  final File? file;
  final VoidCallback? onClear;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasFile = file != null;

    return AspectRatio(
      aspectRatio: square ? 1 : 4 / 3,
      child: Material(
        color: AppColors.homeMutedFill.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPick,
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              if (hasFile)
                Image.file(file!, fit: BoxFit.cover)
              else
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    Icon(icon, color: AppColors.brandPrimary, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tap to add',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              if (hasFile) ...<Widget>[
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    color: Colors.black.withValues(alpha: 0.45),
                    child: Text(
                      label,
                      style: textTheme.labelMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                if (onClear != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Material(
                      color: Colors.black.withValues(alpha: 0.55),
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: onClear,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SubmitBar extends StatelessWidget {
  const _SubmitBar({
    required this.submitting,
    required this.onSubmit,
  });

  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.sm,
          ),
          child: FilledButton(
            onPressed: submitting ? null : onSubmit,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Submit for approval'),
          ),
        ),
      ),
    );
  }
}
