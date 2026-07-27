import 'dart:ui';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/features/auth/presentation/pages/shop_forgot_password_email_page.dart';
import 'package:mnd_shop/features/auth/presentation/pages/shop_registration_form_page.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_legal_policy_dialog.dart';

class ShopLoginPage extends ConsumerStatefulWidget {
  const ShopLoginPage({super.key});

  @override
  ConsumerState<ShopLoginPage> createState() => _ShopLoginPageState();
}

class _ShopLoginPageState extends ConsumerState<ShopLoginPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  OverlayEntry? _topErrorEntry;

  @override
  void dispose() {
    _removeTopError();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _removeTopError() {
    _topErrorEntry?.remove();
    _topErrorEntry = null;
  }

  void _showTopErrorSnackBar(String message) {
    _removeTopError();
    final OverlayState overlay = Overlay.of(context);
    final double topInset = MediaQuery.paddingOf(context).top;

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (BuildContext context) {
        return Positioned(
          top: topInset + 8,
          left: 16,
          right: 16,
          child: Material(
            color: Colors.transparent,
            child: Dismissible(
              key: const Key('top_error_snack'),
              direction: DismissDirection.up,
              onDismissed: (_) => _removeTopError(),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: -24, end: 0),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                builder: (BuildContext context, double dy, Widget? child) {
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade100),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: <Widget>[
                        Icon(
                          Icons.error_outline_rounded,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            message,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    _topErrorEntry = entry;
    overlay.insert(entry);

    Future<void>.delayed(const Duration(seconds: 4), () {
      if (_topErrorEntry == entry) {
        _removeTopError();
      }
    });
  }

  String? _validateEmail(String? value) {
    final String t = value?.trim() ?? '';
    if (t.isEmpty) {
      return _vTxt(context, en: 'Enter your email', si: 'ඔබේ email එක ඇතුල් කරන්න');
    }
    if (!t.contains('@') || t.length < 5) {
      return _vTxt(context, en: 'Enter a valid email address', si: 'වලංගු email ලිපිනයක් ඇතුල් කරන්න');
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return _vTxt(context, en: 'Enter your password', si: 'ඔබේ මුරපදය ඇතුල් කරන්න');
    }
    return null;
  }

  Future<void> _forgotPassword() async {
    final String email = _email.text.trim();
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ShopForgotPasswordEmailPage(
          initialEmail: email.isEmpty ? null : email,
        ),
      ),
    );
  }

  Future<void> _signIn() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() => _busy = true);
    try {
      await ref
          .read(firebaseAuthProvider)
          .signInWithEmailAndPassword(
            email: _email.text.trim(),
            password: _password.text,
          );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        _showTopErrorSnackBar(e.message ?? e.code);
      }
    } catch (e) {
      if (mounted) {
        _showTopErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _openRegistrationForm() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ShopRegistrationFormPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Size size = MediaQuery.sizeOf(context);
    final double keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    // 3-button / gesture nav bar — without this, Privacy/Terms sit under system buttons.
    final double bottomSafe = MediaQuery.paddingOf(context).bottom;
    final bool tabletLayout = size.width >= 700;

    if (tabletLayout) {
      return _buildTabletScaffold(
        theme: theme,
        size: size,
        keyboardInset: keyboardInset,
        bottomSafe: bottomSafe,
      );
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.dark,
        systemNavigationBarContrastEnforced: false,
      ),
      child: Scaffold(
      backgroundColor: const Color(0xFF4A3FE0),
      body: Stack(
        children: <Widget>[
          // 1. Hero background pinned to the top.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.55,
            child: Image.asset(
              'assets/shop_login_bg.png',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),

          // 2. Content Area with Wavy Edge (Middle layer)
          Positioned.fill(
            top: size.height * 0.42,
            child: ClipPath(
              clipper: _WavyClipper(),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  color: Colors.white.withValues(alpha: 0.88),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      28,
                      75,
                      28,
                      20 + bottomSafe + keyboardInset,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 460),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Text(
                                _vTxt(context, en: 'Welcome Back', si: 'නැවත සාදරයෙන් පිළිගනිමු'),
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textCharcoal,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email Field
                              _buildLabel(_vTxt(context, en: 'Email Address', si: 'Email ලිපිනය')),
                              const SizedBox(height: 3),
                              TextFormField(
                                controller: _email,
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                                autocorrect: false,
                                style: const TextStyle(fontSize: 14),
                                autofillHints: const <String>[AutofillHints.email],
                                validator: _validateEmail,
                                onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
                                decoration: _inputDecoration(
                                  hintText: 'name@yourshop.com',
                                  icon: Icons.mail_outline_rounded,
                                ),
                              ),
                              const SizedBox(height: 10),

                              // Password Field
                              _buildLabel(_vTxt(context, en: 'Password', si: 'මුරපදය')),
                              const SizedBox(height: 3),
                              TextFormField(
                                controller: _password,
                                obscureText: _obscurePassword,
                                textInputAction: TextInputAction.done,
                                style: const TextStyle(fontSize: 14),
                                autofillHints: const <String>[AutofillHints.password],
                                validator: _validatePassword,
                                onFieldSubmitted: (_) => _signIn(),
                                decoration: _inputDecoration(
                                  hintText: '••••••••',
                                  icon: Icons.lock_outline_rounded,
                                  suffixIcon: IconButton(
                                    constraints: const BoxConstraints(),
                                    padding: EdgeInsets.zero,
                                    tooltip: _obscurePassword
                                        ? _vTxt(context, en: 'Show password', si: 'මුරපදය පෙන්වන්න')
                                        : _vTxt(context, en: 'Hide password', si: 'මුරපදය සඟවන්න'),
                                    onPressed: _busy
                                        ? null
                                        : () => setState(() => _obscurePassword = !_obscurePassword),
                                    icon: Icon(
                                      _obscurePassword
                                          ? Icons.visibility_outlined
                                          : Icons.visibility_off_outlined,
                                      color: AppColors.textMuted,
                                      size: 18,
                                    ),
                                  ),
                                ),
                              ),

                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: _busy ? null : _forgotPassword,
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.primaryBlue,
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                  ),
                                  child: Text(
                                    _vTxt(context, en: 'Forgot password?', si: 'මුරපදය අමතකද?'),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),

                              // Sign In Button
                              Container(
                                width: double.infinity,
                                height: 48,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: AppColors.heroGradient,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: <BoxShadow>[
                                    BoxShadow(
                                      color: AppColors.primaryBlue.withValues(alpha: 0.3),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ElevatedButton(
                                  onPressed: _busy ? null : _signIn,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.transparent,
                                    foregroundColor: Colors.white,
                                    shadowColor: Colors.transparent,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: _busy
                                      ? const SizedBox(
                                          height: 16,
                                          width: 16,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : FittedBox(
                                          fit: BoxFit.scaleDown,
                                          child: Row(
                                            mainAxisAlignment: MainAxisAlignment.center,
                                            mainAxisSize: MainAxisSize.min,
                                            children: <Widget>[
                                              const Icon(Icons.login_rounded, size: 16),
                                              const SizedBox(width: 6),
                                              Text(
                                                _vTxt(context, en: 'Sign In', si: 'පිවිසෙන්න'),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 15,
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Center(
                                child: InkWell(
                                  onTap: _busy ? null : _openRegistrationForm,
                                  borderRadius: BorderRadius.circular(100),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Wrap(
                                      crossAxisAlignment: WrapCrossAlignment.center,
                                      children: <Widget>[
                                        const Icon(
                                          Icons.storefront_rounded,
                                          size: 14,
                                          color: AppColors.primaryBlue,
                                        ),
                                        const SizedBox(width: 6),
                                        RichText(
                                          text: TextSpan(
                                            style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                                            ),
                                            children: <TextSpan>[
                                              TextSpan(text: _vTxt(context, en: 'New vendor? ', si: 'නව vendor කෙනෙක්ද? ')),
                                              TextSpan(
                                                text: _vTxt(context, en: 'Register', si: 'ලියාපදිංචි වන්න'),
                                                style: const TextStyle(
                                                  color: AppColors.primaryBlue,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              Center(
                                child: Wrap(
                                  alignment: WrapAlignment.center,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: <Widget>[
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => showShopLegalPolicyDialog(
                                                context,
                                                type: ShopLegalPolicyType.privacy,
                                              ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.textMuted,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        _vTxt(
                                          context,
                                          en: 'Privacy Policy',
                                          si: 'රහස්‍යතා ප්‍රතිපත්තිය',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                    const Text(
                                      '  |  ',
                                      style: TextStyle(
                                        color: AppColors.textMuted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _busy
                                          ? null
                                          : () => showShopLegalPolicyDialog(
                                                context,
                                                type: ShopLegalPolicyType.terms,
                                              ),
                                      style: TextButton.styleFrom(
                                        foregroundColor: AppColors.textMuted,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 2,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                        visualDensity: VisualDensity.compact,
                                      ),
                                      child: Text(
                                        _vTxt(
                                          context,
                                          en: 'Terms of Service',
                                          si: 'සේවා නියම',
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          decoration: TextDecoration.underline,
                                          decorationColor: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Header with Logo (Top-most layer)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: size.height * 0.45,
            child: SafeArea(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  // Logo inside a white circular background with strong smooth shadow
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 40,
                          spreadRadius: 2,
                          offset: const Offset(0, 15),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/shop_auth_logo.png',
                      width: 64,
                      height: 64,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _vTxt(context, en: 'Manage your shop with ease', si: 'ඔබේ shop එක පහසුවෙන් කළමනාකරණය කරන්න'),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
                      shadows: <Shadow>[
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildTabletScaffold({
    required ThemeData theme,
    required Size size,
    required double keyboardInset,
    required double bottomSafe,
  }) {
    final double horizontalPadding = size.width >= 1000 ? 36 : 24;
    final double verticalPadding = size.height >= 760 ? 30 : 20;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1180),
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                verticalPadding,
                horizontalPadding,
                verticalPadding,
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    flex: 11,
                    child: _TabletHeroPanel(
                      tagline: 'Manage your shop with ease',
                    ),
                  ),
                  const SizedBox(width: 22),
                  Expanded(
                    flex: 9,
                    child: Align(
                      alignment: Alignment.center,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.only(
                          top: keyboardInset > 0 ? 12 : 0,
                          bottom: bottomSafe + keyboardInset,
                        ),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 430),
                          padding: const EdgeInsets.fromLTRB(30, 30, 30, 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: Colors.black.withValues(alpha: 0.05),
                            ),
                            boxShadow: <BoxShadow>[
                              BoxShadow(
                                color: const Color(0xFF15213D)
                                    .withValues(alpha: 0.10),
                                blurRadius: 30,
                                offset: const Offset(0, 18),
                              ),
                            ],
                          ),
                          child: Form(
                            key: _formKey,
                            child: _buildTabletFormContent(theme),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabletFormContent(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Center(
          child: Image.asset(
            'assets/shop_auth_logo.png',
            width: 72,
            height: 72,
            fit: BoxFit.contain,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.textCharcoal,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Sign in to continue managing orders, products, and reports.',
          style: TextStyle(
            color: AppColors.textMuted,
            fontSize: 13,
            height: 1.45,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 22),
        _buildLabel('Email Address'),
        const SizedBox(height: 5),
        TextFormField(
          controller: _email,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autocorrect: false,
          style: const TextStyle(fontSize: 14),
          autofillHints: const <String>[AutofillHints.email],
          validator: _validateEmail,
          onFieldSubmitted: (_) => FocusScope.of(context).nextFocus(),
          decoration: _inputDecoration(
            hintText: 'name@yourshop.com',
            icon: Icons.mail_outline_rounded,
          ),
        ),
        const SizedBox(height: 14),
        _buildLabel('Password'),
        const SizedBox(height: 5),
        TextFormField(
          controller: _password,
          obscureText: _obscurePassword,
          textInputAction: TextInputAction.done,
          style: const TextStyle(fontSize: 14),
          autofillHints: const <String>[AutofillHints.password],
          validator: _validatePassword,
          onFieldSubmitted: (_) => _signIn(),
          decoration: _inputDecoration(
            hintText: '********',
            icon: Icons.lock_outline_rounded,
            suffixIcon: IconButton(
              constraints: const BoxConstraints(),
              padding: EdgeInsets.zero,
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: _busy
                  ? null
                  : () => setState(
                        () => _obscurePassword = !_obscurePassword,
                      ),
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                color: AppColors.textMuted,
                size: 18,
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _busy ? null : _forgotPassword,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(vertical: 3),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
            child: const Text(
              'Forgot password?',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          height: 50,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: AppColors.heroGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: AppColors.primaryBlue.withValues(alpha: 0.26),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: _busy ? null : _signIn,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: _busy
                ? const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(Icons.login_rounded, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Sign In',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: InkWell(
            onTap: _busy ? null : _openRegistrationForm,
            borderRadius: BorderRadius.circular(100),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  const Icon(
                    Icons.storefront_rounded,
                    size: 14,
                    color: AppColors.primaryBlue,
                  ),
                  const SizedBox(width: 6),
                  RichText(
                    text: TextSpan(
                      style: TextStyle(
                        color: AppColors.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        fontFamily: theme.textTheme.bodyMedium?.fontFamily,
                      ),
                      children: const <TextSpan>[
                        TextSpan(text: 'New vendor? '),
                        TextSpan(
                          text: 'Register',
                          style: TextStyle(
                            color: AppColors.primaryBlue,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              TextButton(
                onPressed: _busy
                    ? null
                    : () => showShopLegalPolicyDialog(
                          context,
                          type: ShopLegalPolicyType.privacy,
                        ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Privacy Policy',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
              ),
              const Text(
                '  |  ',
                style: TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              TextButton(
                onPressed: _busy
                    ? null
                    : () => showShopLegalPolicyDialog(
                          context,
                          type: ShopLegalPolicyType.terms,
                        ),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textMuted,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                ),
                child: const Text(
                  'Terms of Service',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        color: AppColors.textCharcoal,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      prefixIcon: Icon(icon, color: AppColors.textMuted, size: 20),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: const Color(0xFFF7F9FC),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
      ),
    );
  }
}

class _WavyClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final Path path = Path();
    path.lineTo(0, 40);

    // More dramatic wave to match the red line:
    // Higher peak on the left-middle, and a much deeper valley on the right-middle.
    path.cubicTo(
      size.width * 0.3, -35,  // High peak on the left side
      size.width * 0.65, 160, // Very deep dip (valley) as marked in red
      size.width, 40,         // Rising back up towards the right edge
    );

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => true;
}

class _TabletHeroPanel extends StatelessWidget {
  const _TabletHeroPanel({required this.tagline});

  final String tagline;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Image.asset(
            'assets/shop_login_bg.png',
            fit: BoxFit.cover,
            alignment: Alignment.centerLeft,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: <Color>[
                  const Color(0xFF15124A).withValues(alpha: 0.18),
                  const Color(0xFF15124A).withValues(alpha: 0.68),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.18),
                        blurRadius: 28,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/shop_auth_logo.png',
                    width: 54,
                    height: 54,
                    fit: BoxFit.contain,
                  ),
                ),
                const Spacer(),
                Text(
                  tagline,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    height: 1.08,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0,
                  ),
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const <Widget>[
                    _TabletHeroChip(
                      icon: Icons.receipt_long_rounded,
                      label: 'Orders',
                    ),
                    _TabletHeroChip(
                      icon: Icons.inventory_2_rounded,
                      label: 'Products',
                    ),
                    _TabletHeroChip(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabletHeroChip extends StatelessWidget {
  const _TabletHeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.28)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, color: Colors.white, size: 17),
              const SizedBox(width: 7),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0,
                ),
              ),
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
