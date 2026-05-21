import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_auth_gradient_scaffold.dart';

class RiderPhoneLoginPage extends ConsumerStatefulWidget {
  const RiderPhoneLoginPage({super.key});

  @override
  ConsumerState<RiderPhoneLoginPage> createState() => _RiderPhoneLoginPageState();
}

class _RiderPhoneLoginPageState extends ConsumerState<RiderPhoneLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool _usePassword = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _continueWithOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String? verificationId = await ref
        .read(riderPhoneAuthProvider.notifier)
        .sendOtp(_phone.text.trim());
    if (!mounted) {
      return;
    }
    final String? error = ref.read(riderPhoneAuthProvider).errorMessage;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    if (verificationId == null) {
      return;
    }
    final String e164 =
        normalizeSriLankaPhone(RiderPhoneAuthController.dialCode, _phone.text.trim());
    context.push(
      Uri(
        path: RoutePaths.otp,
        queryParameters: <String, String>{
          'verificationId': verificationId,
          'phone': e164,
        },
      ).toString(),
    );
  }

  Future<void> _signInWithPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final bool ok = await ref.read(riderPhoneAuthProvider.notifier).signInWithPassword(
          localPhoneDigits: _phone.text.trim(),
          password: _password.text,
        );
    if (!mounted) {
      return;
    }
    if (!ok) {
      final String? error = ref.read(riderPhoneAuthProvider).errorMessage;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      }
      return;
    }

    final String uid = ref.read(riderAuthStateProvider).valueOrNull?.uid ?? '';
    if (uid.isEmpty) {
      return;
    }
    final profile =
        await ref.read(riderAuthRepositoryProvider).fetchRiderProfile(uid);
    if (!mounted) {
      return;
    }
    context.go(
      profile?.isRegistrationComplete == true
          ? RoutePaths.shell
          : RoutePaths.register,
    );
  }

  @override
  Widget build(BuildContext context) {
    final RiderPhoneAuthState auth = ref.watch(riderPhoneAuthProvider);

    return RiderAuthGradientScaffold(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const SizedBox(height: 24),
              const Icon(Icons.two_wheeler_rounded, size: 56, color: Colors.white),
              const SizedBox(height: 20),
              const Text(
                'MND Rider',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _usePassword
                    ? 'Sign in with your phone and password'
                    : 'Enter your mobile number to receive an OTP',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.88)),
              ),
              const SizedBox(height: 36),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Text(
                              '+94',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextFormField(
                              controller: _phone,
                              keyboardType: TextInputType.phone,
                              inputFormatters: <TextInputFormatter>[
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Mobile number',
                                hintText: '771234567 or 0771234567',
                              ),
                              validator: (String? v) => const RiderRegistrationValidator()
                                  .validatePhoneLogin(v ?? ''),
                            ),
                          ),
                        ],
                      ),
                      if (_usePassword) ...<Widget>[
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          validator: (String? v) {
                            if ((v ?? '').length < 8) {
                              return 'Enter your password';
                            }
                            return null;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.isLoading
                            ? null
                            : (_usePassword ? _signInWithPassword : _continueWithOtp),
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(_usePassword ? 'Sign in' : 'Send OTP'),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: auth.isLoading
                            ? null
                            : () => setState(() => _usePassword = !_usePassword),
                        child: Text(
                          _usePassword
                              ? 'Use OTP instead'
                              : 'Sign in with password instead',
                        ),
                      ),
                      if (kDebugMode && !_usePassword) ...<Widget>[
                        const SizedBox(height: 4),
                        OutlinedButton(
                          onPressed: auth.isLoading
                              ? null
                              : () {
                                  final String e164 = normalizeSriLankaPhone(
                                    RiderPhoneAuthController.dialCode,
                                    _phone.text.trim(),
                                  );
                                  context.push(
                                    Uri(
                                      path: RoutePaths.otp,
                                      queryParameters: <String, String>{
                                        'verificationId': kTemporaryOtpVerificationId,
                                        'phone': e164,
                                      },
                                    ).toString(),
                                  );
                                },
                          child: const Text('Dev: use OTP 123456'),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => context.push(RoutePaths.register),
                child: const Text(
                  'New rider? Register',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
