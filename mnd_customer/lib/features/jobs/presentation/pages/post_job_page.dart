import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/home/home_page_background.dart';
import 'package:mnd_delivery_app/core/widgets/sign_in_required_prompt.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/jobs/domain/entities/job_listing.dart';
import 'package:mnd_delivery_app/features/jobs/domain/job_constants.dart';
import 'package:mnd_delivery_app/features/jobs/presentation/providers/jobs_providers.dart';
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
  String _category = JobConstants.quickCategories.first;
  String _type = JobConstants.jobTypes.first;
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Post a job'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(28),
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Employer feature — manage from Profile',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          const HomePageBackground(),
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.xl,
            ),
            child: guest || signedOut
                ? const SignInRequiredBanner(
                    message: 'Sign in to post a job vacancy. Listings require admin approval.',
                  )
                : Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Text(
                          'Your listing will be reviewed before going live.',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _title,
                          decoration: const InputDecoration(labelText: 'Job title *'),
                          validator: (String? v) =>
                              (v == null || v.trim().length < 3) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _category,
                          decoration: const InputDecoration(labelText: 'Category'),
                          items: JobConstants.quickCategories
                              .map(
                                (String c) => DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) =>
                              setState(() => _category = v ?? _category),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          value: _type,
                          decoration: const InputDecoration(labelText: 'Job type'),
                          items: JobConstants.jobTypes
                              .map(
                                (String t) => DropdownMenuItem<String>(
                                  value: t,
                                  child: Text(t),
                                ),
                              )
                              .toList(),
                          onChanged: (String? v) =>
                              setState(() => _type = v ?? _type),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _company,
                          decoration: const InputDecoration(
                            labelText: 'Company / your name *',
                          ),
                          validator: (String? v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _laborCount,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Workers needed *',
                            hintText: 'How many people can be booked',
                            helperText:
                                'You can book up to this many applicants',
                          ),
                          validator: (String? v) {
                            final int? n = int.tryParse(v?.trim() ?? '');
                            if (n == null) {
                              return 'Enter a number';
                            }
                            if (n < JobConstants.minLaborCount ||
                                n > JobConstants.maxLaborCount) {
                              return '${JobConstants.minLaborCount}–${JobConstants.maxLaborCount} only';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _salary,
                          decoration: const InputDecoration(
                            labelText: 'Salary / rate *',
                            hintText: 'e.g. LKR 25,000 / month',
                          ),
                          validator: (String? v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _location,
                          decoration: const InputDecoration(labelText: 'Location *'),
                          validator: (String? v) =>
                              (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _city,
                          decoration: const InputDecoration(labelText: 'City'),
                        ),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          title: const Text('Remote job'),
                          value: _remote,
                          onChanged: (bool v) => setState(() => _remote = v),
                        ),
                        SwitchListTile(
                          title: const Text('Urgent hiring'),
                          value: _urgent,
                          onChanged: (bool v) => setState(() => _urgent = v),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _description,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: 'Description *'),
                          validator: (String? v) =>
                              (v == null || v.trim().length < 10) ? 'Min 10 characters' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _responsibilities,
                          maxLines: 3,
                          decoration: const InputDecoration(
                            labelText: 'Responsibilities (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _schedule,
                          decoration: const InputDecoration(
                            labelText: 'Work schedule (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(labelText: 'Contact phone *'),
                          validator: (String? v) =>
                              (v == null || v.trim().length < 8) ? 'Required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _whatsapp,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'WhatsApp (optional)',
                          ),
                        ),
                        const SizedBox(height: 12),
                        ListTile(
                          title: Text(
                            _deadline == null
                                ? 'Application deadline (optional)'
                                : 'Deadline: ${_deadline!.day}/${_deadline!.month}/${_deadline!.year}',
                          ),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: () async {
                            final DateTime? d = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now().add(const Duration(days: 14)),
                              firstDate: DateTime.now(),
                              lastDate: DateTime.now().add(const Duration(days: 365)),
                            );
                            if (d != null) {
                              setState(() => _deadline = d);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(isLogo: false),
                                icon: const Icon(Icons.image_outlined),
                                label: const Text('Banner'),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: () => _pickImage(isLogo: true),
                                icon: const Icon(Icons.business_outlined),
                                label: const Text('Logo'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox(
                                  height: 22,
                                  width: 22,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Submit for approval'),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
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
