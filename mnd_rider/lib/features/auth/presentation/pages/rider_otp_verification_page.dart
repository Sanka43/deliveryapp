import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_auth_gradient_scaffold.dart';

class RiderOtpVerificationPage extends ConsumerStatefulWidget {
  const RiderOtpVerificationPage({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
  });

  final String verificationId;
  final String phoneNumber;

  @override
  ConsumerState<RiderOtpVerificationPage> createState() =>
      _RiderOtpVerificationPageState();
}

class _RiderOtpVerificationPageState extends ConsumerState<RiderOtpVerificationPage> {
  final TextEditingController _otp = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final bool ok = await ref.read(riderPhoneAuthProvider.notifier).verifyOtp(
          verificationId: widget.verificationId,
          e164Phone: widget.phoneNumber,
          otp: _otp.text.trim(),
        );
    if (!mounted || !ok) {
      final String? err = ref.read(riderPhoneAuthProvider).errorMessage;
      if (err != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      }
      return;
    }

    final bool complete =
        ref.read(riderHasCompleteProfileProvider).valueOrNull ?? false;
    if (!mounted) {
      return;
    }
    context.go(complete ? RoutePaths.shell : RoutePaths.register);
  }

  Future<void> _resend() async {
    final String local = widget.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final String local9 = local.length > 9 ? local.substring(local.length - 9) : local;
    final String? verificationId =
        await ref.read(riderPhoneAuthProvider.notifier).sendOtp(local9);
    if (!mounted || verificationId == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('OTP sent again.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final RiderPhoneAuthState auth = ref.watch(riderPhoneAuthProvider);

    return RiderAuthGradientScaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Verify OTP'),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Enter the 6-digit code sent to\n${widget.phoneNumber}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), height: 1.4),
              ),
              const SizedBox(height: 28),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: <Widget>[
                      TextFormField(
                        controller: _otp,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 12,
                        ),
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: const InputDecoration(
                          hintText: '••••••',
                          border: OutlineInputBorder(),
                        ),
                        validator: (String? v) =>
                            const RiderRegistrationValidator().validateOtp(v ?? ''),
                        onFieldSubmitted: (_) => _verify(),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: auth.isLoading ? null : _verify,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Verify & continue'),
                      ),
                      TextButton(
                        onPressed: auth.isLoading ? null : _resend,
                        child: const Text('Resend code'),
                      ),
                    ],
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
