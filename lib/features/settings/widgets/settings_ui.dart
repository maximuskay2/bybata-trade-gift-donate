import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../core/theme/borderless_input_decoration.dart';
import '../../../core/widgets/bybata_glass_container.dart';
import '../../../core/widgets/cached_media_image.dart';
import '../../profile/models/user_profile.dart';

/// Shared layout tokens for all settings screens.
class SettingsUi {
  SettingsUi._();

  static const double cardRadius = 20;
  static const EdgeInsets screenPadding = EdgeInsets.fromLTRB(20, 0, 20, 32);
  static const EdgeInsets cardPadding = EdgeInsets.fromLTRB(20, 20, 20, 12);

  static Color pageBackground(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
  }
}

/// Settings page with profile-aligned chrome (custom back, no default AppBar clutter).
class SettingsPageScaffold extends StatelessWidget {
  final String title;
  final Widget body;
  final Widget? bottom;
  final bool showSearch;
  final TextEditingController? searchController;
  final ValueChanged<String>? onSearchChanged;
  final VoidCallback? onBack;

  const SettingsPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.bottom,
    this.showSearch = false,
    this.searchController,
    this.onSearchChanged,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: SettingsUi.pageBackground(context),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                child: Row(
                  children: [
                    _SettingsBackButton(
                      onTap: onBack ?? () => Navigator.of(context).pop(),
                      isDark: isDark,
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),
                    const SizedBox(width: 44),
                  ],
                ),
              ),
              if (showSearch) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: scheme.outlineVariant.withValues(alpha: 0.4),
                      ),
                    ),
                    child: TextField(
                      controller: searchController,
                      onChanged: onSearchChanged,
                      decoration: BorderlessInputDecoration.search(
                        hintText: 'Search settings',
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              Expanded(child: body),
              if (bottom != null) bottom!,
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsBackButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _SettingsBackButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.15)
                : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: isDark ? Colors.white : Colors.black87,
        ),
      ),
    );
  }
}

class SettingsProfileHeader extends StatelessWidget {
  final UserProfile profile;

  const SettingsProfileHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.35),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: scheme.shadow.withValues(alpha: 0.12),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipOval(
              child: profile.avatar != null && profile.avatar!.isNotEmpty
                  ? CachedMediaImage(
                      mediaKey: profile.avatar,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      errorWidget: _initials(context),
                    )
                  : _initials(context),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.email,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (profile.isVerified) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.successColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Verified',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.successColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _initials(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Center(
        child: Text(
          profile.initials,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class SettingsGroupCard extends StatelessWidget {
  final String? title;
  final List<Widget> children;

  const SettingsGroupCard({
    super.key,
    this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
      child: Padding(
        padding: SettingsUi.cardPadding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (title != null) ...[
              Text(
                title!,
                style: textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
            ],
            ...children,
          ],
        ),
      ),
    );
  }
}

class SettingsHubTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const SettingsHubTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      leading: Container(
        width: 44,
        height: 44,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: accent, size: 22),
      ),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            )
          : null,
      trailing: trailing ??
          Icon(
            Icons.chevron_right_rounded,
            color: scheme.onSurfaceVariant,
            size: 22,
          ),
      onTap: onTap,
      onLongPress: onLongPress,
    );
  }
}

class SettingsNavTile extends SettingsHubTile {
  const SettingsNavTile({
    super.key,
    required super.icon,
    required super.title,
    super.subtitle,
    super.trailing,
    super.onTap,
    super.onLongPress,
  });
}

class SettingsSwitchTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  const SettingsSwitchTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      title: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.35,
            ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: scheme.onPrimary,
      activeTrackColor: scheme.primary,
    );
  }
}

/// Divider aligned with icon-leading rows (nav / hub tiles).
class SettingsNavDivider extends StatelessWidget {
  const SettingsNavDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: 56,
      endIndent: 0,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

/// Divider for switch-only rows (full width).
class SettingsSwitchDivider extends StatelessWidget {
  const SettingsSwitchDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.45),
    );
  }
}

class SettingsDangerCard extends StatelessWidget {
  final String buttonLabel;
  final VoidCallback onPressed;

  const SettingsDangerCard({
    super.key,
    required this.buttonLabel,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;

    return ByBataGlassContainer(
      borderRadius: BorderRadius.circular(SettingsUi.cardRadius),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DANGER ZONE',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: danger,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Permanently remove your account and all associated data.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPressed,
                icon: Icon(Icons.delete_forever_rounded, color: danger, size: 22),
                label: Text(
                  buttonLabel,
                  style: TextStyle(
                    color: danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: danger,
                  side: BorderSide(color: danger.withValues(alpha: 0.65)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void showSettingsSnack(
  BuildContext context,
  String message, {
  bool success = true,
}) {
  if (success) {
    AppToast.success(context, message);
  } else {
    AppToast.error(context, message);
  }
}
