import 'package:flutter/material.dart';

import '../widgets/cached_media_image.dart';
import 'living_slide.dart';

/// A listing photo seated in the hub color, with a lit edge and a shadow.
class StagePhotoWell extends StatelessWidget {
  final String? imageKey;
  final Color color;
  final double radius;
  final double inset;
  final bool lit;

  const StagePhotoWell({
    super.key,
    required this.imageKey,
    required this.color,
    this.radius = 28,
    this.inset = 12,
    this.lit = false,
  });

  @override
  Widget build(BuildContext context) {
    final edge = Color.lerp(color, Colors.white, lit ? 0.84 : 0.62)!;
    final well = Color.lerp(color, Colors.white, 0.22)!;
    final inner = (radius - 3).clamp(0.0, radius);
    return SizedBox.expand(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          color: well,
          border: Border.all(color: edge, width: lit ? 3.5 : 2.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.28),
              blurRadius: 22,
              offset: const Offset(0, 12),
            ),
            BoxShadow(
              color: edge.withValues(alpha: lit ? 0.85 : 0.5),
              blurRadius: lit ? 22 : 16,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(inner),
          child: ColoredBox(
            color: well,
            child: Padding(
              padding: EdgeInsets.all(inset),
              child: _StageStill(imageKey: imageKey),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageStill extends StatelessWidget {
  final String? imageKey;

  const _StageStill({this.imageKey});

  @override
  Widget build(BuildContext context) {
    final key = imageKey?.trim() ?? '';
    if (key.isEmpty) {
      return const Center(
        child: Icon(Icons.image_outlined, color: Colors.black38, size: 36),
      );
    }
    final remote = stageImageIsRemote(key);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final sized =
            width.isFinite && height.isFinite && width > 0 && height > 0;
        return CachedMediaImage(
          mediaKey: remote ? null : key,
          directUrl: remote ? key : null,
          fit: BoxFit.cover,
          width: sized ? width : null,
          height: sized ? height : null,
          optimizedForFeed: true,
          errorWidget: const Icon(
            Icons.image_outlined,
            color: Colors.black38,
            size: 36,
          ),
        );
      },
    );
  }
}
