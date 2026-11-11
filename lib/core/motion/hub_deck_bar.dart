import 'package:flutter/material.dart';

/// One tab hiding under the Activity chip.
class HubActivity {
  final String label;
  final int index;

  const HubActivity(this.label, this.index);
}

/// Browse / Mine / Activity. The existing tab children stay where they are.
/// Optional [accent] tints the selected chip — presentation only.
class HubDeckBar extends StatelessWidget {
  final TabController controller;
  final String browseLabel;
  final String mineLabel;
  final int browseIndex;
  final int mineIndex;
  final List<HubActivity> activity;
  final bool Function(int index)? guard;
  final Color? accent;

  const HubDeckBar({
    super.key,
    required this.controller,
    this.browseLabel = 'Browse',
    this.mineLabel = 'Mine',
    this.browseIndex = 0,
    this.mineIndex = 1,
    this.activity = const [],
    this.guard,
    this.accent,
  });

  void _go(int index) {
    if (guard != null && !guard!(index)) return;
    controller.animateTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tint = accent;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final index = controller.index;
        final activityOpen = activity.any((item) => item.index == index);
        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          child: Column(
            children: [
              Container(
                height: 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.06)
                      : Colors.white.withValues(alpha: 0.72),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: (tint ?? Colors.black).withValues(
                      alpha: isDark ? 0.12 : 0.06,
                    ),
                  ),
                  boxShadow: isDark
                      ? null
                      : [
                          BoxShadow(
                            color: (tint ?? Colors.black)
                                .withValues(alpha: 0.06),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    _Chip(
                      label: browseLabel,
                      selected: index == browseIndex,
                      accent: tint,
                      onTap: () => _go(browseIndex),
                    ),
                    _Chip(
                      label: mineLabel,
                      selected: index == mineIndex,
                      accent: tint,
                      onTap: () => _go(mineIndex),
                    ),
                    _Chip(
                      label: 'Activity',
                      selected: activityOpen,
                      accent: tint,
                      onTap: () {
                        if (activityOpen || activity.isEmpty) return;
                        _go(activity.first.index);
                      },
                    ),
                  ],
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: activityOpen
                    ? Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final item in activity)
                              _ActivityPill(
                                label: item.label,
                                selected: index == item.index,
                                accent: tint,
                                onTap: () => _go(item.index),
                              ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBg = accent != null
        ? accent!.withValues(alpha: isDark ? 0.28 : 0.14)
        : (isDark ? const Color(0xFF1E1A28) : Colors.white);
    final selectedFg = accent != null
        ? (isDark ? Colors.white : accent!)
        : (isDark ? Colors.white : const Color(0xFF1C1921));

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: selected ? selectedBg : Colors.transparent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: selected && !isDark && accent != null
                ? [
                    BoxShadow(
                      color: accent!.withValues(alpha: 0.16),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Center(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected
                        ? selectedFg
                        : Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActivityPill extends StatelessWidget {
  final String label;
  final bool selected;
  final Color? accent;
  final VoidCallback onTap;

  const _ActivityPill({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final color = accent ?? (isDark ? Colors.white : Colors.black);
    return Material(
      color: selected
          ? color.withValues(alpha: isDark ? 0.22 : 0.12)
          : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 12,
              color: selected
                  ? (isDark ? Colors.white : color)
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.45),
            ),
          ),
        ),
      ),
    );
  }
}
