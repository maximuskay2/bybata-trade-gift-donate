import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'capture_gate.dart';

/// Places a transparent cutout on a flat field and writes the upload JPEG.
class StageImage {
  StageImage._();

  static const int width = 1600;
  static const int height = 1000;

  static Future<File> render({
    required Uint8List pngBytes,
    required int red,
    required int green,
    required int blue,
    required SubjectBox? subject,
    required Directory directory,
  }) async {
    final decoded = img.decodePng(pngBytes);
    if (decoded == null) {
      throw StateError('Cutout could not be read.');
    }

    final trimmed = _trim(decoded, subject);
    final canvas = img.Image(width: width, height: height, numChannels: 3);
    img.fill(canvas, color: img.ColorRgb8(red, green, blue));

    final maxW = (width * 0.62).round();
    final maxH = (height * 0.72).round();
    final scale = math.min(maxW / trimmed.width, maxH / trimmed.height);
    final dw = math.max(1, (trimmed.width * scale).round());
    final dh = math.max(1, (trimmed.height * scale).round());
    final sprite = img.copyResize(
      trimmed,
      width: dw,
      height: dh,
      interpolation: img.Interpolation.average,
    );
    final dx = (width - dw) ~/ 2;
    final dy = ((height - dh) / 2).round() + (height * 0.03).round();

    _shadow(
      canvas,
      cx: dx + dw ~/ 2,
      cy: math.min(height - 8, dy + dh - (dh * 0.04).round()),
      rx: (dw * 0.34).round(),
      ry: math.max(8, (dh * 0.06).round()),
    );
    _blend(canvas, sprite, dx, dy);

    final file = File(
      '${directory.path}/stage_${DateTime.now().microsecondsSinceEpoch}.jpg',
    );
    var quality = 88;
    var bytes = img.encodeJpg(canvas, quality: quality);
    while (bytes.length > 180 * 1024 && quality > 50) {
      quality -= 6;
      bytes = img.encodeJpg(canvas, quality: quality);
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  static img.Image _trim(img.Image source, SubjectBox? subject) {
    if (subject == null) return source;
    final x = subject.left.round().clamp(0, source.width - 1);
    final y = subject.top.round().clamp(0, source.height - 1);
    final w = subject.width.round().clamp(1, source.width - x);
    final h = subject.height.round().clamp(1, source.height - y);
    if (w >= source.width - 1 && h >= source.height - 1) return source;
    return img.copyCrop(source, x: x, y: y, width: w, height: h);
  }

  static void _shadow(
    img.Image canvas, {
    required int cx,
    required int cy,
    required int rx,
    required int ry,
  }) {
    if (rx < 1 || ry < 1) return;
    for (var y = cy - ry; y <= cy + ry; y++) {
      for (var x = cx - rx; x <= cx + rx; x++) {
        if (x < 0 || y < 0 || x >= canvas.width || y >= canvas.height) continue;
        final nx = (x - cx) / rx;
        final ny = (y - cy) / ry;
        final distance = nx * nx + ny * ny;
        if (distance > 1) continue;
        final strength = (1 - distance) * 0.28;
        final pixel = canvas.getPixel(x, y);
        canvas.setPixelRgb(
          x,
          y,
          (pixel.r * (1 - strength)).round(),
          (pixel.g * (1 - strength)).round(),
          (pixel.b * (1 - strength)).round(),
        );
      }
    }
  }

  static void _blend(img.Image canvas, img.Image sprite, int dx, int dy) {
    for (var y = 0; y < sprite.height; y++) {
      final targetY = dy + y;
      if (targetY < 0 || targetY >= canvas.height) continue;
      for (var x = 0; x < sprite.width; x++) {
        final targetX = dx + x;
        if (targetX < 0 || targetX >= canvas.width) continue;
        final src = sprite.getPixel(x, y);
        final alpha = src.a / 255;
        if (alpha < 0.04) continue;
        final dst = canvas.getPixel(targetX, targetY);
        canvas.setPixelRgb(
          targetX,
          targetY,
          (src.r * alpha + dst.r * (1 - alpha)).round(),
          (src.g * alpha + dst.g * (1 - alpha)).round(),
          (src.b * alpha + dst.b * (1 - alpha)).round(),
        );
      }
    }
  }
}
