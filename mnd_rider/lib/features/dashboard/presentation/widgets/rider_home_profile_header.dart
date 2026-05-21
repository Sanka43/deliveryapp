import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/features/auth/domain/rider_profile_document.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';

class RiderHomeProfileHeader extends StatelessWidget {
  const RiderHomeProfileHeader({
    super.key,
    required this.profile,
    required this.isOnline,
  });

  final RiderProfileDocument? profile;
  final bool isOnline;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final String name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Rider';
    final String? photo = profile?.profilePhotoUrl;
    final RiderVehicleType? vehicle =
        profile != null ? profile!.vehicleType : null;

    return Material(
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(18),
      color: theme.colorScheme.surface.withValues(alpha: 0.96),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            Stack(
              children: <Widget>[
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.15),
                  backgroundImage:
                      photo != null && photo.isNotEmpty ? NetworkImage(photo) : null,
                  child: photo == null || photo.isEmpty
                      ? const Icon(Icons.person, color: AppColors.primaryBlue)
                      : null,
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
                      shape: BoxShape.circle,
                      border: Border.all(color: theme.colorScheme.surface, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    vehicle?.label ?? 'MND Delivery Rider',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isOnline
                    ? AppColors.onlineGreen.withValues(alpha: 0.15)
                    : theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                isOnline ? 'Online' : 'Offline',
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isOnline ? AppColors.onlineGreen : AppColors.offlineGrey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
