import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/jobs/data/vendor_jobs_repository.dart';
import 'package:mnd_shop/features/jobs/domain/job_constants.dart';
import 'package:mnd_shop/features/jobs/domain/job_listing.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/products/presentation/widgets/vendor_products_ui.dart';
import 'package:permission_handler/permission_handler.dart';

class JobFormPage extends ConsumerStatefulWidget {
  const JobFormPage({super.key});

  @override
  ConsumerState<JobFormPage> createState() => _JobFormPageState();
}

class _JobFormPageState extends ConsumerState<JobFormPage> {
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
  bool _prefilled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _prefillFromVendor();
    });
  }

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

  String _vTxt(BuildContext context, {required String en, required String si}) {
    final String languageCode = Localizations.localeOf(context).languageCode;
    if (languageCode == 'si') {
      return si;
    }
    if (languageCode == 'ta') {
      return vendorTamilFallback(en);
    }
    return en;
  }

  void _prefillFromVendor() {
    if (_prefilled) {
      return;
    }
    final Map<String, dynamic>? doc =
        ref.read(vendorAccountDocDataProvider).valueOrNull;
    final String shopName = ref.read(vendorShopDisplayNameProvider);
    if (shopName.isNotEmpty && _company.text.trim().isEmpty) {
      _company.text = shopName;
    }
    if (doc != null) {
      final String phone = (doc['phone'] as String?)?.trim() ?? '';
      final String whatsapp = (doc['whatsapp'] as String?)?.trim() ?? '';
      final String city = (doc['city'] as String?)?.trim() ?? '';
      final String address = (doc['addressLine'] as String?)?.trim() ?? '';
      if (phone.isNotEmpty && _phone.text.trim().isEmpty) {
        _phone.text = phone;
      }
      if (whatsapp.isNotEmpty && _whatsapp.text.trim().isEmpty) {
        _whatsapp.text = whatsapp;
      }
      if (city.isNotEmpty && _city.text.trim().isEmpty) {
        _city.text = city;
      }
      if (address.isNotEmpty && _location.text.trim().isEmpty) {
        _location.text = address;
      } else if (city.isNotEmpty && _location.text.trim().isEmpty) {
        _location.text = city;
      }
    }
    _prefilled = true;
  }

  Future<bool> _ensurePhotoLibraryPermission() async {
    if (kIsWeb) {
      return true;
    }
    if (Platform.isIOS) {
      final PermissionStatus s = await Permission.photos.request();
      return s.isGranted || s.isLimited;
    }
    if (Platform.isAndroid) {
      PermissionStatus s = await Permission.photos.request();
      if (s.isGranted || s.isLimited) {
        return true;
      }
      s = await Permission.storage.request();
      return s.isGranted;
    }
    return true;
  }

  Future<void> _pickImage({required bool isLogo}) async {
    final bool ok = await _ensurePhotoLibraryPermission();
    if (!ok) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _vTxt(
              context,
              en: 'Photo permission is required',
              si: 'ඡායාරූප අවසරය අවශ්‍යයි',
            ),
          ),
        ),
      );
      return;
    }
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      imageQuality: 85,
    );
    if (file == null || !mounted) {
      return;
    }
    setState(() {
      if (isLogo) {
        _logoFile = File(file.path);
      } else {
        _imageFile = File(file.path);
      }
    });
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
        status: JobConstants.statusPending,
        remote: _remote,
        urgent: _urgent,
        city: _city.text.trim(),
        createdAt: DateTime.now(),
        availableLaborCount: laborCount,
      );
      await ref.read(vendorJobsRepositoryProvider).submitJob(
            draft: draft,
            imageFile: _imageFile,
            logoFile: _logoFile,
          );
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(kVendorDialogRadius),
          ),
          title: Text(
            _vTxt(ctx, en: 'Pending approval', si: 'අනුමැතිය බලාපොරොත්තු'),
          ),
          content: Text(
            _vTxt(
              ctx,
              en:
                  'Your job was submitted. An admin will review it before it appears publicly.',
              si:
                  'රැකියාව ඉදිරිපත් කළා. ප්‍රසිද්ධ වීමට පෙර admin සමාලෝචනය කරයි.',
            ),
          ),
          actions: <Widget>[
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(_vTxt(ctx, en: 'OK', si: 'හරි')),
            ),
          ],
        ),
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              userFacingError(
                e,
                fallback: 'Could not save job. Please try again.',
              ),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color canvas = VendorProductsTheme.canvas(context);
    final Color card = VendorProductsTheme.cardSurface(context);
    final Color muted = VendorProductsTheme.mutedText(context);
    final Color accent = VendorProductsTheme.accent(context);

    return Scaffold(
      backgroundColor: canvas,
      appBar: AppBar(
        backgroundColor: canvas,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              _vTxt(context, en: 'Post a job', si: 'රැකියාවක් පළ කරන්න'),
              style: textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: VendorProductsTheme.primaryText(context),
              ),
            ),
            Text(
              _vTxt(
                context,
                en: 'Reviewed before going live',
                si: 'සජීවී වීමට පෙර සමාලෝචනය',
              ),
              style: textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: VendorResponsiveContent(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: <Widget>[
                    _ReviewBanner(vTxt: _vTxt),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: _vTxt(context, en: 'Basics', si: 'මූලික'),
                      subtitle: _vTxt(
                        context,
                        en: 'Title and how applicants filter this role',
                        si: 'මාතෘකාව සහ කාණ්ඩය',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _title,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Job title *',
                                si: 'මාතෘකාව *',
                              ),
                              hintText: 'e.g. Delivery rider',
                              prefixIcon:
                                  const Icon(Icons.work_outline_rounded),
                            ),
                            validator: (String? v) =>
                                (v == null || v.trim().length < 3)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _vTxt(context, en: 'Category', si: 'කාණ්ඩය'),
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _vTxt(
                              context,
                              en: 'What kind of work',
                              si: 'කුමන වැඩ වර්ගයද',
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              color: VendorProductsTheme.mutedText(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ChoiceChipWrap(
                            options: JobConstants.quickCategories,
                            selected: _category,
                            onSelected: (String v) =>
                                setState(() => _category = v),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _vTxt(context, en: 'Job type', si: 'වර්ගය'),
                            style: textTheme.labelLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _vTxt(
                              context,
                              en: 'Schedule / commitment',
                              si: 'කාලසටහන / බැඳීම',
                            ),
                            style: textTheme.bodySmall?.copyWith(
                              color: VendorProductsTheme.mutedText(context),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _ChoiceChipWrap(
                            options: JobConstants.jobTypes,
                            selected: _type,
                            onSelected: (String v) => setState(() => _type = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: _vTxt(
                        context,
                        en: 'Company & hiring',
                        si: 'සමාගම සහ බඳවා ගැනීම',
                      ),
                      subtitle: _vTxt(
                        context,
                        en: 'Who is hiring and how many people you need',
                        si: 'කවුද බඳවා ගන්නේ සහ කී දෙනෙක් අවශ්‍යද',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _company,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Company / shop name *',
                                si: 'සමාගම / වෙළඳසැල *',
                              ),
                              prefixIcon:
                                  const Icon(Icons.storefront_outlined),
                            ),
                            validator: (String? v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _laborCount,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Workers needed *',
                                si: 'කම්කරුවන් *',
                              ),
                              prefixIcon: const Icon(Icons.groups_outlined),
                              helperText: _vTxt(
                                context,
                                en:
                                    'You can book up to this many applicants',
                                si: 'මෙතෙක් අයදුම්කරුවන් book කළ හැක',
                              ),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: _vTxt(
                        context,
                        en: 'Pay & location',
                        si: 'වැටුප සහ ස්ථානය',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _salary,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Salary / rate *',
                                si: 'වැටුප *',
                              ),
                              hintText: 'e.g. LKR 25,000 / month',
                              prefixIcon:
                                  const Icon(Icons.payments_outlined),
                            ),
                            validator: (String? v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _location,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Location *',
                                si: 'ස්ථානය *',
                              ),
                              hintText: _vTxt(
                                context,
                                en: 'Area or landmark',
                                si: 'ප්‍රදේශය හෝ සලකුණ',
                              ),
                              prefixIcon: const Icon(Icons.place_outlined),
                            ),
                            validator: (String? v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _city,
                            textCapitalization: TextCapitalization.words,
                            decoration: InputDecoration(
                              labelText:
                                  _vTxt(context, en: 'City', si: 'නගරය'),
                              prefixIcon:
                                  const Icon(Icons.location_city_outlined),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _OptionTile(
                            icon: Icons.wifi_tethering_rounded,
                            title: _vTxt(
                              context,
                              en: 'Remote job',
                              si: 'දුරස්ථ',
                            ),
                            subtitle: _vTxt(
                              context,
                              en: 'Work can be done from anywhere',
                              si: 'ඕනෑම තැනකින් වැඩ කළ හැක',
                            ),
                            value: _remote,
                            accent: accent,
                            onChanged: (bool v) =>
                                setState(() => _remote = v),
                          ),
                          _OptionTile(
                            icon: Icons.bolt_rounded,
                            title: _vTxt(
                              context,
                              en: 'Urgent hiring',
                              si: 'හදිසි බඳවා ගැනීම',
                            ),
                            subtitle: _vTxt(
                              context,
                              en: 'Highlight this listing as urgent',
                              si: 'මෙම ලැයිස්තුව හදිසි ලෙස පෙන්වන්න',
                            ),
                            value: _urgent,
                            accent: AppColors.pendingAmber,
                            onChanged: (bool v) =>
                                setState(() => _urgent = v),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: _vTxt(context, en: 'Description', si: 'විස්තරය'),
                      subtitle: _vTxt(
                        context,
                        en: 'Tell applicants what the role involves',
                        si: 'රැකියාව ගැන අයදුම්කරුවන්ට කියන්න',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _description,
                            maxLines: 5,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Description *',
                                si: 'විස්තරය *',
                              ),
                              hintText: _vTxt(
                                context,
                                en:
                                    'Day-to-day work, requirements, and perks',
                                si: 'දිනපතා වැඩ, අවශ්‍යතා සහ ප්‍රතිලාභ',
                              ),
                              alignLabelWithHint: true,
                            ),
                            validator: (String? v) =>
                                (v == null || v.trim().length < 10)
                                    ? 'Min 10 characters'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _responsibilities,
                            maxLines: 3,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Responsibilities (optional)',
                                si: 'වගකීම් (විකල්ප)',
                              ),
                              alignLabelWithHint: true,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _schedule,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Work schedule (optional)',
                                si: 'කාලසටහන (විකල්ප)',
                              ),
                              hintText: 'e.g. Mon–Fri, 9am–5pm',
                              prefixIcon:
                                  const Icon(Icons.schedule_outlined),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: _vTxt(context, en: 'Contact', si: 'සම්බන්ධතා'),
                      subtitle: _vTxt(
                        context,
                        en: 'How applicants can reach you',
                        si: 'අයදුම්කරුවන් ඔබව සම්බන්ධ කරගන්නා ආකාරය',
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          TextFormField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'Contact phone *',
                                si: 'දුරකථන *',
                              ),
                              hintText: '07x xxx xxxx',
                              prefixIcon: const Icon(Icons.phone_outlined),
                            ),
                            validator: (String? v) =>
                                (v == null || v.trim().length < 8)
                                    ? 'Required'
                                    : null,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _whatsapp,
                            keyboardType: TextInputType.phone,
                            decoration: InputDecoration(
                              labelText: _vTxt(
                                context,
                                en: 'WhatsApp (optional)',
                                si: 'WhatsApp (විකල්ප)',
                              ),
                              prefixIcon: const Icon(Icons.chat_outlined),
                            ),
                          ),
                          const SizedBox(height: 8),
                          _DeadlineTile(
                            deadline: _deadline,
                            label: _deadline == null
                                ? _vTxt(
                                    context,
                                    en: 'Deadline (optional)',
                                    si: 'අවසාන දිනය (විකල්ප)',
                                  )
                                : _vTxt(
                                    context,
                                    en: 'Application deadline',
                                    si: 'අවසාන දිනය',
                                  ),
                            hint: _vTxt(
                              context,
                              en: 'Tap to choose a closing date',
                              si: 'අවසාන දිනය තෝරන්න',
                            ),
                            onPick: _pickDeadline,
                            onClear: _deadline == null
                                ? null
                                : () => setState(() => _deadline = null),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      title: _vTxt(context, en: 'Photos', si: 'ඡායාරූප'),
                      subtitle: _vTxt(
                        context,
                        en: 'Optional banner and company logo',
                        si: 'විකල්ප banner සහ logo',
                      ),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: _MediaPickCard(
                              label: _vTxt(
                                context,
                                en: 'Banner',
                                si: 'Banner',
                              ),
                              tapHint: _vTxt(
                                context,
                                en: 'Tap to add',
                                si: 'එකතු කරන්න',
                              ),
                              icon: Icons.image_outlined,
                              file: _imageFile,
                              onPick: () => _pickImage(isLogo: false),
                              onClear: _imageFile == null
                                  ? null
                                  : () => setState(() => _imageFile = null),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _MediaPickCard(
                              label: _vTxt(context, en: 'Logo', si: 'Logo'),
                              tapHint: _vTxt(
                                context,
                                en: 'Tap to add',
                                si: 'එකතු කරන්න',
                              ),
                              icon: Icons.business_outlined,
                              file: _logoFile,
                              square: true,
                              onPick: () => _pickImage(isLogo: true),
                              onClear: _logoFile == null
                                  ? null
                                  : () => setState(() => _logoFile = null),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          _SubmitBar(
            submitting: _submitting,
            label: _vTxt(
              context,
              en: 'Submit for approval',
              si: 'අනුමැතිය සඳහා ඉදිරිපත් කරන්න',
            ),
            surface: card,
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }
}

typedef _VTxt = String Function(
  BuildContext context, {
  required String en,
  required String si,
});

class _ReviewBanner extends StatelessWidget {
  const _ReviewBanner({required this.vTxt});

  final _VTxt vTxt;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color accent = VendorProductsTheme.accent(context);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            accent.withValues(alpha: 0.16),
            accent.withValues(alpha: 0.06),
            VendorProductsTheme.cardSurface(context),
          ],
        ),
        borderRadius: BorderRadius.circular(kVendorCardRadius),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VendorProductsTheme.cardSurface(context)
                  .withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.verified_user_outlined, color: accent),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  vTxt(
                    context,
                    en: 'Admin review required',
                    si: 'Admin සමාලෝචනය අවශ්‍යයි',
                  ),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: VendorProductsTheme.primaryText(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  vTxt(
                    context,
                    en:
                        'Your listing will be checked before it goes live on Jobs.',
                    si: 'සජීවී වීමට පෙර ලැයිස්තුව සමාලෝචනය කෙරේ.',
                  ),
                  style: textTheme.bodySmall?.copyWith(
                    color: VendorProductsTheme.mutedText(context),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VendorProductsTheme.cardSurface(context),
        borderRadius: BorderRadius.circular(kVendorCardRadius),
        border: Border.all(
          color: VendorProductsTheme.inputBorder(context),
        ),
        boxShadow: VendorProductsTheme.cardShadow(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            title,
            style: textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: VendorProductsTheme.primaryText(context),
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle!,
              style: textTheme.bodySmall?.copyWith(
                color: VendorProductsTheme.mutedText(context),
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
    final Color accent = VendorProductsTheme.accent(context);

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
              color: isSelected
                  ? VendorProductsTheme.chipSelectedFg(context)
                  : VendorProductsTheme.primaryText(context),
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          onSelected: (_) => onSelected(label),
          backgroundColor: VendorProductsTheme.isDark(context)
              ? VendorProductsTheme.thumbPlaceholderFill(context)
              : AppColors.surfaceMuted,
          selectedColor: accent,
          side: BorderSide(
            color: isSelected
                ? accent
                : VendorProductsTheme.inputBorder(context),
          ),
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
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: value
            ? accent.withValues(alpha: 0.1)
            : VendorProductsTheme.softAccentFill(
                context,
                lightAlpha: 0.04,
                darkAlpha: 0.12,
              ),
        borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
        child: InkWell(
          borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
          onTap: () => onChanged(!value),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: <Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: VendorProductsTheme.cardSurface(context),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: accent),
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
                          color: VendorProductsTheme.mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Switch.adaptive(
                  value: value,
                  activeTrackColor: accent,
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
    required this.label,
    required this.hint,
    required this.onPick,
    this.onClear,
  });

  final DateTime? deadline;
  final String label;
  final String hint;
  final VoidCallback onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasDate = deadline != null;
    final Color accent = VendorProductsTheme.accent(context);

    return Material(
      color: VendorProductsTheme.softAccentFill(
        context,
        lightAlpha: 0.04,
        darkAlpha: 0.12,
      ),
      borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(kVendorFormFieldRadius),
        onTap: onPick,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: VendorProductsTheme.cardSurface(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.calendar_today_outlined,
                  size: 18,
                  color: hasDate
                      ? accent
                      : VendorProductsTheme.mutedText(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      label,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      hasDate
                          ? '${deadline!.day}/${deadline!.month}/${deadline!.year}'
                          : hint,
                      style: textTheme.bodySmall?.copyWith(
                        color: VendorProductsTheme.mutedText(context),
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
                  color: VendorProductsTheme.mutedText(context),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: VendorProductsTheme.mutedText(context),
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
    required this.tapHint,
    required this.icon,
    required this.onPick,
    this.file,
    this.onClear,
    this.square = false,
  });

  final String label;
  final String tapHint;
  final IconData icon;
  final VoidCallback onPick;
  final File? file;
  final VoidCallback? onClear;
  final bool square;

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final bool hasFile = file != null;
    final Color accent = VendorProductsTheme.accent(context);

    return AspectRatio(
      aspectRatio: square ? 1 : 4 / 3,
      child: Material(
        color: VendorProductsTheme.softAccentFill(
          context,
          lightAlpha: 0.04,
          darkAlpha: 0.12,
        ),
        borderRadius: BorderRadius.circular(kVendorStatCardRadius),
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
                    Icon(icon, color: accent, size: 28),
                    const SizedBox(height: 8),
                    Text(
                      label,
                      style: textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tapHint,
                      style: textTheme.bodySmall?.copyWith(
                        color: VendorProductsTheme.mutedText(context),
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
    required this.label,
    required this.surface,
    required this.onSubmit,
  });

  final bool submitting;
  final String label;
  final Color surface;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(color: VendorProductsTheme.inputBorder(context)),
        ),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                : Text(label),
          ),
        ),
      ),
    );
  }
}
