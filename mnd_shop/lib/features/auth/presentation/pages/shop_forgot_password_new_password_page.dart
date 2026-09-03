import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/auth/data/shop_password_reset_repository.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_auth_form_chrome.dart';

class ShopForgotPasswordNewPasswordPage extends ConsumerStatefulWidget {
  const ShopForgotPasswordNewPasswordPage({
    required this.email,
    required this.resetToken,
    super.key,
  });

  final String email;
  final String resetToken;

  @override
  ConsumerState<ShopForgotPasswordNewPasswordPage> createState() =>
      _ShopForgotPasswordNewPasswordPageState();
}

class _ShopForgotPasswordNewPasswordPageState
    extends ConsumerState<ShopForgotPasswordNewPasswordPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirm = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return shopAuthTxt(
        context,
        en: 'Enter a new password',
        si: 'නව මුරපදයක් ඇතුල් කරන්න',
      );
    }
    if (value.length < 6) {
      return shopAuthTxt(
        context,
        en: 'Password must be at least 6 characters',
        si: 'මුරපදය අවම වශයෙන් අකුරු 6ක් විය යුතුය',
      );
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return shopAuthTxt(
        context,
        en: 'Confirm your new password',
        si: 'නව මුරපදය තහවුරු කරන්න',
      );
    }
    if (value != _password.text) {
      return shopAuthTxt(
        context,
        en: 'Passwords do not match',
        si: 'මුරපද නොගැලපේ',
      );
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(shopPasswordResetRepositoryProvider).confirmNewPassword(
            email: widget.email,
            resetToken: widget.resetToken,
            newPassword: _password.text,
          );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shopAuthTxt(
              context,
              en: 'Password updated. Sign in with your new password.',
              si: 'මුරපදය යාවත්කාලීන විය. නව මුරපදයෙන් පිවිසෙන්න.',
            ),
          ),
        ),
      );
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    } on ShopPasswordResetException catch (e) {
      setState(
        () => _error = userFacingError(
          e,
          fallback: 'Could not update password. Please try again.',
        ),
      );
    } catch (e) {
      setState(
        () => _error = userFacingError(
          e,
          fallback: 'Could not update password. Please try again.',
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return ShopAuthPageScaffold(
      child: Form(
        key: _formKey,
        child: ShopAuthFormCard(
          title: shopAuthTxt(
            context,
            en: 'New password',
            si: 'නව මුරපදය',
          ),
          subtitle: shopAuthTxt(
            context,
            en: 'Choose a new password for ${widget.email}',
            si: '${widget.email} සඳහා නව මුරපදයක් තෝරන්න',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                shopAuthTxt(
                  context,
                  en: 'New password',
                  si: 'නව මුරපදය',
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _password,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: _validatePassword,
                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                decoration: shopAuthInputDecoration(
                  context,
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? shopAuthTxt(
                            context,
                            en: 'Show password',
                            si: 'මුරපදය පෙන්වන්න',
                          )
                        : shopAuthTxt(
                            context,
                            en: 'Hide password',
                            si: 'මුරපදය සඟවන්න',
                          ),
                    onPressed: _busy
                        ? null
                        : () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                shopAuthTxt(
                  context,
                  en: 'Confirm password',
                  si: 'මුරපදය තහවුරු කරන්න',
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _confirm,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.newPassword],
                validator: _validateConfirm,
                onFieldSubmitted: (_) => _submit(),
                decoration: shopAuthInputDecoration(
                  context,
                  hintText: '••••••••',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscureConfirm
                        ? shopAuthTxt(
                            context,
                            en: 'Show password',
                            si: 'මුරපදය පෙන්වන්න',
                          )
                        : shopAuthTxt(
                            context,
                            en: 'Hide password',
                            si: 'මුරපදය සඟවන්න',
                          ),
                    onPressed: _busy
                        ? null
                        : () => setState(
                              () => _obscureConfirm = !_obscureConfirm,
                            ),
                    icon: Icon(
                      _obscureConfirm
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              if (_error != null) ...<Widget>[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.error),
                ),
              ],
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _submit,
                  style: shopAuthPrimaryButtonStyle(),
                  icon: _busy
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _busy
                        ? shopAuthTxt(
                            context,
                            en: 'Saving...',
                            si: 'සුරකිමින්...',
                          )
                        : shopAuthTxt(
                            context,
                            en: 'Update password',
                            si: 'මුරපදය යාවත්කාලීන කරන්න',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: Text(
                  shopAuthTxt(
                    context,
                    en: 'After updating, sign in with your new password.',
                    si: 'යාවත්කාලීන කිරීමෙන් පසු නව මුරපදයෙන් පිවිසෙන්න.',
                  ),
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
