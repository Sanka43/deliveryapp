import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';
import 'package:mnd_delivery_app/features/customer/domain/profile_update_result.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/l10n/generated/app_localizations.dart';

/// Mandatory first-login step: name is required, email optional.
/// The router keeps customers here until a real name is saved.
class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  bool _saving = false;
  bool _prefilled = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  /// Keep an email saved earlier (e.g. before a name was set).
  void _prefillOnce(CustomerProfile? profile) {
    if (_prefilled || profile == null) {
      return;
    }
    _prefilled = true;
    if (profile.hasRealName) {
      _nameController.text = profile.name;
    }
    _emailController.text = profile.email ?? '';
  }

  String? _validateName(String? v, AppLocalizations l10n) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) {
      return l10n.completeProfileNameRequired;
    }
    if (t.length < 2) {
      return l10n.completeProfileNameTooShort;
    }
    if (t.length > 80) {
      return l10n.completeProfileNameTooLong;
    }
    if (t.toLowerCase() == 'customer') {
      return l10n.completeProfileNameInvalid;
    }
    return null;
  }

  String? _validateEmail(String? v, AppLocalizations l10n) {
    final String t = (v ?? '').trim();
    if (t.isEmpty) {
      return null;
    }
    final bool ok = RegExp(
      r'^[a-zA-Z0-9.!#$%&*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
    ).hasMatch(t);
    return ok ? null : l10n.completeProfileEmailInvalid;
  }

  Future<void> _onContinue() async {
    if (_saving) {
      return;
    }
    FocusScope.of(context).unfocus();
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
    if (!result.success) {
      showMndSnackBar(
        context,
        result.errorMessage ??
            AppLocalizations.of(context).completeProfileSaveFailed,
        variant: MndSnackBarVariant.error,
      );
      return;
    }
    final String? pending = ref.read(postAuthRedirectProvider);
    ref.read(postAuthRedirectProvider.notifier).state = null;
    context.go(
      pending != null && pending.isNotEmpty ? pending : AppRoutes.customer,
    );
  }

  Future<void> _onLogout() async {
    if (_saving) {
      return;
    }
    ref.read(postAuthRedirectProvider.notifier).state = null;
    await ref.read(phoneAuthControllerProvider.notifier).signOut();
    if (mounted) {
      context.go(AppRoutes.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    final CustomerProfile? profile =
        ref.watch(customerProfileStreamProvider).valueOrNull;
    _prefillOnce(profile);
    final String phone = profile?.phone ?? '';

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppColors.backgroundCanvas,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        const Icon(
                          Icons.account_circle_outlined,
                          size: 72,
                          color: AppColors.brandPrimary,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        Text(
                          l10n.completeProfileTitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          l10n.completeProfileSubtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          autofillHints: const <String>[AutofillHints.name],
                          decoration: InputDecoration(
                            labelText: '${l10n.completeProfileNameLabel} *',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                          validator: (String? v) => _validateName(v, l10n),
                          textInputAction: TextInputAction.next,
                          enabled: !_saving,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const <String>[AutofillHints.email],
                          decoration: InputDecoration(
                            labelText: l10n.completeProfileEmailLabel,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.mail_outline_rounded),
                            hintText: 'name@example.com',
                          ),
                          validator: (String? v) => _validateEmail(v, l10n),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _onContinue(),
                          enabled: !_saving,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        InputDecorator(
                          decoration: InputDecoration(
                            labelText: l10n.completeProfilePhoneLabel,
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.phone_outlined),
                            enabled: false,
                          ),
                          child: Text(
                            phone.isEmpty ? '—' : phone,
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        FilledButton(
                          onPressed: _saving ? null : _onContinue,
                          style: FilledButton.styleFrom(
                            minimumSize: const Size.fromHeight(52),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(l10n.completeProfileContinue),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        TextButton(
                          onPressed: _saving ? null : _onLogout,
                          child: Text(l10n.completeProfileWrongNumber),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
