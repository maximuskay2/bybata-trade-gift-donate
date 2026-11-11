import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../motion/swipe_commit.dart';
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
  final String? chapterCaption;
  final String? swipeCommitLabel;
  final Future<void> Function()? onSwipeCommit;
  final bool onStage;
  final String? heroPath;
  final String? reviewLabel;
  /// Opens the same capture flow as the media picker (stage “Add a photo”).
  final VoidCallback? onHeroTap;

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
    this.chapterCaption,
    this.swipeCommitLabel,
    this.onSwipeCommit,
    this.onStage = false,
    this.heroPath,
    this.reviewLabel,
    this.onHeroTap,
  });

  @override
  Widget build(BuildContext context) {
    final themeDark = Theme.of(context).brightness == Brightness.dark;
    final isDark = onStage || themeDark;
    final bgColor = onStage
        ? accentColor
        : (themeDark ? const Color(0xFF121212) : const Color(0xFFF4F7FA));

    final content = SafeArea(
      bottom: false,
      child: Column(
        children: [
          ListingCreateHeader(
            title: title,
            accentColor: onStage ? Colors.white : accentColor,
            isDark: isDark,
            caption: chapterCaption,
            stepIndex: onStage ? currentStep : null,
            stepCount: onStage ? steps.length : null,
            stepIcons: onStage
                ? steps.map((s) => s.icon).toList(growable: false)
                : null,
          ),
          if (onStage)
            CreateStageWell(
              path: heroPath,
              color: accentColor,
              onTap: onHeroTap,
            ),
          if (!onStage)
            EnhancedStepper(
              currentStep: currentStep,
              totalSteps: steps.length,
              steps: steps,
              primaryColor: accentColor,
              isDark: isDark,
            ),
          Expanded(
            child: onStage
                ? _CreateGlassSheet(
                    accent: accentColor,
                    child: body,
                  )
                : body,
          ),
          ListingCreateNavBar(
            accentColor: accentColor,
            isDark: isDark,
            stageColor: onStage ? accentColor : null,
            showBack: showBackButton && currentStep > 0,
            onBack: onBack,
            onPrimary: isLoading ? null : onPrimary,
            primaryLabel: primaryLabel,
            isLoading: isLoading,
            swipeCommitLabel: swipeCommitLabel,
            onSwipeCommit: onSwipeCommit,
            reviewLabel: reviewLabel,
          ),
        ],
      ),
    );

    return Scaffold(
      backgroundColor: bgColor,
      body: GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: () {
          final focus = FocusManager.instance.primaryFocus;
          if (focus != null && focus.hasFocus) {
            focus.unfocus();
          }
        },
        child: onStage
            ? Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color.lerp(accentColor, Colors.white, 0.18)!,
                          accentColor,
                          Color.lerp(accentColor, Colors.black, 0.22)!,
                        ],
                        stops: const [0.0, 0.42, 1.0],
                      ),
                    ),
                  ),
                  Positioned(
                    top: -80,
                    right: -60,
                    child: IgnorePointer(
                      child: Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.12),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 140,
                    left: -70,
                    child: IgnorePointer(
                      child: Container(
                        width: 180,
                        height: 180,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.black.withValues(alpha: 0.08),
                        ),
                      ),
                    ),
                  ),
                  content,
                ],
              )
            : content,
      ),
    );
  }
}

class _CreateGlassSheet extends StatelessWidget {
  final Color accent;
  final Widget child;

  const _CreateGlassSheet({required this.accent, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.94),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.55),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, -6),
                ),
                BoxShadow(
                  color: accent.withValues(alpha: 0.22),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Theme(
              data: Theme.of(context).copyWith(
                brightness: Brightness.light,
                colorScheme: ColorScheme.light(
                  primary: accent,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                  onSurface: Colors.black87,
                ),
              ),
              child: DefaultTextStyle.merge(
                style: const TextStyle(color: Colors.black87),
                child: IconTheme.merge(
                  data: const IconThemeData(color: Colors.black87),
                  child: child,
                ),
              ),
            ),
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
  final String? caption;
  final int? stepIndex;
  final int? stepCount;
  final List<IconData>? stepIcons;

  const ListingCreateHeader({
    super.key,
    required this.title,
    required this.accentColor,
    required this.isDark,
    this.onBack,
    this.caption,
    this.stepIndex,
    this.stepCount,
    this.stepIcons,
  });

  @override
  Widget build(BuildContext context) {
    final showSteps = stepIndex != null && stepCount != null && stepCount! > 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Material(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.white,
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
                            ? Colors.white.withValues(alpha: 0.16)
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    if (caption != null && caption!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        caption!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.78)
                              : accentColor,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (showSteps) ...[
            const SizedBox(height: 14),
            _CreateStepPills(
              current: stepIndex!,
              total: stepCount!,
              icons: stepIcons,
              light: isDark,
            ),
          ],
        ],
      ),
    );
  }
}

class _CreateStepPills extends StatelessWidget {
  final int current;
  final int total;
  final List<IconData>? icons;
  final bool light;

