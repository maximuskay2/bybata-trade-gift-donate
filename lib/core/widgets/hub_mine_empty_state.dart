import 'package:flutter/material.dart';

/// Branded empty state for hub "Mine" tabs (Trade, Gift, Donation).
/// Content centred; compact create CTA pinned near the bottom (not full-width).
class HubMineEmptyState extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final String buttonLabel;
  final VoidCallback onCreate;
  final List<String> hints;
  final bool showCreateButton;

  const HubMineEmptyState({
    super.key,
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.buttonLabel,
    required this.onCreate,
    this.hints = const [],
    this.showCreateButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              mainAxisAlignment: showCreateButton
                  ? MainAxisAlignment.spaceBetween
                  : MainAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 48, 28, 24),
                  child: Column(
                    children: [
                      _HeroIcon(
                        accentColor: accentColor,
                        icon: icon,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 28),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.4,
                          color: scheme.onSurface,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: scheme.onSurface.withValues(alpha: 0.62),
                        ),
                      ),
                      if (hints.isNotEmpty) ...[
                        const SizedBox(height: 24),
                        ...hints.map(
                          (hint) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _HintRow(
                              text: hint,
                              accentColor: accentColor,
                              scheme: scheme,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (showCreateButton)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                    child: Center(
                      child: _CompactCreateButton(
                        label: buttonLabel,
                        accentColor: accentColor,
                        onTap: onCreate,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact bottom create bar when the user already has listings.
class HubMineCreateBar extends StatelessWidget {
  final Color accentColor;
  final String label;
  final VoidCallback onTap;

  const HubMineCreateBar({
    super.key,
    required this.accentColor,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Center(
        child: _CompactCreateButton(
          label: label,
          accentColor: accentColor,
          onTap: onTap,
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final Color accentColor;
  final IconData icon;
  final bool isDark;

  const _HeroIcon({
    required this.accentColor,
    required this.icon,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
          ),
        ),
        Container(
          width: 88,
          height: 88,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                accentColor.withValues(alpha: 0.22),
                accentColor.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.18),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Icon(icon, size: 40, color: accentColor),
        ),
      ],
    );
  }
}

class _HintRow extends StatelessWidget {
  final String text;
  final Color accentColor;
  final ColorScheme scheme;

  const _HintRow({
    required this.text,
    required this.accentColor,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.check_circle_rounded, size: 16, color: accentColor.withValues(alpha: 0.85)),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
        ),
      ],
    );
  }
}

class _CompactCreateButton extends StatelessWidget {
  final String label;
  final Color accentColor;
  final VoidCallback onTap;

  const _CompactCreateButton({
    required this.label,
    required this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              colors: [accentColor, accentColor.withValues(alpha: 0.82)],
            ),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.35),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.add_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 0.2,
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
