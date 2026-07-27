import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/app/providers/locale_provider.dart';
import 'package:mnd_shop/app/providers/theme_mode_provider.dart';
import 'package:mnd_shop/app/providers/vendor_shell_tab_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/core/locale/vendor_ta_fallback.dart';
import 'package:mnd_shop/core/media/shop_cover_image_spec.dart';
import 'package:mnd_shop/core/widgets/vendor_shell_ui.dart';
import 'package:mnd_shop/features/billing/presentation/pages/vendor_monthly_fees_page.dart';
import 'package:mnd_shop/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:mnd_shop/features/notifications/presentation/providers/vendor_notifications_providers.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_id_provider.dart';
import 'package:mnd_shop/features/profile/data/vendor_account_deletion_repository.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_language_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_notification_settings_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_profile_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_settings_actions.dart';
import 'package:mnd_shop/features/auth/presentation/widgets/shop_legal_policy_dialog.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_shop_gallery_page.dart';
import 'package:mnd_shop/features/profile/presentation/widgets/vendor_settings_tiles.dart';
import 'package:mnd_shop/features/reports/presentation/pages/vendor_reports_page.dart';
import 'package:mnd_shop/features/dashboard/presentation/widgets/vendor_pill_bottom_nav.dart';

/// Hub tab: shop identity, settings shortcuts, preferences, and account.
class VendorSettingsPage extends ConsumerWidget {
  const VendorSettingsPage({super.key});

  static Color _primaryText(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurface
        : AppColors.textCharcoal;
  }

  static String resolveShopImageUrl(Map<String, dynamic>? doc) {
    if (doc == null) {
      return '';
    }
    final String direct = (doc['imageUrl'] as String?)?.trim() ?? '';
    if (direct.isNotEmpty) {
      return direct;
    }
    final List<dynamic>? gallery = doc['galleryImageUrls'] as List<dynamic>?;
    if (gallery != null && gallery.isNotEmpty) {
      return (gallery.first as String?)?.trim() ?? '';
    }
    return '';
  }

  static String _approvalLabel(BuildContext context, String? approval) {
    switch (approval) {
      case 'pending':
        return _vTxt(
          context,
          en: 'Pending approval',
          si: 'අනුමැතිය බලාපොරොත්තුයි',
        );
      case 'rejected':
        return _vTxt(context, en: 'Rejected', si: 'ප්‍රතික්ෂේපයි');
      case 'approved':
        return _vTxt(context, en: 'Approved', si: 'අනුමතයි');
      default:
        return approval == null || approval.isEmpty
            ? _vTxt(context, en: 'Approved', si: 'අනුමතයි')
            : approval;
    }
  }

