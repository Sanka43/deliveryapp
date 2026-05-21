import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  String _selectedDialCode = '+94';

  final List<String> _dialCodes = <String>['+94', '+91', '+1', '+44'];

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  void _onTemporaryDevOtp(WidgetRef ref) {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String fullPhoneNumber =
        '$_selectedDialCode${_phoneController.text.trim()}';
    context.go(
      Uri(
        path: AppRoutes.otp,
        queryParameters: <String, String>{
          'verificationId': kTemporaryOtpVerificationId,
          'phone': fullPhoneNumber,
        },
      ).toString(),
    );
  }

  Future<void> _onContinue(WidgetRef ref) async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final String fullPhoneNumber =
        '$_selectedDialCode${_phoneController.text.trim()}';
    final String? verificationId = await ref
        .read(phoneAuthControllerProvider.notifier)
        .sendOtp(fullPhoneNumber);
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

    if (verificationId == null) {
      return;
    }

    context.go(
      Uri(
        path: AppRoutes.otp,
        queryParameters: <String, String>{
          'verificationId': verificationId,
          'phone': fullPhoneNumber,
        },
      ).toString(),
    );
  }

  void _onGuestContinue(WidgetRef ref) {
    ref.read(guestBrowsingProvider.notifier).state = true;
    context.go(AppRoutes.customer);
  }

  Future<void> _onGoogleSignIn(WidgetRef ref) async {
    final bool success =
        await ref.read(phoneAuthControllerProvider.notifier).signInWithGoogle();
    if (!mounted || success) {
      return;
    }
    final String? errorMessage =
        ref.read(phoneAuthControllerProvider).errorMessage;
    if (errorMessage == null) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(errorMessage)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (BuildContext context, WidgetRef ref, Widget? child) {
        final PhoneAuthState authState = ref.watch(phoneAuthControllerProvider);

        return Scaffold(
          body: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: <Color>[
                  Color(0xFFEDF4FF),
                  Colors.white,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.local_shipping_outlined,
                        color: AppColors.primaryBlue,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    Text(
                      'Welcome back',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sign in with your phone number to continue with MND Delivery.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.black54,
                          ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Card(
                      elevation: 0,
                      color: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side:
                            BorderSide(color: Colors.black.withValues(alpha: 0.08)),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                'Phone Number',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: <Widget>[
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpacing.sm),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF7F9FC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: Colors.black12),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedDialCode,
                                        borderRadius: BorderRadius.circular(12),
                                        items: _dialCodes
                                            .map(
                                              (String code) =>
                                                  DropdownMenuItem<String>(
                                                value: code,
                                                child: Text(code),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (String? value) {
                                          if (value == null) {
                                            return;
                                          }
                                          setState(() {
                                            _selectedDialCode = value;
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: TextFormField(
                                      controller: _phoneController,
                                      keyboardType: TextInputType.phone,
                                      inputFormatters: <TextInputFormatter>[
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(10),
                                      ],
                                      decoration: const InputDecoration(
                                        hintText: 'Enter phone number',
                                        filled: true,
                                        fillColor: Color(0xFFF7F9FC),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(12)),
                                          borderSide: BorderSide.none,
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(12)),
                                          borderSide: BorderSide.none,
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.all(
                                              Radius.circular(12)),
                                          borderSide: BorderSide(
                                            color: AppColors.primaryBlue,
                                            width: 1.5,
                                          ),
                                        ),
                                      ),
                                      validator: (String? value) {
                                        final String phone = value?.trim() ?? '';
                                        if (phone.isEmpty) {
                                          return 'Phone number is required';
                                        }
                                        if (phone.length < 9) {
                                          return 'Enter a valid phone number';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton(
                                  onPressed: authState.isLoading
                                      ? null
                                      : () => _onContinue(ref),
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: AppSpacing.md),
                                    backgroundColor: AppColors.primaryBlue,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: authState.isLoading
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Text('Continue'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              Row(
                                children: <Widget>[
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.sm,
                                    ),
                                    child: Text(
                                      'or',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall
                                          ?.copyWith(color: Colors.black54),
                                    ),
                                  ),
                                  const Expanded(child: Divider()),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: authState.isLoading
                                      ? null
                                      : () => _onGoogleSignIn(ref),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.md,
                                    ),
                                    side: BorderSide(
                                      color: Colors.black.withValues(alpha: 0.12),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: const Icon(
                                    Icons.g_mobiledata_rounded,
                                    color: AppColors.primaryBlue,
                                  ),
                                  label: const Text('Continue with Google'),
                                ),
                              ),
                              const SizedBox(height: AppSpacing.md),
                              SizedBox(
                                width: double.infinity,
                                child: TextButton(
                                  onPressed: authState.isLoading
                                      ? null
                                      : () => _onGuestContinue(ref),
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: AppSpacing.sm,
                                    ),
                                    foregroundColor: Colors.black54,
                                  ),
                                  child: const Text('Continue as guest'),
                                ),
                              ),
                              if (kDebugMode) ...<Widget>[
                                const SizedBox(height: AppSpacing.lg),
                                Text(
                                  'Developer',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        color: Colors.black45,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                Text(
                                  'Skip SMS: OTP screen use PIN 123456. Saves profile to Firestore (Email/Password must be enabled in Firebase).',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: Colors.black45,
                                      ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  width: double.infinity,
                                  child: OutlinedButton(
                                    onPressed: authState.isLoading
                                        ? null
                                        : () => _onTemporaryDevOtp(ref),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.deepOrange,
                                      side: const BorderSide(color: Colors.deepOrange),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Text('Temporary OTP login (123456)'),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
