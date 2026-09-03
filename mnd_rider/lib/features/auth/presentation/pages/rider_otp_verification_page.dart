import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_rider/app/providers/firebase_providers.dart';
import 'package:mnd_rider/app/providers/rider_auth_state_provider.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/data/rider_auth_repository.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_auth_light_background.dart';

/// OTP verify — light chrome matching [RiderPhoneLoginPage].
class RiderOtpVerificationPage extends ConsumerStatefulWidget {
  const RiderOtpVerificationPage({super.key});

  @override
  ConsumerState<RiderOtpVerificationPage> createState() =>
      _RiderOtpVerificationPageState();
}

class _RiderOtpVerificationPageState extends ConsumerState<RiderOtpVerificationPage> {
  static const int _otpLength = 6;
  static const int _resendSeconds = 45;
  static const Color _ink = Color(0xFF0A0A0A);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = AppColors.primaryBlue;

  final List<TextEditingController> _digitControllers =
      List<TextEditingController>.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List<FocusNode>.generate(_otpLength, (_) => FocusNode());

  Timer? _countdownTimer;
  int _secondsRemaining = _resendSeconds;
  String? _otpError;

  /// Set before clearing OTP session + navigating so the empty-session guard
  /// cannot bounce a successful login over to register.
  bool _handoff = false;

  String get _otpCode =>
      _digitControllers.map((TextEditingController c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _startCountdown();

    for (int i = 0; i < _otpLength; i++) {
      final int index = i;
      _focusNodes[index].addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
      _focusNodes[index].onKeyEvent = (FocusNode node, KeyEvent event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _digitControllers[index].text.isEmpty &&
            index > 0) {
          _digitControllers[index - 1].clear();
          _focusNodes[index - 1].requestFocus();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNodes.first.requestFocus();
      }
    });
  }

