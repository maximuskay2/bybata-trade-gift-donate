import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'discard_changes_sheet.dart';
import 'listing_create_shell.dart';

/// Shared shell for edit screens: header, scroll body, sticky actions, unsaved guard.
class EditFormScaffold extends StatelessWidget {
  final String title;
  final String? subtitle;
  final bool isLoading;
  final bool isDirty;
  final VoidCallback onSave;
  final Widget child;
  final Color? accentColor;
  final String? swipeCommitLabel;
  final Future<void> Function()? onSwipeCommit;

  /// Optional label for discard sheet copy, e.g. "gift", "trade", "donation".
  final String? discardItemLabel;

  const EditFormScaffold({
    super.key,
    required this.title,
    required this.isLoading,
    required this.isDirty,
    required this.onSave,
    required this.child,
    this.subtitle,
    this.accentColor,
    this.discardItemLabel,
    this.swipeCommitLabel,
    this.onSwipeCommit,
  });

  Future<bool> _confirmDiscard(BuildContext context) async {
    if (!isDirty) return true;
    return DiscardChangesSheet.show(
      context,
      itemLabel: discardItemLabel,
    );
  }

  Future<void> _handleBack(BuildContext context) async {
    final leave = await _confirmDiscard(context);
    if (leave && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);
    final accent = accentColor ?? AppColors.primary;

    return PopScope(
      canPop: !isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleBack(context);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: GestureDetector(
          behavior: HitTestBehavior.deferToChild,
          onTap: () {
            final focus = FocusManager.instance.primaryFocus;
            if (focus != null && focus.hasFocus) {
              focus.unfocus();
            }
          },
          child: SafeArea(
            child: Column(
              children: [
                ListingCreateHeader(
                  title: title,
                  accentColor: accent,
                  isDark: isDark,
                  onBack: () => _handleBack(context),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (subtitle != null) ...[
                          Text(
                            subtitle!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.4,
                              color: isDark ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 14),
                        ],
                        child,
                      ],
                    ),
                  ),
                ),
                ListingCreateNavBar(
                  accentColor: accent,
                  isDark: isDark,
                  showBack: true,
                  secondaryLabel: 'Cancel',
                  onBack: () => _handleBack(context),
                  onPrimary: isLoading ? null : onSave,
                  primaryLabel: 'Save changes',
                  isLoading: isLoading,
                  swipeCommitLabel: swipeCommitLabel,
                  onSwipeCommit: onSwipeCommit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grouped card for edit forms — keeps related fields in one visual block.
class EditFormCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color accentColor;
  final Widget child;

  const EditFormCard({
    super.key,
    required this.title,
    required this.icon,
    required this.accentColor,
    required this.child,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A20) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.07)
              : Colors.black.withValues(alpha: 0.06),
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDark ? 0.18 : 0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(icon, color: accentColor, size: 21),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: isDark ? Colors.grey[500] : Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            child: child,
          ),
        ],
      ),
    );
  }
}

/// Subtle divider between fields inside an [EditFormCard].
class EditFormDivider extends StatelessWidget {
  const EditFormDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark
            ? Colors.white.withValues(alpha: 0.07)
            : Colors.black.withValues(alpha: 0.06),
      ),
    );
  }
}

/// Compact footnote below cards (replaces large tip banners on edit screens).
class EditFormFootnote extends StatelessWidget {
  final String text;
  final Color accentColor;
  final IconData icon;

  const EditFormFootnote({
    super.key,
    required this.text,
    required this.accentColor,
    this.icon = Icons.info_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 2, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: accentColor.withValues(alpha: 0.85)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Karma / claims slider block used inside gift edit cards.
class EditFormKarmaBlock extends StatelessWidget {
  final Color accent;
  final bool isDark;
  final int karmaReward;
  final int karmaMin;
  final int karmaMax;
  final int maxClaims;
  final ValueChanged<int> onKarmaChanged;
  final ValueChanged<int> onMaxClaimsChanged;

  const EditFormKarmaBlock({
    super.key,
    required this.accent,
    required this.isDark,
    required this.karmaReward,
    required this.karmaMin,
    required this.karmaMax,
    required this.maxClaims,
    required this.onKarmaChanged,
    required this.onMaxClaimsChanged,
  });

  @override
  Widget build(BuildContext context) {
    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: accent,
      thumbColor: accent,
      inactiveTrackColor: accent.withValues(alpha: 0.2),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Karma reward',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.grey[400] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Text(
              '$karmaReward',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: accent,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'KARMA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: accent.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: sliderTheme,
          child: karmaMax > karmaMin
              ? Slider(
                  value: karmaReward.clamp(karmaMin, karmaMax).toDouble(),
                  min: karmaMin.toDouble(),
                  max: karmaMax.toDouble(),
                  divisions: (karmaMax - karmaMin).clamp(1, 100),
                  onChanged: (v) => onKarmaChanged(v.round()),
                )
              : const SizedBox.shrink(),
        ),
        if (karmaMax <= karmaMin)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              'Fixed at $karmaMin KARMA per gift claim',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
            ),
          ),
        const SizedBox(height: 4),
        Text(
          'Max claims: $maxClaims',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        SliderTheme(
          data: sliderTheme,
          child: Slider(
            value: maxClaims.toDouble().clamp(1, 20),
            min: 1,
            max: 20,
            divisions: 19,
            onChanged: (v) => onMaxClaimsChanged(v.round()),
          ),
        ),
      ],
    );
  }
}

/// Legacy section wrapper — prefer [EditFormCard] with an explicit icon.
class EditFormSection extends EditFormCard {
  EditFormSection({
    super.key,
    required super.title,
    super.subtitle,
    required super.child,
    Color? accentColor,
    IconData icon = Icons.edit_note_rounded,
  }) : super(icon: icon, accentColor: accentColor ?? AppColors.primary);
}
