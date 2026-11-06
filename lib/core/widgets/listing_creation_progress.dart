import 'dart:ui';

import 'package:flutter/material.dart';

/// Reports fractional progress [0, 1] and a human-readable stage label.
typedef ListingCreationReporter = void Function(double progress, String stage);

/// Full-screen progress overlay while a trade, gift, or donation is being created.
class ListingCreationProgress {
  ListingCreationProgress._();

  /// Runs [task] behind a modal progress UI. Returns its result, or null if the
  /// context unmounts before completion.
  static Future<T?> run<T>({
    required BuildContext context,
    required Color accentColor,
    required IconData icon,
    required String title,
    required Future<T> Function(ListingCreationReporter report) task,
  }) async {
    final progressNotifier = ValueNotifier<_ProgressSnapshot>(
      _ProgressSnapshot(progress: 0.02, stage: 'Getting started…'),
    );

    if (!context.mounted) return null;

    final navigator = Navigator.of(context, rootNavigator: true);
    navigator.push<void>(
      PageRouteBuilder<void>(
        opaque: false,
        barrierDismissible: false,
        pageBuilder: (_, __, ___) => _ListingCreationProgressOverlay(
          accentColor: accentColor,
          icon: icon,
          title: title,
          progressListenable: progressNotifier,
        ),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    T? result;
    var succeeded = false;
    try {
      result = await task((progress, stage) {
        progressNotifier.value = _ProgressSnapshot(
          progress: progress.clamp(0.0, 1.0),
          stage: stage,
        );
      });
      succeeded = result != false;
      if (succeeded) {
        progressNotifier.value = _ProgressSnapshot(
          progress: 1.0,
          stage: 'Done!',
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
      }
    } finally {
      progressNotifier.dispose();
      if (navigator.mounted) {
        navigator.pop();
      }
    }

    return result;
  }
}

class _ProgressSnapshot {
  final double progress;
  final String stage;

  const _ProgressSnapshot({required this.progress, required this.stage});
}

class _ListingCreationProgressOverlay extends StatefulWidget {
  final Color accentColor;
  final IconData icon;
  final String title;
  final ValueNotifier<_ProgressSnapshot> progressListenable;

  const _ListingCreationProgressOverlay({
    required this.accentColor,
    required this.icon,
    required this.title,
    required this.progressListenable,
  });

  @override
  State<_ListingCreationProgressOverlay> createState() =>
      _ListingCreationProgressOverlayState();
}

class _ListingCreationProgressOverlayState
    extends State<_ListingCreationProgressOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.black.withValues(alpha: isDark ? 0.55 : 0.45),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 360),
                  padding: const EdgeInsets.fromLTRB(28, 32, 28, 28),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E24).withValues(alpha: 0.92)
                        : Colors.white.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.12)
                          : Colors.white,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: widget.accentColor.withValues(alpha: 0.18),
                        blurRadius: 32,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: ValueListenableBuilder<_ProgressSnapshot>(
                    valueListenable: widget.progressListenable,
                    builder: (context, snapshot, _) {
                      final pct = (snapshot.progress * 100).round().clamp(0, 100);
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ScaleTransition(
                            scale: Tween<double>(begin: 0.96, end: 1.04).animate(
                              CurvedAnimation(
                                parent: _pulseController,
                                curve: Curves.easeInOut,
                              ),
                            ),
                            child: Container(
                              width: 72,
                              height: 72,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: [
                                    widget.accentColor,
                                    widget.accentColor.withValues(alpha: 0.75),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: widget.accentColor.withValues(alpha: 0.35),
                                    blurRadius: 16,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                              child: Icon(widget.icon, color: Colors.white, size: 34),
                            ),
                          ),
                          const SizedBox(height: 22),
                          Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: scheme.onSurface,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.stage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 24),
                          _GradientProgressBar(
                            progress: snapshot.progress,
                            accentColor: widget.accentColor,
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '$pct%',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w800,
                                  color: widget.accentColor,
                                ),
                              ),
                              Text(
                                'Working in the background',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            'Please keep the app open — this usually takes a few seconds.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                              height: 1.4,
                            ),
                          ),
                        ],
                      );
                    },
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

class _GradientProgressBar extends StatelessWidget {
  final double progress;
  final Color accentColor;

  const _GradientProgressBar({
    required this.progress,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trackColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : Colors.black.withValues(alpha: 0.06);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * progress.clamp(0.0, 1.0);
        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: trackColor,
            borderRadius: BorderRadius.circular(999),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 320),
                curve: Curves.easeOutCubic,
                width: width,
                height: 10,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [
                      accentColor.withValues(alpha: 0.85),
                      accentColor,
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
