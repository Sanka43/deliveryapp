import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';

class OtpVerificationPage extends ConsumerStatefulWidget {
  const OtpVerificationPage({
    required this.verificationId,
    required this.phoneNumber,
    super.key,
  });

  final String verificationId;
  final String phoneNumber;

  @override
  ConsumerState<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends ConsumerState<OtpVerificationPage> {
  static const int _resendSeconds = 30;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _otpController = TextEditingController();
  Timer? _countdownTimer;
  late String _verificationId;
  int _secondsRemaining = _resendSeconds;

  @override
  void initState() {
    super.initState();
    _verificationId = widget.verificationId;
    if (widget.verificationId == kTemporaryOtpVerificationId) {
      _secondsRemaining = 0;
    } else {
      _startCountdown();
    }
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = _resendSeconds;
    });
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() {
          _secondsRemaining = 0;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  bool get _isTemporaryDevOtp =>
      widget.verificationId == kTemporaryOtpVerificationId;

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String code = _otpController.text.trim();
    final bool success = _isTemporaryDevOtp
        ? await ref
            .read(phoneAuthControllerProvider.notifier)
            .signInWithTemporaryOtp(
              phoneNumber: widget.phoneNumber,
              smsCode: code,
            )
        : await ref.read(phoneAuthControllerProvider.notifier).verifyOtp(
              verificationId: _verificationId,
              smsCode: code,
            );
    if (!mounted) {
      return;
    }
    if (success) {
      context.go(AppRoutes.splash);
    }
  }

  Future<void> _resendCode() async {
    if (_secondsRemaining > 0) {
      return;
    }

    if (_isTemporaryDevOtp) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Dev login does not send SMS. Use PIN 123456.'),
        ),
      );
      return;
    }

    final String? newVerificationId =
        await ref.read(phoneAuthControllerProvider.notifier).sendOtp(
              widget.phoneNumber,
            );
    if (!mounted) {
      return;
    }

    final String? errorMessage =
        ref.read(phoneAuthControllerProvider).errorMessage;
    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    if (newVerificationId == null) {
      return;
    }

    setState(() {
      _verificationId = newVerificationId;
    });
    _startCountdown();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP code resent successfully.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final PhoneAuthState authState = ref.watch(phoneAuthControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Enter verification code',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isTemporaryDevOtp
                      ? 'Dev mode: no SMS. Enter PIN 123456, then verify. Profile is saved to Firestore.'
                      : 'We sent a 6-digit OTP to ${widget.phoneNumber}.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.black54,
                      ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Row(
                  children: <Widget>[
                    Text(
                      _secondsRemaining > 0
                          ? 'Resend code in ${_secondsRemaining}s'
                          : 'Didn\'t receive the code?',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    TextButton(
                      onPressed: authState.isLoading || _secondsRemaining > 0
                          ? null
                          : _resendCode,
                      child: const Text('Resend'),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.xl),
                TextFormField(
                  controller: _otpController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(6),
                  ],
                  decoration: const InputDecoration(
                    hintText: 'Enter OTP',
                    filled: true,
                    fillColor: Color(0xFFF7F9FC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.all(Radius.circular(12)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  validator: (String? value) {
                    final String otp = value?.trim() ?? '';
                    if (otp.length != 6) {
                      return 'Enter valid 6-digit OTP';
                    }
                    return null;
                  },
                ),
                if (authState.errorMessage != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    authState.errorMessage!,
                    style: const TextStyle(color: AppColors.error),
                  ),
                ],
                const SizedBox(height: AppSpacing.lg),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: authState.isLoading ? null : _verifyOtp,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                      backgroundColor: AppColors.primaryBlue,
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Verify & Continue'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
