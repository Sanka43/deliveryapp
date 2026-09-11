import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/constants/support_constants.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/utils/user_facing_error.dart';
import 'package:mnd_shop/features/auth/domain/vendor_deletion_status.dart';
import 'package:mnd_shop/features/auth/presentation/pages/shop_registration_form_page.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ensures the signed-in Firebase user has a `vendors/{uid}` profile before the shell loads.
class VendorAccountGate extends ConsumerWidget {
  const VendorAccountGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<Map<String, dynamic>?> account =
        ref.watch(vendorAccountDocDataProvider);

    return account.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (Object e, StackTrace _) => _MessageScaffold(
        title: _vTxt(context, en: 'Could not load shop profile', si: 'shop පැතිකඩ පූරණය කළ නොහැක'),
        body: userFacingError(
          e,
          fallback: 'Please check your connection and try again.',
        ),
        actions: <Widget>[
          FilledButton(
            onPressed: () => ref.invalidate(vendorAccountDocDataProvider),
            child: Text(_vTxt(context, en: 'Retry', si: 'නැවත උත්සාහ කරන්න')),
          ),
        ],
      ),
      data: (Map<String, dynamic>? doc) {
        if (doc != null && doc.isNotEmpty) {
          if (VendorDeletionStatus.blocksAppAccess(doc)) {
            return const _VendorDeletionBlockedPage();
          }
          if (VendorDeletionStatus.needsReRegistration(doc)) {
            return const _VendorClosedReopenPage();
          }
          final String approvalStatus =
              (doc['approvalStatus'] as String?)?.trim().toLowerCase() ?? '';
          if (approvalStatus == 'rejected') {
            return _VendorRejectedPage(
              reason: (doc['rejectionReason'] as String?)?.trim(),
            );
          }
          final bool requiresEmailVerification =
              doc['requireEmailVerification'] == true;
          final User? user = ref.watch(firebaseAuthProvider).currentUser;
          if (requiresEmailVerification &&
              user != null &&
              !user.emailVerified) {
            return const _VendorEmailVerificationPage();
          }
          return child;
        }
        return const _VendorProfileMissingPage();
      },
    );
  }
}

class _VendorClosedReopenPage extends ConsumerWidget {
  const _VendorClosedReopenPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MessageScaffold(
      title: _vTxt(
        context,
        en: 'Register your shop again',
        si: 'නැවත shop එක register කරන්න',
      ),
      body: _vTxt(
        context,
        en:
            'Your previous shop on this login was closed. Complete registration '
            'again to open a new storefront.',
        si:
            'මෙම login එකේ පැරණි shop එක වසා ඇත. නව shop එකක් සඳහා registration '
            'එක නැවත සම්පූර්ණ කරන්න.',
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const ShopRegistrationFormPage(),
              ),
            );
          },
          child: Text(
            _vTxt(context, en: 'Register shop', si: 'Shop register කරන්න'),
          ),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(firebaseAuthProvider).signOut();
          },
          child: Text(
            _vTxt(
              context,
              en: 'Sign out and use another account',
              si: 'වෙනත් ගිණුමකින් පිවිසෙන්න',
            ),
          ),
        ),
      ],
    );
  }
}

