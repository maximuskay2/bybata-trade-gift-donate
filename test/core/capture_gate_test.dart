import 'dart:io';
import 'dart:typed_data';

import 'package:bybata/core/media/capture_gate.dart';
import 'package:bybata/core/media/stage_image.dart';
import 'package:bybata/core/media/stage_prepare.dart';
import 'package:bybata/core/media/subject_cutout.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('a dark frame is refused and a flat frame is refused as blur', () {
    final dark = img.Image(width: 80, height: 80, numChannels: 3);
    img.fill(dark, color: img.ColorRgb8(8, 8, 8));
    expect(CaptureGate.exposure(dark)?.message, 'Add light.');

    final flat = img.Image(width: 80, height: 80, numChannels: 3);
    img.fill(flat, color: img.ColorRgb8(140, 140, 140));
    expect(CaptureGate.sharpness(flat)?.message, contains('blurry'));
    expect(CaptureGate.exposure(flat), isNull);
  });

  test('a high-contrast frame passes the blur check', () {
    final sharp = img.Image(width: 80, height: 80, numChannels: 3);
    img.fill(sharp, color: img.ColorRgb8(240, 240, 240));
    for (var x = 0; x < sharp.width; x += 4) {
      img.drawLine(
        sharp,
        x1: x,
        y1: 0,
        x2: x,
        y2: sharp.height - 1,
        color: img.ColorRgb8(10, 10, 10),
      );
    }
    expect(CaptureGate.sharpness(sharp), isNull);
  });

  test('subject box must sit inside the frame and be one item', () {
    const wide = 1000.0;
    const tall = 1000.0;

    expect(
      CaptureGate.subject(
        box: const SubjectBox(left: 0, top: 200, width: 400, height: 400),
        imageWidth: wide.toInt(),
        imageHeight: tall.toInt(),
      )?.message,
      contains('Step back'),
    );

    expect(
      CaptureGate.subject(
        box: const SubjectBox(left: 460, top: 460, width: 80, height: 80),
        imageWidth: 1000,
        imageHeight: 1000,
      )?.message,
      contains('Move closer'),
    );

    expect(
      CaptureGate.subject(
        box: const SubjectBox(left: 250, top: 200, width: 500, height: 500),
        imageWidth: 1000,
        imageHeight: 1000,
      ),
      isNull,
    );

    expect(
      CaptureGate.subject(box: null, imageWidth: 1000, imageHeight: 1000)?.message,
      contains('could not find'),
    );
  });

  test('the cutout is placed on the stage color and the room is not kept', () async {
    final cutout = img.Image(width: 200, height: 200, numChannels: 4);
    img.fill(cutout, color: img.ColorRgba8(0, 0, 0, 0));
    img.fillRect(
      cutout,
      x1: 60,
      y1: 40,
      x2: 140,
      y2: 160,
      color: img.ColorRgba8(220, 30, 30, 255),
    );

    final dir = await Directory.systemTemp.createTemp('stage_image');
    final file = await StageImage.render(
      pngBytes: Uint8List.fromList(img.encodePng(cutout)),
      red: 10,
      green: 40,
      blue: 120,
      subject: const SubjectBox(left: 60, top: 40, width: 80, height: 120),
      directory: dir,
    );

    final staged = img.decodeJpg(await file.readAsBytes())!;
    final corner = staged.getPixel(4, 4);
    expect(corner.r, lessThan(30));
    expect(corner.b, greaterThan(80));

    final center = staged.getPixel(staged.width ~/ 2, staged.height ~/ 2);
    expect(center.r, greaterThan(center.b));
    await dir.delete(recursive: true);
  });

  test('prepare refuses a dark photo before the cutout runs', () async {
    var calls = 0;
    final cutout = _CountingCutout(() => calls++);
    final dir = await Directory.systemTemp.createTemp('stage_prepare');
    final photo = File('${dir.path}/dark.jpg');
    final dark = img.Image(width: 120, height: 80, numChannels: 3);
    img.fill(dark, color: img.ColorRgb8(5, 5, 5));
    await photo.writeAsBytes(img.encodeJpg(dark));

    final result = await prepareStagePhoto(
      sourcePath: photo.path,
      red: 20,
      green: 20,
      blue: 20,
      cutout: cutout,
    );

    expect(result, isA<StageRejected>());
    expect((result as StageRejected).message, 'Add light.');
    expect(calls, 0);
    await dir.delete(recursive: true);
  });

  test('prepare keeps only the staged file when the mask passes', () async {
    final dir = await Directory.systemTemp.createTemp('stage_prepare_ok');
    final photo = File('${dir.path}/item.jpg');
    final sharp = img.Image(width: 320, height: 240, numChannels: 3);
    img.fill(sharp, color: img.ColorRgb8(180, 180, 180));
    for (var x = 0; x < sharp.width; x += 6) {
      img.drawLine(
        sharp,
        x1: x,
        y1: 0,
        x2: x,
        y2: sharp.height - 1,
        color: img.ColorRgb8(20, 20, 20),
      );
    }
    await photo.writeAsBytes(img.encodeJpg(sharp));

    final result = await prepareStagePhoto(
      sourcePath: photo.path,
      red: 30,
      green: 10,
      blue: 80,
      cutout: _FixedCutout(dir),
    );

    expect(result, isA<StageReady>());
    final staged = img.decodeJpg(await (result as StageReady).file.readAsBytes())!;
    expect(staged.width, StageImage.width);
    expect(staged.height, StageImage.height);
    final corner = staged.getPixel(2, 2);
    expect(corner.b, greaterThan(corner.g));
    await dir.delete(recursive: true);
  });
}

class _CountingCutout implements SubjectCutout {
  final void Function() onRemove;

  _CountingCutout(this.onRemove);

  @override
  Future<CutoutAttempt> remove(String imagePath) async {
    onRemove();
    return const CutoutMiss('unused');
  }
}

class _FixedCutout implements SubjectCutout {
  final Directory directory;

  _FixedCutout(this.directory);

  @override
  Future<CutoutAttempt> remove(String imagePath) async {
    final decoded = img.decodeJpg(await File(imagePath).readAsBytes())!;
    final png = img.Image(width: decoded.width, height: decoded.height, numChannels: 4);
    img.fill(png, color: img.ColorRgba8(0, 0, 0, 0));
    final box = SubjectBox(
      left: decoded.width * 0.3,
      top: decoded.height * 0.25,
      width: decoded.width * 0.4,
      height: decoded.height * 0.5,
    );
    img.fillRect(
      png,
      x1: box.left.round(),
      y1: box.top.round(),
      x2: box.right.round(),
      y2: box.bottom.round(),
      color: img.ColorRgba8(200, 40, 40, 255),
    );
    final file = File('${directory.path}/mask.png');
    await file.writeAsBytes(img.encodePng(png));
    return CutoutHit(pngPath: file.path, box: box);
  }
}
