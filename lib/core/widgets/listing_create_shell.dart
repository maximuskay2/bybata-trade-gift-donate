import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'enhanced_stepper.dart';

/// Shared chrome for Trade / Gift / Donation create flows.
class ListingCreateShell extends StatelessWidget {
  final String title;
  final Color accentColor;
  final int currentStep;
  final List<StepConfig> steps;
  final Widget body;
  final VoidCallback? onBack;
  final VoidCallback? onPrimary;
  final String primaryLabel;
  final bool isLoading;
  final bool showBackButton;

  const ListingCreateShell({
    super.key,
    required this.title,
    required this.accentColor,
    required this.currentStep,
    required this.steps,
    required this.body,
    required this.primaryLabel,
    this.onBack,
    this.onPrimary,
    this.isLoading = false,
    this.showBackButton = true,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA);

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: Column(
            children: [
              ListingCreateHeader(
                title: title,
                accentColor: accentColor,
                isDark: isDark,
              ),
              EnhancedStepper(
                currentStep: currentStep,
                totalSteps: steps.length,
                steps: steps,
                primaryColor: accentColor,
                isDark: isDark,
              ),
              Expanded(child: body),
              ListingCreateNavBar(
                accentColor: accentColor,
                isDark: isDark,
                showBack: showBackButton && currentStep > 0,
                onBack: onBack,
                onPrimary: isLoading ? null : onPrimary,
                primaryLabel: primaryLabel,
                isLoading: isLoading,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ListingCreateHeader extends StatelessWidget {
  final String title;
  final Color accentColor;
  final bool isDark;
  final VoidCallback? onBack;

  const ListingCreateHeader({
    super.key,
    required this.title,
    required this.accentColor,
    required this.isDark,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Row(
        children: [
          Material(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onBack ?? () => Navigator.of(context).maybePop(),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 16,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 3,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ListingCreateNavBar extends StatelessWidget {
  final Color accentColor;
  final bool isDark;
  final bool showBack;
  final VoidCallback? onBack;
  final VoidCallback? onPrimary;
  final String primaryLabel;
  final String secondaryLabel;
  final bool isLoading;

  const ListingCreateNavBar({
    super.key,
    required this.accentColor,
    required this.isDark,
    required this.showBack,
    required this.primaryLabel,
    this.secondaryLabel = 'Back',
    this.onBack,
    this.onPrimary,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF121212).withValues(alpha: 0.96)
            : Colors.white.withValues(alpha: 0.96),
        border: Border(
          top: BorderSide(
            color: isDark
                ? Colors.white.withValues(alpha: 0.06)
                : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          if (showBack) ...[
            Expanded(
              child: OutlinedButton(
                onPressed: onBack == null
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        onBack!();
                      },
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark ? Colors.white : Colors.black87,
                  side: BorderSide(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.18)
                        : Colors.black.withValues(alpha: 0.12),
                  ),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  secondaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            flex: showBack ? 2 : 1,
            child: FilledButton(
              onPressed: onPrimary == null
                  ? null
                  : () {
                      HapticFeedback.lightImpact();
                      onPrimary!();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Colors.white,
                disabledBackgroundColor: accentColor.withValues(alpha: 0.45),
                minimumSize: const Size.fromHeight(52),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      primaryLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Soft tip / helper card used inside create steps.
class ListingCreateTipCard extends StatelessWidget {
  final String text;
  final Color accentColor;
  final bool isDark;
  final IconData icon;

  const ListingCreateTipCard({
    super.key,
    required this.text,
    required this.accentColor,
    required this.isDark,
    this.icon = Icons.lightbulb_outline_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.12 : 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: accentColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w500,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.82)
                    : Colors.black.withValues(alpha: 0.72),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggle row used in create/edit preference sections.
class ListingEditToggleCard extends StatelessWidget {
  final bool isDark;
  final Color accent;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final bool highlighted;
  final bool embedded;

  const ListingEditToggleCard({
    super.key,
    required this.isDark,
    required this.accent,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.highlighted = false,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: embedded
          ? null
          : BoxDecoration(
              color: highlighted
                  ? accent.withValues(alpha: isDark ? 0.14 : 0.08)
                  : (isDark
                      ? const Color(0xFF1E1E24).withValues(alpha: 0.7)
                      : Colors.white),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: highlighted
                    ? accent.withValues(alpha: 0.35)
                    : (isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.06)),
              ),
            ),
      padding: EdgeInsets.symmetric(
        horizontal: embedded ? 0 : 14,
        vertical: embedded ? 10 : 12,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: accent, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeColor: accent,
          ),
        ],
      ),
    );
  }
}

/// Read-only pill for fields that cannot change after publish.
class ListingEditReadOnlyBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final bool isDark;
  final IconData? icon;

  const ListingEditReadOnlyBadge({
    super.key,
    required this.label,
    required this.value,
    required this.accent,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: accent),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.lock_outline_rounded,
            size: 16,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ],
      ),
    );
  }
}

/// Compact row of locked fields (e.g. gift type + category).
class ListingEditLockedChipsRow extends StatelessWidget {
  final Color accent;
  final bool isDark;
  final List<(String label, String value, IconData? icon)> items;

  const ListingEditLockedChipsRow({
    super.key,
    required this.accent,
    required this.isDark,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: isDark ? 0.08 : 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Container(
                width: 1,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 10),
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.08),
              ),
            Expanded(
              child: _LockedChip(
                label: items[i].$1,
                value: items[i].$2,
                icon: items[i].$3,
                accent: accent,
                isDark: isDark,
              ),
            ),
          ],
          const SizedBox(width: 6),
          Icon(
            Icons.lock_outline_rounded,
            size: 14,
            color: isDark ? Colors.grey[600] : Colors.grey[400],
          ),
        ],
      ),
    );
  }
}

class _LockedChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color accent;
  final bool isDark;

  const _LockedChip({
    required this.label,
    required this.value,
    required this.accent,
    required this.isDark,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[500] : Colors.grey[600],
          ),
        ),
        const SizedBox(height: 3),
        Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: accent),
              const SizedBox(width: 4),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Summary row used on review steps.
class ListingCreateSummaryCard extends StatelessWidget {
  final String title;
  final List<(String, String)> rows;
  final Color accentColor;
  final bool isDark;

  const ListingCreateSummaryCard({
    super.key,
    required this.title,
    required this.rows,
    required this.accentColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E24) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accentColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 88,
                    child: Text(
                      row.$1,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.grey[500] : Colors.grey[600],
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      row.$2,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