  static Color _approvalColor(String? approval, ColorScheme cs) {
    switch (approval) {
      case 'pending':
        return const Color(0xFFB8860B);
      case 'rejected':
        return cs.error;
      default:
        return const Color(0xFF2A7F3A);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final Map<String, dynamic>? doc = ref
        .watch(vendorAccountDocDataProvider)
        .valueOrNull;
    final String shopName = ref.watch(vendorShopDisplayNameProvider);
    final String imageUrl = resolveShopImageUrl(doc);
    final String? approval = doc?['approvalStatus'] as String?;
    final bool canToggleLive =
        approval == null || approval.isEmpty || approval == 'approved';
    final String email = (doc?['email'] as String?)?.trim() ?? '';
    final int unread =
        ref.watch(vendorUnreadNotificationCountProvider).valueOrNull ?? 0;
    final Locale? locale = ref.watch(appLocaleProvider).valueOrNull;
    final double gutter = vendorResponsiveHorizontalPadding(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? cs.surface
          : AppColors.canvas,
      appBar: AppBar(
        title: Text(_vTxt(context, en: 'Settings', si: 'සැකසුම්')),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: theme.textTheme.titleLarge?.copyWith(
          color: _primaryText(context),
          fontWeight: FontWeight.w700,
        ),
      ),
      body: VendorResponsiveContent(
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            gutter,
            4,
            gutter,
            VendorPillBottomNav.scrollBottomPadding(
              context,
              extra: 0,
              includeOuterMargin: false,
            ),
          ),
          children: <Widget>[
            _ShopIdentityHeader(
              imageUrl: imageUrl,
              shopName: shopName,
              approvalLabel: _approvalLabel(context, approval),
              approvalColor: _approvalColor(approval, cs),
              onAvatarTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorShopGalleryPage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            VendorSettingsSectionTitle(
              label: _vTxt(context, en: 'Business', si: 'ව්‍යාපාරය'),
            ),
            const SizedBox(height: 10),
            _StoreOpenSwitchTile(canToggle: canToggleLive),
            const SizedBox(height: 20),
            VendorSettingsSectionTitle(
              label: _vTxt(context, en: 'Preferences', si: 'මනාපයන්'),
            ),
            const SizedBox(height: 10),
            const _DarkModeSwitchTile(),
            VendorSettingsNavTile(
              icon: Icons.notifications_outlined,
              label: _vTxt(
                context,
                en: 'Notification preferences',
                si: 'දැනුම්දීම් මනාප',
              ),
              subtitle: _vTxt(
                context,
                en: 'Sounds and in-app alerts',
                si: 'ශබ්ද සහ app දැනුම්දීම්',
              ),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorNotificationSettingsPage(),
                  ),
                );
              },
            ),
            VendorSettingsNavTile(
              icon: Icons.language_rounded,
              label: _vTxt(context, en: 'Language', si: 'භාෂාව'),
              subtitle: describeAppLocaleChoice(locale),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorLanguagePage(),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            VendorSettingsSectionTitle(
              label: _vTxt(context, en: 'Support', si: 'සහාය'),
            ),
            const SizedBox(height: 10),
            VendorSettingsNavTile(
              icon: Icons.notifications_none_outlined,
              label: _vTxt(context, en: 'Notifications', si: 'දැනුම්දීම්'),
              subtitle: _vTxt(
                context,
                en: 'Order and account messages',
                si: 'ඇණවුම් සහ ගිණුම් පණිවිඩ',
              ),
              trailingBadge: unread,
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorNotificationsPage(),
                  ),
                );
              },
            ),
            VendorSettingsNavTile(
              icon: Icons.lock_reset_rounded,
              label: _vTxt(
                context,
                en: 'Change password',
                si: 'මුරපදය වෙනස් කරන්න',
              ),
              subtitle: _vTxt(
                context,
                en: 'Send reset link to your email',
                si: 'email එකට reset link එක යවන්න',
              ),
              onTap: () {
                VendorSettingsActions.sendPasswordResetEmail(
                  context,
                  email: email,
                  auth: ref.read(firebaseAuthProvider),
                );
              },
            ),
            VendorSettingsNavTile(
              icon: Icons.help_outline_rounded,
              label: _vTxt(context, en: 'Help & support', si: 'උදව් සහ සහාය'),
              onTap: () => VendorSettingsActions.openHelpSupport(context),
            ),
            VendorSettingsNavTile(
              icon: Icons.info_outline_rounded,
              label: _vTxt(context, en: 'About MND Shop', si: 'MND Shop ගැන'),
              onTap: () => VendorSettingsActions.showAboutDialog(context),
            ),
            VendorSettingsNavTile(
              icon: Icons.privacy_tip_outlined,
              label: _vTxt(
                context,
                en: 'Privacy Policy',
                si: 'රහස්‍යතා ප්‍රතිපත්තිය',
              ),
              subtitle: _vTxt(
                context,
                en: 'How we handle shop data',
                si: 'කඩ දත්ත හසුරුවන ආකාරය',
              ),
              onTap: () => showShopLegalPolicyDialog(
                context,
                type: ShopLegalPolicyType.privacy,
              ),
            ),
            VendorSettingsNavTile(
              icon: Icons.description_outlined,
              label: _vTxt(context, en: 'Terms of Service', si: 'සේවා නියම'),
              subtitle: _vTxt(
                context,
                en: 'Vendor platform rules',
                si: 'Vendor වේදිකා නීති',
              ),
              onTap: () => showShopLegalPolicyDialog(
                context,
                type: ShopLegalPolicyType.terms,
              ),
            ),
            const SizedBox(height: 20),
            VendorSettingsSectionTitle(
              label: _vTxt(context, en: 'Account', si: 'ගිණුම'),
            ),
            const SizedBox(height: 10),
            VendorSettingsNavTile(
              icon: Icons.edit_outlined,
              label: _vTxt(context, en: 'Edit profile', si: 'පැතිකඩ සංස්කරණය'),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorProfilePage(),
                  ),
                );
              },
            ),
            VendorSettingsNavTile(
              icon: Icons.insights_outlined,
              label: _vTxt(context, en: 'Reports', si: 'වාර්තා'),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorReportsPage(),
                  ),
                );
              },
            ),
            VendorSettingsNavTile(
              icon: Icons.receipt_long_outlined,
              label: _vTxt(
                context,
                en: 'Monthly platform fees',
                si: 'මාසික වේදිකා ගාස්තු',
              ),
              subtitle: _vTxt(
                context,
                en: 'View invoices and payment status',
                si: 'ඉන්වොයිස් සහ ගෙවීම් තත්ත්වය බලන්න',
              ),
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    builder: (_) => const VendorMonthlyFeesPage(),
                  ),
                );
              },
            ),
            VendorSettingsNavTile(
              icon: Icons.delete_outline_rounded,
              label: _vTxt(
                context,
                en: 'Request account deletion',
                si: 'Request account deletion',
              ),
              subtitle: _vTxt(
                context,
                en: 'Close this shop after support review',
                si: 'Close this shop after support review',
              ),
              onTap: () => _requestAccountDeletion(context, ref, shopName),
            ),
            VendorSettingsNavTile(
              icon: Icons.logout_rounded,
              label: _vTxt(context, en: 'Log out', si: 'ඉවත් වන්න'),
              trimBottomSpacing: true,
              onTap: () async {
                final bool? ok = await VendorSettingsActions.confirmLogout(
                  context,
                );
                if (ok != true || !context.mounted) {
                  return;
                }
                await ref.read(vendorStoreIdProvider.notifier).setStoreId('');
                ref.invalidate(vendorShellTabIndexProvider);
                await ref.read(firebaseAuthProvider).signOut();
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _requestAccountDeletion(
    BuildContext context,
    WidgetRef ref,
    String shopName,
  ) async {
    final TextEditingController reasonController = TextEditingController();
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Request account deletion'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'This will submit a deletion request for $shopName. Your shop '
                'will be closed for new orders while MND support reviews it.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Completed orders, payouts, tax, and legal records may be kept '
                'where required.',
              ),
              const SizedBox(height: 16),
              TextField(
                controller: reasonController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Reason (optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            child: const Text('Submit request'),
          ),
        ],
      ),
    );
    final String reason = reasonController.text;
    reasonController.dispose();
    if (ok != true || !context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Submitting deletion request...')),
    );
    try {
      await ref
          .read(vendorAccountDeletionRepositoryProvider)
          .requestDeletion(reason: reason);
      ref.invalidate(vendorAccountDocDataProvider);
      ref.invalidate(vendorStoreActiveProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Deletion request submitted. Your shop is now closed for new orders.',
            ),
          ),
        );
      }
    } on VendorAccountDeletionException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _StoreOpenSwitchTile extends ConsumerWidget {
  const _StoreOpenSwitchTile({required this.canToggle});

  final bool canToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String storeId = ref.watch(vendorEffectiveStoreIdProvider).trim();
    final AsyncValue<bool> activeAsync = ref.watch(vendorStoreActiveProvider);
    final bool isOpen = activeAsync.valueOrNull ?? true;
    final bool busy = activeAsync.isLoading;

    return VendorSettingsSwitchTile(
      icon: Icons.storefront_rounded,
      label: _vTxt(context, en: 'Open for orders', si: 'ඇණවුම් සඳහා විවෘතයි'),
      subtitle: canToggle
          ? _vTxt(
              context,
              en: 'Customers can place orders while open',
              si: 'විවෘත අවස්ථාවේ ගනුදෙනුකරුවන්ට ඇණවුම් කළ හැක',
            )
          : _vTxt(
              context,
              en: 'Available after admin approves your shop',
              si: 'Admin අනුමත කළ පසු මෙය සක්‍රීය වේ',
            ),
      value: isOpen && canToggle,
      onChanged: !canToggle || busy || storeId.isEmpty
          ? null
          : (bool value) async {
              if (!canToggle) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _vTxt(
                        context,
                        en: 'Your shop must be approved before going live.',
                        si: 'Live වෙන්න පෙර ඔබගේ සාප්පුව අනුමත විය යුතුය.',
                      ),
                    ),
                  ),
                );
                return;
              }
              if (storeId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _vTxt(
                        context,
                        en: 'Set store ID under Products first.',
                        si: 'මුලින් Products යටතේ store ID සකසන්න.',
                      ),
                    ),
                  ),
                );
                return;
              }
              final String? err = await ref
                  .read(vendorOrdersRepositoryProvider)
                  .setVendorActive(storeId, value);
              if (context.mounted && err != null) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(err)));
              }
            },
    );
  }
}

