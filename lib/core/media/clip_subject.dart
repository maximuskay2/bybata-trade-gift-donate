import 'dart:ui';

import 'capture_gate.dart';

/// One sampled frame, in fractions of that frame.
class NormRect {
  final double left;
  final double top;
  final double width;
  final double height;

  const NormRect({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
  double get centerX => left + width / 2;
  double get centerY => top + height / 2;

  factory NormRect.fromBox(SubjectBox box, {required int width, required int height}) {
    if (width < 1 || height < 1) {
      return const NormRect(left: 0, top: 0, width: 1, height: 1);
    }
    return NormRect(
      left: box.left / width,
      top: box.top / height,
      width: box.width / width,
      height: box.height / height,
    );
  }

  SubjectBox toBox({int width = 1000, int height = 1000}) {
    return SubjectBox(
      left: left * width,
      top: top * height,
      width: this.width * width,
      height: this.height * height,
    );
  }

  Rect get rect => Rect.fromLTWH(left, top, width, height);
}

/// Subject samples across a short clip: refuse a wandering take, else one crop.
class ClipSubject {
  ClipSubject._();

  static const String leaveFrame = 'Keep the item in the frame.';

  static String? rejection(List<NormRect> frames) {
    if (frames.isEmpty) return null;
    for (final frame in frames) {
      final blocked = CaptureGate.subject(
        box: frame.toBox(),
        imageWidth: 1000,
        imageHeight: 1000,
      );
      if (blocked != null) return leaveFrame;
    }
    for (var i = 1; i < frames.length; i++) {
      final jumpX = (frames[i].centerX - frames[i - 1].centerX).abs();
      final jumpY = (frames[i].centerY - frames[i - 1].centerY).abs();
      if (jumpX > 0.45 || jumpY > 0.45) return leaveFrame;
    }
    return null;
  }

  /// Average box, padded, clamped to the frame. Even width and height in pixels
  /// are the encoder's job; this stays in 0–1.
  static NormRect smooth(List<NormRect> frames) {
    if (frames.isEmpty) {
      return const NormRect(left: 0.1, top: 0.1, width: 0.8, height: 0.8);
    }
    var left = 0.0;
    var top = 0.0;
    var width = 0.0;
    var height = 0.0;
    for (final frame in frames) {
      left += frame.left;
      top += frame.top;
      width += frame.width;
      height += frame.height;
    }
    final count = frames.length.toDouble();
    left = left / count - 0.04;
    top = top / count - 0.04;
    width = width / count + 0.08;
    height = height / count + 0.08;
    if (left < 0) {
      width += left;
      left = 0;
    }
    if (top < 0) {
      height += top;
      top = 0;
    }
    if (left + width > 1) width = 1 - left;
    if (top + height > 1) height = 1 - top;
    if (width < 0.2) width = 0.2;
    if (height < 0.2) height = 0.2;
    if (left + width > 1) left = 1 - width;
    if (top + height > 1) top = 1 - height;
    return NormRect(left: left, top: top, width: width, height: height);
  }
}
