import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_rider/core/constants/route_paths.dart';
import 'package:mnd_rider/core/widgets/rider_snackbar.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_phone_auth_provider.dart';
import 'package:mnd_rider/features/auth/presentation/providers/rider_registration_provider.dart';
import 'package:mnd_rider/features/auth/presentation/widgets/rider_auth_light_background.dart';

/// Full-screen loading while registration photos/profile are uploaded after OTP.
class RiderRegisterSubmittingPage extends ConsumerStatefulWidget {
  const RiderRegisterSubmittingPage({super.key});

  @override
  ConsumerState<RiderRegisterSubmittingPage> createState() =>
      _RiderRegisterSubmittingPageState();
}

class _RiderRegisterSubmittingPageState
    extends ConsumerState<RiderRegisterSubmittingPage> {
  static const Color _ink = Color(0xFF0A0A0A);
  static const Color _bg = Color(0xFFF5F5F5);
  static const Color _muted = Color(0xFF6B7280);

  bool _started = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _started) {
        return;
      }
      _started = true;
      _submit();
    });
  }

  Future<void> _submit() async {
    final bool ok =
        await ref.read(riderRegistrationSubmitProvider.notifier).submit();
    if (!mounted) {
      return;
    }

    if (!ok) {
      final RiderRegistrationSubmitState state =
          ref.read(riderRegistrationSubmitProvider);
      final String message = state.errorMessage ??
          'Could not finish registration. Check your details and try again.';
      showRiderSnackBar(context, message);
      context.go(RoutePaths.register);
      return;
    }

    showRiderSnackBar(
      context,
      'Registration submitted. An admin must approve your account before you can drive.',
      duration: const Duration(seconds: 5),
    );
    ref.read(riderPhoneAuthProvider.notifier).clearSession();
    context.go(RoutePaths.shell);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: PopScope(
        canPop: false,
        child: Scaffold(
          backgroundColor: _bg,
          body: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              const RiderAuthLightBackground(),
              SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        const SizedBox(
                          width: 40,
                          height: 40,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.8,
                            color: _ink,
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'Submitting registration',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: _ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Uploading your photos and creating your rider profile. Please wait…',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.plusJakartaSans(
                            color: _muted,
                            fontSize: 14,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
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