  const _CreateStepPills({
    required this.current,
    required this.total,
    required this.light,
    this.icons,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutCubic,
              height: 40,
              decoration: BoxDecoration(
                color: i == current
                    ? Colors.white
                    : Colors.white.withValues(alpha: i < current ? 0.28 : 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: i == current ? 0.95 : 0.2,
                  ),
                ),
                boxShadow: i == current
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.16),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    icons != null && i < icons!.length
                        ? icons![i]
                        : Icons.circle,
                    size: 16,
                    color: i == current
                        ? Colors.black87
                        : Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${i + 1}',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      color: i == current
                          ? Colors.black87
                          : Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
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
  final String? swipeCommitLabel;
  final Future<void> Function()? onSwipeCommit;
  final String? reviewLabel;
  final Color? stageColor;

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
    this.swipeCommitLabel,
    this.onSwipeCommit,
    this.reviewLabel,
    this.stageColor,
  });

  @override
  Widget build(BuildContext context) {
    final stage = stageColor;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        12,
        20,
        12 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: BoxDecoration(
        color: stage ??
            (isDark
                ? const Color(0xFF121212).withValues(alpha: 0.96)
                : Colors.white.withValues(alpha: 0.96)),
        border: Border(
          top: BorderSide(
            color: stage != null
                ? Colors.white.withValues(alpha: 0.12)
                : (isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.05)),
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
                  foregroundColor: stage != null
                      ? Colors.white
                      : (isDark ? Colors.white : Colors.black87),
                  side: BorderSide(
                    color: stage != null
                        ? Colors.white.withValues(alpha: 0.28)
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.18)
                            : Colors.black.withValues(alpha: 0.12)),
                  ),
                  minimumSize: const Size.fromHeight(54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
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
            child: swipeCommitLabel != null
                ? SwipeCommitControl(
                    label: swipeCommitLabel!,
                    accent: accentColor,
                    inverted: stage != null,
                    busy: isLoading,
                    onCommit: () async {
                      final commit = onSwipeCommit;
                      if (commit != null) {
                        await commit();
                        return;
                      }
                      onPrimary?.call();
                    },
                  )
                : reviewLabel != null
                    ? _ReviewPill(
                        label: reviewLabel!,
                        accent: stage != null ? Colors.white : accentColor,
                        onStage: stage != null,
                        onTap: onPrimary,
                      )
                    : FilledButton(
                        onPressed: onPrimary == null
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                onPrimary!();
                              },
                        style: FilledButton.styleFrom(
                          backgroundColor:
                              stage != null ? Colors.white : accentColor,
                          foregroundColor:
                              stage != null ? accentColor : Colors.white,
                          disabledBackgroundColor: (stage != null
                                  ? Colors.white
                                  : accentColor)
                              .withValues(alpha: 0.45),
                          minimumSize: const Size.fromHeight(54),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child: isLoading
                            ? SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    stage != null ? accentColor : Colors.white,
                                  ),
                                ),
                              )
                            : Text(
                                primaryLabel,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
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

class _ReviewPill extends StatelessWidget {
  final String label;
  final Color accent;
  final bool onStage;
  final VoidCallback? onTap;

  const _ReviewPill({
    required this.label,
    required this.accent,
    required this.onStage,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: Material(
        color: onStage ? Colors.white : accent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          key: const Key('create-review-handle'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.3,
                    fontSize: 15,
                    color: onStage ? Colors.black87 : Colors.white,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: onStage ? Colors.black87 : Colors.white,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Empty hub-colored well. A new photo flies into the ring.
class CreateStageWell extends StatefulWidget {
  final String? path;
  final Color color;
  final VoidCallback? onTap;

  const CreateStageWell({
    super.key,
    required this.color,
    this.path,
    this.onTap,
  });

  @override
  State<CreateStageWell> createState() => _CreateStageWellState();
}

class _CreateStageWellState extends State<CreateStageWell>
    with TickerProviderStateMixin {
  late final AnimationController _fly;
  late final AnimationController _breathe;
  String? _seen;

  @override
  void initState() {
    super.initState();
    _fly = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 520),
    );
    _breathe = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _seen = widget.path;
    if (widget.path != null) _fly.value = 1;
  }

  @override
  void didUpdateWidget(CreateStageWell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.path != _seen && widget.path != null) {
      _seen = widget.path;
      _fly.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _fly.dispose();
    _breathe.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.path;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final well = SizedBox(
      height: 188,
      child: AnimatedBuilder(
        animation: Listenable.merge([_fly, _breathe]),
        builder: (context, _) {
          final t = reduce
              ? 1.0
              : Curves.easeOutBack.transform(_fly.value.clamp(0.0, 1.0));
          final breath = reduce ? 0.0 : _breathe.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: 1 + 0.04 * breath,
                child: Container(
                  width: 176,
                  height: 176,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE8C872).withValues(
                        alpha: 0.55 + 0.35 * breath,
                      ),
                      width: 3,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE8C872).withValues(
                          alpha: 0.18 + 0.22 * breath,
                        ),
                        blurRadius: 28,
                      ),
                    ],
                    gradient: RadialGradient(
                      colors: [
                        Colors.white.withValues(alpha: 0.32),
                        Colors.white.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              if (path != null && path.isNotEmpty)
                Transform.scale(
                  scale: 0.18 + 0.82 * t,
                  child: Container(
                    width: 128,
                    height: 128,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.28),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.file(
                        File(path),
                        width: 128,
                        height: 128,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const ColoredBox(
                          color: Colors.white24,
                          child: Icon(
                            Icons.image_outlined,
                            color: Colors.white,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
              else
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_a_photo_outlined,
                      color: Colors.white.withValues(alpha: 0.92),
                      size: 28,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add a photo',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
            ],
          );
        },
      ),
    );
    if (widget.onTap == null) return well;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap!();
        },
        customBorder: const CircleBorder(),
        child: well,
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
        color: accentColor.withValues(alpha: isDark ? 0.14 : 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.28)),
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
                fontWeight: FontWeight.w600,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.88)
                    : Colors.black.withValues(alpha: 0.75),
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