  void _startCountdown() {
    _countdownTimer?.cancel();
    setState(() => _secondsRemaining = _resendSeconds);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (Timer timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_secondsRemaining <= 1) {
        timer.cancel();
        setState(() => _secondsRemaining = 0);
      } else {
        setState(() => _secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final TextEditingController c in _digitControllers) {
      c.dispose();
    }
    for (final FocusNode n in _focusNodes) {
      n.dispose();
    }
    super.dispose();
  }

  void _clearOtp() {
    for (final TextEditingController c in _digitControllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _showSnack(String message) {
    showRiderSnackBar(context, message);
  }

  void _onDigitChanged(int index, String value) {
    setState(() => _otpError = null);

    final String digits = value.replaceAll(RegExp(r'[^0-9]'), '');

    if (digits.isEmpty) {
      _digitControllers[index].clear();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    if (digits.length > 1) {
      for (int i = 0; i < _otpLength; i++) {
        final int src = i - index;
        _digitControllers[i].text = src >= 0 && src < digits.length
            ? digits[src]
            : (i < index ? _digitControllers[i].text : '');
      }
      final int last = (index + digits.length - 1).clamp(0, _otpLength - 1);
      _focusNodes[last].requestFocus();
      if (_otpCode.length == _otpLength) {
        _verify();
      }
      return;
    }

    if (_digitControllers[index].text != digits) {
      _digitControllers[index].text = digits;
    }
    if (index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otpCode.length == _otpLength) {
      _verify();
    }
  }

  Future<void> _verify() async {
    final String otp = _otpCode;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _otpError = 'Enter the full 6-digit code');
      return;
    }

    final RiderPhoneAuthState session = ref.read(riderPhoneAuthProvider);
    final String? verificationId = session.verificationId;
    final String? e164Phone = session.e164Phone;
    if (verificationId == null ||
        verificationId.isEmpty ||
        e164Phone == null ||
        e164Phone.isEmpty) {
      _showSnack('Phone verification expired. Request a new OTP.');
      context.go(RoutePaths.login);
      return;
    }

    final bool ok = await ref.read(riderPhoneAuthProvider.notifier).verifyOtp(
          verificationId: verificationId,
          e164Phone: e164Phone,
          otp: otp,
        );
    if (!mounted || !ok) {
      final String? err = ref.read(riderPhoneAuthProvider).errorMessage;
      if (err != null && mounted) {
        setState(() => _otpError = err);
      }
      return;
    }

    await _navigateAfterPhoneAuth();
  }

  /// Registered riders go to the dashboard; only new phones continue registration.
  Future<void> _navigateAfterPhoneAuth() async {
    final String uid = ref.read(firebaseAuthProvider).currentUser?.uid ??
        ref.read(riderAuthStateProvider).valueOrNull?.uid ??
        '';
    if (uid.isEmpty) {
      _showSnack('Signed in, but session is missing. Try again.');
      context.go(RoutePaths.login);
      return;
    }

    // Wait briefly for authStateChanges + profile stream to catch up after
    // custom-token sign-in so the router does not treat the profile as missing.
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) {
      return;
    }

    final RiderProfileDocument? profile =
        await ref.read(riderAuthRepositoryProvider).fetchRiderProfile(uid);
    if (!mounted) {
      return;
    }

    final bool isRegisterIntent =
        ref.read(riderPhoneAuthProvider).intent.trim().toLowerCase() ==
            'register';

    final String next;
    if (profile?.isRegistrationComplete == true) {
      next = RoutePaths.shell;
    } else if (isRegisterIntent) {
      next = RoutePaths.registerSubmitting;
    } else {
      next = RoutePaths.register;
    }

    _handoff = true;
    ref.read(riderPhoneAuthProvider.notifier).clearSession();
    if (!mounted) {
      return;
    }
    context.go(next);
  }

  Future<void> _resend() async {
    if (_secondsRemaining > 0) {
      return;
    }

    final RiderPhoneAuthState session = ref.read(riderPhoneAuthProvider);
    final String? e164 = session.e164Phone;
    if (e164 == null || e164.isEmpty) {
      _showSnack('Phone verification expired. Go back and try again.');
      return;
    }

    final String local = e164.replaceAll(RegExp(r'[^0-9]'), '');
    final String local9 =
        local.length > 9 ? local.substring(local.length - 9) : local;
    final String? verificationId = await ref
        .read(riderPhoneAuthProvider.notifier)
        .sendOtp(local9, intent: session.intent, force: true);

    if (!mounted) {
      return;
    }

    if (verificationId == null || verificationId.isEmpty) {
      final String? err = ref.read(riderPhoneAuthProvider).errorMessage;
      _showSnack(err ?? 'Could not resend OTP. Try again.');
      return;
    }

    _clearOtp();
    setState(() => _otpError = null);
    _startCountdown();
    _showSnack('OTP code resent successfully.');
  }

  String _formatPhone(String e164) {
    final String digits = e164.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length >= 11 && digits.startsWith('94')) {
      final String local = digits.substring(2);
      if (local.length == 9) {
        return '+94 ${local.substring(0, 2)} ${local.substring(2, 5)} ${local.substring(5)}';
      }
    }
    return e164;
  }

