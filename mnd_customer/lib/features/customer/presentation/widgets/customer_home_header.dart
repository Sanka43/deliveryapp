import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/constants/app_routes.dart';
import 'package:mnd_delivery_app/core/constants/app_spacing.dart';
import 'package:mnd_delivery_app/features/customer/data/customer_live_location_service.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_live_location_provider.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/presentation/providers/customer_profile_provider.dart';

/// Content below status bar (greeting + location row).
const double kCustomerHomeHeaderContentHeight = 76;

double customerHomeHeaderTotalHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + kCustomerHomeHeaderContentHeight;
}

String _timeBasedGreeting() {
  final int hour = DateTime.now().hour;
  if (hour < 12) {
    return 'Good morning';
  }
  if (hour < 17) {
    return 'Good afternoon';
  }
  return 'Good evening';
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

class CustomerHomeHeaderSection extends ConsumerWidget {
  const CustomerHomeHeaderSection({
    required this.horizontalPadding,
    super.key,
  });

  final double horizontalPadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileStreamProvider).asData?.value;
    final String? firstName = _firstNameFromProfile(profile?.name);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          AppSpacing.xs,
          horizontalPadding,
          AppSpacing.sm,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: <Widget>[
                _ProfileAvatar(
                  photoUrl: profile?.photoUrl,
                  name: firstName,
                  onTap: () => context.go(AppRoutes.customerProfile),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(
                        firstName != null
                            ? '${_timeBasedGreeting()}, $firstName 👋'
                            : '${_timeBasedGreeting()} 👋',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.35,
                          height: 1.05,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const _HomeLiveLocationRow(),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                _NotificationBellButton(
                  onTap: () => context.push(AppRoutes.customerNotificationSettings),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _firstNameFromProfile(String? name) {
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
    return _capitalizeWord(parts.first);
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
        style: GoogleFonts.plusJakartaSans(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: AppColors.brandPrimary,
        ),
      ),
    );
  }
}

class _HomeLiveLocationRow extends ConsumerWidget {
  const _HomeLiveLocationRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<CustomerLiveLocationLabel> location =
        ref.watch(customerLiveLocationProvider);

    return location.when(
      data: (CustomerLiveLocationLabel label) =>
          _LocationChip(label: label, loading: false),
      loading: () => const _LocationChip(
        label: CustomerLiveLocationLabel.loading(),
        loading: true,
      ),
      error: (_, __) => const _LocationChip(
        label: CustomerLiveLocationLabel.unavailable('Could not load location'),
        loading: false,
      ),
    );
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({required this.label, required this.loading});

  final CustomerLiveLocationLabel label;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final bool unavailable = !label.isLive && !loading;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => context.push(AppRoutes.customerSavedAddresses),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 1),
          child: Row(
            children: <Widget>[
              Icon(
                Icons.location_on_rounded,
                size: 14,
                color: AppColors.brandPrimary.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 4),
              if (loading)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.brandPrimary.withValues(alpha: 0.8),
                  ),
                ),
              if (loading) const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label.line,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: unavailable
                        ? AppColors.textSecondary
                        : AppColors.textPrimary.withValues(alpha: 0.85),
                  ),
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                size: 16,
                color: AppColors.textSecondary.withValues(alpha: 0.7),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationBellButton extends StatefulWidget {
  const _NotificationBellButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_NotificationBellButton> createState() => _NotificationBellButtonState();
}

class _NotificationBellButtonState extends State<_NotificationBellButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Material(
      color: Colors.transparent,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: widget.onTap,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: AppColors.cardShadow,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: AppColors.textPrimary,
                size: 20,
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: reduceMotion
                  ? _UnreadDot(opacity: 1)
                  : AnimatedBuilder(
                      animation: _pulse,
                      builder: (BuildContext context, Widget? child) {
                        return _UnreadDot(opacity: 0.65 + _pulse.value * 0.35);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot({required this.opacity});

  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.brandSecondary.withValues(alpha: opacity),
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.brandPrimary.withValues(alpha: 0.5 * opacity),
            blurRadius: 6,
            spreadRadius: 1,
          ),
        ],
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
