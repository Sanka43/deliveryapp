import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/data/saved_address.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_notifications_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/saved_addresses_provider.dart';

/// Content below status bar (avatar + deliver-to + bell).
const double kCustomerHomeHeaderContentHeight = 56;

double customerHomeHeaderTotalHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + kCustomerHomeHeaderContentHeight;
}

String _capitalizeWord(String word) {
  if (word.isEmpty) {
    return word;
  }
  if (word.length == 1) {
    return word.toUpperCase();
  }
  return '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}';
}

String? _displayNameFromProfile(String? name) {
  if (name == null) {
    return null;
  }
  final String trimmed = name.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final List<String> parts =
      trimmed.split(RegExp(r'\s+')).where((String s) => s.isNotEmpty).toList();
  if (parts.isEmpty) {
    return null;
  }
  if (parts.length == 1) {
    return _capitalizeWord(parts.first);
  }
  return '${_capitalizeWord(parts.first)} ${_capitalizeWord(parts[1])}';
}

SavedAddress? _preferredAddress(List<SavedAddress> addresses) {
  for (final SavedAddress a in addresses) {
    if (a.isDefault) {
      return a;
    }
  }
  return addresses.isEmpty ? null : addresses.first;
}

class CustomerHomeHeaderSection extends ConsumerWidget {
  const CustomerHomeHeaderSection({
    required this.horizontalPadding,
    super.key,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileStreamProvider).asData?.value;
    final String? displayName = _displayNameFromProfile(profile?.name);
    final List<SavedAddress> addresses =
        ref.watch(savedAddressesStreamProvider).asData?.value ??
            const <SavedAddress>[];
    final SavedAddress? address = _preferredAddress(addresses);
    final String deliverLabel = address != null
        ? (address.label.trim().isNotEmpty
            ? address.label.trim()
            : address.line1.trim())
        : (displayName ?? 'Add address');

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.xs,
          horizontalPadding,
          AppSpacing.sm,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            _ProfileAvatar(
              photoUrl: profile?.photoUrl,
              name: displayName,
              onTap: () => context.push(AppRoutes.customerProfile),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: InkWell(
                onTap: () => context.push(AppRoutes.customerSavedAddresses),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          const Icon(
                            Icons.location_on_rounded,
                            size: 14,
                            color: AppColors.brandPrimary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Deliver to',
                            style:
                                Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: AppColors.textSecondary,
                                      fontWeight: FontWeight.w500,
                                      height: 1.1,
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              deliverLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.3,
                                    height: 1.15,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 20,
                            color: AppColors.textPrimary,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            _NotificationBellButton(
              tooltip: 'Notifications',
              hasUnread: (ref
                      .watch(customerUnreadNotificationCountProvider)
                      .asData
                      ?.value ??
                  0) >
                  0,
              onTap: () => context.push(AppRoutes.customerNotifications),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({
    required this.onTap,
    this.photoUrl,
    this.name,
  });

  final String? photoUrl;
  final String? name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String initials = name != null && name!.isNotEmpty
        ? name!.substring(0, 1).toUpperCase()
        : '?';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          padding: const EdgeInsets.all(2),
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            gradient: AppColors.brandGradient,
          ),
          child: DecoratedBox(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: ClipOval(
              child: photoUrl != null && photoUrl!.isNotEmpty
                  ? MndNetworkImage(
                      imageUrl: photoUrl!,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      showWatermarkOnError: false,
                      errorChild: _InitialsAvatar(initials: initials),
                    )
                  : _InitialsAvatar(initials: initials),
            ),
          ),
        ),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  const _InitialsAvatar({required this.initials});

  final String initials;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: AppColors.homeMutedFill,
      child: Text(
        initials,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.brandPrimary,
            ),
      ),
    );
  }
}

class _NotificationBellButton extends StatelessWidget {
  const _NotificationBellButton({
    required this.onTap,
    this.hasUnread = false,
    this.tooltip = 'Notifications',
  });

  final VoidCallback onTap;
  final bool hasUnread;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                const Icon(
                  Icons.notifications_none_rounded,
                  color: AppColors.textPrimary,
                  size: 24,
                ),
                if (hasUnread)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.brandPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