  @override
  Widget build(BuildContext context) {
    final RiderPhoneAuthState auth = ref.watch(riderPhoneAuthProvider);
    final bool busy = auth.isLoading;
    final bool isRegisterIntent = auth.intent.trim().toLowerCase() == 'register';
    final String phoneLabel = _formatPhone(auth.e164Phone ?? '');
    final String? errorText = _otpError ?? auth.errorMessage;
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    if (!auth.hasPendingOtpSession && !auth.isLoading) {
      if (!_handoff) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _handoff) {
            return;
          }
          if (ref.read(riderPhoneAuthProvider).hasPendingOtpSession ||
              ref.read(riderPhoneAuthProvider).isLoading) {
            return;
          }
          final bool signedIn =
              ref.read(riderAuthStateProvider).valueOrNull != null ||
                  ref.read(firebaseAuthProvider).currentUser != null;
          // Never force register here — that raced with successful login→shell.
          context.go(signedIn ? RoutePaths.shell : RoutePaths.login);
        });
      }
      return const Scaffold(
        backgroundColor: _bg,
        body: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.2,
            color: _ink,
          ),
        ),
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const RiderAuthLightBackground(),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 4, AppSpacing.lg, 0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: busy
                            ? null
                            : () {
                                ref
                                    .read(riderPhoneAuthProvider.notifier)
                                    .clearSession();
                                if (isRegisterIntent) {
                                  context.go(RoutePaths.register);
                                } else {
                                  context.pop();
                                }
                              },
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                          color: _ink.withValues(alpha: busy ? 0.35 : 0.9),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (BuildContext context, BoxConstraints constraints) {
                        return SingleChildScrollView(
                          padding: EdgeInsets.fromLTRB(
                            AppSpacing.lg,
                            8,
                            AppSpacing.lg,
                            24 + bottomInset,
                          ),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight - 32 - bottomInset,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.end,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                Text(
                                  'Enter OTP',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _ink,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isRegisterIntent
                                      ? 'Enter the 6-digit code to finish registration'
                                      : 'Enter the 6-digit code sent to',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _muted,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  phoneLabel,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _ink,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 28),
                                _OtpBoxes(
                                  controllers: _digitControllers,
                                  focusNodes: _focusNodes,
                                  enabled: !busy,
                                  hasError: errorText != null,
                                  onChanged: _onDigitChanged,
                                ),
                                if (errorText != null) ...<Widget>[
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    errorText,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: AppColors.errorRed,
                                      fontSize: 13,
                                      height: 1.35,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 28),
                                SizedBox(
                                  height: AppSpacing.ctaHeight,
                                  width: double.infinity,
                                  child: FilledButton(
                                    onPressed: busy ? null : _verify,
                                    style: FilledButton.styleFrom(
                                      backgroundColor: _ink,
                                      disabledBackgroundColor:
                                          _ink.withValues(alpha: 0.4),
                                      foregroundColor: Colors.white,
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          AppSpacing.buttonRadius,
                                        ),
                                      ),
                                    ),
                                    child: busy
                                        ? const SizedBox(
                                            width: 22,
                                            height: 22,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2.2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : Text(
                                            isRegisterIntent
                                                ? 'Verify & submit'
                                                : 'Verify & continue',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 16,
                                            ),
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _secondsRemaining > 0
                                      ? 'Resend in ${_secondsRemaining}s'
                                      : "Didn't get the code?",
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _muted,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                TextButton(
                                  onPressed: busy || _secondsRemaining > 0
                                      ? null
                                      : _resend,
                                  style: TextButton.styleFrom(
                                    foregroundColor: _accent,
                                    disabledForegroundColor:
                                        _muted.withValues(alpha: 0.4),
                                  ),
                                  child: Text(
                                    'Resend',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
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

  static const Color _border = Color(0xFFE5E7EB);

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List<Widget>.generate(controllers.length, (int index) {
        final bool isFocused = focusNodes[index].hasFocus;

        final Color borderColor;
        if (hasError) {
          borderColor = AppColors.errorRed;
        } else if (isFocused) {
          borderColor = AppColors.primaryBlue;
        } else {
          borderColor = _border;
        }

        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(
              left: index == 0 ? 0 : 5,
              right: index == controllers.length - 1 ? 0 : 5,
            ),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
                border: Border.all(color: borderColor),
              ),
              alignment: Alignment.center,
              child: TextField(
                controller: controllers[index],
                focusNode: focusNodes[index],
                enabled: enabled,
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                style: GoogleFonts.plusJakartaSans(
                  color: const Color(0xFF0A0A0A),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                cursorColor: AppColors.primaryBlue,
                cursorWidth: 1.5,
                inputFormatters: <TextInputFormatter>[
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
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