class _VendorRejectedPage extends ConsumerWidget {
  const _VendorRejectedPage({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? trimmedReason =
        (reason != null && reason!.isNotEmpty) ? reason : null;
    return _MessageScaffold(
      title: _vTxt(
        context,
        en: 'Shop application rejected',
        si: 'Shop application එක ප්‍රතික්ෂේප කර ඇත',
      ),
      body: trimmedReason != null
          ? _vTxt(
              context,
              en: 'Your shop application was not approved: $trimmedReason',
              si: 'ඔබේ shop application එක approve වුනේ නෑ: $trimmedReason',
            )
          : _vTxt(
              context,
              en:
                  'Your shop application was not approved. Contact support '
                  'for more details.',
              si:
                  'ඔබේ shop application එක approve වුනේ නෑ. වැඩි විස්තර සඳහා '
                  'support අමතන්න.',
            ),
      actions: <Widget>[
        FilledButton.icon(
          onPressed: () => launchUrl(SupportConstants.supportEmailUri),
          icon: const Icon(Icons.mail_outline_rounded, size: 18),
          label: Text(
            _vTxt(context, en: 'Contact support', si: 'Support අමතන්න'),
          ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () async {
            await ref.read(firebaseAuthProvider).signOut();
          },
          child: Text(_vTxt(context, en: 'Sign out', si: 'Sign out')),
        ),
      ],
    );
  }
}

class _VendorEmailVerificationPage extends ConsumerStatefulWidget {
  const _VendorEmailVerificationPage();

  @override
  ConsumerState<_VendorEmailVerificationPage> createState() =>
      _VendorEmailVerificationPageState();
}

class _VendorEmailVerificationPageState
    extends ConsumerState<_VendorEmailVerificationPage> {
  bool _busy = false;
  String? _info;
  DateTime? _lastSentAt;

  bool get _canResend =>
      _lastSentAt == null ||
      DateTime.now().difference(_lastSentAt!) > const Duration(seconds: 30);

  Future<void> _resend() async {
    if (_busy || !_canResend) return;
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final User? user = ref.read(firebaseAuthProvider).currentUser;
      await user?.sendEmailVerification();
      _lastSentAt = DateTime.now();
      if (mounted) {
        setState(() {
          _info = _vTxt(
            context,
            en: 'Verification email sent. Check your inbox (and spam folder).',
            si: 'Verification email එක යවා ඇත. ඔබේ inbox එක (spam folder එකත්) පරීක්ෂා කරන්න.',
          );
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _info = _vTxt(
            context,
            en: 'Could not send the email right now. Try again shortly.',
            si: 'දැන් email එක යැවිය නොහැක. මදකින් නැවත උත්සාහ කරන්න.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _iVerified() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _info = null;
    });
    try {
      final User? user = ref.read(firebaseAuthProvider).currentUser;
      await user?.reload();
      final User? refreshed = ref.read(firebaseAuthProvider).currentUser;
      if (refreshed != null && refreshed.emailVerified) {
        ref.invalidate(vendorAccountDocDataProvider);
        return;
      }
      if (mounted) {
        setState(() {
          _info = _vTxt(
            context,
            en: 'Still not verified. Open the link in the email we sent, then try again.',
            si: 'තවම verify වී නැත. email එකේ ඇති link එක open කර නැවත උත්සාහ කරන්න.',
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final User? user = ref.watch(firebaseAuthProvider).currentUser;
    final String email = user?.email ?? '';
    return _MessageScaffold(
      title: _vTxt(
        context,
        en: 'Verify your email',
        si: 'ඔබේ email එක verify කරන්න',
      ),
      body: _vTxt(
        context,
        en:
            'We sent a verification link to $email. Verify it, then tap '
            "I've verified to continue.",
        si:
            '$email වෙත verification link එකක් යවා ඇත. එය verify කර, ඉන්පසු '
            'continue කිරීමට "Verified — Continue" ඔබන්න.',
      ),
      actions: <Widget>[
        if (_info != null) ...<Widget>[
          Text(
            _info!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
        ],
        FilledButton(
          onPressed: _busy ? null : _iVerified,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(
                  _vTxt(
                    context,
                    en: "I've verified — Continue",
                    si: 'Verified — Continue',
                  ),
                ),
        ),
        const SizedBox(height: 10),
        TextButton(
          onPressed: (_busy || !_canResend) ? null : _resend,
          child: Text(
            _vTxt(context, en: 'Resend email', si: 'නැවත email එක යවන්න'),
          ),
        ),
        TextButton(
          onPressed: () async {
            await ref.read(firebaseAuthProvider).signOut();
          },
          child: Text(
            _vTxt(
              context,
              en: 'Sign out and use another account',
              si: 'වෙනත් ගිණුමකින් පිවිසෙන්න',
            ),
          ),
        ),
      ],
    );
  }
}

class _VendorDeletionBlockedPage extends ConsumerWidget {
  const _VendorDeletionBlockedPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _MessageScaffold(
      title: _vTxt(
        context,
        en: 'Shop account closed',
        si: 'Shop ගිණුම වසා ඇත',
      ),
      body: _vTxt(
        context,
        en:
            'Your shop account is being closed. Please wait a moment, then sign '
            'out and try again. Contact MND support if this continues.',
        si:
            'මෙම vendor ගිණුම වසා ඉවත් කර ඇත. ඔබ sign out වෙයි. '
            'වැරදියක් නම් MND support අමතන්න.',
      ),
      actions: <Widget>[
        FilledButton(
          onPressed: () async {
            await ref.read(firebaseAuthProvider).signOut();
          },
          child: Text(_vTxt(context, en: 'Sign out', si: 'Sign out')),
        ),
      ],
    );
  }
}

class _VendorProfileMissingPage extends ConsumerWidget {
  const _VendorProfileMissingPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final Size size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          // 1. Header with Gradient
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.28,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: AppColors.heroGradient,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    const Icon(
                      Icons.storefront_rounded,
                      size: 48,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _vTxt(context, en: 'Almost There!', si: 'තව ස්වල්පයයි!'),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                ),
              ),
            ),
          ),

          // 2. Content Area with Wavy Edge
          Positioned.fill(
            top: size.height * 0.2,
            child: ClipPath(
              clipper: _GateWavyClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.9),
                  padding: const EdgeInsets.fromLTRB(28, 80, 28, 30),
                  child: Column(
                    children: <Widget>[
                      Text(
                        _vTxt(context, en: 'Complete Shop Setup', si: 'Shop Setup එක සම්පූර්ණ කරන්න'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          color: AppColors.textCharcoal,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _vTxt(
                          context,
                          en: 'This account is signed in but has no vendor shop profile yet. Register your shop to start selling.',
                          si: 'මෙම ගිණුමෙන් sign in වී ඇත, නමුත් profile එකක් නැත. විකිණීම ආරම්භ කිරීමට ඔබේ shop එක ලියාපදිංචි කරන්න.',
                        ),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: AppColors.textMuted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 54,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: AppColors.heroGradient,
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: <BoxShadow>[
                            BoxShadow(
                              color: AppColors.primaryBlue.withValues(alpha: 0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context).push<void>(
                              MaterialPageRoute<void>(
                                builder: (_) => const ShopRegistrationFormPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Text(
                            _vTxt(context, en: 'Register Shop Now', si: 'දැන් ලියාපදිංචි වන්න'),
                            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      TextButton(
                        onPressed: () async {
                          await ref.read(firebaseAuthProvider).signOut();
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textMuted,
                        ),
                        child: Text(
                          _vTxt(context, en: 'Sign out and use another account', si: 'වෙනත් ගිණුමකින් පිවිසෙන්න'),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GateWavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, 40);
    path.cubicTo(
      size.width * 0.3, -35,
      size.width * 0.65, 160,
      size.width, 40,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class _MessageScaffold extends StatelessWidget {
  const _MessageScaffold({
    required this.title,
    required this.body,
    required this.actions,
  });

  final String title;
  final String body;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                body,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              ...actions,
            ],
          ),
        ),
      ),
    );
  }
}

String _vTxt(
  BuildContext context, {
  required String en,
  required String si,
  String? ta,
}) {
  final String languageCode = Localizations.localeOf(context).languageCode;
  if (languageCode == 'si') return si;
  if (languageCode == 'ta') return ta ?? vendorTamilFallback(en);
  return en;
}
