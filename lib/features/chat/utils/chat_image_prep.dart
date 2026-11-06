import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Chat-specific image normalization — keep aspect ratio, JPEG output.
class ChatImagePrep {
  ChatImagePrep._();

  static const int maxEdge = 1600;
  static const int maxBytes = 900 * 1024;

  /// Decode → resize (max edge) → JPEG. Falls back to [file] if decode fails.
  static Future<File> prepareJpeg(File file, {int quality = 85}) async {
    try {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return file;

      final decoded = img.decodeImage(bytes);
      if (decoded == null) {
        debugPrint('[ChatImagePrep] decode failed; uploading original');
        return file;
      }

      img.Image canvas = decoded;
      final longest = decoded.width > decoded.height ? decoded.width : decoded.height;
      if (longest > maxEdge) {
        if (decoded.width >= decoded.height) {
          canvas = img.copyResize(
            decoded,
            width: maxEdge,
            interpolation: img.Interpolation.average,
          );
        } else {
          canvas = img.copyResize(
            decoded,
            height: maxEdge,
            interpolation: img.Interpolation.average,
          );
        }
      }

      final outPath =
          '${file.parent.path}/chat_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final out = File(outPath);
      var q = quality;
      var jpg = img.encodeJpg(canvas, quality: q);
      while (jpg.length > maxBytes && q > 40) {
        q -= 5;
        jpg = img.encodeJpg(canvas, quality: q);
      }
      await out.writeAsBytes(jpg, flush: true);
      return out;
    } catch (e) {
      debugPrint('[ChatImagePrep] prepare failed: $e');
      return file;
    }
  }
}
