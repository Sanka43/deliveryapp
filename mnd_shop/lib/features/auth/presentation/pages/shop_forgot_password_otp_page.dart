import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/features/auth/data/shop_password_reset_repository.dart';
import 'package:mnd_shop/features/auth/presentation/pages/shop_forgot_password_new_password_page.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_auth_form_chrome.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_otp_pin_field.dart';

class ShopForgotPasswordOtpPage extends ConsumerStatefulWidget {
  const ShopForgotPasswordOtpPage({required this.email, super.key});

  final String email;

  @override
  ConsumerState<ShopForgotPasswordOtpPage> createState() =>
      _ShopForgotPasswordOtpPageState();
}

class _ShopForgotPasswordOtpPageState
    extends ConsumerState<ShopForgotPasswordOtpPage> {
  final TextEditingController _otp = TextEditingController();

  bool _busy = false;
  bool _resending = false;
  String? _otpError;
  String? _error;

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final String code = _otp.text.trim();
    if (code.length != 6) {
      setState(() {
        _otpError = shopAuthTxt(
          context,
          en: 'Enter the 6-digit code',
          si: 'ඉලක්කම් 6ක කේතය ඇතුල් කරන්න',
        );
        _error = null;
      });
      return;
    }

    setState(() {
      _busy = true;
      _otpError = null;
      _error = null;
    });
    try {
      final String resetToken = await ref
          .read(shopPasswordResetRepositoryProvider)
          .verifyOtp(email: widget.email, otp: code);
      if (!mounted) {
        return;
      }
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => ShopForgotPasswordNewPasswordPage(
            email: widget.email,
            resetToken: resetToken,
          ),
        ),
      );
    } on ShopPasswordResetException catch (e) {
      setState(() {
        _otpError = e.message;
        _error = e.message;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
      _otpError = null;
    });
    try {
      final ShopPasswordResetRequestResult result = await ref
          .read(shopPasswordResetRepositoryProvider)
          .requestOtp(widget.email);
      if (!mounted) {
        return;
      }
      _otp.clear();
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
                en: 'A new code was sent if the account exists.',
                si: 'ගිණුම තිබේ නම් නව කේතයක් යවන ලදී.',
              ),
            ),
          ),
        );
      }
    } on ShopPasswordResetException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _resending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool blocked = _busy || _resending;

    return ShopAuthPageScaffold(
      child: ShopAuthFormCard(
        title: shopAuthTxt(
          context,
          en: 'Enter code',
          si: 'කේතය ඇතුල් කරන්න',
        ),
        subtitle: shopAuthTxt(
          context,
          en: 'We sent a 6-digit code to ${widget.email}',
          si: '${widget.email} වෙත ඉලක්කම් 6ක කේතයක් යවන ලදී',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            ShopOtpPinField(
              controller: _otp,
              errorText: _otpError,
              onCompleted: blocked ? null : _verify,
            ),
            if (_error != null && _error != _otpError) ...<Widget>[
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
                onPressed: blocked ? null : _verify,
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
                    : const Icon(Icons.verified_outlined),
                label: Text(
                  _busy
                      ? shopAuthTxt(
                          context,
                          en: 'Verifying...',
                          si: 'තහවුරු කරමින්...',
                        )
                      : shopAuthTxt(
                          context,
                          en: 'Verify code',
                          si: 'කේතය තහවුරු කරන්න',
                        ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.center,
              child: TextButton(
                onPressed: blocked ? null : _resend,
                child: Text(
                  _resending
                      ? shopAuthTxt(
                          context,
                          en: 'Sending...',
                          si: 'යවමින්...',
                        )
                      : shopAuthTxt(
                          context,
                          en: 'Resend code',
                          si: 'කේතය නැවත යවන්න',
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
    );
  }
}
