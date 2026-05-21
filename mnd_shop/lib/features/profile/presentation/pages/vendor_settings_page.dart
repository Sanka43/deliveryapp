import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mnd_shop/app/providers/firebase_providers.dart';
import 'package:mnd_shop/app/providers/locale_provider.dart';
import 'package:mnd_shop/app/providers/theme_mode_provider.dart';
import 'package:mnd_shop/app/providers/vendor_shell_tab_provider.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';
import 'package:mnd_shop/features/notifications/presentation/pages/vendor_notifications_page.dart';
import 'package:mnd_shop/features/notifications/presentation/providers/vendor_notifications_providers.dart';
import 'package:mnd_shop/features/orders/data/vendor_orders_repository.dart';
import 'package:mnd_shop/features/orders/presentation/providers/vendor_order_board_provider.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_session_store_providers.dart';
import 'package:mnd_shop/features/products/presentation/providers/vendor_store_id_provider.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_language_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_notification_settings_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_profile_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_settings_actions.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_shop_business_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_shop_category_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_shop_gallery_page.dart';
import 'package:mnd_shop/features/profile/presentation/pages/vendor_shop_location_page.dart';
import 'package:mnd_shop/features/profile/presentation/widgets/vendor_settings_tiles.dart';
import 'package:mnd_shop/features/reports/presentation/pages/vendor_reports_page.dart';

/// Hub tab: shop identity, settings shortcuts, preferences, and account.
class VendorSettingsPage extends ConsumerWidget {
  const VendorSettingsPage({super.key});

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

  static String _approvalLabel(String? approval) {
    switch (approval) {
      case 'pending':
        return 'Pending approval';
      case 'rejected':
        return 'Rejected';
      case 'approved':
        return 'Approved';
      default:
        return approval == null || approval.isEmpty ? 'Approved' : approval;
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
    final Map<String, dynamic>? doc = ref.watch(vendorAccountDocDataProvider).valueOrNull;
    final String shopName = ref.watch(vendorShopDisplayNameProvider);
    final String imageUrl = resolveShopImageUrl(doc);
    final String? approval = doc?['approvalStatus'] as String?;
    final bool canToggleLive =
        approval == null || approval.isEmpty || approval == 'approved';
    final String email = (doc?['email'] as String?)?.trim() ?? '';
    final int unread =
        ref.watch(vendorUnreadNotificationCountProvider).valueOrNull ?? 0;
    final Locale? locale = ref.watch(appLocaleProvider).valueOrNull;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: <Widget>[
          _ShopIdentityHeader(
            imageUrl: imageUrl,
            shopName: shopName,
            approvalLabel: _approvalLabel(approval),
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
          const VendorSettingsSectionTitle(label: 'Business'),
          const SizedBox(height: 10),
          _StoreOpenSwitchTile(canToggle: canToggleLive),
          VendorSettingsNavTile(
            icon: Icons.tune_rounded,
            label: 'Business settings',
            subtitle: 'Minimum order, staff notes',
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const VendorShopBusinessPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const VendorSettingsSectionTitle(label: 'Shop details'),
          const SizedBox(height: 10),
          VendorSettingsNavTile(
            icon: Icons.photo_library_outlined,
            label: 'Shop photos',
            subtitle: 'Up to 4 storefront images',
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const VendorShopGalleryPage(),
                ),
              );
            },
          ),
          VendorSettingsNavTile(
            icon: Icons.map_outlined,
            label: 'Store location',
            subtitle: 'Map pin for delivery',
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const VendorShopLocationPage(),
                ),
              );
            },
          ),
          VendorSettingsNavTile(
            icon: Icons.category_outlined,
            label: 'Category & type',
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const VendorShopCategoryPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 20),
          const VendorSettingsSectionTitle(label: 'Preferences'),
          const SizedBox(height: 10),
          const _DarkModeSwitchTile(),
          VendorSettingsNavTile(
            icon: Icons.notifications_outlined,
            label: 'Notification preferences',
            subtitle: 'Sounds and in-app alerts',
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
            label: 'Language',
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
          const VendorSettingsSectionTitle(label: 'Support'),
          const SizedBox(height: 10),
          VendorSettingsNavTile(
            icon: Icons.notifications_none_outlined,
            label: 'Notifications',
            subtitle: 'Order and account messages',
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
            label: 'Change password',
            subtitle: 'Send reset link to your email',
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
            label: 'Help & support',
            onTap: () => VendorSettingsActions.openHelpSupport(context),
          ),
          VendorSettingsNavTile(
            icon: Icons.info_outline_rounded,
            label: 'About MND Shop',
            onTap: () => VendorSettingsActions.showAboutDialog(context),
          ),
          const SizedBox(height: 20),
          const VendorSettingsSectionTitle(label: 'Account'),
          const SizedBox(height: 10),
          VendorSettingsNavTile(
            icon: Icons.edit_outlined,
            label: 'Edit profile',
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
            label: 'Reports',
            onTap: () {
              Navigator.of(context).push<void>(
                MaterialPageRoute<void>(
                  builder: (_) => const VendorReportsPage(),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          const _LogoutTile(),
        ],
      ),
    );
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
      label: 'Open for orders',
      subtitle: canToggle
          ? 'Customers can place orders while open'
          : 'Available after admin approves your shop',
      value: isOpen && canToggle,
      onChanged: !canToggle || busy || storeId.isEmpty
          ? null
          : (bool value) async {
              if (!canToggle) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Your shop must be approved before going live.'),
                  ),
                );
                return;
              }
              if (storeId.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Set store ID under Products first.')),
                );
                return;
              }
              final String? err = await ref
                  .read(vendorOrdersRepositoryProvider)
                  .setVendorActive(storeId, value);
              if (context.mounted && err != null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(err)),
                );
              }
            },
    );
  }
}

