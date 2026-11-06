import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CreatorCard extends StatelessWidget {
  final String userId;
  final String name;
  final String? avatarUrl;
  final double rating;
  final bool isVerified;
  final String subtitle;
  final bool showButtons;
  final VoidCallback? onViewProfile;
  final VoidCallback? onMessage;
  final VoidCallback? onSecondaryAction;
  final String? secondaryButtonLabel;

  const CreatorCard({
    super.key,
    required this.userId,
    required this.name,
    this.avatarUrl,
    required this.rating,
    required this.isVerified,
    required this.subtitle,
    this.showButtons = true,
    this.onViewProfile,
    this.onMessage,
    this.onSecondaryAction,
    this.secondaryButtonLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = scheme.surface;
    final primaryColor = AppColors.primary;
    final viewProfile = onViewProfile;
    final message = onMessage;
    final secondaryAction = onSecondaryAction;

    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.1) : Colors.grey[300] ?? Colors.grey,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 8)],
                ),
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFFF0F2F5),
                  backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                  child: avatarUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: primaryColor),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: scheme.onSurface,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isVerified) ...[
                          const SizedBox(width: 6),
                          Icon(Icons.verified_rounded, color: primaryColor, size: 18),
                        ]
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '$rating ★',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.55),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (showButtons) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (viewProfile != null) ...[
                  Expanded(
                    child: _ActionButton(
                      label: 'Profile',
                      onTap: viewProfile,
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (message != null) ...[
                  Expanded(
                    child: _ActionButton(
                      label: 'Message',
                      onTap: message,
                      isPrimary: false,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                if (secondaryAction != null)
                  Expanded(
                    child: _ActionButton(
                      label: secondaryButtonLabel ?? 'Follow',
                      onTap: secondaryAction,
                      isPrimary: true,
                    ),
                  ),
              ],
            ),
          ]
        ],
      ),
    );
  }
}

class _ActionButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isPrimary;

  const _ActionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  State<_ActionButton> createState() => _ActionButtonState();
}

class _ActionButtonState extends State<_ActionButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;
    final scheme = Theme.of(context).colorScheme;
    final bgColor = widget.isPrimary
        ? primaryColor
        : (isDark ? scheme.onSurface.withValues(alpha: 0.1) : scheme.surface);
    final textColor = widget.isPrimary ? Colors.white : scheme.onSurface;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(top: _isPressed ? 2 : 0),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(10),
          border: widget.isPrimary
              ? null
              : Border.all(
                  color: isDark ? Colors.white.withOpacity(0.2) : Colors.grey[300] ?? Colors.grey,
                  width: 1.5,
                ),
          boxShadow: _isPressed
              ? []
              : [
                  BoxShadow(
                    color: (widget.isPrimary ? primaryColor : Colors.black).withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  )
                ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
