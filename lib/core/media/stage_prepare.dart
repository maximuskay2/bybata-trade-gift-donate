import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'capture_gate.dart';
import 'stage_image.dart';
import 'subject_cutout.dart';

/// A photo that passed the gate, or the sentence that blocked it.
sealed class StagePrepareResult {
  const StagePrepareResult();
}

class StageReady extends StagePrepareResult {
  final File file;

  const StageReady(this.file);
}

class StageRejected extends StagePrepareResult {
  final String message;

  const StageRejected(this.message);
}

/// Runs the light, blur, cutout, and stage-color steps on one still.
Future<StagePrepareResult> prepareStagePhoto({
  required String sourcePath,
  required int red,
  required int green,
  required int blue,
  SubjectCutout cutout = const NativeSubjectCutout(),
}) async {
  final source = File(sourcePath);
  if (!source.existsSync()) {
    return const StageRejected('That photo could not be read. Take it again.');
  }

  final bytes = await source.readAsBytes();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return const StageRejected('That photo could not be read. Take it again.');
  }

  final prepared = _fit(img.bakeOrientation(decoded));
  final dark = CaptureGate.exposure(prepared);
  if (dark != null) return StageRejected(dark.message);
  final blur = CaptureGate.sharpness(prepared);
  if (blur != null) return StageRejected(blur.message);

  final directory = source.parent;
  final working = File(
    '${directory.path}/capture_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  await working.writeAsBytes(img.encodeJpg(prepared, quality: 92), flush: true);

  final attempt = await cutout.remove(working.path);
  switch (attempt) {
    case CutoutMiss(:final message):
      return StageRejected(message);
    case CutoutHit(:final pngPath, :final box):
      final framed = CaptureGate.subject(
        box: box,
        imageWidth: prepared.width,
        imageHeight: prepared.height,
      );
      if (framed != null) return StageRejected(framed.message);
      final png = await File(pngPath).readAsBytes();
      final staged = await StageImage.render(
        pngBytes: Uint8List.fromList(png),
        red: red,
        green: green,
        blue: blue,
        subject: box,
        directory: directory,
      );
      return StageReady(staged);
  }
}

img.Image _fit(img.Image image) {
  const maxSide = 1600;
  final longSide = math.max(image.width, image.height);
  if (longSide <= maxSide) return image;
  final scale = maxSide / longSide;
  return img.copyResize(
    image,
    width: math.max(1, (image.width * scale).round()),
    height: math.max(1, (image.height * scale).round()),
    interpolation: img.Interpolation.average,
  );
}
