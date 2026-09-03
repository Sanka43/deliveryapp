import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mnd_delivery_app/core/constants/app_colors.dart';
import 'package:mnd_delivery_app/core/widgets/mnd_network_image.dart';
import 'package:mnd_delivery_app/features/customer/domain/entities/customer_profile.dart';

/// Circular profile avatar with optional local preview and camera badge.
class CustomerProfileAvatar extends StatelessWidget {
  const CustomerProfileAvatar({
    required this.profile,
    this.size = 72,
    this.localFile,
    this.showCameraBadge = false,
    this.onTap,
    this.isLoading = false,
    super.key,
  });

  final CustomerProfile profile;
  final double size;
  final File? localFile;
  final bool showCameraBadge;
  final VoidCallback? onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final Widget avatar = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: AppColors.primaryBlue.withValues(alpha: 0.2),
            blurRadius: size * 0.14,
            offset: Offset(0, size * 0.05),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          _AvatarFace(
            profile: profile,
            size: size,
            localFile: localFile,
          ),
          if (isLoading)
            ColoredBox(
              color: Colors.black.withValues(alpha: 0.35),
              child: const Center(
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    Widget body = avatar;
    if (showCameraBadge) {
      final double badge = (size * 0.28).clamp(22.0, 32.0);
      body = SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            avatar,
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: AppColors.primaryBlue,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: <BoxShadow>[
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.camera_alt_rounded,
                  size: badge * 0.48,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (onTap == null) {
      return body;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        customBorder: const CircleBorder(),
        child: body,
      ),
    );
  }
}

class _AvatarFace extends StatelessWidget {
  const _AvatarFace({
    required this.profile,
    required this.size,
    this.localFile,
  });

  final CustomerProfile profile;
  final double size;
  final File? localFile;

  @override
  Widget build(BuildContext context) {
    if (localFile != null) {
      return Image.file(
        localFile!,
        fit: BoxFit.cover,
        width: size,
        height: size,
        errorBuilder: (_, __, ___) => _InitialsFallback(
          profile: profile,
          size: size,
        ),
      );
    }

    final String? url = profile.photoUrl;
    if (url != null && url.isNotEmpty) {
      return MndNetworkImage(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        borderRadius: BorderRadius.circular(size / 2),
        showWatermarkOnError: false,
        errorChild: _InitialsFallback(profile: profile, size: size),
      );
    }

    return _InitialsFallback(profile: profile, size: size);
  }
}

class _InitialsFallback extends StatelessWidget {
  const _InitialsFallback({
    required this.profile,
    required this.size,
  });

  final CustomerProfile profile;
  final double size;

  @override
  Widget build(BuildContext context) {
    final double fontSize = size * 0.32;
    return ColoredBox(
      color: AppColors.primaryBlue.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          profile.initials,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontSize: fontSize,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryBlue,
              ),
        ),
      ),
    );
  }
}
