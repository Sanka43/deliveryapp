import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';

class EditCustomerProfilePage extends ConsumerWidget {
  const EditCustomerProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerProfile?> async = ref.watch(customerProfileStreamProvider);

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
        appBar: AppBar(title: const Text('Edit profile')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text('Could not load profile.\n$e', textAlign: TextAlign.center),
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
  ConsumerState<_EditProfileFormScaffold> createState() => _EditProfileFormScaffoldState();
}

class _EditProfileFormScaffoldState extends ConsumerState<_EditProfileFormScaffold> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _emailController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.profile.name);
    _emailController = TextEditingController(text: widget.profile.email ?? '');
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
    if (_saving) {
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _saving = true);
    final result = await ref.read(customerProfileRepositoryProvider).updateProfile(
          displayName: _nameController.text,
          email: _emailController.text,
        );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    if (result.success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      context.pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.errorMessage ?? 'Could not update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final CustomerProfile p = widget.profile;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit profile'),
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: _saving ? null : () => context.pop(),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: _saving ? null : _onSave,
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
          if (!p.isProfileComplete)
            Card(
              color: AppColors.offerOrange.withValues(alpha: 0.08),
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
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
                            color: Colors.black54,
                          ),
                    ),
                  ],
                ),
              ),
            )
          else
            Card(
              color: Colors.green.withValues(alpha: 0.08),
              elevation: 0,
              child: const ListTile(
                leading: Icon(Icons.check_circle_outline, color: Colors.green),
                title: Text('Profile ready for job applications'),
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Your name and phone appear on job applications. Phone comes from sign-in.',
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.black54),
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
                  enabled: !_saving,
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
                    helperText: 'Employers may use this to follow up on your application',
                  ),
                  validator: _validateEmail,
                  textInputAction: TextInputAction.done,
                  enabled: !_saving,
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
                  style: theme.textTheme.bodySmall?.copyWith(color: Colors.black45),
                ),
                const SizedBox(height: AppSpacing.lg),
                FilledButton(
                  onPressed: _saving ? null : _onSave,
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
