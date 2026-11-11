import 'dart:io';
import 'dart:ui' show Rect;

import 'package:native_cutout/native_cutout.dart';

import 'capture_gate.dart';

/// A lifted subject, or the reason the mask was refused.
sealed class CutoutAttempt {
  const CutoutAttempt();
}

class CutoutHit extends CutoutAttempt {
  final String pngPath;
  final SubjectBox? box;

  const CutoutHit({required this.pngPath, required this.box});
}

class CutoutMiss extends CutoutAttempt {
  final String message;

  const CutoutMiss(this.message);
}

/// On-device foreground mask. Tests supply a fake.
abstract class SubjectCutout {
  Future<CutoutAttempt> remove(String imagePath);
}

class NativeSubjectCutout implements SubjectCutout {
  const NativeSubjectCutout();

  @override
  Future<CutoutAttempt> remove(String imagePath) async {
    final result = await NativeCutout.removeBackground(
      imagePath,
      options: const CutoutOptions(cropToSubject: false, writeToCache: true),
    );
    switch (result) {
      case CutoutFileSuccess(:final path, :final subjectBounds):
        return CutoutHit(pngPath: path, box: _box(subjectBounds));
      case CutoutBytesSuccess(:final pngBytes, :final subjectBounds):
        final file = File(
          '${Directory.systemTemp.path}/cutout_${DateTime.now().microsecondsSinceEpoch}.png',
        );
        await file.writeAsBytes(pngBytes, flush: true);
        return CutoutHit(pngPath: file.path, box: _box(subjectBounds));
      case CutoutFailure(:final code, :final message):
        return CutoutMiss(_message(code, message));
    }
  }

  static SubjectBox? _box(Rect? rect) {
    if (rect == null || rect.width < 2 || rect.height < 2) return null;
    return SubjectBox(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
    );
  }

  static String _message(CutoutErrorCode code, String fallback) {
    final lower = fallback.toLowerCase();
    if (lower.contains('ios 17') || lower.contains('unsupported')) {
      return 'This phone needs iOS 17 or newer, or an Android phone with Google Play, to lift the background.';
    }
    switch (code) {
      case CutoutErrorCode.noSubjectFound:
        return 'Show one item, with space around it.';
      case CutoutErrorCode.invalidInput:
        return 'That photo could not be read. Take it again.';
      case CutoutErrorCode.processingFailed:
        return 'Could not separate the item. Use a plainer background and leave space around it.';
    }
  }

  static Future<void> warmUpAndroidModel() async {
    if (!Platform.isAndroid) return;
    final ready = await NativeCutout.isModelAvailable();
    if (ready) return;
    final downloaded = await NativeCutout.downloadModel();
    if (!downloaded) {
      throw StateError(
        'The cutout model needs a connection the first time. Try again online.',
      );
    }
  }
}
