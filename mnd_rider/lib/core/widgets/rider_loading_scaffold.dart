import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';

/// In-app loading scaffold — brand mark + message (trip/ride routes).
class RiderLoadingScaffold extends StatelessWidget {
  const RiderLoadingScaffold({super.key, this.message = 'Loading…'});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme cs = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: dark ? cs.surface : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: cs.outlineVariant),
                  boxShadow: dark
                      ? null
                      : <BoxShadow>[
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Image.asset(
                  'assets/images/branding/app_icon.png',
                  fit: BoxFit.cover,
                  errorBuilder: (
                    BuildContext context,
                    Object error,
                    StackTrace? stackTrace,
                  ) {
                    return ColoredBox(
                      color: AppColors.primaryBlue,
                      child: Icon(
                        Icons.two_wheeler_rounded,
                        color: cs.onPrimary,
                        size: 30,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: cs.primary,
                  backgroundColor: cs.primary.withValues(alpha: 0.12),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: cs.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
