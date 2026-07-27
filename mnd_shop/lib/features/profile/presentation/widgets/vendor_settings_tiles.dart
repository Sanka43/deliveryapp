import 'package:flutter/material.dart';
import 'package:mnd_shop/core/constants/app_colors.dart';

Color _primaryText(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onSurface
      : AppColors.textCharcoal;
}

Color _mutedText(BuildContext context) {
  final ThemeData theme = Theme.of(context);
  return theme.brightness == Brightness.dark
      ? theme.colorScheme.onSurfaceVariant
      : AppColors.textMuted;
}

class VendorSettingsSectionTitle extends StatelessWidget {
  const VendorSettingsSectionTitle({required this.label, super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.titleSmall?.copyWith(
        fontWeight: FontWeight.w700,
        color: _mutedText(context),
        letterSpacing: 0.15,
      ),
    );
  }
}

class VendorSettingsNavTile extends StatelessWidget {
  const VendorSettingsNavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.trailingBadge,
    this.trimBottomSpacing = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final String? subtitle;
  final int? trailingBadge;
  final bool trimBottomSpacing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: EdgeInsets.only(bottom: trimBottomSpacing ? 0 : 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              color: theme.brightness == Brightness.dark
                  ? cs.surfaceContainerLow
                  : Colors.white,
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.4),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: cs.shadow.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: <Widget>[
                  Icon(icon, color: AppColors.primaryBlue, size: 22),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          label,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: _primaryText(context),
                          ),
                        ),
                        if (subtitle != null &&
                            subtitle!.isNotEmpty) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: _mutedText(context),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (trailingBadge != null && trailingBadge! > 0) ...<Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: cs.error,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        trailingBadge! > 99 ? '99+' : '$trailingBadge',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onError,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Icon(Icons.chevron_right_rounded, color: _mutedText(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class VendorSettingsSwitchTile extends StatelessWidget {
  const VendorSettingsSwitchTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: theme.brightness == Brightness.dark
                ? cs.surfaceContainerLow
                : Colors.white,
            border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.4)),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(icon, color: AppColors.primaryBlue, size: 22),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        label,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _primaryText(context),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: _mutedText(context),
                        ),
                      ),
                    ],
                  ),
                ),
                _TriggerToggleButton(value: value, onChanged: onChanged),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TriggerToggleButton extends StatelessWidget {
  const _TriggerToggleButton({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme cs = theme.colorScheme;
    final bool disabled = onChanged == null;
    final Color trackColor = disabled
        ? cs.outlineVariant.withValues(alpha: 0.35)
        : (value
              ? AppColors.primaryBlue
              : (theme.brightness == Brightness.dark
                    ? cs.surfaceContainerHighest
                    : const Color(0xFFDCE3F5)));
    final Color knobColor = disabled
        ? cs.surfaceContainerHighest
        : (value ? Colors.white : cs.surface);

    return Opacity(
      opacity: disabled ? 0.65 : 1,
      child: GestureDetector(
        onTap: disabled ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: 56,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: value
                  ? AppColors.primaryBlue.withValues(alpha: 0.9)
                  : cs.outlineVariant.withValues(alpha: 0.4),
            ),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: cs.shadow.withValues(alpha: 0.16),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: knobColor,
                shape: BoxShape.circle,
                boxShadow: <BoxShadow>[
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                value ? Icons.check_rounded : Icons.close_rounded,
                size: 14,
                color: value ? AppColors.primaryBlue : _mutedText(context),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
