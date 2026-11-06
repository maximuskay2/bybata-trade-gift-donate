import 'dart:ui';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme/theme_provider.dart';
import 'home_v2_tokens.dart';

/// The skeleton of every V2 home surface (authenticated + unauthenticated +
/// Discover tab). Responsible for:
///   1. Painting the purple ambient orbs that hand off from the splash.
///   2. Hosting a `CustomScrollView` so every section can compose as a
///      sliver (required for 60fps infinite feed scroll).
///   3. Applying a Cupertino pull-to-refresh bound to the caller.
///   4. Honoring light / dark / glass themes via [ThemeProvider].
///
/// The shell is intentionally unaware of the auth state — the caller picks
/// the `slivers` list based on `isAuthed` flag in its own widget.
class HomeShell extends StatefulWidget {
  final List<Widget> slivers;
  final Future<void> Function()? onRefresh;
  final bool ambientBackground;

  const HomeShell({
    super.key,
    required this.slivers,
    this.onRefresh,
    // Default OFF — product direction is a clean white home surface. Orbs
    // can still be opted into per-surface (e.g. preview / marketing) by
    // explicitly passing `ambientBackground: true`.
    this.ambientBackground = false,
  });

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _orbController;
  late final Animation<double> _orbAnimation;

  @override
  void initState() {
    super.initState();
    _orbController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
    _orbAnimation =
        CurvedAnimation(parent: _orbController, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _orbController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.primaryColor;
    // `ThemeProvider` may not be provided in every preview/test context — use
    // `watch` with a fallback so we never crash but still react to changes.
    final themeProvider = context.watch<ThemeProvider?>();
    final isGlass = themeProvider?.isGlassTheme ?? false;
    final isDark = theme.brightness == Brightness.dark || isGlass;
    final scheme = theme.colorScheme;

    // Orbs should feel ambient — dim them in light mode (they sit on white)
    // and boost them a hair in dark/glass mode where they need to glow.
    final orbFillAlpha = isDark ? 0.18 : 0.10;
    final orbGlowAlpha = isDark ? 0.22 : 0.14;

    final shellColor = isGlass
        ? const Color(0xFF0E0A18)
        : (isDark ? scheme.background : scheme.surface);

    return Container(
      color: shellColor,
      child: Stack(
        children: [
          if (widget.ambientBackground)
            ..._buildOrbs(primary, orbFillAlpha, orbGlowAlpha),
          if (isGlass)
            // Frosted veneer on top of the orbs so glass mode reads as a
            // single translucent pane rather than naked orbs on black.
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: ColoredBox(
                  color: scheme.onSurface.withValues(alpha: 0.03),
                ),
              ),
            ),
          CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              if (widget.onRefresh != null)
                CupertinoSliverRefreshControl(onRefresh: widget.onRefresh),
              ...widget.slivers,
              const SliverToBoxAdapter(
                child: SizedBox(height: HomeV2Tokens.kBottomNavClearance),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Two drifting translucent orbs that blend the splash purple into the
  /// home surface. Ported from the legacy BrowseHomeScreen but parameterized
  /// so a single widget powers every home variant.
  List<Widget> _buildOrbs(Color primary, double fillAlpha, double glowAlpha) {
    return [
      Positioned(
        top: -100,
        right: -50,
        child: AnimatedBuilder(
          animation: _orbAnimation,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, 30 * _orbAnimation.value),
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withValues(alpha: fillAlpha),
                boxShadow: [
                  BoxShadow(
                    color: primary.withValues(alpha: glowAlpha),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        bottom: 100,
        left: -50,
        child: AnimatedBuilder(
          animation: _orbAnimation,
          builder: (context, _) => Transform.translate(
            offset: Offset(0, -30 * _orbAnimation.value),
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.purple.withValues(alpha: fillAlpha * 0.8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purple.withValues(alpha: glowAlpha * 0.7),
                    blurRadius: 100,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ];
  }
}
