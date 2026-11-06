import 'package:flutter/material.dart';

import '../../core/widgets/bybata_loading_indicator.dart';

/// Branded splash shown while the app boots. Logo and text render on frame 0
/// so the handoff from native purple is straight into the animated splash.
class AnimatedSplashScreen extends StatefulWidget {
  final VoidCallback? onComplete;
  final bool showLoadingIndicator;
  final Widget? overlay;

  const AnimatedSplashScreen({
    super.key,
    this.onComplete,
    this.showLoadingIndicator = true,
    this.overlay,
  });

  @override
  State<AnimatedSplashScreen> createState() => _AnimatedSplashScreenState();
}

class _AnimatedSplashScreenState extends State<AnimatedSplashScreen>
    with TickerProviderStateMixin {
  static const Color _nativeHandoffPurple = Color(0xFF5E35B1);

  /// Branding motion (subtle glow pulse) — logo and text are visible on frame 0.
  static const Duration _brandingMotion = Duration(milliseconds: 1200);

  late AnimationController _ambientController;
  late AnimationController _brandingController;

  late Animation<double> _backgroundMorph;
  late Animation<double> _logoGlow;

  @override
  void initState() {
    super.initState();

    _ambientController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _backgroundMorph = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _ambientController,
        curve: Curves.easeInOutSine,
      ),
    );

    _brandingController = AnimationController(
      duration: _brandingMotion,
      vsync: this,
    );

    _logoGlow = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _brandingController,
        curve: Curves.easeInOut,
      ),
    );

    _brandingController.forward();
  }

  @override
  void dispose() {
    _ambientController.dispose();
    _brandingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: _nativeHandoffPurple,
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _backgroundMorph,
            builder: (context, child) {
              return Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: isDark
                        ? [
                            const Color(0xFF0D0B12),
                            Color.lerp(
                              const Color(0xFF15101F),
                              _nativeHandoffPurple,
                              _backgroundMorph.value * 0.15,
                            )!,
                            const Color(0xFF0D0B12),
                          ]
                        : [
                            _nativeHandoffPurple,
                            Color.lerp(
                              const Color(0xFF7B2CBF),
                              const Color(0xFF321668),
                              _backgroundMorph.value,
                            )!,
                            const Color(0xFF15101F),
                          ],
                  ),
                ),
              );
            },
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _brandingController,
                    builder: (context, child) {
                      return Container(
                        width: 110,
                        height: 110,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF7B2CBF)
                                  .withValues(alpha: 0.4 * _logoGlow.value),
                              blurRadius: 40,
                              spreadRadius: 4,
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset(
                            'assets/animations/logo.png',
                            fit: BoxFit.cover,
                            gaplessPlayback: true,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFF7B2CBF),
                                child: const Icon(
                                  Icons.auto_awesome_rounded,
                                  color: Colors.white,
                                  size: 48,
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 32),
                  if (widget.showLoadingIndicator)
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const BybataLoadingIndicator(
                          size: BybataLoadingSize.large,
                          color: Colors.white,
                          highlightColor: Colors.white,
                        ),
                        const SizedBox(height: 14),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 44),
                          child: Text(
                            'Trade. Gift. Donate and Grow Together',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              color: Color(0xA6FFFFFF),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (widget.overlay != null) widget.overlay!,
        ],
      ),
    );
  }
}
