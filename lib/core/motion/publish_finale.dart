import 'dart:io';

import 'package:flutter/material.dart';

import '../navigation/guarded_navigator.dart';
import '../theme/app_theme.dart';

/// Listed / Live check on the create stage, then the photo shrinks away.
Future<void> showPublishFinale(
  BuildContext context, {
  required String line,
  required Color color,
  String? imagePath,
}) async {
  if (!context.mounted) return;
  if (MediaQuery.disableAnimationsOf(context)) return;
  await GuardedNavigator.push<void>(
    context,
    PageRouteBuilder<void>(
      opaque: false,
      barrierColor: color,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) =>
          PublishFinale(line: line, color: color, imagePath: imagePath),
    ),
    force: true,
  );
}

class PublishFinale extends StatefulWidget {
  final String line;
  final Color color;
  final String? imagePath;

  const PublishFinale({
    super.key,
    required this.line,
    required this.color,
    this.imagePath,
  });

  @override
  State<PublishFinale> createState() => _PublishFinaleState();
}

class _PublishFinaleState extends State<PublishFinale>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(
            vsync: this,
            duration: const Duration(milliseconds: 1100),
          )
          ..forward().whenComplete(() {
            if (mounted) Navigator.of(context).pop();
          });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final path = widget.imagePath;
    final file = path == null || path.isEmpty ? null : File(path);
    return Material(
      color: widget.color,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final showCheck = t > 0.28 && t < 0.72;
          final shrink = t < 0.72 ? 1.0 : 1 - ((t - 0.72) / 0.28);
          final lift = t < 0.72
              ? 0.0
              : -MediaQuery.sizeOf(context).height * 0.42 * (1 - shrink);
          return Stack(
            fit: StackFit.expand,
            children: [
              const _Radiance(),
              Center(
                child: Transform.translate(
                  offset: Offset(0, lift),
                  child: Transform.scale(
                    scale: shrink.clamp(0.05, 1),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'BYBATA',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2.4,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: 168,
                          height: 168,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: const Color(0xFFE8C872),
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.28),
                                blurRadius: 36,
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: file != null && file.existsSync()
                              ? Image.file(file, fit: BoxFit.cover)
                              : const Icon(
                                  Icons.image_outlined,
                                  color: Colors.white,
                                  size: 48,
                                ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          widget.line,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Opacity(
                          opacity: showCheck ? 1 : 0,
                          child: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 64,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Radiance extends StatelessWidget {
  const _Radiance();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          radius: 0.9,
          colors: [Color(0x55FFFFFF), Color(0x00FFFFFF)],
        ),
      ),
    );
  }
}
