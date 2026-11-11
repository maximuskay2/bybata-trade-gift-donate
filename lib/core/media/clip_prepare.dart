import 'dart:io';

import 'package:image/image.dart' as img;
import 'package:video_compress/video_compress.dart';

import 'clip_subject.dart';
import 'hero_clip_channel.dart';
import 'subject_cutout.dart';

/// A clip that can be uploaded, or a sentence that sends the user back.
class ClipPrep {
  final String? path;
  final String? refusal;

  const ClipPrep.kept(this.path) : refusal = null;
  const ClipPrep.refused(this.refusal) : path = null;
}

/// Samples the clip, refuses a take that leaves the frame, and crops the rest.
class HeroClipPrep {
  HeroClipPrep._();

  static const List<int> _stampsMs = [400, 2000, 4000, 6000];

  static Future<ClipPrep> run(
    String sourcePath, {
    SubjectCutout cutout = const NativeSubjectCutout(),
  }) async {
    final frames = <NormRect>[];
    for (final stamp in _stampsMs) {
      try {
        final thumb = await VideoCompress.getFileThumbnail(
          sourcePath,
          quality: 60,
          position: stamp,
        );
        final attempt = await cutout.remove(thumb.path);
        if (attempt is! CutoutHit || attempt.box == null) continue;
        final bytes = await File(thumb.path).readAsBytes();
        final decoded = img.decodeImage(bytes);
        if (decoded == null) continue;
        frames.add(
          NormRect.fromBox(
            attempt.box!,
            width: decoded.width,
            height: decoded.height,
          ),
        );
      } catch (_) {}
    }

    final refusal = ClipSubject.rejection(frames);
    if (refusal != null) return ClipPrep.refused(refusal);
    if (frames.isEmpty) return ClipPrep.kept(sourcePath);

    final rect = ClipSubject.smooth(frames);
    final dest =
        '${File(sourcePath).parent.path}/hero_clip_${DateTime.now().microsecondsSinceEpoch}.mp4';
    final cropped = await HeroClipChannel.crop(
      source: sourcePath,
      dest: dest,
      rect: rect,
    );
    if (cropped != null && cropped != sourcePath) {
      try {
        await File(sourcePath).delete();
      } catch (_) {}
    }
    return ClipPrep.kept(cropped ?? sourcePath);
  }
}