class _LogoutTile extends ConsumerWidget {
  const _LogoutTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () async {
            final bool? ok = await VendorSettingsActions.confirmLogout(context);
            if (ok != true || !context.mounted) {
              return;
            }
            await ref.read(vendorStoreIdProvider.notifier).setStoreId('');
            ref.invalidate(vendorShellTabIndexProvider);
            await ref.read(firebaseAuthProvider).signOut();
          },
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: cs.error.withValues(alpha: 0.35),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(Icons.logout_rounded, color: cs.error, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      'Log out',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: cs.error,
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
      label: 'Dark mode',
      subtitle: 'Light or dark theme for the app',
      value: isDark,
      onChanged: busy
          ? null
          : (bool enabled) {
              ref.read(themeModeProvider.notifier).setThemeMode(
                    enabled ? ThemeMode.dark : ThemeMode.light,
                  );
            },
    );
  }
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

    return Column(
      children: <Widget>[
        GestureDetector(
          onTap: onAvatarTap,
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.18),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              children: <Widget>[
                CircleAvatar(
                  radius: 52,
                  backgroundColor: cs.surfaceContainerHighest,
                  child: ClipOval(
                    child: imageUrl.isEmpty
                        ? ColoredBox(
                            color: AppColors.primaryBlue.withValues(alpha: 0.12),
                            child: SizedBox(
                              width: 104,
                              height: 104,
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 52,
                                color: AppColors.primaryBlue,
                              ),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            width: 104,
                            height: 104,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => ColoredBox(
                              color: AppColors.primaryBlue.withValues(alpha: 0.12),
                              child: SizedBox(
                                width: 104,
                                height: 104,
                                child: Icon(
                                  Icons.storefront_rounded,
                                  size: 52,
                                  color: AppColors.primaryBlue,
                                ),
                              ),
                            ),
                            loadingBuilder: (_, Widget child, ImageChunkEvent? loading) {
                              if (loading == null) {
                                return child;
                              }
                              return SizedBox(
                                width: 104,
                                height: 104,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: AppColors.primaryBlue.withValues(alpha: 0.7),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (onAvatarTap != null)
                  Positioned(
                    right: 4,
                    bottom: 4,
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: AppColors.primaryBlue,
                      child: Icon(Icons.camera_alt_rounded, size: 18, color: cs.onPrimary),
                    ),
                  ),
              ],
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
