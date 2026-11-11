import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../screens/splash/radiant_field.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// First-run welcome. The old onboard.mp4 is gone; this is the same radiant field as the splash.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _flow;
  int _chapter = 0;

  static const _chapters = [
    _Chapter('Trade', 'Offer what you have. Take what you need.'),
    _Chapter('Gift', 'Pass something on. Karma follows the giving.'),
    _Chapter('Donate', 'Fund a cause and watch the number rise.'),
  ];

  @override
  void initState() {
    super.initState();
    _flow = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 5200),
    );
    _flow.addListener(_advance);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (reduce) {
      _flow.stop();
    } else if (!_flow.isAnimating) {
      _flow.repeat();
    }
  }

  void _advance() {
    if (!mounted) return;
    final next = (_flow.value * _chapters.length).floor().clamp(0, _chapters.length - 1);
    if (next != _chapter) setState(() => _chapter = next);
  }

  @override
  void dispose() {
    _flow.removeListener(_advance);
    _flow.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompletedKey, true);
    if (!mounted) return;
    GuardedNavigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    final chapter = _chapters[_chapter];
    return Scaffold(
      backgroundColor: const Color(0xFF3A1768),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _flow,
            builder: (context, _) => CustomPaint(
              painter: RadiantFieldPainter(t: _flow.value),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
              child: Column(
                children: [
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _completeOnboarding,
                      child: const Text(
                        'Skip',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  ClipOval(
                    child: Image.asset(
                      'assets/animations/logo.png',
                      width: 84,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.auto_awesome_rounded,
                        size: 72,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    'Welcome to ByBata',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(height: 18),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    child: Column(
                      key: ValueKey(chapter.title),
                      children: [
                        Text(
                          chapter.title,
                          style: const TextStyle(
                            color: Color(0xFFE8C872),
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          chapter.line,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  ThreeDButton(
                    text: 'Get Started',
                    onPressed: _completeOnboarding,
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

class _Chapter {
  final String title;
  final String line;
  const _Chapter(this.title, this.line);
}

class ThreeDButton extends StatefulWidget {
  final String text;
  final VoidCallback onPressed;

  const ThreeDButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  State<ThreeDButton> createState() => _ThreeDButtonState();
}

class _ThreeDButtonState extends State<ThreeDButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onPressed,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        margin: EdgeInsets.only(top: _isPressed ? 6 : 0),
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(16),
          boxShadow: _isPressed
              ? []
              : [
                  const BoxShadow(
                    color: Color(0xFF5A189A),
                    offset: Offset(0, 6),
                    blurRadius: 0,
                  ),
                ],
        ),
        alignment: Alignment.center,
        child: Text(
          widget.text,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
