import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/constants/app_spacing.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/data/rider_registration_validator.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';

/// Login — brand logo + light cyan wash matching the app icon.
class RiderPhoneLoginPage extends ConsumerStatefulWidget {
  const RiderPhoneLoginPage({super.key});

  @override
  ConsumerState<RiderPhoneLoginPage> createState() => _RiderPhoneLoginPageState();
}

class _RiderPhoneLoginPageState extends ConsumerState<RiderPhoneLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _phone = TextEditingController();
  final FocusNode _phoneFocus = FocusNode();

  static const Color _ink = Color(0xFF0A0A0A);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _field = Color(0xFFFFFFFF);
  static const Color _muted = Color(0xFF6B7280);
  static const Color _accent = AppColors.primaryBlue;

  @override
  void dispose() {
    _phone.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _showSnack(String message) {
    showRiderSnackBar(context, message);
  }

  Future<void> _continueWithOtp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final String? verificationId =
        await ref.read(riderPhoneAuthProvider.notifier).sendOtp(_phone.text.trim());
    if (!mounted) {
      return;
    }
    final String? error = ref.read(riderPhoneAuthProvider).errorMessage;
    if (error != null) {
      _showSnack(error);
      return;
    }
    if (verificationId == null || verificationId.isEmpty) {
      return;
    }

    context.push(RoutePaths.otp);
  }

  bool _isNotRegisteredError(String? message) {
    if (message == null) {
      return false;
    }
    final String lower = message.toLowerCase();
    return lower.contains('still not registered') ||
        lower.contains('not registered');
  }

  @override
  Widget build(BuildContext context) {
    final RiderPhoneAuthState auth = ref.watch(riderPhoneAuthProvider);
    final bool busy = auth.isLoading;
    final bool notRegistered = _isNotRegisteredError(auth.errorMessage);
    final double bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: _bg,
        resizeToAvoidBottomInset: true,
        body: Stack(
          fit: StackFit.expand,
          children: <Widget>[
            const _LoginBrandBackground(),
            SafeArea(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      24,
                      AppSpacing.lg,
                      24 + bottomInset,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 48 - bottomInset,
                      ),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: <Widget>[
                            const _LoginHeader(),
                            const SizedBox(height: 28),
                            Text(
                              'Phone number',
                              style: GoogleFonts.plusJakartaSans(
                                color: _ink,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Container(
                                  height: 56,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    color: _field,
                                    borderRadius: BorderRadius.circular(
                                      AppSpacing.buttonRadius,
                                    ),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    '+94',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: _ink,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: TextFormField(
                                    controller: _phone,
                                    focusNode: _phoneFocus,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    style: _fieldTextStyle(letterSpacing: 0.4),
                                    cursorColor: _accent,
                                    inputFormatters: <TextInputFormatter>[
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onFieldSubmitted: (_) {
                                      if (!busy) {
                                        _continueWithOtp();
                                      }
                                    },
                                    decoration: _fieldDecoration(
                                      hint: '7X XXX XXXX',
                                    ),
                                    validator: (String? value) =>
                                        const RiderRegistrationValidator()
                                            .validatePhoneLogin(value ?? ''),
                                  ),
                                ),
                              ],
                            ),
                            if (auth.errorMessage != null) ...<Widget>[
                              const SizedBox(height: AppSpacing.md),
                              Text(
                                auth.errorMessage!,
                                style: GoogleFonts.plusJakartaSans(
                                  color: AppColors.errorRed,
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (notRegistered) ...<Widget>[
                                const SizedBox(height: 6),
                                Text(
                                  'Create an account with Register below.',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: _muted,
                                    fontSize: 13,
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 28),
                            SizedBox(
                              height: AppSpacing.ctaHeight,
                              width: double.infinity,
                              child: FilledButton(
                                onPressed: busy ? null : _continueWithOtp,
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
                                        'Continue',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: busy
                                  ? null
                                  : () => context.push(RoutePaths.register),
                              style: TextButton.styleFrom(
                                foregroundColor: _accent,
                                disabledForegroundColor:
                                    _muted.withValues(alpha: 0.4),
                              ),
                              child: Text.rich(
                                TextSpan(
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 14,
                                    fontWeight: notRegistered
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: _muted,
                                  ),
                                  children: <InlineSpan>[
                                    TextSpan(
                                      text: notRegistered
                                          ? 'Still not registered? '
                                          : 'New rider? ',
                                    ),
                                    TextSpan(
                                      text: 'Register',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontWeight: FontWeight.w700,
                                        color: _accent,
                                      ),
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Soft photo wash + light overlay — keeps form readable.
class _LoginBrandBackground extends StatelessWidget {
  const _LoginBrandBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Image.asset(
          'assets/images/onboarding/deliver.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.center,
          errorBuilder: (
            BuildContext context,
            Object error,
            StackTrace? stackTrace,
          ) {
            return const ColoredBox(color: Color(0xFFF5F5F5));
          },
        ),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                Color(0xB3F5F5F5),
                Color(0xE6F5F5F5),
                Color(0xF5F5F5F5),
              ],
              stops: <double>[0.0, 0.45, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}

OutlineInputBorder _fieldBorder({Color? color}) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppSpacing.buttonRadius),
      borderSide: BorderSide(color: color ?? const Color(0xFFE5E7EB)),
    );

InputDecoration _fieldDecoration({
  required String hint,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: GoogleFonts.plusJakartaSans(
      color: const Color(0xFF9CA3AF),
      fontWeight: FontWeight.w400,
      fontSize: 15,
    ),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    border: _fieldBorder(),
    enabledBorder: _fieldBorder(),
    focusedBorder: _fieldBorder(color: AppColors.primaryBlue),
    errorBorder: _fieldBorder(color: AppColors.errorRed),
    focusedErrorBorder: _fieldBorder(color: AppColors.errorRed),
    errorStyle: GoogleFonts.plusJakartaSans(
      color: AppColors.errorRed,
      fontSize: 12,
    ),
  );
}

TextStyle _fieldTextStyle({double letterSpacing = 0}) =>
    GoogleFonts.plusJakartaSans(
      color: const Color(0xFF0A0A0A),
      fontSize: 15,
      fontWeight: FontWeight.w600,
      letterSpacing: letterSpacing,
    );

class _LoginHeader extends StatelessWidget {
  const _LoginHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: ColoredBox(
              color: Colors.white,
              child: Image.asset(
                'assets/images/branding/app_icon.png',
                height: 160,
                fit: BoxFit.contain,
                filterQuality: FilterQuality.high,
                errorBuilder: (
                  BuildContext context,
                  Object error,
                  StackTrace? stackTrace,
                ) {
                  return const SizedBox(
                    height: 160,
                    width: 160,
                    child: Center(
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        size: 64,
                        color: Color(0xFF0A0A0A),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to start earning',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            color: const Color(0xFF6B7280),
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
