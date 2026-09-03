import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/utils/phone_number_utils.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_snackbar.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/guest_browsing_provider.dart';
import 'package:mnd_delivery_app/features/auth/presentation/providers/phone_auth_controller.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';

enum _LoginStep { phone, otp }

/// Login — bike hero, brand, slogan, phone, then an in-page OTP step that
/// slides in from the right (phone content slides out to the left).
class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage>
    with SingleTickerProviderStateMixin {
  static const Color _fieldFill = Colors.white;
  static const Color _ink = AppColors.textPrimary;
  static const Color _muted = AppColors.textSecondary;
  static const Color _cyan = AppColors.brandSecondary;

  static const int _otpLength = 6;
  static const int _resendSeconds = 30;
  static const String _smsHelpHint =
      "Didn't get a code? Check mobile signal, tap Resend, "
      'or try again later. Some networks deliver SMS slower than others.';

  // ── Phone step ──
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();
  final String _selectedDialCode = '+94';
  bool _isSubmitting = false;

  // ── Step transition ──
  _LoginStep _step = _LoginStep.phone;
  late final AnimationController _stepController;
  late final Animation<Offset> _phoneSlideOut;
  late final Animation<Offset> _otpSlideIn;
  String _verifiedPhoneNumber = '';

  // ── OTP step ──
  final List<TextEditingController> _otpDigitControllers =
      List<TextEditingController>.generate(
    _otpLength,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _otpDigitFocusNodes = List<FocusNode>.generate(
    _otpLength,
    (_) => FocusNode(),
  );
  Timer? _countdownTimer;
  int _secondsRemaining = _resendSeconds;
  int _resendAttempts = 0;
  String? _otpError;
  bool _isDistributingDigits = false;
  bool _verifyQueued = false;

  @override
  void initState() {
    super.initState();
    _stepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
      reverseDuration: const Duration(milliseconds: 320),
    );
    _phoneSlideOut = Tween<Offset>(
      begin: Offset.zero,
      end: const Offset(-1, 0),
    ).animate(
      CurvedAnimation(
        parent: _stepController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );
    _otpSlideIn = Tween<Offset>(
      begin: const Offset(1, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _stepController,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      ),
    );

    for (int i = 0; i < _otpLength; i++) {
      final int index = i;
      _otpDigitFocusNodes[index].addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      _otpDigitFocusNodes[index].onKeyEvent = (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _otpDigitControllers[index].text.isEmpty &&
            index > 0) {
          _otpDigitControllers[index - 1].clear();
          _otpDigitFocusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocus.dispose();
    _stepController.dispose();
    _countdownTimer?.cancel();
    for (final TextEditingController controller in _otpDigitControllers) {
      controller.dispose();
    }
    for (final FocusNode node in _otpDigitFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _fullPhoneNumber => PhoneNumberUtils.toE164(
        dialCode: _selectedDialCode,
        nationalNumber: _phoneController.text,
      );

  void _showSnack(String message) {
    showMndSnackBar(context, message);
  }

  Future<void> _onContinue() async {
    if (_isSubmitting || ref.read(phoneAuthControllerProvider).isLoading) {
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    _isSubmitting = true;
    try {
      final String fullPhoneNumber = _fullPhoneNumber;
      final String? verificationId = await ref
          .read(phoneAuthControllerProvider.notifier)
          .sendOtp(fullPhoneNumber);
      if (!mounted) {
        return;
      }

      final String? errorMessage =
          ref.read(phoneAuthControllerProvider).errorMessage;
      if (errorMessage != null) {
        _showSnack(errorMessage);
        return;
      }

      if (verificationId == null) {
        ref.read(guestBrowsingProvider.notifier).state = false;
        return;
      }

      _enterOtpStep(fullPhoneNumber);
    } finally {
      _isSubmitting = false;
    }
  }

  void _enterOtpStep(String phoneNumber) {
    final PhoneAuthController auth =
        ref.read(phoneAuthControllerProvider.notifier);
    if (auth.pendingVerificationId == null ||
        auth.pendingVerificationId!.isEmpty) {
      return;
    }

    setState(() {
      _step = _LoginStep.otp;
      _verifiedPhoneNumber = phoneNumber;
      _otpError = null;
      _resendAttempts = 0;
    });
    _clearOtpBoxes();
    _startOtpCountdown();
    _stepController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _otpDigitFocusNodes.first.requestFocus();
    });
  }

  void _goToPhoneStep() {
    if (_step != _LoginStep.otp) {
      return;
    }
    _countdownTimer?.cancel();
    setState(() => _step = _LoginStep.phone);
    _stepController.reverse();
  }

  void _onGuestContinue() {
    ref.read(guestBrowsingProvider.notifier).state = true;
    context.go(AppRoutes.customer);
  }

  // ── OTP helpers ──

  void _startOtpCountdown() {
    _countdownTimer?.cancel();
    _secondsRemaining = _resendSeconds;
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

  String get _otpCode =>
      _otpDigitControllers.map((TextEditingController c) => c.text).join();

  void _clearOtpBoxes() {
    _isDistributingDigits = true;
    for (final TextEditingController controller in _otpDigitControllers) {
      controller.clear();
    }
    _isDistributingDigits = false;
  }

  void _onOtpDigitChanged(int index, String value) {
    if (_isDistributingDigits) {
      return;
    }

    setState(() => _otpError = null);
    ref.read(phoneAuthControllerProvider.notifier).clearError();

    if (value.length > 1) {
      // Paste / autofill: distribute digits across boxes.
      final String digits = value.replaceAll(RegExp(r'\D'), '');
      _isDistributingDigits = true;
      for (int i = 0; i < _otpLength; i++) {
        _otpDigitControllers[i].text = i < digits.length ? digits[i] : '';
      }
      _isDistributingDigits = false;
      final int focusIndex = digits.length.clamp(0, _otpLength) - 1;
      if (digits.length >= _otpLength) {
        _otpDigitFocusNodes[_otpLength - 1].unfocus();
        _verifyOtp();
      } else if (focusIndex >= 0) {
        _otpDigitFocusNodes[focusIndex + 1].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty && index < _otpLength - 1) {
      _otpDigitFocusNodes[index + 1].requestFocus();
    }

    if (_otpCode.length == _otpLength) {
      _verifyOtp();
    }
  }

  Future<void> _verifyOtp() async {
    if (_verifyQueued || ref.read(phoneAuthControllerProvider).isLoading) {
      return;
    }
    _verifyQueued = true;

    try {
      final String code = _otpCode.replaceAll(RegExp(r'\D'), '');
      if (code.length != _otpLength) {
        setState(() => _otpError = 'Enter the full 6-digit code');
        return;
      }

      final bool success =
          await ref.read(phoneAuthControllerProvider.notifier).verifyOtp(
                smsCode: code,
              );
      if (!mounted) {
        return;
      }
      if (success) {
        ref.read(guestBrowsingProvider.notifier).state = false;
        // Prefetch profile into the stream so home header is not empty on first frame.
        ref.invalidate(customerProfileStreamProvider);
        try {
          await ref.read(customerProfileStreamProvider.future);
        } catch (_) {}
        if (!mounted) {
          return;
        }
        // Skip splash so postAuthRedirect is not raced by splash → home.
        final String? pending = ref.read(postAuthRedirectProvider);
        if (pending != null && pending.isNotEmpty) {
          ref.read(postAuthRedirectProvider.notifier).state = null;
          context.go(pending);
        } else {
          context.go(AppRoutes.customer);
        }
      }
    } finally {
      _verifyQueued = false;
    }
  }

  Future<void> _resendOtpCode() async {
    if (_secondsRemaining > 0) {
      return;
    }

    final String? newVerificationId =
        await ref.read(phoneAuthControllerProvider.notifier).sendOtp(
              _verifiedPhoneNumber,
              forceResend: true,
            );
    if (!mounted) {
      return;
    }

    final String? errorMessage =
        ref.read(phoneAuthControllerProvider).errorMessage;
    if (errorMessage != null) {
      _showSnack(errorMessage);
      return;
    }

    if (newVerificationId == null) {
      // In-flight / race — do not drop guest browsing.
      return;
    }

    setState(() {
      _otpError = null;
      _resendAttempts++;
    });
    _clearOtpBoxes();
    _otpDigitFocusNodes.first.requestFocus();
    _startOtpCountdown();
    _showSnack('OTP code resent successfully.');
  }

  @override
  Widget build(BuildContext context) {
    final PhoneAuthState authState = ref.watch(phoneAuthControllerProvider);
    final Size size = MediaQuery.sizeOf(context);
    final bool isOtpStep = _step == _LoginStep.otp;

    return PopScope(
      canPop: !isOtpStep,
      onPopInvokedWithResult: (bool didPop, Object? result) {
        if (didPop) {
          return;
        }
        if (isOtpStep) {
          _goToPhoneStep();
        }
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              // Delivery hero photo — full-bleed background.
              Positioned.fill(
                child: IgnorePointer(
                  child: Image.asset(
                    'assets/images/auth/login_hero.jpg',
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
              // Bottom-to-top scrim — black at the bottom fading to transparent up top.
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.55),
                          Colors.black,
                        ],
                        stops: const <double>[0.0, 0.55, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: LayoutBuilder(
                  builder: (BuildContext context, BoxConstraints constraints) {
                    return ClipRect(
                      child: Stack(
                        children: <Widget>[
                          Positioned.fill(
                            child: SlideTransition(
                              position: _phoneSlideOut,
                              child: IgnorePointer(
                                ignoring: isOtpStep,
                                child: _buildPhoneStep(
                                  context,
                                  authState,
                                  size,
                                  constraints,
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: SlideTransition(
                              position: _otpSlideIn,
                              child: IgnorePointer(
                                ignoring: !isOtpStep,
                                child: _buildOtpStep(
                                  context,
                                  authState,
                                  constraints,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep(
    BuildContext context,
    PhoneAuthState authState,
    Size size,
    BoxConstraints constraints,
  ) {
    final OutlineInputBorder quietBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(28),
      borderSide: BorderSide(color: AppColors.brandPrimary.withValues(alpha: 0.14)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: constraints.maxHeight),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const SizedBox(height: AppSpacing.xxl),
              Text(
                'MASTER N DELIVERY',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.brandPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                'Everything You Need, One App',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      height: 1.08,
                    ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Sign in to order food, shop for groceries, book a ride, '
                'or find your next job.',
                textAlign: TextAlign.left,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w400,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    height: 56,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: _fieldFill,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: AppColors.brandPrimary.withValues(alpha: 0.14),
                      ),
                      boxShadow: AppColors.cardShadow,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _selectedDialCode,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _ink,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: TextFormField(
                      controller: _phoneController,
                      focusNode: _phoneFocus,
                      keyboardType: TextInputType.phone,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: _ink,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.4,
                          ),
                      cursorColor: _cyan,
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      onFieldSubmitted: (_) {
                        if (!authState.isLoading) {
                          _onContinue();
                        }
                      },
                      decoration: InputDecoration(
                        hintText: 'Phone number',
                        hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: _muted.withValues(alpha: 0.6),
                              fontWeight: FontWeight.w400,
                            ),
                        prefixIcon: Icon(
                          Icons.phone_iphone_rounded,
                          color: _muted.withValues(alpha: 0.7),
                          size: 20,
                        ),
                        filled: true,
                        fillColor: _fieldFill,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        border: quietBorder,
                        enabledBorder: quietBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: BorderSide(
                            color: _cyan.withValues(alpha: 0.65),
                          ),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                        focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(28),
                          borderSide: const BorderSide(color: AppColors.error),
                        ),
                        errorStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.error,
                            ),
                      ),
                      validator: (String? value) {
                        return PhoneNumberUtils.validateNationalNumber(
                          dialCode: _selectedDialCode,
                          nationalNumber: value,
                        );
                      },
                    ),
                  ),
                ],
              ),
              if (authState.errorMessage != null) ...<Widget>[
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    authState.errorMessage!,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppColors.error,
                          height: 1.35,
                        ),
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: FilledButton(
                  onPressed: authState.isLoading ? null : _onContinue,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.brandPrimary,
                    disabledBackgroundColor:
                        AppColors.brandPrimary.withValues(alpha: 0.45),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shadowColor: AppColors.brandPrimary.withValues(alpha: 0.35),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: authState.isLoading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            Text(
                              'Continue',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: 0.3,
                                  ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            const Icon(Icons.arrow_forward_rounded, size: 18),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              SizedBox(
                height: 56,
                width: double.infinity,
                child: TextButton(
                  onPressed: authState.isLoading ? null : _onGuestContinue,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    'Browse as guest',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.2,
                          decoration: TextDecoration.underline,
                          decorationColor: Colors.white.withValues(alpha: 0.9),
                        ),
                  ),
                ),
              ),
              if (kIsWeb) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'This site is protected by reCAPTCHA and the Google '
                  'Privacy Policy and Terms of Service apply.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.65),
                        height: 1.35,
                      ),
                ),
              ],
              // Clear home indicator / gesture bar.
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOtpStep(
    BuildContext context,
    PhoneAuthState authState,
    BoxConstraints constraints,
  ) {
    final String? errorText = _otpError ?? authState.errorMessage;

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.sm,
            AppSpacing.sm,
            AppSpacing.sm,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Material(
              color: Colors.black.withValues(alpha: 0.28),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: authState.isLoading ? null : _goToPhoneStep,
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 52),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'VERIFY',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppColors.brandPrimary,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 3,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Enter your code',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          height: 1.08,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    'Enter the 6-digit code sent to $_verifiedPhoneNumber',
                    textAlign: TextAlign.left,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          fontWeight: FontWeight.w400,
                          height: 1.4,
                        ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  _OtpBoxes(
                    controllers: _otpDigitControllers,
                    focusNodes: _otpDigitFocusNodes,
                    enabled: !authState.isLoading,
                    hasError: errorText != null,
                    onChanged: _onOtpDigitChanged,
                  ),
                  if (errorText != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      errorText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: AppColors.error,
                            height: 1.35,
                          ),
                    ),
                  ],
                  if (_secondsRemaining == 0 || _resendAttempts >= 1) ...<Widget>[
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      _smsHelpHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.65),
                            height: 1.4,
                          ),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.xl),
                  SizedBox(
                    height: 56,
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: authState.isLoading ? null : _verifyOtp,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.brandPrimary,
                        disabledBackgroundColor:
                            AppColors.brandPrimary.withValues(alpha: 0.45),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: AppColors.brandPrimary.withValues(alpha: 0.35),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      child: authState.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text(
                                  'Verify & continue',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.3,
                                      ),
                                ),
                                const SizedBox(width: AppSpacing.xs),
                                const Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Center(
                    child: Column(
                      children: <Widget>[
                        Text(
                          _secondsRemaining > 0
                              ? 'Resend in ${_secondsRemaining}s'
                              : "Didn't get the code?",
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontWeight: FontWeight.w400,
                              ),
                        ),
                        TextButton(
                          onPressed: authState.isLoading || _secondsRemaining > 0
                              ? null
                              : _resendOtpCode,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            disabledForegroundColor: Colors.white,
                          ).copyWith(
                            overlayColor: WidgetStateProperty.all(
                              Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Text(
                            'Resend',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.white,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OtpBoxes extends StatelessWidget {
  const _OtpBoxes({
    required this.controllers,
    required this.focusNodes,
    required this.enabled,
    required this.hasError,
    required this.onChanged,
  });

  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool enabled;
  final bool hasError;
  final void Function(int index, String value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List<Widget>.generate(controllers.length, (int index) {
        final bool isFocused = focusNodes[index].hasFocus;
        final bool hasDigit = controllers[index].text.isNotEmpty;

        final Color borderColor;
        if (hasError) {
          borderColor = AppColors.error;
        } else if (isFocused) {
          borderColor = AppColors.brandSecondary.withValues(alpha: 0.65);
        } else if (hasDigit) {
          borderColor = AppColors.brandPrimary.withValues(alpha: 0.28);
        } else {
          borderColor = AppColors.brandPrimary.withValues(alpha: 0.14);
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 5,
              right: index == controllers.length - 1 ? 0 : 5,
            ),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1.5),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                enabled: enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                maxLength: 6,
                autofillHints: index == 0
                    ? const <String>[AutofillHints.oneTimeCode]
                    : null,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                cursorColor: AppColors.brandSecondary,
                cursorWidth: 1.5,
                showCursor: true,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                ],
                decoration: const InputDecoration(
                  counterText: '',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  filled: true,
                  fillColor: Colors.transparent,
                  isCollapsed: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: (String value) => onChanged(index, value),
                onTap: () {
                  controllers[index].selection = TextSelection(
                    baseOffset: 0,
                    extentOffset: controllers[index].text.length,
                  );
                },
              ),
            ),
          ),
        );
      }),
    );
  }
}
