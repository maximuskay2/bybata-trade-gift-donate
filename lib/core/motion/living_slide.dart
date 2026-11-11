import 'package:flutter/material.dart';

/// Global rect of the widget that opened the stage, used as the gold ring.
Rect? stageCardOrigin(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// One item on a living stage. The photo stays; the card changes.
class LivingSlide {
  final String id;
  final String title;
  final String subtitle;
  final String story;
  final String place;
  final String want;
  final String? imageKey;
  final List<String> galleryKeys;
  final String numberLabel;
  final String primaryLabel;
  final bool isOwner;
  final String ownerId;
  final String ownerName;
  final int? value;
  final Object? source;

  const LivingSlide({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.story = '',
    this.place = '',
    this.want = '',
    this.imageKey,
    this.galleryKeys = const [],
    this.numberLabel = '',
    required this.primaryLabel,
    this.isOwner = false,
    this.ownerId = '',
    this.ownerName = '',
    this.value,
    this.source,
  });
}

bool stageImageIsRemote(String value) {
  final lower = value.toLowerCase();
  return lower.startsWith('https://') || lower.startsWith('http://');
}
