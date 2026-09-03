import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/user_facing_error.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/core/widgets/home/mnd_premium_card.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_page_app_bar.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/domain/profile_update_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/widgets/customer_profile_avatar.dart';

class EditCustomerProfilePage extends ConsumerWidget {
  const EditCustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerProfile?> async =
        ref.watch(customerProfileStreamProvider);

    return async.when(
      data: (CustomerProfile? profile) {
        if (profile == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted && context.canPop()) {
              context.pop();
            }
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return _EditProfileFormScaffold(profile: profile);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace _) => Scaffold(
        appBar: mndPageAppBar(title: 'Edit profile'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              userFacingError(
                e,
                fallback: 'Could not load profile. Please try again.',
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}

class _EditProfileFormScaffold extends ConsumerStatefulWidget {
  const _EditProfileFormScaffold({required this.profile});

  final CustomerProfile profile;

  @override
  ConsumerState<_EditProfileFormScaffold> createState() =>
      _EditProfileFormScaffoldState();
}

class _EditProfileFormScaffoldState
    extends ConsumerState<_EditProfileFormScaffold> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;
  bool _photoBusy = false;
  File? _localPreview;

  CustomerProfile get _profile =>
      ref.watch(customerProfileStreamProvider).valueOrNull ?? widget.profile;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _emailController =
        TextEditingController(text: widget.profile.email ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) {
      return 'Please enter your name';
    }
    if (v.trim().length > 80) {
      return 'Name is too long';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) {
      return null;
    }
    final String t = v.trim();
    final bool ok = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)*$',
    ).hasMatch(t);
    if (!ok) {
      return 'Enter a valid email address';
    }
    return null;
  }

  Future<void> _onSave() async {
    if (_saving || _photoBusy) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final ProfileUpdateResult result =
        await ref.read(customerProfileRepositoryProvider).updateProfile(
              displayName: _nameController.text,
              email: _emailController.text,
            );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (result.success) {
      showMndSnackBar(context, 'Profile updated', variant: MndSnackBarVariant.success);
      context.pop();
    } else {
      showMndSnackBar(context, result.errorMessage ?? 'Could not update profile', variant: MndSnackBarVariant.error);
    }
  }

  Future<void> _showPhotoSheet() async {
    if (_saving || _photoBusy) {
      return;
    }
    final CustomerProfile p = _profile;
    final bool hasPhoto =
        (_localPreview != null) ||
        (p.photoUrl != null && p.photoUrl!.isNotEmpty);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              0,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Text(
                  'Profile photo',
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: const Text('Take photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUpload(ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickAndUpload(ImageSource.gallery);
                  },
                ),
                if (hasPhoto)
                  ListTile(
                    leading: Icon(
                      Icons.delete_outline_rounded,
                      color: AppColors.error,
                    ),
                    title: Text(
                      'Remove photo',
                      style: TextStyle(color: AppColors.error),
                    ),
                    onTap: () {
                      Navigator.pop(sheetContext);
                      _removePhoto();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickAndUpload(ImageSource source) async {
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) {
      return;
    }

    final File file = File(picked.path);
    setState(() {
      _localPreview = file;
      _photoBusy = true;
    });

    final ProfileUpdateResult result = await ref
        .read(customerProfileRepositoryProvider)
        .uploadProfilePhoto(file);

    if (!mounted) {
      return;
    }
    setState(() => _photoBusy = false);

    if (result.success) {
      setState(() => _localPreview = null);
      showMndSnackBar(context, 'Profile photo updated', variant: MndSnackBarVariant.success);
    } else {
      showMndSnackBar(context, result.errorMessage ?? 'Could not upload photo', variant: MndSnackBarVariant.error);
    }
  }

  Future<void> _removePhoto() async {
    setState(() => _photoBusy = true);
    final ProfileUpdateResult result =
        await ref.read(customerProfileRepositoryProvider).removeProfilePhoto();
    if (!mounted) {
      return;
    }
    setState(() {
      _photoBusy = false;
      if (result.success) {
        _localPreview = null;
      }
    });
    showMndSnackBar(context, result.success
          ? 'Profile photo removed'
          : (result.errorMessage ?? 'Could not remove photo'), variant: result.success ? MndSnackBarVariant.success : MndSnackBarVariant.error);
  }

  @override
  Widget build(BuildContext context) {
    final CustomerProfile p = _profile;
    final ThemeData theme = Theme.of(context);
    final bool busy = _saving || _photoBusy;

    return Scaffold(
      backgroundColor: AppColors.backgroundCanvas,
      appBar: mndPageAppBar(
        title: 'Edit profile',
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: busy ? null : () => context.pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: busy ? null : _onSave,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: <Widget>[
          Center(
            child: Column(
              children: <Widget>[
                CustomerProfileAvatar(
                  profile: p,
                  size: 112,
                  localFile: _localPreview,
                  showCameraBadge: true,
                  isLoading: _photoBusy,
                  onTap: _showPhotoSheet,
                ),
                const SizedBox(height: AppSpacing.sm),
                TextButton(
                  onPressed: busy ? null : _showPhotoSheet,
                  child: const Text('Change photo'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (!p.isProfileComplete)
            MndPremiumCard(
              padding: EdgeInsets.zero,
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
                  color: AppColors.offerOrange.withValues(alpha: 0.08),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Profile ${p.profileCompletionPercent}% complete',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'A full profile helps employers contact you when you apply to jobs.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            MndPremiumCard(
              padding: EdgeInsets.zero,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm + 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AppColors.cardRadiusMd),
                  color: AppColors.success.withValues(alpha: 0.08),
                ),
                child: Row(
                  children: <Widget>[
                    const Icon(
                      Icons.check_circle_outline,
                      color: AppColors.success,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Profile ready for job applications',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your name and phone appear on job applications. Phone comes from sign-in.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  validator: _validateName,
                  textInputAction: TextInputAction.next,
                  enabled: !busy,
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const <String>[AutofillHints.email],
                  decoration: const InputDecoration(
                    labelText: 'Email (recommended for jobs)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.mail_outline_rounded),
                    hintText: 'name@example.com',
                    helperText:
                        'Employers may use this to follow up on your application',
                  ),
                  validator: _validateEmail,
                  textInputAction: TextInputAction.done,
                  enabled: !busy,
                ),
                const SizedBox(height: AppSpacing.md),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.phone_outlined),
                    enabled: false,
                  ),
                  child: Text(
                    p.phone.isEmpty ? '—' : p.phone,
                    style: theme.textTheme.bodyLarge,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'To change your phone number, sign in again with the new number or contact support.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: busy ? null : _onSave,
                  child: const Text('Save changes'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
