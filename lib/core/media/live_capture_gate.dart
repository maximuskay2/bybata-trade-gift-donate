import 'dart:typed_data';

/// Downsampled camera luma used to lock the shutter.
class LiveFrame {
  LiveFrame._();

  static const int cols = 24;
  static const int rows = 18;

  static Float32List gridFromLuma(
    Uint8List bytes, {
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    return _grid(width, height, (x, y) {
      final index = y * bytesPerRow + x;
      if (index < 0 || index >= bytes.length) return 0;
      return bytes[index].toDouble();
    });
  }

  /// iOS preview frames are BGRA.
  static Float32List gridFromBgra(
    Uint8List bytes, {
    required int width,
    required int height,
    required int bytesPerRow,
  }) {
    return _grid(width, height, (x, y) {
      final index = y * bytesPerRow + x * 4;
      if (index + 2 >= bytes.length) return 0;
      final b = bytes[index].toDouble();
      final g = bytes[index + 1].toDouble();
      final r = bytes[index + 2].toDouble();
      return r * 0.299 + g * 0.587 + b * 0.114;
    });
  }

  static Float32List _grid(
    int width,
    int height,
    double Function(int x, int y) sample,
  ) {
    final grid = Float32List(cols * rows);
    if (width < 2 || height < 2) return grid;
    for (var row = 0; row < rows; row++) {
      final y = (row * (height - 1) / (rows - 1)).round().clamp(0, height - 1);
      for (var col = 0; col < cols; col++) {
        final x = (col * (width - 1) / (cols - 1)).round().clamp(0, width - 1);
        grid[row * cols + col] = sample(x, y);
      }
    }
    return grid;
  }

  static double mean(Float32List grid) {
    if (grid.isEmpty) return 0;
    var sum = 0.0;
    for (final value in grid) {
      sum += value;
    }
    return sum / grid.length;
  }

  static double motion(Float32List previous, Float32List next) {
    if (previous.length != next.length || previous.isEmpty) return 0;
    var sum = 0.0;
    for (var i = 0; i < previous.length; i++) {
      final delta = previous[i] - next[i];
      sum += delta < 0 ? -delta : delta;
    }
    return sum / previous.length;
  }

  static double variance(Float32List grid, {required bool center}) {
    if (grid.length != cols * rows) return 0;
    final values = <double>[];
    for (var row = 0; row < rows; row++) {
      for (var col = 0; col < cols; col++) {
        final inside = col >= 6 && col < cols - 6 && row >= 4 && row < rows - 4;
        if (inside != center) continue;
        values.add(grid[row * cols + col]);
      }
    }
    if (values.length < 2) return 0;
    var sum = 0.0;
    for (final value in values) {
      sum += value;
    }
    final average = sum / values.length;
    var square = 0.0;
    for (final value in values) {
      final delta = value - average;
      square += delta * delta;
    }
    return square / values.length;
  }
}

/// Why the shutter stays dark, or null when the take may start.
class LiveCaptureGate {
  LiveCaptureGate._();

  static const double minLuma = 36;
  static const double maxLuma = 248;
  static const double maxMotion = 14;
  static const double minCenterEnergy = 10;
  static const double subjectRatio = 1.05;
  static const int steadyFrames = 2;

  static const String moveCloser = 'Move closer.';
  static const String centerItem = 'Center the item in the frame.';
  static const String holdStill = 'Hold still.';
  static const String addLight = 'Add light.';
  static const String blownOut =
      'The shot is blown out. Turn away from the glare.';

  static bool isFramingIssue(String? message) {
    return message == moveCloser || message == centerItem;
  }

  static String? message({
    required double luma,
    required double motion,
    required double centerEnergy,
    required double edgeEnergy,
    required int steadyCount,
  }) {
    if (luma < minLuma) return addLight;
    if (luma > maxLuma) return blownOut;
    if (centerEnergy < minCenterEnergy) return moveCloser;
    if (centerEnergy <= edgeEnergy * subjectRatio) return centerItem;
    if (motion > maxMotion || steadyCount < steadyFrames) return holdStill;
    return null;
  }
}

/// Counts quiet frames so the shutter opens after the phone settles.
class LiveShutterLock {
  int _steady = 0;

  int get steadyCount => _steady;

  String? consider({
    required double luma,
    required double motion,
    required double centerEnergy,
    required double edgeEnergy,
  }) {
    final quiet = motion <= LiveCaptureGate.maxMotion;
    _steady = quiet ? _steady + 1 : 0;
    return LiveCaptureGate.message(
      luma: luma,
      motion: motion,
      centerEnergy: centerEnergy,
      edgeEnergy: edgeEnergy,
      steadyCount: _steady,
    );
  }

  void reset() => _steady = 0;
}

/// Two hard shakes in a row mean the clip should stop.
class WhipWatch {
  static const double threshold = 16;
  int _hits = 0;

  bool add(double magnitude) {
    if (magnitude >= threshold) {
      _hits += 1;
    } else {
      _hits = 0;
    }
    return _hits >= 2;
  }

  void reset() => _hits = 0;
}
