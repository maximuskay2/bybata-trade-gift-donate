import 'dart:typed_data';

import 'package:bybata/core/media/capture_gate.dart';
import 'package:bybata/core/media/clip_subject.dart';
import 'package:bybata/core/media/live_capture_gate.dart';
import 'package:bybata/core/motion/stage_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a bright still subject opens the shutter after a few quiet frames', () {
    final lock = LiveShutterLock();
    String? last;
    for (var i = 0; i < LiveCaptureGate.steadyFrames; i++) {
      last = lock.consider(
        luma: 120,
        motion: 1,
        centerEnergy: 80,
        edgeEnergy: 10,
      );
    }
    expect(last, isNull);
  });

  test('dark, empty, and moving frames keep the shutter off', () {
    expect(
      LiveCaptureGate.message(
        luma: 10,
        motion: 0,
        centerEnergy: 80,
        edgeEnergy: 4,
        steadyCount: 8,
      ),
      'Add light.',
    );
    expect(
      LiveCaptureGate.message(
        luma: 120,
        motion: 0,
        centerEnergy: 4,
        edgeEnergy: 4,
        steadyCount: 8,
      ),
      LiveCaptureGate.moveCloser,
    );
    expect(
      LiveCaptureGate.message(
        luma: 120,
        motion: 20,
        centerEnergy: 80,
        edgeEnergy: 8,
        steadyCount: 8,
      ),
      'Hold still.',
    );
  });

  test('luma grids measure light and motion', () {
    final bytes = Uint8List(12 * 8);
    for (var i = 0; i < bytes.length; i++) {
      bytes[i] = 140;
    }
    final calm = LiveFrame.gridFromLuma(bytes, width: 12, height: 8, bytesPerRow: 12);
    expect(LiveFrame.mean(calm), closeTo(140, 0.1));
    expect(LiveFrame.motion(calm, calm), 0);

    final moved = Float32List.fromList(calm);
    moved[0] = 20;
    expect(LiveFrame.motion(calm, moved), greaterThan(0));
  });

  test('two hard shakes stop a clip', () {
    final whip = WhipWatch();
    expect(whip.add(2), isFalse);
    expect(whip.add(20), isFalse);
    expect(whip.add(20), isTrue);
  });

  test('a subject that jumps the frame is refused and a steady one crops', () {
    const inside = NormRect(left: 0.25, top: 0.2, width: 0.4, height: 0.5);
    const edge = NormRect(left: 0.0, top: 0.2, width: 0.4, height: 0.5);
    expect(ClipSubject.rejection(const [inside, inside]), isNull);
    expect(ClipSubject.rejection(const [edge]), ClipSubject.leaveFrame);

    final smooth = ClipSubject.smooth(const [inside, inside]);
    expect(smooth.left, greaterThan(0));
    expect(smooth.right, lessThan(1.01));
    expect(
      CaptureGate.subject(box: smooth.toBox(), imageWidth: 1000, imageHeight: 1000),
      isNull,
    );
  });

  test('a hero opened from a card shrinks closed instead of vanishing', () {
    final stage = StageController()
      ..open('sandal', origin: const Rect.fromLTWH(12, 40, 55, 55));
    expect(stage.back(), isTrue);
    expect(stage.isClosing, isTrue);
    expect(stage.isOpen, isTrue);
    stage.finishClose();
    expect(stage.layer, StageLayer.closed);
    expect(stage.isOpen, isFalse);
  });
}