class _DarkModeSwitchTile extends ConsumerWidget {
  const _DarkModeSwitchTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final AsyncValue<ThemeMode> modeAsync = ref.watch(themeModeProvider);
    final bool isDark = theme.brightness == Brightness.dark;
    final bool busy = modeAsync.isLoading;

    return VendorSettingsSwitchTile(
      icon: isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
      label: _vTxt(context, en: 'Dark mode', si: 'අඳුරු තේමාව'),
      subtitle: _vTxt(
        context,
        en: 'Light or dark theme for the app',
        si: 'යෙදුම සඳහා දීප්තිමත් හෝ අඳුරු තේමාව',
      ),
      value: isDark,
      onChanged: busy
          ? null
          : (bool enabled) {
              ref
                  .read(themeModeProvider.notifier)
                  .setThemeMode(enabled ? ThemeMode.dark : ThemeMode.light);
            },
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

class _ShopIdentityHeader extends StatelessWidget {
  const _ShopIdentityHeader({
    required this.imageUrl,
    required this.shopName,
    required this.approvalLabel,
    required this.approvalColor,
    this.onAvatarTap,
  });

  final String imageUrl;
  final String shopName;
  final String approvalLabel;
  final Color approvalColor;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    const BorderRadius imageRadius = BorderRadius.all(Radius.circular(16));

    Widget placeholder() {
      return ColoredBox(
        color: AppColors.primaryBlue.withValues(alpha: 0.12),
        child: Center(
          child: Icon(
            Icons.storefront_rounded,
            size: 48,
            color: AppColors.primaryBlue,
          ),
        ),
      );
    }

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onAvatarTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: imageRadius,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: AspectRatio(
              // Matches crop/upload: 1432×800 → same wide cover customers see.
              aspectRatio: ShopCoverImageSpec.previewAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: imageRadius,
                    child: imageUrl.isEmpty
                        ? placeholder()
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => placeholder(),
                            loadingBuilder:
                                (_, Widget child, ImageChunkEvent? loading) {
                                  if (loading == null) {
                                    return child;
                                  }
                                  return Center(
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primaryBlue.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  );
                                },
                          ),
                  ),
                  if (onAvatarTap != null)
                    Positioned(
                      right: 10,
                      bottom: 10,
                      child: Material(
                        color: AppColors.primaryBlue,
                        borderRadius: BorderRadius.circular(10),
                        child: SizedBox(
                          width: 36,
                          height: 36,
                          child: Icon(
                            Icons.camera_alt_rounded,
                            size: 18,
                            color: cs.onPrimary,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          shopName,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: VendorSettingsPage._primaryText(context),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: approvalColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: approvalColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            approvalLabel,
            style: theme.textTheme.labelMedium?.copyWith(
              color: approvalColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}
