import 'package:flutter/material.dart';
import '../../../core/utils/haptic_utils.dart';

class SettingsTile extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final EdgeInsetsGeometry? contentPadding;

  const SettingsTile({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.contentPadding,
  });

  // Factory constructor for navigation tiles
  factory SettingsTile.navigation({
    required String title,
    String? subtitle,
    Widget? leading,
    Widget? trailing,
    VoidCallback? onTap,
    bool enabled = true,
    IconData? leadingIcon,
    Color? textColor,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leading: leading ?? (leadingIcon != null ? Icon(leadingIcon) : null),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: onTap,
      enabled: enabled,
    );
  }

  // Factory constructor for switch tiles
  factory SettingsTile.switchTile({
    required String title,
    String? subtitle,
    Widget? leading,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool enabled = true,
    IconData? leadingIcon,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leading: leading ?? (leadingIcon != null ? Icon(leadingIcon) : null),
      trailing: Switch(
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
      onTap: enabled && onChanged != null 
          ? () {
              HapticUtils.light();
              onChanged(!value);
            }
          : null,
      enabled: enabled,
    );
  }

  // Factory constructor for widget tiles
  factory SettingsTile.widget({
    required String title,
    String? subtitle,
    Widget? leading,
    required Widget widget,
    VoidCallback? onTap,
    bool enabled = true,
    IconData? leadingIcon,
  }) {
    return SettingsTile(
      title: title,
      subtitle: subtitle,
      leading: leading ?? (leadingIcon != null ? Icon(leadingIcon) : null),
      trailing: widget,
      onTap: onTap,
      enabled: enabled,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          color: enabled
              ? Theme.of(context).colorScheme.onSurface
              : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: TextStyle(
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            )
          : null,
      leading: leading != null
          ? IconTheme(
              data: IconThemeData(
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              child: leading!,
            )
          : null,
      trailing: trailing != null
          ? IconTheme(
              data: IconThemeData(
                color: enabled
                    ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)
                    : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              ),
              child: trailing!,
            )
          : null,
      onTap: enabled ? onTap : null,
      enabled: enabled,
      contentPadding: contentPadding ?? const EdgeInsets.symmetric(horizontal: 20),
    );
  }
}