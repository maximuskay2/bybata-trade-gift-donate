import 'package:image/image.dart' as img;

/// Why a listing photo cannot be used, in the words shown on the review screen.
class CaptureRejection {
  final String message;

  const CaptureRejection(this.message);
}

/// Bounding box of the lifted subject, in pixels of the cutout image.
class SubjectBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const SubjectBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;
}

/// Light, blur, and subject-size checks shared by trade, gift, and donation.
class CaptureGate {
  CaptureGate._();

  static const double minLuma = 36;
  static const double maxLuma = 248;
  static const double minSharpness = 12;
  static const double minCoverage = 0.08;
  static const double maxCoverage = 0.88;
  static const double edgeMargin = 0.015;

  static CaptureRejection? exposure(img.Image image) {
    final luma = meanLuma(image);
    if (luma < minLuma) return const CaptureRejection('Add light.');
    if (luma > maxLuma) {
      return const CaptureRejection('The shot is blown out. Turn away from the glare.');
    }
    return null;
  }

  static CaptureRejection? sharpness(img.Image image) {
    if (laplacianVariance(image) < minSharpness) {
      return const CaptureRejection('Hold still. The item is blurry.');
    }
    return null;
  }

  static CaptureRejection? subject({
    required SubjectBox? box,
    required int imageWidth,
    required int imageHeight,
  }) {
    if (box == null || box.width < 2 || box.height < 2 || imageWidth < 2 || imageHeight < 2) {
      return const CaptureRejection(
        'We could not find the item. Center it and try again.',
      );
    }

    final touchesEdge = box.left <= imageWidth * edgeMargin ||
        box.top <= imageHeight * edgeMargin ||
        box.right >= imageWidth * (1 - edgeMargin) ||
        box.bottom >= imageHeight * (1 - edgeMargin);
    if (touchesEdge) {
      return const CaptureRejection(
        'Step back a little so the whole item stays inside the frame.',
      );
    }

    final coverage = (box.width * box.height) / (imageWidth * imageHeight);
    if (coverage < minCoverage) {
      return const CaptureRejection(
        'Move closer so the item fills more of the frame.',
      );
    }
    if (coverage > maxCoverage) {
      return const CaptureRejection(
        'Step back a little so the whole item stays inside the frame.',
      );
    }
    return null;
  }

  static double meanLuma(img.Image image) {
    final sample = img.copyResize(image, width: 64);
    var sum = 0.0;
    var count = 0;
    for (final pixel in sample) {
      sum += pixel.r * 0.299 + pixel.g * 0.587 + pixel.b * 0.114;
      count++;
    }
    if (count == 0) return 0;
    return sum / count;
  }

  /// Variance of a 4-neighbour Laplacian. A flat frame scores near 0.
  static double laplacianVariance(img.Image image) {
    final sample = img.copyResize(image, width: image.width < 160 ? image.width : 160);
    final gray = img.grayscale(sample);
    if (gray.width < 3 || gray.height < 3) return 0;

    var sum = 0.0;
    var sumSq = 0.0;
    var count = 0;
    for (var y = 1; y < gray.height - 1; y++) {
      for (var x = 1; x < gray.width - 1; x++) {
        final center = gray.getPixel(x, y).r;
        final value = gray.getPixel(x - 1, y).r +
            gray.getPixel(x + 1, y).r +
            gray.getPixel(x, y - 1).r +
            gray.getPixel(x, y + 1).r -
            (4 * center);
        sum += value;
        sumSq += value * value;
        count++;
      }
    }
    if (count == 0) return 0;
    final mean = sum / count;
    return sumSq / count - mean * mean;
  }
}
