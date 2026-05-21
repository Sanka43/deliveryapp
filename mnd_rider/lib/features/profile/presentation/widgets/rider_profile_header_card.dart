import 'package:flutter/material.dart';
import 'package:mnd_rider/core/constants/app_colors.dart';
import 'package:mnd_rider/core/widgets/rider_large_card.dart';
import 'package:mnd_rider/features/auth/domain/rider_vehicle_type.dart';
import 'package:mnd_rider/features/profile/domain/rider_profile.dart';

class RiderProfileHeaderCard extends StatelessWidget {
  const RiderProfileHeaderCard({
    super.key,
    required this.profile,
    required this.onChangePhoto,
    required this.onEditProfile,
  });

  final RiderProfile profile;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color approvalColor = _approvalColor(profile.approvalStatusLabel);

    return RiderLargeCard(
      child: Column(
        children: <Widget>[
          Stack(
            children: <Widget>[
              CircleAvatar(
                radius: 44,
                backgroundColor: AppColors.surfaceMuted,
                backgroundImage: profile.profilePhotoUrl != null
                    ? NetworkImage(profile.profilePhotoUrl!)
                    : null,
                child: profile.profilePhotoUrl == null
                    ? Icon(Icons.person, size: 44, color: theme.colorScheme.primary)
                    : null,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Material(
                  color: theme.colorScheme.primary,
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onChangePhoto,
                    customBorder: const CircleBorder(),
                    child: const Padding(
                      padding: EdgeInsets.all(8),
                      child: Icon(Icons.camera_alt_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            profile.fullName,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          if (profile.phone.isNotEmpty)
            Text(
              profile.phone,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(
              color: approvalColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: approvalColor.withValues(alpha: 0.35)),
            ),
            child: Text(
              profile.approvalStatusLabel,
              style: theme.textTheme.labelMedium?.copyWith(
                color: approvalColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(
                _vehicleIcon(profile.vehicleType),
                size: 18,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                '${profile.vehicleType.label} · ${profile.vehicleNumber}',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onEditProfile,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit profile'),
            ),
          ),
        ],
      ),
    );
  }

  static Color _approvalColor(String label) {
    final String s = label.toLowerCase();
    if (s.contains('approved')) {
      return AppColors.onlineGreen;
    }
    if (s.contains('rejected')) {
      return AppColors.errorRed;
    }
    return AppColors.warningAmber;
  }

  static IconData _vehicleIcon(RiderVehicleType type) {
    return switch (type) {
      RiderVehicleType.bike => Icons.two_wheeler,
      RiderVehicleType.threeWheeler => Icons.electric_rickshaw_outlined,
      RiderVehicleType.van => Icons.local_shipping_outlined,
    };
  }
}
