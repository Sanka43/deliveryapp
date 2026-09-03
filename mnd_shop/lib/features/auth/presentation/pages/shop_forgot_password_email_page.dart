import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/auth/data/shop_password_reset_repository.dart';
import 'package:mnd_shop/features/auth/presentation/pages/shop_forgot_password_otp_page.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_auth_form_chrome.dart';

class ShopForgotPasswordEmailPage extends ConsumerStatefulWidget {
  const ShopForgotPasswordEmailPage({this.initialEmail, super.key});

  final String? initialEmail;

  @override
  ConsumerState<ShopForgotPasswordEmailPage> createState() =>
      _ShopForgotPasswordEmailPageState();
}

class _ShopForgotPasswordEmailPageState
    extends ConsumerState<ShopForgotPasswordEmailPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _email;

  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _email = TextEditingController(text: widget.initialEmail?.trim() ?? '');
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    final String t = value?.trim() ?? '';
    if (t.isEmpty) {
      return shopAuthTxt(
        context,
        en: 'Enter your email',
        si: 'ඔබේ email එක ඇතුල් කරන්න',
      );
    }
    if (!t.contains('@') || t.length < 5) {
      return shopAuthTxt(
        context,
        en: 'Enter a valid email address',
        si: 'වලංගු email ලිපිනයක් ඇතුල් කරන්න',
      );
    }
    return null;
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    final String email = _email.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final ShopPasswordResetRequestResult result =
          await ref.read(shopPasswordResetRepositoryProvider).requestOtp(email);
      if (!mounted) {
        return;
      }
      if (kDebugMode && result.debugOtp != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Debug OTP: ${result.debugOtp}'),
            duration: const Duration(seconds: 8),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              shopAuthTxt(
                context,
                en: 'If an account exists for that email, a code was sent.',
                si: 'එම email සඳහා ගිණුමක් තිබේ නම් කේතයක් යවන ලදී.',
              ),
            ),
          ),
        );
      }
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (_) => ShopForgotPasswordOtpPage(email: email),
        ),
      );
    } on ShopPasswordResetException catch (e) {
      setState(
        () => _error = userFacingError(
          e,
          fallback: 'Could not send reset code. Please try again.',
        ),
      );
    } catch (e) {
      setState(
        () => _error = userFacingError(
          e,
          fallback: 'Could not send reset code. Please try again.',
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
            en: 'Forgot password',
            si: 'මුරපදය අමතකද',
          ),
          subtitle: shopAuthTxt(
            context,
            en: 'Enter your shop email and we will send a 6-digit code.',
            si: 'ඔබේ shop email එක ඇතුල් කරන්න. අපි 6-ඉලක්කම් කේතයක් යවමු.',
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                shopAuthTxt(
                  context,
                  en: 'Email Address',
                  si: 'Email ලිපිනය',
                ),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.done,
                autocorrect: false,
                autofillHints: const <String>[AutofillHints.email],
                validator: _validateEmail,
                onFieldSubmitted: (_) => _submit(),
                decoration: shopAuthInputDecoration(
                  context,
                  hintText: 'name@yourshop.com',
                  prefixIcon: const Icon(Icons.mail_outline_rounded),
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
                      : const Icon(Icons.send_rounded),
                  label: Text(
                    _busy
                        ? shopAuthTxt(
                            context,
                            en: 'Sending...',
                            si: 'යවමින්...',
                          )
                        : shopAuthTxt(
                            context,
                            en: 'Send code',
                            si: 'කේතය යවන්න',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.center,
                child: TextButton(
                  onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
                  child: Text(
                    shopAuthTxt(
                      context,
                      en: 'Back to sign in',
                      si: 'පිවිසුමට ආපසු',
                    ),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w600,
                    ),
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
