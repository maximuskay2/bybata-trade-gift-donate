import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';

import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/bybata_loading_indicator.dart';
import 'package:bybata/core/navigation/guarded_navigator.dart';

/// Single-video onboarding. Previous multi-slide flow:
/// [backups/onboarding_pre_video_20260605/onboarding_screen.dart]
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  static const String videoAsset = 'assets/video/onboard.mp4';

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  VideoPlayerController? _controller;
  bool _initializing = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final controller = VideoPlayerController.asset(OnboardingScreen.videoAsset);
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      await controller.play();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (e) {
      await controller.dispose();
      if (!mounted) return;
      setState(() {
        _initializing = false;
        _error = 'Could not load onboarding video';
      });
    }
  }

  @override
  void dispose() {
    unawaited(_releaseVideo());
    super.dispose();
  }

  Future<void> _releaseVideo() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    try {
      await controller.pause();
      await controller.dispose();
    } catch (_) {}
  }

  Future<void> _completeOnboarding() async {
    await _releaseVideo();
    await _markOnboardingComplete();
    if (!mounted) return;
    GuardedNavigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
  }

  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompletedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_controller != null && _controller!.value.isInitialized)
            _OnboardVideoBackground(controller: _controller!)
          else if (_initializing)
            const ColoredBox(
              color: Color(0xFF1a1a1a),
              child: Center(child: BybataLoadingIndicator()),
            )
          else
            ColoredBox(
              color: const Color(0xFF1a1a1a),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Text(
                    _error ?? 'Video unavailable',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),
          const _OnboardOverlay(),
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
                  Image.network(
                    'https://mails.bybata.com/logomail.png',
                    width: 72,
                    height: 72,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.apps,
                      size: 72,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Welcome to ByBata',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Trade, gift, and fund causes in one community.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 16,
                      height: 1.45,
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

class _OnboardVideoBackground extends StatelessWidget {
  final VideoPlayerController controller;

  const _OnboardVideoBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black,
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: controller.value.size.width,
          height: controller.value.size.height,
          child: VideoPlayer(controller),
        ),
      ),
    );
  }
}

class _OnboardOverlay extends StatelessWidget {
  const _OnboardOverlay();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.35),
              Colors.black.withValues(alpha: 0.15),
              Colors.black.withValues(alpha: 0.55),
              Colors.black.withValues(alpha: 0.82),
            ],
            stops: const [0, 0.35, 0.72, 1],
          ),
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
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
                  BoxShadow(
                    color: const Color(0xFF5a189a),
                    offset: const Offset(0, 6),
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
